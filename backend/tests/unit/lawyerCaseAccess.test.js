process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";

const mongoose = require("mongoose");

const mockState = { caseItem: null, lawyerCases: [] };

jest.mock("../../src/models/Case", () => {
  const chain = (resolve) => {
    const query = {
      populate: () => query,
      sort: () => query,
      select: () => query,
      lean: async () => resolve(),
      then: (ok, fail) => Promise.resolve(resolve()).then(ok, fail),
    };
    return query;
  };
  return {
    REQUIRED_LAWYER_COUNT: 3,
    findById: () => chain(() => (mockState.caseItem ? { ...mockState.caseItem } : null)),
    find: () => chain(() => mockState.lawyerCases),
  };
});

jest.mock("../../src/models/Lawyer", () => ({
  findOne: () => ({ lean: async () => null }),
}));
jest.mock("../../src/models/Proposal", () => ({}));
jest.mock("../../src/models/User", () => ({}));
jest.mock("../../src/services/notification/notificationService", () => ({
  createAndSendNotification: async () => null,
}));

const caseController = require("../../src/controllers/case/caseController");
const lawyerController = require("../../src/controllers/lawyer/lawyerController");

const id = () => new mongoose.Types.ObjectId();

const CLIENT_ID = id();
const ASSIGNED = id();
const INVITED = id();
const OUTSIDER = id();
const CASE_ID = id();

const client = {
  _id: CLIENT_ID,
  fullName: "Ajith",
  email: "ajith@example.test",
  mobile: "9876543210",
  profileImage: "",
};

const baseCase = (overrides = {}) => ({
  _id: CASE_ID,
  client,
  title: "Divorce petition",
  category: "Family & Divorce",
  status: "Awaiting Lawyer Acceptance",
  assignedLawyer: null,
  selectedLawyer: null,
  documents: [{ name: "petition.pdf", url: "uploads/documents/p.pdf", size: "1200" }],
  lawyerRequests: [
    { lawyer: { _id: INVITED, fullName: "Invited" }, status: "Pending" },
    { lawyer: { _id: id(), fullName: "Second" }, status: "Pending" },
    { lawyer: { _id: id(), fullName: "Third" }, status: "Pending" },
  ],
  ...overrides,
});

const lawyer = (_id) => ({ _id, role: "lawyer" });

const makeRes = () => {
  const res = { statusCode: 200, body: null };
  res.status = (code) => {
    res.statusCode = code;
    return res;
  };
  res.json = (payload) => {
    res.body = payload;
    return res;
  };
  return res;
};

const getCase = async (user, caseId = CASE_ID.toString()) => {
  const res = makeRes();
  let failure = null;
  await caseController.getCaseById({ params: { id: caseId }, user }, res, (err) => {
    failure = err;
  });
  if (failure) throw failure;
  return res;
};

beforeEach(() => {
  mockState.caseItem = null;
  mockState.lawyerCases = [];
});

describe("GET /cases/:id for lawyers", () => {
  test("an invited lawyer can read the lead, without the client's contact details", async () => {
    mockState.caseItem = baseCase();

    const res = await getCase(lawyer(INVITED));

    expect(res.statusCode).toBe(200);
    expect(res.body.data._id).toBe(CASE_ID);
    expect(res.body.data.myRequestStatus).toBe("Pending");
    expect(res.body.data.lawyerRequests).toHaveLength(1);
    expect(res.body.data.client).toEqual({
      _id: CLIENT_ID,
      fullName: "Ajith",
      profileImage: "",
    });
  });

  test("the assigned lawyer reads the case with the client's contact details", async () => {
    mockState.caseItem = baseCase({
      status: "Accepted",
      assignedLawyer: { _id: ASSIGNED, fullName: "Assigned" },
      lawyerRequests: [],
    });

    const res = await getCase(lawyer(ASSIGNED));

    expect(res.statusCode).toBe(200);
    expect(res.body.data.client.email).toBe("ajith@example.test");
    expect(res.body.data.client.mobile).toBe("9876543210");
  });

  test("a lawyer with no request on the case is refused with 403", async () => {
    mockState.caseItem = baseCase();

    const res = await getCase(lawyer(OUTSIDER));

    expect(res.statusCode).toBe(403);
    expect(res.body.success).toBe(false);
    expect(res.body.data).toBeUndefined();
  });

  test("another lawyer's accepted case is refused with 403", async () => {
    mockState.caseItem = baseCase({
      status: "Accepted",
      assignedLawyer: { _id: ASSIGNED },
      lawyerRequests: [],
    });

    const res = await getCase(lawyer(OUTSIDER));

    expect(res.statusCode).toBe(403);
  });

  test("an invited lawyer whose lead went to someone else gets 409 and no case data", async () => {
    mockState.caseItem = baseCase({
      status: "Accepted",
      assignedLawyer: { _id: ASSIGNED },
      lawyerRequests: [
        { lawyer: { _id: ASSIGNED }, status: "Accepted" },
        { lawyer: { _id: INVITED }, status: "Unavailable" },
        { lawyer: { _id: id() }, status: "Unavailable" },
      ],
    });

    const res = await getCase(lawyer(INVITED));

    expect(res.statusCode).toBe(409);
    expect(res.body).toEqual({
      success: false,
      message: "This case has already been accepted by another lawyer.",
    });
  });

  test("a lawyer who declined gets 409", async () => {
    mockState.caseItem = baseCase({
      lawyerRequests: [
        { lawyer: { _id: INVITED }, status: "Declined" },
        { lawyer: { _id: id() }, status: "Pending" },
        { lawyer: { _id: id() }, status: "Pending" },
      ],
    });

    const res = await getCase(lawyer(INVITED));

    expect(res.statusCode).toBe(409);
    expect(res.body.message).toBe("You have already declined this case request.");
  });

  test("an unknown case is 404", async () => {
    const res = await getCase(lawyer(INVITED), id().toString());

    expect(res.statusCode).toBe(404);
  });
});

describe("GET /lawyers/clients", () => {
  test("each row carries the real case and client ids and case fields", async () => {
    const acceptedAt = new Date("2026-09-19T10:00:00Z");
    mockState.lawyerCases = [
      {
        _id: CASE_ID,
        client,
        title: "Divorce petition",
        category: "Family & Divorce",
        location: "Visakhapatnam",
        preferredCourt: "Family Court",
        urgency: "High",
        status: "Accepted",
        acceptedAt,
        updatedAt: acceptedAt,
      },
      {
        _id: id(),
        client: null,
        title: "Untitled",
        status: "In Progress",
        updatedAt: acceptedAt,
      },
    ];

    const res = makeRes();
    await lawyerController.getClients({ user: lawyer(ASSIGNED) }, res, (err) => {
      throw err;
    });

    const [row] = res.body.data.accepted;
    expect(row).toMatchObject({
      clientId: CLIENT_ID,
      caseId: CASE_ID,
      category: "Family & Divorce",
      location: "Visakhapatnam",
      preferredCourt: "Family Court",
      urgency: "High",
      acceptedAt,
    });

    const [inProgress] = res.body.data.inProgress;
    expect(inProgress.category).toBe("");
    expect(inProgress.preferredCourt).toBe("");
    expect(inProgress.acceptedAt).toBeNull();
  });
});
