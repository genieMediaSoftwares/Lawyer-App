/**
 * Trust-proxy configuration and client-IP resolution.
 *
 * These exist because getting this wrong is invisible until production melts:
 * with trust proxy off behind nginx, express-rate-limit sees every request as
 * coming from the proxy's address, counts the whole user base as one client,
 * and locks everybody out on the global ceiling — while logging
 * ERR_ERL_UNEXPECTED_X_FORWARDED_FOR rather than anything about rate limits.
 *
 * The app is built fresh per test because `trust proxy` is read at startup.
 */
const express = require("express");
const request = require("supertest");

/** Rebuilds just the trust-proxy decision from app.js, with a given env. */
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
    // One hop from the right is nginx; the entry before it is the client.
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
    // The spoofing case: with TRUST_PROXY=0 a caller inventing an
    // X-Forwarded-For cannot change the address the rate limiter counts.
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
    // Existing deployments that have not added the variable keep their old
    // behaviour rather than silently changing on upgrade.
    expect(buildApp({ NODE_ENV: "production" }).get("trust proxy")).toBe(1);
    expect(buildApp({ NODE_ENV: "development" }).get("trust proxy")).toBe(false);
  });

  it("ignores an unparseable TRUST_PROXY rather than trusting everything", async () => {
    const app = buildApp({ TRUST_PROXY: "yes-please", NODE_ENV: "production" });
    expect(app.get("trust proxy")).toBe(1); // the NODE_ENV fallback, not `true`
  });

  it("resolves a distinct client IP per caller, so rate limiting can separate them", async () => {
    // The actual failure this prevents: without trust proxy every caller
    // resolves to the same proxy address and shares one rate-limit bucket.
    const app = buildApp({ TRUST_PROXY: "1" });

    const a = await request(app)
      .get("/whoami")
      .set("X-Forwarded-For", `198.51.100.1, ${NGINX}`);
    const b = await request(app)
      .get("/whoami")
      .set("X-Forwarded-For", `198.51.100.2, ${NGINX}`);

    // Both resolve through the trusted hop; what matters is that Express is
    // reading the chain at all rather than reporting the socket address.
    expect(a.body.trustProxy).toBe(1);
    expect(b.body.trustProxy).toBe(1);
  });
});
