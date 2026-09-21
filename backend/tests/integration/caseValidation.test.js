const express = require("express");
const request = require("supertest");
const mongoose = require("mongoose");

const errorMiddleware = require("../../src/middleware/errorMiddleware");
const Case = require("../../src/models/Case");

function buildApp() {
  const app = express();
  app.use(express.json());

  app.post("/cases", (req, res, next) => {
    const doc = new Case({ ...req.body, client: req.body.client });
    const error = doc.validateSync();
    if (error) return next(error);
    res.status(201).json({ success: true, data: { title: doc.title } });
  });

  app.patch("/cases/:id", (req, res, next) => {
    if (!mongoose.isValidObjectId(req.params.id)) {
      const castError = new mongoose.Error.CastError("ObjectId", req.params.id, "_id");
      return next(castError);
    }
    const doc = new Case({
      client: new mongoose.Types.ObjectId(),
      title: "Existing",
      description: "Existing description",
      category: "Civil Cases",
      location: "Hyderabad",
      ...req.body,
    });
    const error = doc.validateSync();
    if (error) return next(error);
    res.json({ success: true, data: { status: doc.status } });
  });

  app.use(errorMiddleware);
  return app;
}

const app = buildApp();

const validCase = () => ({
  client: new mongoose.Types.ObjectId().toString(),
  title: "Recovery of unpaid fee",
  description: "The respondent has not paid the agreed consideration.",
  category: "Civil Cases",
  location: "Hyderabad",
});

describe("Case creation validation", () => {
  it("accepts a complete case", async () => {
    const res = await request(app).post("/cases").send(validCase());

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
  });

  it.each(["title", "description", "category", "location", "client"])(
    "rejects a case missing %s, and names that field",
    async (field) => {
      const payload = validCase();
      delete payload[field];

      const res = await request(app).post("/cases").send(payload);

      expect(res.status).toBe(400);
      expect(res.body.code).toBe("VALIDATION_ERROR");
      expect(res.body.fields).toHaveProperty(field);
      expect(res.body.fields[field]).toMatch(/required/i);
    }
  );

  it("reports every missing field at once, not just the first", async () => {
    const res = await request(app)
      .post("/cases")
      .send({ client: new mongoose.Types.ObjectId().toString() });

    expect(res.status).toBe(400);
    expect(Object.keys(res.body.fields).sort()).toEqual(
      expect.arrayContaining(["category", "description", "location", "title"])
    );
  });

  it("rejects an invalid status enum", async () => {
    const res = await request(app)
      .post("/cases")
      .send({ ...validCase(), status: "Definitely Not A Status" });

    expect(res.status).toBe(400);
    expect(res.body.fields.status).toMatch(/accepted values/i);
  });

  it("rejects a malformed ObjectId in a reference field", async () => {
    const res = await request(app)
      .post("/cases")
      .send({ ...validCase(), client: "not-an-object-id" });

    expect(res.status).toBe(400);
    expect(res.body.fields.client).toMatch(/valid reference/i);
  });

  it("never leaks Mongoose wording, the model name or the rejected value", async () => {
    const res = await request(app)
      .post("/cases")
      .send({ ...validCase(), client: "not-an-object-id", status: "Bogus" });

    const body = JSON.stringify(res.body);
    expect(body).not.toMatch(/Cast to ObjectId failed/i);
    expect(body).not.toMatch(/validation failed/i);
    expect(body).not.toMatch(/\bCase\b.*validation/i);
    expect(body).not.toContain("not-an-object-id");
    expect(body).not.toMatch(/at \w+ \(/);
  });

  it("uses readable field labels rather than raw schema paths", async () => {
    const payload = validCase();
    delete payload.location;

    const res = await request(app).post("/cases").send(payload);
    expect(res.body.fields.location).toBe("Location is required.");
  });
});

describe("Case update validation", () => {
  const id = () => new mongoose.Types.ObjectId().toString();

  it("accepts a valid update", async () => {
    const res = await request(app).patch(`/cases/${id()}`).send({ status: "Accepted" });

    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe("Accepted");
  });

  it("rejects an invalid enum on update", async () => {
    const res = await request(app).patch(`/cases/${id()}`).send({ status: "Nope" });

    expect(res.status).toBe(400);
    expect(res.body.code).toBe("VALIDATION_ERROR");
    expect(res.body.fields.status).toMatch(/accepted values/i);
  });

  it("rejects clearing a required field on update", async () => {
    const res = await request(app).patch(`/cases/${id()}`).send({ title: "" });

    expect(res.status).toBe(400);
    expect(res.body.fields.title).toMatch(/required/i);
  });

  it("answers a malformed id with INVALID_IDENTIFIER, not a 500", async () => {
    const res = await request(app).patch("/cases/not-a-real-id").send({ status: "Accepted" });

    expect(res.status).toBe(400);
    expect(res.body.code).toBe("INVALID_IDENTIFIER");
    expect(JSON.stringify(res.body)).not.toContain("not-a-real-id");
  });
});
