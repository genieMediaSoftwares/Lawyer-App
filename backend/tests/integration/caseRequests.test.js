const request = require("supertest");
const mongoose = require("mongoose");
const jwt = require("jsonwebtoken");

const TEST_MONGO_URI = process.env.TEST_MONGO_URI;
const describeWithDb = TEST_MONGO_URI ? describe : describe.skip;

process.env.JWT_SECRET = process.env.JWT_SECRET || "case-requests-test-secret";

const app = require("../../src/app");
const Case = require("../../src/models/Case");
const User = require("../../src/models/User");
const Notification = require("../../src/models/Notification");
const Chat = require("../../src/models/Chat");

const tokenFor = (user) =>
  jwt.sign({ id: user._id.toString(), role: user.role }, process.env.JWT_SECRET, { expiresIn: "15m" });

let counter = 0;
const makeUser = (role, extra = {}) => {
  counter += 1;
  return User.create({
    fullName: `${role} ${counter}`,
    email: `${role}${counter}-${Date.now()}@example.test`,
    mobile: `9${String(counter).padStart(9, "0")}`,
    password: "Password123",
    role,
    ...extra,
  });
};

const casePayload = (lawyers, extra = {}) => ({
  title: "Recovery of unpaid rent",
  description: "Tenant has not paid rent for six months.",
  category: "Civil Cases",
  location: "Hyderabad",
  selectedLawyers: lawyers.map((l) => (l._id ? l._id.toString() : l)),
  ...extra,
});

const post = (path, user, body) =>
  request(app).post(`/api${path}`).set("Authorization", `Bearer ${tokenFor(user)}`).send(body);
const get = (path, user) =>
  request(app).get(`/api${path}`).set("Authorization", `Bearer ${tokenFor(user)}`);

describeWithDb("Multi-lawyer case requests", () => {
  let client;
  let lawyers;
  let outsider;

  beforeAll(async () => {
    await mongoose.connect(TEST_MONGO_URI);
    if (!/test/i.test(mongoose.connection.name)) {
      throw new Error("TEST_MONGO_URI must point at a database whose name contains 'test'.");
    }
    await Case.init();
  });

  beforeEach(async () => {
    await Promise.all([
      Case.deleteMany({}),
      User.deleteMany({}),
      Notification.deleteMany({}),
      Chat.deleteMany({}),
    ]);
    client = await makeUser("client");
    lawyers = [await makeUser("lawyer"), await makeUser("lawyer"), await makeUser("lawyer")];
    outsider = await makeUser("lawyer");
  });

  afterAll(async () => {
    if (mongoose.connection.readyState === 1) {
      await mongoose.connection.dropDatabase();
      await mongoose.disconnect();
    }
  });

  const createCase = async () => {
    const res = await post("/cases", client, casePayload(lawyers));
    expect(res.status).toBe(201);
    return res.body.data._id;
  };

  describe("creating a case", () => {
    it("creates ONE case with exactly three pending lawyer requests", async () => {
      const res = await post("/cases", client, casePayload(lawyers));

      expect(res.status).toBe(201);
      expect(await Case.countDocuments()).toBe(1);

      const saved = await Case.findById(res.body.data._id).lean();
      expect(saved.status).toBe("Awaiting Lawyer Acceptance");
      expect(saved.assignedLawyer ?? null).toBeNull();
      expect(saved.lawyerRequests).toHaveLength(3);
      expect(saved.lawyerRequests.every((r) => r.status === "Pending")).toBe(true);
      expect(saved.lawyerRequests.map((r) => r.lawyer.toString()).sort()).toEqual(
        lawyers.map((l) => l._id.toString()).sort()
      );
    });

    it("notifies exactly the three selected lawyers", async () => {
      await createCase();

      const notified = await Notification.find({ type: "case_posted" }).lean();
      expect(notified.map((n) => n.receiverId.toString()).sort()).toEqual(
        lawyers.map((l) => l._id.toString()).sort()
      );
    });

    it.each([
      ["no lawyers", () => []],
      ["one lawyer", () => lawyers.slice(0, 1)],
      ["two lawyers", () => lawyers.slice(0, 2)],
      ["four lawyers", () => [...lawyers, outsider]],
    ])("rejects %s", async (_, pick) => {
      const res = await post("/cases", client, casePayload(pick()));

      expect(res.status).toBe(400);
      expect(res.body).toEqual({ success: false, message: "Exactly 3 lawyers must be selected." });
      expect(await Case.countDocuments()).toBe(0);
    });

    it("rejects a missing lawyer list", async () => {
      const payload = casePayload(lawyers);
      delete payload.selectedLawyers;

      const res = await post("/cases", client, payload);

      expect(res.status).toBe(400);
      expect(res.body.message).toBe("Exactly 3 lawyers must be selected.");
    });

    it("rejects duplicate lawyer ids", async () => {
      const res = await post("/cases", client, casePayload([lawyers[0], lawyers[0], lawyers[1]]));

      expect(res.status).toBe(400);
      expect(res.body.message).toBe("The same lawyer cannot be selected more than once.");
      expect(await Case.countDocuments()).toBe(0);
    });

    it.each([
      ["a malformed id", () => "not-an-id"],
      ["an unknown id", () => new mongoose.Types.ObjectId().toString()],
      ["a client instead of a lawyer", async () => (await makeUser("client"))._id.toString()],
      ["an inactive lawyer", async () => (await makeUser("lawyer", { isActive: false }))._id.toString()],
    ])("rejects %s", async (_, makeId) => {
      const badId = await makeId();
      const res = await post("/cases", client, casePayload([lawyers[0], lawyers[1], badId]));

      expect(res.status).toBe(400);
      expect(res.body.message).toBe("One or more selected lawyers are not available.");
      expect(await Case.countDocuments()).toBe(0);
    });

    it("rejects the client selecting themselves", async () => {
      const res = await post("/cases", client, casePayload([lawyers[0], lawyers[1], client]));

      expect(res.status).toBe(400);
      expect(await Case.countDocuments()).toBe(0);
    });

    it("does not let a lawyer post a case", async () => {
      const res = await post("/cases", lawyers[0], casePayload([lawyers[1], lawyers[2], outsider]));

      expect(res.status).toBe(403);
      expect(await Case.countDocuments()).toBe(0);
    });

    it("ignores a client id in the body and files the case under the caller", async () => {
      const otherClient = await makeUser("client");
      const res = await post("/cases", client, casePayload(lawyers, { client: otherClient._id.toString() }));

      expect(res.status).toBe(201);
      const saved = await Case.findById(res.body.data._id).lean();
      expect(saved.client.toString()).toBe(client._id.toString());
    });

    it("creates one case when the same submission arrives twice at once", async () => {
      const payload = casePayload(lawyers, { clientRequestId: "submit-abc12345" });

      const [first, second] = await Promise.all([
        post("/cases", client, payload),
        post("/cases", client, payload),
      ]);

      expect([first.status, second.status].sort()).toEqual([200, 201]);
      expect(first.body.data._id).toBe(second.body.data._id);
      expect(await Case.countDocuments()).toBe(1);
      expect(await Notification.countDocuments({ type: "case_posted" })).toBe(3);
    });

    it("returns the existing case for a retried submission", async () => {
      const payload = casePayload(lawyers, { clientRequestId: "submit-retry-001" });

      const first = await post("/cases", client, payload);
      const retry = await post("/cases", client, payload);

      expect(first.status).toBe(201);
      expect(retry.status).toBe(200);
      expect(retry.body.data._id).toBe(first.body.data._id);
      expect(await Case.countDocuments()).toBe(1);
    });
  });

  describe("lawyer requests", () => {
    it("shows the request as pending to all three lawyers and not to others", async () => {
      const caseId = await createCase();

      for (const lawyer of lawyers) {
        const res = await get("/lawyers/leads", lawyer);
        const lead = res.body.data.find((l) => l.caseId === caseId);
        expect(lead).toBeDefined();
        expect(lead.requestStatus).toBe("Pending");
      }

      const res = await get("/lawyers/leads", outsider);
      expect(res.body.data.find((l) => l.caseId === caseId)).toBeUndefined();
    });

    it("lets an invited lawyer read the case, seeing only their own request", async () => {
      const caseId = await createCase();

      const res = await get(`/cases/${caseId}`, lawyers[1]);

      expect(res.status).toBe(200);
      expect(res.body.data.myRequestStatus).toBe("Pending");
      expect(res.body.data.lawyerRequests).toHaveLength(1);
      expect(res.body.data.lawyerRequests[0].lawyer._id).toBe(lawyers[1]._id.toString());
    });

    it("refuses the case to a lawyer who was not invited", async () => {
      const caseId = await createCase();

      const res = await get(`/cases/${caseId}`, outsider);

      expect(res.status).toBe(403);
      expect(res.body.data).toBeUndefined();
    });

    it("gives an invited lawyer the client's name but not their contact details", async () => {
      const caseId = await createCase();

      const res = await get(`/cases/${caseId}`, lawyers[1]);

      expect(res.body.data.client.fullName).toBe(client.fullName);
      expect(res.body.data.client.email).toBeUndefined();
      expect(res.body.data.client.mobile).toBeUndefined();
    });
  });

  describe("accepting a request", () => {
    it("refuses a lawyer who was not invited", async () => {
      const caseId = await createCase();

      const res = await post(`/cases/${caseId}/accept-request`, outsider);

      expect(res.status).toBe(403);
      expect(res.body).toEqual({
        success: false,
        message: "You are not authorized to respond to this case request.",
      });
      const saved = await Case.findById(caseId).lean();
      expect(saved.assignedLawyer ?? null).toBeNull();
    });

    it("refuses a client accepting on a lawyer's behalf", async () => {
      const caseId = await createCase();

      const res = await post(`/cases/${caseId}/accept-request`, client);

      expect(res.status).toBe(403);
    });

    it("returns 404 for an unknown or malformed case id", async () => {
      const unknown = await post(`/cases/${new mongoose.Types.ObjectId()}/accept-request`, lawyers[0]);
      const malformed = await post("/cases/not-an-id/accept-request", lawyers[0]);

      expect(unknown.status).toBe(404);
      expect(unknown.body.message).toBe("Case request not found.");
      expect(malformed.status).toBe(404);
    });

    it("assigns the first lawyer and closes the other two requests", async () => {
      const caseId = await createCase();

      const res = await post(`/cases/${caseId}/accept-request`, lawyers[0]);

      expect(res.status).toBe(200);
      const saved = await Case.findById(caseId).lean();
      expect(saved.status).toBe("Accepted");
      expect(saved.assignedLawyer.toString()).toBe(lawyers[0]._id.toString());
      expect(saved.acceptedAt).toBeTruthy();

      const byLawyer = Object.fromEntries(saved.lawyerRequests.map((r) => [r.lawyer.toString(), r]));
      expect(byLawyer[lawyers[0]._id].status).toBe("Accepted");
      expect(byLawyer[lawyers[0]._id].acceptedAt).toBeTruthy();
      expect(byLawyer[lawyers[1]._id].status).toBe("Unavailable");
      expect(byLawyer[lawyers[2]._id].status).toBe("Unavailable");
    });

    it("stops the other two lawyers accepting through the API", async () => {
      const caseId = await createCase();
      await post(`/cases/${caseId}/accept-request`, lawyers[0]);

      for (const lawyer of [lawyers[1], lawyers[2]]) {
        const res = await post(`/cases/${caseId}/accept-request`, lawyer);
        expect(res.status).toBe(409);
        expect(res.body).toEqual({
          success: false,
          message: "This case has already been accepted by another lawyer.",
        });
      }

      const saved = await Case.findById(caseId).lean();
      expect(saved.assignedLawyer.toString()).toBe(lawyers[0]._id.toString());
    });

    it("shows the other lawyers the request as unavailable, with the reason", async () => {
      const caseId = await createCase();
      await post(`/cases/${caseId}/accept-request`, lawyers[0]);

      const res = await get("/lawyers/leads", lawyers[1]);
      const lead = res.body.data.find((l) => l.caseId === caseId);

      expect(lead.requestStatus).toBe("Unavailable");
      expect(lead.unavailableReason).toBe("This case has already been accepted by another lawyer.");
      expect(lead.location).toBe("");
      const detail = await get(`/cases/${caseId}`, lawyers[1]);
      expect(detail.status).toBe(409);
      expect(detail.body).toEqual({
        success: false,
        message: "This case has already been accepted by another lawyer.",
      });
    });

    it("lets exactly ONE of three simultaneous acceptances succeed", async () => {
      for (let round = 0; round < 10; round += 1) {
        const caseId = await createCase();

        const responses = await Promise.all(
          lawyers.map((lawyer) => post(`/cases/${caseId}/accept-request`, lawyer))
        );

        const winners = responses.filter((r) => r.status === 200);
        const losers = responses.filter((r) => r.status === 409);
        expect(winners).toHaveLength(1);
        expect(losers).toHaveLength(2);
        losers.forEach((r) =>
          expect(r.body.message).toBe("This case has already been accepted by another lawyer.")
        );

        const saved = await Case.findById(caseId).lean();
        const accepted = saved.lawyerRequests.filter((r) => r.status === "Accepted");
        expect(accepted).toHaveLength(1);
        expect(saved.lawyerRequests.filter((r) => r.status === "Unavailable")).toHaveLength(2);
        expect(saved.assignedLawyer.toString()).toBe(accepted[0].lawyer.toString());
      }
    });

    it("treats a repeated acceptance by the winner as a safe no-op", async () => {
      const caseId = await createCase();

      const responses = await Promise.all([
        post(`/cases/${caseId}/accept-request`, lawyers[0]),
        post(`/cases/${caseId}/accept-request`, lawyers[0]),
        post(`/cases/${caseId}/accept-request`, lawyers[0]),
      ]);

      expect(responses.every((r) => r.status === 200)).toBe(true);
      const saved = await Case.findById(caseId).lean();
      expect(saved.assignedLawyer.toString()).toBe(lawyers[0]._id.toString());
      expect(saved.lawyerRequests.filter((r) => r.status === "Accepted")).toHaveLength(1);
      expect(await Chat.countDocuments()).toBe(1);
      expect(
        await Notification.countDocuments({ receiverId: client._id, type: "proposal_accepted" })
      ).toBe(1);
    });

    it("does not let a lawyer accept after declining", async () => {
      const caseId = await createCase();
      await post(`/cases/${caseId}/reject-request`, lawyers[1]);

      const res = await post(`/cases/${caseId}/accept-request`, lawyers[1]);

      expect(res.status).toBe(409);
      expect(res.body.message).toBe("You have already declined this case request.");
    });

    it("does not reopen a closed case", async () => {
      const caseId = await createCase();
      await Case.updateOne({ _id: caseId }, { $set: { status: "Closed" } });

      const res = await post(`/cases/${caseId}/accept-request`, lawyers[0]);

      expect(res.status).toBe(409);
      expect(res.body.message).toBe("This case request is no longer available.");
    });
  });

  describe("declining a request", () => {
    it("declines one request and leaves the others open", async () => {
      const caseId = await createCase();

      const res = await post(`/cases/${caseId}/reject-request`, lawyers[0]);

      expect(res.status).toBe(200);
      const saved = await Case.findById(caseId).lean();
      expect(saved.status).toBe("Awaiting Lawyer Acceptance");
      expect(saved.lawyerRequests.map((r) => r.status).sort()).toEqual(["Declined", "Pending", "Pending"]);

      const accept = await post(`/cases/${caseId}/accept-request`, lawyers[1]);
      expect(accept.status).toBe(200);
    });

    it("marks the case rejected once all three decline", async () => {
      const caseId = await createCase();

      for (const lawyer of lawyers) {
        await post(`/cases/${caseId}/reject-request`, lawyer);
      }

      const saved = await Case.findById(caseId).lean();
      expect(saved.status).toBe("Rejected");
    });

    it("refuses a lawyer who was not invited", async () => {
      const caseId = await createCase();

      const res = await post(`/cases/${caseId}/reject-request`, outsider);

      expect(res.status).toBe(403);
    });

    it("cannot decline a case another lawyer already accepted", async () => {
      const caseId = await createCase();
      await post(`/cases/${caseId}/accept-request`, lawyers[0]);

      const res = await post(`/cases/${caseId}/reject-request`, lawyers[1]);

      expect(res.status).toBe(409);
      expect(res.body.message).toBe("This case has already been accepted by another lawyer.");
    });
  });

  describe("client proposal acceptance", () => {
    it("does not let another user assign a lawyer to someone else's case", async () => {
      const caseId = await createCase();
      const intruder = await makeUser("client");

      const res = await post(`/cases/${caseId}/accept`, intruder, { lawyerId: outsider._id.toString() });

      expect(res.status).toBe(404);
      const saved = await Case.findById(caseId).lean();
      expect(saved.assignedLawyer ?? null).toBeNull();
    });
  });
});
