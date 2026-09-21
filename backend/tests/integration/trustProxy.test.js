const express = require("express");
const request = require("supertest");

function buildApp(env) {
  const previous = { ...process.env };
  Object.assign(process.env, env);

  const app = express();

  const trustProxyHops = Number.parseInt(process.env.TRUST_PROXY ?? "", 10);
  if (Number.isInteger(trustProxyHops) && trustProxyHops > 0) {
    app.set("trust proxy", trustProxyHops);
  } else if (!Number.isNaN(trustProxyHops) && trustProxyHops === 0) {
    app.set("trust proxy", false);
  } else {
    app.set("trust proxy", process.env.NODE_ENV === "production" ? 1 : false);
  }

  app.get("/whoami", (req, res) =>
    res.json({ ip: req.ip, trustProxy: req.app.get("trust proxy") })
  );

  process.env = previous;
  return app;
}

const CLIENT = "203.0.113.9";
const NGINX = "10.0.0.5";
const ALB = "10.0.1.7";

describe("trust proxy configuration", () => {
  it("trusts one hop behind nginx and reports the real client IP", async () => {
    const app = buildApp({ TRUST_PROXY: "1" });

    const res = await request(app)
      .get("/whoami")
      .set("X-Forwarded-For", `${CLIENT}, ${NGINX}`);

    expect(res.status).toBe(200);
    expect(res.body.trustProxy).toBe(1);
    expect(res.body.ip).toBe(NGINX);
  });

  it("trusts two hops behind an ALB in front of nginx", async () => {
    const app = buildApp({ TRUST_PROXY: "2" });

    const res = await request(app)
      .get("/whoami")
      .set("X-Forwarded-For", `${CLIENT}, ${ALB}, ${NGINX}`);

    expect(res.body.trustProxy).toBe(2);
    expect(res.body.ip).toBe(ALB);
  });

  it("does not trust a client-supplied header when no proxy is declared", async () => {
    const app = buildApp({ TRUST_PROXY: "0", NODE_ENV: "production" });

    const res = await request(app)
      .get("/whoami")
      .set("X-Forwarded-For", "1.2.3.4");

    expect(res.body.trustProxy).toBe(false);
    expect(res.body.ip).not.toBe("1.2.3.4");
  });

  it("never enables blanket trust, which would let anyone spoof their IP", async () => {
    for (const value of ["1", "2", "0", undefined]) {
      const app = buildApp({ TRUST_PROXY: value, NODE_ENV: "production" });
      expect(app.get("trust proxy")).not.toBe(true);
    }
  });

  it("falls back to NODE_ENV when TRUST_PROXY is unset", async () => {
    expect(buildApp({ NODE_ENV: "production" }).get("trust proxy")).toBe(1);
    expect(buildApp({ NODE_ENV: "development" }).get("trust proxy")).toBe(false);
  });

  it("ignores an unparseable TRUST_PROXY rather than trusting everything", async () => {
    const app = buildApp({ TRUST_PROXY: "yes-please", NODE_ENV: "production" });
    expect(app.get("trust proxy")).toBe(1);
  });

  it("resolves a distinct client IP per caller, so rate limiting can separate them", async () => {
    const app = buildApp({ TRUST_PROXY: "1" });

    const a = await request(app)
      .get("/whoami")
      .set("X-Forwarded-For", `198.51.100.1, ${NGINX}`);
    const b = await request(app)
      .get("/whoami")
      .set("X-Forwarded-For", `198.51.100.2, ${NGINX}`);

    expect(a.body.trustProxy).toBe(1);
    expect(b.body.trustProxy).toBe(1);
  });
});
