/**
 * End-to-end exercise of the authentication flow.
 *
 * Everything above the database is real: routes, validation, rate limiters,
 * controllers, authService, sessionService, authMiddleware and the error
 * handler. Only the two Mongoose models are replaced, with in-memory fakes that
 * reproduce the query shapes those layers actually use — including the unique
 * indexes, so the duplicate-key path can be exercised the way Mongo would
 * really trigger it.
 *
 * The models are faked rather than pointed at a live database because the
 * configured MONGO_URI is a shared cluster; a test suite must not write there.
 */
process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";
process.env.JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || "7d";
process.env.NODE_ENV = "test";

// ---------------------------------------------------------------------------
// In-memory stand-ins for the two collections this flow touches.
//
// The `mock` prefix is required: Jest hoists jest.mock() factories above the
// imports and only lets them close over variables named this way.
// ---------------------------------------------------------------------------

const mockUsers = [];
const mockSessions = [];
const mockState = { nextId: 1 };

/** Imitates a unique-index violation, message and all. */
const mockDuplicateKeyError = (field, value) => {
  const error = new Error(
    `E11000 duplicate key error collection: law.users index: ${field}_1 dup key: { ${field}: "${value}" }`
  );
  error.code = 11000;
  error.keyPattern = { [field]: 1 };
  return error;
};

jest.mock("../../src/models/User", () => {
  const bcrypt = require("bcryptjs");

  const matches = (user, query) =>
    Object.entries(query).every(([key, value]) => {
      if (value && typeof value === "object" && value.$regex) {
        return new RegExp(value.$regex, value.$options).test(user[key]);
      }
      return String(user[key]) === String(value);
    });

  // Stands in for a Mongoose Query: awaitable on its own AND chainable through
  // .select(). Returning only `{select}` meant `await User.findById(id)` — the
  // form userRepository uses — resolved to the helper object itself rather than
  // to the document, so a caller that did not chain .select() silently got a
  // user with no fields. `.select()` filtering is still a no-op; the fake
  // documents carry every field and nothing under test asserts on it.
  const selectable = (value) => ({
    select: () => Promise.resolve(value),
    then: (resolve, reject) => Promise.resolve(value).then(resolve, reject),
  });

  return {
    findOne: (query) =>
      selectable(mockUsers.find((u) => matches(u, query)) || null),
    findById: (id) =>
      selectable(mockUsers.find((u) => String(u._id) === String(id)) || null),
    findByIdAndUpdate: async (id, data) => {
      const user = mockUsers.find((u) => String(u._id) === String(id));
      if (user) Object.assign(user, data);
      return user || null;
    },
    findByIdAndDelete: async (id) => {
      const index = mockUsers.findIndex((u) => String(u._id) === String(id));
      return index >= 0 ? mockUsers.splice(index, 1)[0] : null;
    },
    create: async (data) => {
      // The real guarantee is the unique index, not the pre-insert check.
      if (mockUsers.some((u) => u.email === data.email)) {
        throw mockDuplicateKeyError("email", data.email);
      }
      if (mockUsers.some((u) => u.mobile === data.mobile)) {
        throw mockDuplicateKeyError("mobile", data.mobile);
      }

      const user = {
        _id: `user-${mockState.nextId++}`,
        profileImage: "",
        location: "",
        isActive: true,
        ...data,
        // Mirrors the schema's `lowercase: true` and the pre-save hash hook.
        email: String(data.email).toLowerCase(),
        // Cost 4 rather than the schema's 10 — this suite hashes a lot.
        password: await bcrypt.hash(data.password, 4),
        comparePassword(candidate) {
          return bcrypt.compare(candidate, this.password);
        },
      };
      mockUsers.push(user);
      return user;
    },
  };
});

jest.mock("../../src/models/RefreshToken", () => {
  const matches = (row, query) =>
    Object.entries(query).every(([key, value]) => {
      if (key === "expiresAt" && value && value.$gt) {
        return row.expiresAt > value.$gt;
      }
      return String(row[key]) === String(value);
    });

  return {
    create: async (data) => {
      const row = { ...data, createdAt: new Date() };
      mockSessions.push(row);
      return row;
    },
    findOne: (query) => ({
      sort: async () =>
        [...mockSessions].reverse().find((row) => matches(row, query)) || null,
    }),
    find: (query) => ({
      sort: async () => [...mockSessions].reverse().filter((row) => matches(row, query)),
    }),
    /**
     * Mongo applies findOneAndUpdate atomically, which is exactly the property
     * refresh-token rotation depends on: two requests spending the same token
     * must produce one winner. Node is single-threaded and this fake does no
     * awaiting between the match and the write, so it reproduces that.
     */
    findOneAndUpdate: async (query, update) => {
      const row = mockSessions.find((r) => matches(r, query));
      if (!row) return null;
      Object.assign(row, update.$set);
      return row;
    },
    exists: async (query) =>
      mockSessions.some((row) => matches(row, query)) ? { _id: "x" } : null,
    updateOne: async (query, update) => {
      const row = mockSessions.find((r) => matches(r, query));
      if (row) Object.assign(row, update.$set);
      return { modifiedCount: row ? 1 : 0 };
    },
    updateMany: async (query, update) => {
      const rows = mockSessions.filter((r) => matches(r, query));
      rows.forEach((row) => Object.assign(row, update.$set));
      return { modifiedCount: rows.length };
    },
  };
});

const request = require("supertest");
const AUTH_CODES = require("../../src/utils/authCodes");

/**
 * Rebuilt for every test — see the beforeEach.
 *
 * The rate limiters keep their counters in a store created when app.js is first
 * evaluated, and supertest presents the same loopback address every time, so a
 * single app instance would have the whole suite sharing one bucket: later
 * tests would start failing on the accumulated traffic of earlier ones. That is
 * correct behaviour for the limiter and useless for a test, so each test gets
 * its own.
 */
let app;

const DEVICE_A = "device-aaa";
const DEVICE_B = "device-bbb";

const SIGNUP = {
  fullName: "Asha Menon",
  email: "asha@example.com",
  mobile: "9876543210",
  password: "secret123",
  role: "client",
};

const signup = (overrides = {}) =>
  request(app)
    .post("/api/auth/signup")
    .send({ ...SIGNUP, deviceId: DEVICE_A, ...overrides });

const login = (overrides = {}) =>
  request(app)
    .post("/api/auth/login")
    .send({
      email: SIGNUP.email,
      password: SIGNUP.password,
      deviceId: DEVICE_A,
      ...overrides,
    });

const DEVICE_C = "device-ccc";

/** The session id a token names, so two logins can be shown to be distinct. */
const decodeSid = (token) =>
  require("jsonwebtoken").decode(token)?.sid;

const profile = (token) =>
  request(app).get("/api/auth/profile").set("Authorization", `Bearer ${token}`);

const refresh = (refreshToken) =>
  request(app).post("/api/auth/refresh-token").send({ refreshToken });

const logoutAll = (token) =>
  request(app)
    .post("/api/auth/logout-all")
    .set("Authorization", `Bearer ${token}`)
    .send({});

const logout = (token) =>
  request(app).post("/api/auth/logout").set("Authorization", `Bearer ${token}`);

/** Signs up, then signs out, leaving one account and no live session. */
const registerAccount = async () => {
  const response = await signup();
  await logout(response.body.data.token);
  return response;
};

beforeEach(() => {
  mockUsers.length = 0;
  mockSessions.length = 0;
  mockState.nextId = 1;

  // Fresh module registry, and therefore fresh rate-limit counters. The
  // jest.mock registrations above survive this.
  jest.resetModules();
  app = require("../../src/app");
});

describe("Signup", () => {
  it("registers a new account", async () => {
    const response = await signup();

    expect(response.status).toBe(201);
    expect(response.body.success).toBe(true);
    expect(response.body.data.user.email).toBe("asha@example.com");
    expect(response.body.data.token).toEqual(expect.any(String));
  });

  it("rejects an email that is already registered, with a code", async () => {
    await registerAccount();

    const response = await signup({ mobile: "9000000001" });

    expect(response.status).toBe(409);
    expect(response.body.message).toBe(
      "This email is already registered. Please use another email or sign in."
    );
    expect(response.body.code).toBe(AUTH_CODES.EMAIL_ALREADY_REGISTERED);
  });

  it("matches an existing email regardless of the casing typed", async () => {
    await registerAccount();

    const response = await signup({
      email: "ASHA@Example.COM",
      mobile: "9000000002",
    });

    expect(response.status).toBe(409);
    expect(response.body.code).toBe(AUTH_CODES.EMAIL_ALREADY_REGISTERED);
  });

  it("rejects a mobile number that is already registered", async () => {
    await registerAccount();

    const response = await signup({ email: "someone.else@example.com" });

    expect(response.status).toBe(409);
    expect(response.body.message).toBe(
      "This mobile number is already registered. Please use another number or sign in."
    );
    expect(response.body.code).toBe(AUTH_CODES.MOBILE_ALREADY_REGISTERED);
  });

  it("allows a second account with the same display name", async () => {
    // Real names collide. Uniqueness is off for fullName by design — see
    // REQUIRE_UNIQUE_FULL_NAME in authService.
    await registerAccount();

    const response = await signup({
      email: "asha.other@example.com",
      mobile: "9000000003",
    });

    expect(response.status).toBe(201);
  });

  it("reports a lost duplicate-key race as a duplicate, not a server error", async () => {
    // The pre-insert check passes and the unique index rejects the write — the
    // window a concurrent signup slips through. The user must see the same
    // message either way, and never the driver's.
    const User = require("../../src/models/User");
    const originalFindOne = User.findOne;
    User.findOne = () => ({ select: () => Promise.resolve(null) });

    try {
      await signup(); // occupies the address
      const response = await signup(); // loses the race

      expect(response.status).toBe(409);
      expect(response.body.code).toBe(AUTH_CODES.EMAIL_ALREADY_REGISTERED);
      expect(response.body.message).not.toMatch(/E11000|index|collection/i);
    } finally {
      User.findOne = originalFindOne;
    }
  });
});

describe("Login", () => {
  it("rejects a wrong password with a specific message", async () => {
    await registerAccount();

    const response = await login({ password: "wrong-password" });

    expect(response.status).toBe(401);
    expect(response.body.message).toBe("Invalid email or password.");
    expect(response.body.code).toBe(AUTH_CODES.INVALID_CREDENTIALS);
  });

  it("rejects an unknown email identically, revealing nothing", async () => {
    const response = await login({ email: "nobody@example.com" });

    expect(response.status).toBe(401);
    expect(response.body.message).toBe("Invalid email or password.");
    expect(response.body.code).toBe(AUTH_CODES.INVALID_CREDENTIALS);
  });

  it("accepts correct credentials", async () => {
    await registerAccount();

    const response = await login();

    expect(response.status).toBe(200);
    expect(response.body.data.token).toEqual(expect.any(String));
    expect(response.body.data.user.email).toBe(SIGNUP.email);
  });

  it("accepts correct credentials typed with different casing", async () => {
    await registerAccount();

    const response = await login({ email: "Asha@Example.com" });

    expect(response.status).toBe(200);
  });

  it("never answers a failed login with a rate-limit message", async () => {
    await registerAccount();

    // Comfortably more than the five attempts the old limiter allowed.
    for (let attempt = 0; attempt < 12; attempt++) {
      const response = await login({ password: "wrong-password" });

      expect(response.status).toBe(401);
      expect(response.body.message).toBe("Invalid email or password.");
    }

    // And the account is still reachable afterwards.
    expect((await login()).status).toBe(200);
  });

  it("does not spend the abuse budget on successful logins", async () => {
    await registerAccount();

    for (let attempt = 0; attempt < 15; attempt++) {
      const response = await login();
      expect(response.status).toBe(200);
      await logout(response.body.data.token);
    }
  });
});

describe("Multi-device sessions", () => {
  it("lets three devices hold the same account at once", async () => {
    await registerAccount();

    const a = await login({ deviceId: DEVICE_A });
    const b = await login({ deviceId: DEVICE_B });
    const c = await login({ deviceId: DEVICE_C });

    expect(a.status).toBe(200);
    expect(b.status).toBe(200);
    expect(c.status).toBe(200);

    // Three independent sessions, not one being handed around.
    const sids = [a, b, c].map((r) => decodeSid(r.body.data.token));
    expect(new Set(sids).size).toBe(3);
  });

  it("never answers a second device with the old device-conflict error", async () => {
    await registerAccount();
    await login({ deviceId: DEVICE_A });

    const response = await login({ deviceId: DEVICE_B });

    expect(response.status).not.toBe(409);
    expect(response.body.message || "").not.toMatch(/already logged in/i);
    expect(response.body.code).not.toBe(AUTH_CODES.ACTIVE_SESSION_EXISTS);
  });

  it("keeps device A working after device B signs in", async () => {
    await registerAccount();
    const a = await login({ deviceId: DEVICE_A });
    const b = await login({ deviceId: DEVICE_B });

    expect((await profile(a.body.data.token)).status).toBe(200);
    expect((await profile(b.body.data.token)).status).toBe(200);
  });

  it("logs out one device without touching the others", async () => {
    await registerAccount();
    const a = await login({ deviceId: DEVICE_A });
    const b = await login({ deviceId: DEVICE_B });
    const c = await login({ deviceId: DEVICE_C });

    expect((await logout(a.body.data.token)).status).toBe(200);

    expect((await profile(a.body.data.token)).status).toBe(401);
    expect((await profile(b.body.data.token)).status).toBe(200);
    expect((await profile(c.body.data.token)).status).toBe(200);
  });

  it("signs every device out on logout-all", async () => {
    await registerAccount();
    const a = await login({ deviceId: DEVICE_A });
    const b = await login({ deviceId: DEVICE_B });
    const c = await login({ deviceId: DEVICE_C });

    expect((await logoutAll(a.body.data.token)).status).toBe(200);

    expect((await profile(a.body.data.token)).status).toBe(401);
    expect((await profile(b.body.data.token)).status).toBe(401);
    expect((await profile(c.body.data.token)).status).toBe(401);
  });

  it("lets the same device sign in again, replacing its own session", async () => {
    // The app was killed, so logout never ran. Routine, not a conflict — and it
    // must not leave two rows behind for one handset.
    await registerAccount();
    const first = await login({ deviceId: DEVICE_A });

    const second = await login({ deviceId: DEVICE_A });
    expect(second.status).toBe(200);

    // The replaced session stops working; the new one works.
    expect((await profile(first.body.data.token)).status).toBe(401);
    expect((await profile(second.body.data.token)).status).toBe(200);
  });

  it("records the device each session belongs to", async () => {
    await registerAccount();
    await login({ deviceId: DEVICE_A, deviceName: "Pixel 8", platform: "android" });

    // The live row, not the one signup opened and this login replaced.
    const session = mockSessions
      .filter((s) => s.deviceInfo === DEVICE_A && !s.isRevoked)
      .pop();
    expect(session.deviceName).toBe("Pixel 8");
    expect(session.platform).toBe("android");
  });
});

describe("Refresh tokens", () => {
  it("issues a refresh token at login", async () => {
    await registerAccount();
    const a = await login({ deviceId: DEVICE_A });

    expect(typeof a.body.data.refreshToken).toBe("string");
    expect(a.body.data.refreshToken.length).toBeGreaterThan(32);
  });

  it("never stores the refresh token in the clear", async () => {
    await registerAccount();
    const a = await login({ deviceId: DEVICE_A });
    const raw = a.body.data.refreshToken;

    const stored = mockSessions.find((s) => s.deviceInfo === DEVICE_A);
    expect(stored.refreshTokenHash).toBeTruthy();
    expect(stored.refreshTokenHash).not.toBe(raw);
    expect(JSON.stringify(mockSessions)).not.toContain(raw);
  });

  it("exchanges a refresh token for a working access token", async () => {
    await registerAccount();
    const a = await login({ deviceId: DEVICE_A });

    const refreshed = await refresh(a.body.data.refreshToken);

    expect(refreshed.status).toBe(200);
    expect((await profile(refreshed.body.data.token)).status).toBe(200);
  });

  it("keeps the refreshed token on the same session", async () => {
    await registerAccount();
    const a = await login({ deviceId: DEVICE_A });

    const refreshed = await refresh(a.body.data.refreshToken);

    expect(decodeSid(refreshed.body.data.token)).toBe(
      decodeSid(a.body.data.token)
    );
  });

  it("rotates the refresh token and rejects the spent one", async () => {
    await registerAccount();
    const a = await login({ deviceId: DEVICE_A });

    const first = await refresh(a.body.data.refreshToken);
    expect(first.status).toBe(200);
    expect(first.body.data.refreshToken).not.toBe(a.body.data.refreshToken);

    // Replaying the token that was just spent must fail.
    expect((await refresh(a.body.data.refreshToken)).status).toBe(401);

    // The one it was exchanged for still works.
    expect((await refresh(first.body.data.refreshToken)).status).toBe(200);
  });

  it("refreshing one device does not disturb another", async () => {
    await registerAccount();
    const a = await login({ deviceId: DEVICE_A });
    const b = await login({ deviceId: DEVICE_B });

    expect((await refresh(a.body.data.refreshToken)).status).toBe(200);

    // B's access token and refresh token both survive A's rotation.
    expect((await profile(b.body.data.token)).status).toBe(200);
    expect((await refresh(b.body.data.refreshToken)).status).toBe(200);
  });

  it("rejects an unknown refresh token", async () => {
    await registerAccount();
    await login({ deviceId: DEVICE_A });

    const response = await refresh("not-a-real-refresh-token");

    expect(response.status).toBe(401);
    expect(response.body.code).toBe(AUTH_CODES.SESSION_EXPIRED);
  });

  it("rejects a missing refresh token", async () => {
    expect((await refresh(undefined)).status).toBe(401);
  });

  it("rejects the refresh token of a revoked session", async () => {
    await registerAccount();
    const a = await login({ deviceId: DEVICE_A });

    await logout(a.body.data.token);

    expect((await refresh(a.body.data.refreshToken)).status).toBe(401);
  });

  it("survives two refreshes racing on the same token", async () => {
    // A device firing several requests at once gets several 401s at once and
    // may try to refresh more than once. Exactly one must win, and the session
    // must survive intact.
    await registerAccount();
    const a = await login({ deviceId: DEVICE_A });

    const [first, second] = await Promise.all([
      refresh(a.body.data.refreshToken),
      refresh(a.body.data.refreshToken),
    ]);

    const codes = [first.status, second.status].sort();
    expect(codes).toEqual([200, 401]);

    // The session itself is still usable by the winner.
    const winner = first.status === 200 ? first : second;
    expect((await profile(winner.body.data.token)).status).toBe(200);
  });
});

describe("Active sessions", () => {
  it("lets the original device sign in again after logging out", async () => {
    await registerAccount();

    const first = await login();
    await logout(first.body.data.token);

    const again = await login();
    expect(again.status).toBe(200);
  });

  it("stops honouring a token once its session is revoked", async () => {
    await registerAccount();

    const session = await login();
    const token = session.body.data.token;

    expect(
      (await request(app).get("/api/auth/profile").set("Authorization", `Bearer ${token}`))
        .status
    ).toBe(200);

    await logout(token);

    const response = await request(app)
      .get("/api/auth/profile")
      .set("Authorization", `Bearer ${token}`);

    expect(response.status).toBe(401);
    expect(response.body.code).toBe(AUTH_CODES.SESSION_EXPIRED);
  });

  it("still honours a token issued before session tracking existed", async () => {
    // Deploying this must not sign out everyone currently using the app.
    await registerAccount();
    const jwt = require("jsonwebtoken");
    const legacyToken = jwt.sign(
      { id: mockUsers[0]._id, role: mockUsers[0].role, email: mockUsers[0].email },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    const response = await request(app)
      .get("/api/auth/profile")
      .set("Authorization", `Bearer ${legacyToken}`);

    expect(response.status).toBe(200);
  });

  it("does not treat the session opened by signup as a rival device", async () => {
    const created = await signup({ deviceId: DEVICE_A });
    expect(created.status).toBe(201);

    // The signup screen sends the user to the login screen without keeping the
    // token, so this is the very next thing that happens on a real device.
    const response = await login({ deviceId: DEVICE_A });

    expect(response.status).toBe(200);
  });
});

describe("Error responses", () => {
  it("never leaks database internals", async () => {
    await registerAccount();

    const response = await signup({ mobile: "9000000009" });

    expect(JSON.stringify(response.body)).not.toMatch(
      /E11000|MongoServerError|keyPattern|law\.users/i
    );
  });

  it("rejects a malformed email at validation", async () => {
    const response = await login({ email: "not-an-email" });

    expect(response.status).toBe(400);
    expect(response.body.success).toBe(false);
  });
});
