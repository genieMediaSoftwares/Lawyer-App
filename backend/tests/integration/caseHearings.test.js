/**
 * Exercises the case-read authorization rule and the hearings endpoints.
 *
 * The controller is real; only the Mongoose models are replaced with in-memory
 * fakes, following the pattern auth.test.js established. The configured
 * MONGO_URI points at a shared cluster, so no test in this repository may write
 * to a database.
 *
 * Two things are being pinned down here:
 *
 *   1. `GET /cases/:id` used to return any case to any authenticated user.
 *      These tests assert the new rule admits exactly the same people that
 *      `getCases` already shows the case to, and nobody else.
 *
 *   2. `nextHearing` predates the hearings array and is read by three existing
 *      screens. These tests assert it stays mirrored to the earliest still
 *      scheduled hearing through add, edit and delete.
 */
process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";
process.env.NODE_ENV = "test";

const mockCases = [];

/**
 * Minimal ObjectId stand-in: distinct values that compare by string.
 *
 * `toJSON` matters — the fake's `.lean()` serialises through JSON, and without
 * it these would flatten to `{}` and every id comparison would pass or fail by
 * accident rather than on the rule under test.
 */
const oid = (value) => ({
  toString: () => value,
  toJSON: () => value,
  _bsontype: "ObjectId",
});

// ---------------------------------------------------------------------------
// Fake Case model
// ---------------------------------------------------------------------------
jest.mock("../../src/models/Case", () => {
  /** Gives an embedded array the two subdocument helpers the controller uses. */
  const asSubdocArray = (array) => {
    array.id = (id) =>
      array.find((item) => item._id && item._id.toString() === String(id)) ||
      null;
    for (const item of array) {
      if (!item.deleteOne) {
        item.deleteOne = () => {
          const index = array.indexOf(item);
          if (index >= 0) array.splice(index, 1);
        };
      }
    }
    return array;
  };

  const hydrate = (record) => {
    record.hearings = asSubdocArray(record.hearings || []);
    record.save = async () => {
      // Re-wrap so a hearing pushed since the last save also gets .deleteOne.
      record.hearings = asSubdocArray(record.hearings);
      return record;
    };
    return record;
  };

  // getCaseById calls .populate() for client, assignedLawyer and selectedLawyer
  // before .lean(), so those three come back as plain sub-documents carrying an
  // _id rather than as bare ids. The fake reproduces that shape, because it is
  // the shape the authorization rule has to read.
  const POPULATED = ["client", "assignedLawyer", "selectedLawyer"];

  const chainable = (record) => ({
    populate() {
      return this;
    },
    select() {
      return this;
    },
    lean: async () => {
      if (!record) return null;
      const plain = JSON.parse(JSON.stringify(record));
      for (const key of POPULATED) {
        if (plain[key]) plain[key] = { _id: plain[key], fullName: "Someone" };
      }
      return plain;
    },
  });

  return {
    __records: mockCases,
    findById: (id) => {
      const record = mockCases.find((c) => c._id.toString() === String(id));
      const result = record ? hydrate(record) : null;
      // findById(...) is awaited directly by the hearing endpoints and
      // .populate().lean() by getCaseById, so the return value has to serve
      // both shapes.
      return Object.assign(Promise.resolve(result), chainable(result));
    },
    find: () => ({
      populate() {
        return this;
      },
      select() {
        return this;
      },
      lean: async () => [],
    }),
    exists: async () => null,
  };
});

jest.mock("../../src/models/User", () => ({ findById: async () => null }));
jest.mock("../../src/models/Lawyer", () => ({
  findOne: () => ({ lean: async () => null }),
}));
jest.mock("../../src/models/Proposal", () => ({}));
jest.mock("../../src/services/notification/notificationService", () => ({
  createAndSendNotification: jest.fn().mockResolvedValue(undefined),
}));

const caseController = require("../../src/controllers/case/caseController");

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------
const CLIENT = oid("client-1");
const OTHER_CLIENT = oid("client-2");
const ASSIGNED_LAWYER = oid("lawyer-1");
const STRANGER_LAWYER = oid("lawyer-2");

const user = (id, role) => ({ _id: id, role });

const makeRes = () => {
  const res = { statusCode: null, body: null };
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
  // The controller reaches for req.app.get("io") to broadcast; returning null
  // exercises the "no socket server" branch without a real io instance.
  app: { get: () => null },
  ...overrides,
});

const seedCase = (overrides = {}) => {
  mockCases.length = 0;
  const record = {
    _id: oid("case-1"),
    title: "Property dispute",
    status: "In Progress",
    client: CLIENT,
    assignedLawyer: ASSIGNED_LAWYER,
    selectedLawyer: null,
    preferredCourt: "District Court",
    nextHearing: null,
    hearings: [],
    ...overrides,
  };
  mockCases.push(record);
  return record;
};

const nextError = () => {
  const fn = jest.fn();
  return fn;
};

describe("getCaseById authorization", () => {
  beforeEach(() => seedCase());

  const read = async (asUser) => {
    const res = makeRes();
    await caseController.getCaseById(
      makeReq({ params: { id: "case-1" }, user: asUser }),
      res,
      nextError()
    );
    return res;
  };

  test("the client who filed the case can read it", async () => {
    const res = await read(user(CLIENT, "client"));
    expect(res.body.success).toBe(true);
  });

  test("a different client cannot read it, and is not told it exists", async () => {
    const res = await read(user(OTHER_CLIENT, "client"));
    expect(res.statusCode).toBe(404);
    expect(res.body.message).toBe("Case not found.");
  });

  test("the assigned lawyer can read it", async () => {
    const res = await read(user(ASSIGNED_LAWYER, "lawyer"));
    expect(res.body.success).toBe(true);
  });

  test("an unrelated lawyer cannot read an engaged case", async () => {
    const res = await read(user(STRANGER_LAWYER, "lawyer"));
    expect(res.statusCode).toBe(404);
  });

  test("any lawyer can still read an open Submitted lead", async () => {
    // getCases shows every lawyer the Submitted pool, so getCaseById must too
    // or opening a lead from the Leads tab would break.
    seedCase({ status: "Submitted", assignedLawyer: null });
    const res = await read(user(STRANGER_LAWYER, "lawyer"));
    expect(res.body.success).toBe(true);
  });

  test("an admin can read any case", async () => {
    const res = await read(user(oid("admin-1"), "admin"));
    expect(res.body.success).toBe(true);
  });
});

describe("addHearing", () => {
  beforeEach(() => seedCase());

  const add = async (asUser, body) => {
    const res = makeRes();
    await caseController.addHearing(
      makeReq({ params: { id: "case-1" }, body, user: asUser }),
      res,
      nextError()
    );
    return res;
  };

  test("a lawyer not on the case is refused", async () => {
    const res = await add(user(STRANGER_LAWYER, "lawyer"), {
      date: "2026-10-01",
    });
    expect(res.statusCode).toBe(403);
    expect(mockCases[0].hearings).toHaveLength(0);
  });

  test("a client cannot list a hearing", async () => {
    const res = await add(user(CLIENT, "client"), { date: "2026-10-01" });
    expect(res.statusCode).toBe(403);
  });

  test("a missing date is rejected before anything is written", async () => {
    const res = await add(user(ASSIGNED_LAWYER, "lawyer"), {});
    expect(res.statusCode).toBe(400);
    expect(mockCases[0].hearings).toHaveLength(0);
  });

  test("an unparseable date is rejected", async () => {
    const res = await add(user(ASSIGNED_LAWYER, "lawyer"), {
      date: "not-a-date",
    });
    expect(res.statusCode).toBe(400);
  });

  test("the assigned lawyer adds a hearing and nextHearing follows it", async () => {
    const res = await add(user(ASSIGNED_LAWYER, "lawyer"), {
      date: "2026-10-01T00:00:00.000Z",
      timeSlot: "10:30 AM",
      purpose: "Framing of charges",
    });

    expect(res.statusCode).toBe(201);
    expect(mockCases[0].hearings).toHaveLength(1);
    expect(mockCases[0].hearings[0].purpose).toBe("Framing of charges");
    expect(new Date(mockCases[0].nextHearing).toISOString()).toBe(
      "2026-10-01T00:00:00.000Z"
    );
  });

  test("the court defaults to the case's preferred court when left blank", async () => {
    await add(user(ASSIGNED_LAWYER, "lawyer"), {
      date: "2026-10-01T00:00:00.000Z",
    });
    expect(mockCases[0].hearings[0].court).toBe("District Court");
  });

  test("nextHearing tracks the earliest hearing, not the most recent write", async () => {
    await add(user(ASSIGNED_LAWYER, "lawyer"), {
      date: "2026-12-01T00:00:00.000Z",
    });
    await add(user(ASSIGNED_LAWYER, "lawyer"), {
      date: "2026-10-05T00:00:00.000Z",
    });

    expect(new Date(mockCases[0].nextHearing).toISOString()).toBe(
      "2026-10-05T00:00:00.000Z"
    );
  });
});

describe("updateHearing", () => {
  const seedWithHearing = () => {
    const record = seedCase();
    record.hearings.push({
      _id: oid("hearing-1"),
      date: new Date("2026-10-01T00:00:00.000Z"),
      timeSlot: "10:30 AM",
      court: "District Court",
      purpose: "Framing of charges",
      status: "scheduled",
      notes: "Bring the sale deed",
    });
    record.nextHearing = new Date("2026-10-01T00:00:00.000Z");
    return record;
  };

  const update = async (asUser, body) => {
    const res = makeRes();
    await caseController.updateHearing(
      makeReq({
        params: { id: "case-1", hearingId: "hearing-1" },
        body,
        user: asUser,
      }),
      res,
      nextError()
    );
    return res;
  };

  beforeEach(seedWithHearing);

  test("a lawyer not on the case is refused", async () => {
    const res = await update(user(STRANGER_LAWYER, "lawyer"), {
      status: "cancelled",
    });
    expect(res.statusCode).toBe(403);
    expect(mockCases[0].hearings[0].status).toBe("scheduled");
  });

  test("fields the caller omitted are left alone", async () => {
    await update(user(ASSIGNED_LAWYER, "lawyer"), { status: "adjourned" });

    const hearing = mockCases[0].hearings[0];
    expect(hearing.status).toBe("adjourned");
    expect(hearing.court).toBe("District Court");
    expect(hearing.notes).toBe("Bring the sale deed");
    expect(hearing.timeSlot).toBe("10:30 AM");
  });

  test("completing the only hearing clears nextHearing", async () => {
    await update(user(ASSIGNED_LAWYER, "lawyer"), { status: "completed" });
    expect(mockCases[0].nextHearing).toBeNull();
  });

  test("an unknown hearing id is a 404", async () => {
    const res = makeRes();
    await caseController.updateHearing(
      makeReq({
        params: { id: "case-1", hearingId: "nope" },
        body: { status: "completed" },
        user: user(ASSIGNED_LAWYER, "lawyer"),
      }),
      res,
      nextError()
    );
    expect(res.statusCode).toBe(404);
  });
});

describe("deleteHearing", () => {
  beforeEach(() => {
    const record = seedCase();
    record.hearings.push(
      {
        _id: oid("hearing-1"),
        date: new Date("2026-10-01T00:00:00.000Z"),
        status: "scheduled",
      },
      {
        _id: oid("hearing-2"),
        date: new Date("2026-11-01T00:00:00.000Z"),
        status: "scheduled",
      }
    );
    record.nextHearing = new Date("2026-10-01T00:00:00.000Z");
  });

  const remove = async (asUser, hearingId) => {
    const res = makeRes();
    await caseController.deleteHearing(
      makeReq({
        params: { id: "case-1", hearingId },
        user: asUser,
      }),
      res,
      nextError()
    );
    return res;
  };

  test("a lawyer not on the case is refused", async () => {
    const res = await remove(user(STRANGER_LAWYER, "lawyer"), "hearing-1");
    expect(res.statusCode).toBe(403);
    expect(mockCases[0].hearings).toHaveLength(2);
  });

  test("removing the soonest hearing promotes the next one", async () => {
    await remove(user(ASSIGNED_LAWYER, "lawyer"), "hearing-1");

    expect(mockCases[0].hearings).toHaveLength(1);
    expect(new Date(mockCases[0].nextHearing).toISOString()).toBe(
      "2026-11-01T00:00:00.000Z"
    );
  });
});
