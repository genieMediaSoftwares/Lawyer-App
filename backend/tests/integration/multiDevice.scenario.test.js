const path = require("path");

process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";
process.env.JWT_EXPIRES_IN = "15m";
process.env.JWT_REFRESH_EXPIRES_IN = "30d";
process.env.NODE_ENV = "test";

const mockUsers = [];
const mockSessions = [];
const mockState = { nextId: 1 };

jest.mock("../../src/models/User", () => {
  const bcrypt = require("bcryptjs");
  const matches = (user, query) =>
    Object.entries(query).every(([k, v]) => String(user[k]) === String(v));
  const selectable = (value) => ({
    select: () => Promise.resolve(value),
    then: (res, rej) => Promise.resolve(value).then(res, rej),
  });
  return {
    findOne: (q) => selectable(mockUsers.find((u) => matches(u, q)) || null),
    findById: (id) =>
      selectable(mockUsers.find((u) => String(u._id) === String(id)) || null),
    create: async (data) => {
      const user = {
        _id: `user-${mockState.nextId++}`,
        ...data,
        password: await bcrypt.hash(data.password, 4),
        profileImage: "",
        location: "",
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
    Object.entries(query).every(([k, v]) => {
      if (k === "expiresAt" && v && v.$gt) return row.expiresAt > v.$gt;
      return String(row[k]) === String(v);
    });
  return {
    create: async (data) => {
      const row = { ...data, createdAt: new Date() };
      mockSessions.push(row);
      return row;
    },
    findOne: (q) => ({
      sort: async () => [...mockSessions].reverse().find((r) => matches(r, q)) || null,
    }),
    find: (q) => ({
      sort: async () => [...mockSessions].reverse().filter((r) => matches(r, q)),
    }),
    findOneAndUpdate: async (q, u) => {
      const row = mockSessions.find((r) => matches(r, q));
      if (!row) return null;
      Object.assign(row, u.$set);
      return row;
    },
    exists: async (q) => (mockSessions.some((r) => matches(r, q)) ? { _id: "x" } : null),
    updateOne: async (q, u) => {
      const row = mockSessions.find((r) => matches(r, q));
      if (row) Object.assign(row, u.$set);
      return { modifiedCount: row ? 1 : 0 };
    },
    updateMany: async (q, u) => {
      const rows = mockSessions.filter((r) => matches(r, q));
      rows.forEach((r) => Object.assign(r, u.$set));
      return { modifiedCount: rows.length };
    },
  };
});

const request = require("supertest");
const app = require(path.join(__dirname, "../../src/app"));

const CREDENTIALS = { email: "multi@example.com", password: "Str0ng!Pass1" };

const login = (deviceId) =>
  request(app).post("/api/auth/login").send({ ...CREDENTIALS, deviceId });

const profile = (token) =>
  request(app).get("/api/auth/profile").set("Authorization", `Bearer ${token}`);

const logout = (token) =>
  request(app).post("/api/auth/logout").set("Authorization", `Bearer ${token}`).send({});

const logoutAll = (token) =>
  request(app)
    .post("/api/auth/logout-all")
    .set("Authorization", `Bearer ${token}`)
    .send({});

const report = [];
const step = (label, ok, detail) => {
  report.push(`${ok ? "PASS" : "FAIL"}  ${label}${detail ? ` — ${detail}` : ""}`);
  return ok;
};

describe("Multi-device acceptance sequence", () => {
  it("runs the full three-device scenario in order", async () => {
    await request(app).post("/api/auth/signup").send({
      fullName: "Multi Device",
      mobile: "9000012345",
      role: "client",
      deviceId: "setup-device",
      ...CREDENTIALS,
    });

    const a = await login("phone-a");
    const b = await login("phone-b");
    const c = await login("laptop-c");

    expect(step("Device A login", a.status === 200, `HTTP ${a.status}`)).toBe(true);
    expect(step("Device B login (same account)", b.status === 200, `HTTP ${b.status}`)).toBe(true);
    expect(step("Device C login (same account)", c.status === 200, `HTTP ${c.status}`)).toBe(true);

    const tokenA = a.body.data.token;
    const tokenB = b.body.data.token;
    const tokenC = c.body.data.token;

    const [pa, pb, pc] = await Promise.all([
      profile(tokenA),
      profile(tokenB),
      profile(tokenC),
    ]);
    expect(step("Device A request", pa.status === 200, `HTTP ${pa.status}`)).toBe(true);
    expect(step("Device B request", pb.status === 200, `HTTP ${pb.status}`)).toBe(true);
    expect(step("Device C request", pc.status === 200, `HTTP ${pc.status}`)).toBe(true);

    await logout(tokenA);

    const afterLogout = await Promise.all([
      profile(tokenA),
      profile(tokenB),
      profile(tokenC),
    ]);
    expect(step("After A logout: A rejected", afterLogout[0].status === 401,
      `HTTP ${afterLogout[0].status}`)).toBe(true);
    expect(step("After A logout: B still works", afterLogout[1].status === 200,
      `HTTP ${afterLogout[1].status}`)).toBe(true);
    expect(step("After A logout: C still works", afterLogout[2].status === 200,
      `HTTP ${afterLogout[2].status}`)).toBe(true);

    const all = await logoutAll(tokenB);
    expect(step("Logout-all accepted", all.status === 200, `HTTP ${all.status}`)).toBe(true);

    const afterAll = await Promise.all([
      profile(tokenA),
      profile(tokenB),
      profile(tokenC),
    ]);
    expect(step("After logout-all: A rejected", afterAll[0].status === 401,
      `HTTP ${afterAll[0].status}`)).toBe(true);
    expect(step("After logout-all: B rejected", afterAll[1].status === 401,
      `HTTP ${afterAll[1].status}`)).toBe(true);
    expect(step("After logout-all: C rejected", afterAll[2].status === 401,
      `HTTP ${afterAll[2].status}`)).toBe(true);

    // eslint-disable-next-line no-console
    console.log("\n" + report.join("\n") + "\n");
  });
});
