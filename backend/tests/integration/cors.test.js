const request = require("supertest");

const loadApp = (env) => {
  const saved = { ...process.env };
  Object.assign(process.env, { JWT_SECRET: "cors-test-secret", ...env });
  let app;
  jest.isolateModules(() => {
    app = require("../../src/app");
  });
  process.env = saved;
  return app;
};

const originHeader = async (app, origin) =>
  (await request(app).get("/api").set("Origin", origin)).headers["access-control-allow-origin"];

describe("CORS in production", () => {
  const app = loadApp({
    NODE_ENV: "production",
    ALLOWED_ORIGINS: "http://127.0.0.1:5174, http://localhost:5174/",
  });

  test("always allows Admin Panel origin https://lawappadmin.vercel.app in production", async () => {
    expect(await originHeader(app, "https://lawappadmin.vercel.app")).toBe("https://lawappadmin.vercel.app");
  });

  test("allows each listed origin, and echoes it rather than '*'", async () => {
    expect(await originHeader(app, "http://127.0.0.1:5174")).toBe("http://127.0.0.1:5174");
    expect(await originHeader(app, "http://localhost:5174")).toBe("http://localhost:5174");
  });

  test("refuses an origin that is not listed", async () => {
    expect(await originHeader(app, "https://unrelated-site.example")).toBeUndefined();
    expect(await originHeader(app, "http://127.0.0.1:9999")).toBeUndefined();
  });

  test("answers the optimize preflight for an allowed origin", async () => {
    const res = await request(app)
      .options("/api/ai/smart-case/optimize")
      .set("Origin", "http://127.0.0.1:5174")
      .set("Access-Control-Request-Method", "POST")
      .set("Access-Control-Request-Headers", "authorization");

    expect(res.status).toBe(204);
    expect(res.headers["access-control-allow-origin"]).toBe("http://127.0.0.1:5174");
    expect(res.headers["access-control-allow-credentials"]).toBe("true");
  });

  test("answers preflight for Admin Panel origin https://lawappadmin.vercel.app", async () => {
    const res = await request(app)
      .options("/api/auth/login")
      .set("Origin", "https://lawappadmin.vercel.app")
      .set("Access-Control-Request-Method", "POST")
      .set("Access-Control-Request-Headers", "content-type,authorization");

    expect(res.status).toBe(204);
    expect(res.headers["access-control-allow-origin"]).toBe("https://lawappadmin.vercel.app");
    expect(res.headers["access-control-allow-credentials"]).toBe("true");
  });

  test("ignores a '*' entry instead of opening the API to every site", async () => {
    const open = loadApp({ NODE_ENV: "production", ALLOWED_ORIGINS: "*" });
    expect(await originHeader(open, "https://unrelated-site.example")).toBeUndefined();
  });
});

describe("CORS outside production", () => {
  const app = loadApp({ NODE_ENV: "development", ALLOWED_ORIGINS: "" });

  test("allows a local browser preview on any port", async () => {
    expect(await originHeader(app, "http://127.0.0.1:5174")).toBe("http://127.0.0.1:5174");
    expect(await originHeader(app, "http://localhost:8081")).toBe("http://localhost:8081");
  });

  test("still refuses other sites", async () => {
    expect(await originHeader(app, "https://unrelated-site.example")).toBeUndefined();
  });
});

describe("nginx 413 hand-off", () => {
  const app = loadApp({ NODE_ENV: "production", ALLOWED_ORIGINS: "http://127.0.0.1:5174" });

  test("returns a JSON 413 that the browser is allowed to read", async () => {
    const res = await request(app)
      .get("/api/errors/payload-too-large")
      .set("Origin", "http://127.0.0.1:5174");

    expect(res.status).toBe(413);
    expect(res.body).toMatchObject({ success: false, code: "PAYLOAD_TOO_LARGE" });
    expect(res.headers["access-control-allow-origin"]).toBe("http://127.0.0.1:5174");
  });
});
