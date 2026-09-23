process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";
process.env.NODE_ENV = "test";

const mockCaseLinks = [];
const mockAppointmentLinks = [];
const mockReviews = [];

const oid = (value) => ({
  toString: () => value,
  toJSON: () => value,
  _bsontype: "ObjectId",
});

jest.mock("../../src/models/Case", () => ({
  exists: async (query) =>
    mockCaseLinks.some(
      (link) =>
        String(query.client) === link.client &&
        String(query.assignedLawyer) === link.assignedLawyer
    )
      ? { _id: "exists" }
      : null,
}));

jest.mock("../../src/models/Appointment", () => ({
  exists: async (query) =>
    mockAppointmentLinks.some(
      (link) =>
        String(query.client) === link.client &&
        String(query.lawyer) === link.lawyer
    )
      ? { _id: "exists" }
      : null,
}));

jest.mock("../../src/models/Review", () => ({
  create: async (doc) => {
    const record = { ...doc, _id: oid(`review-${mockReviews.length + 1}`) };
    mockReviews.push(record);
    return record;
  },
  findOne: async (query) =>
    mockReviews.find(
      (r) =>
        String(r.lawyer) === String(query.lawyer) &&
        String(r.client) === String(query.client)
    ) || null,
  find: async () => mockReviews,
}));

jest.mock("../../src/models/Lawyer", () => ({
  findOneAndUpdate: async () => ({}),
}));

jest.mock("../../src/services/notification/notificationService", () => ({
  createAndSendNotification: jest.fn(async () => {}),
}));

const reviewController = require("../../src/controllers/review/reviewController");

const CLIENT = oid("client-1");
const STRANGER = oid("client-2");
const LAWYER = oid("lawyer-1");

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

const makeReq = (overrides = {}) => ({
  params: {},
  body: {},
  query: {},
  ...overrides,
});

const createReview = async (user, body) => {
  const res = makeRes();
  await reviewController.createReview(makeReq({ user, body }), res, (err) => {
    throw err;
  });
  return res;
};

beforeEach(() => {
  mockCaseLinks.length = 0;
  mockAppointmentLinks.length = 0;
  mockReviews.length = 0;
});

describe("POST /reviews eligibility", () => {
  it("rejects a client who never worked with the advocate", async () => {
    const res = await createReview(
      { _id: STRANGER, role: "client" },
      { lawyerId: LAWYER.toString(), rating: 5, review: "Great" }
    );

    expect(res.statusCode).toBe(403);
    expect(mockReviews).toHaveLength(0);
  });

  it("accepts a client whose case was assigned to that advocate", async () => {
    mockCaseLinks.push({
      client: CLIENT.toString(),
      assignedLawyer: LAWYER.toString(),
    });

    const res = await createReview(
      { _id: CLIENT, role: "client" },
      { lawyerId: LAWYER.toString(), rating: 4, review: "Helpful advice" }
    );

    expect(res.statusCode).toBe(201);
    expect(mockReviews).toHaveLength(1);
    expect(mockReviews[0].rating).toBe(4);
  });

  it("accepts a client who booked an appointment with that advocate", async () => {
    mockAppointmentLinks.push({
      client: CLIENT.toString(),
      lawyer: LAWYER.toString(),
    });

    const res = await createReview(
      { _id: CLIENT, role: "client" },
      { lawyerId: LAWYER.toString(), rating: 5, review: "Clear consultation" }
    );

    expect(res.statusCode).toBe(201);
  });

  it("refuses a second review from the same client for the same advocate", async () => {
    mockCaseLinks.push({
      client: CLIENT.toString(),
      assignedLawyer: LAWYER.toString(),
    });
    await createReview(
      { _id: CLIENT, role: "client" },
      { lawyerId: LAWYER.toString(), rating: 5, review: "First" }
    );

    const res = await createReview(
      { _id: CLIENT, role: "client" },
      { lawyerId: LAWYER.toString(), rating: 1, review: "Second" }
    );

    expect(res.statusCode).toBe(409);
    expect(mockReviews).toHaveLength(1);
  });

  it("rejects a rating outside 1-5", async () => {
    mockCaseLinks.push({
      client: CLIENT.toString(),
      assignedLawyer: LAWYER.toString(),
    });

    const res = await createReview(
      { _id: CLIENT, role: "client" },
      { lawyerId: LAWYER.toString(), rating: 9, review: "Out of range" }
    );

    expect(res.statusCode).toBe(400);
    expect(mockReviews).toHaveLength(0);
  });
});

describe("GET /reviews scoping", () => {
  it("returns only the caller's own reviews when a client asks without a lawyerId", async () => {
    const captured = [];
    jest.isolateModules(() => {});
    const res = makeRes();
    const ReviewModel = require("../../src/models/Review");
    ReviewModel.find = (query) => {
      captured.push(query);
      return { populate: () => ({ sort: async () => [] }) };
    };

    await reviewController.getReviews(
      makeReq({ user: { _id: CLIENT, role: "client" }, query: {} }),
      res,
      (err) => {
        throw err;
      }
    );

    expect(String(captured[0].client)).toBe(CLIENT.toString());
    expect(captured[0].lawyer).toBeUndefined();
  });
});
