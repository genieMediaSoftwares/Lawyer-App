process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";
process.env.NODE_ENV = "test";

const mockClients = [];
const mockCaseLinks = [];
const mockAppointmentLinks = [];
const mockUsers = [];

const oid = (value) => ({
  toString: () => value,
  toJSON: () => value,
  _bsontype: "ObjectId",
});

const idOf = (value) => (value == null ? "" : String(value));

jest.mock("../../src/models/User", () => ({
  findById: (id) => ({
    select: async () =>
      mockUsers.find((u) => u._id.toString() === String(id)) || null,
  }),
}));

jest.mock("../../src/models/Case", () => ({
  exists: async (query) =>
    mockCaseLinks.some((link) => {
      if (query.client && String(query.client) !== link.client) return false;
      if (query._id && String(query._id) !== link._id) return false;
      if (
        query.assignedLawyer &&
        String(query.assignedLawyer) !== link.assignedLawyer
      ) {
        return false;
      }
      if (query.$or) {
        const matched = query.$or.some(
          (clause) =>
            (clause.assignedLawyer &&
              String(clause.assignedLawyer) === link.assignedLawyer) ||
            (clause.selectedLawyer &&
              String(clause.selectedLawyer) === link.selectedLawyer)
        );
        if (!matched) return false;
      }
      return true;
    })
      ? { _id: "exists" }
      : null,
  find: () => ({ distinct: async () => [], lean: async () => [] }),
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
  find: () => ({ distinct: async () => [], lean: async () => [] }),
}));

jest.mock("../../src/models/Document", () => ({
  find: async () => [],
}));

jest.mock("../../src/models/Payment", () => ({}));

jest.mock("../../src/models/Client", () => {
  const asSubdocArray = (array) => {
    array.id = (id) =>
      array.find((item) => item._id && item._id.toString() === String(id)) ||
      null;
    for (const item of array) {
      if (!item._id) {
        item._id = oid(`note-${Math.random().toString(36).slice(2, 9)}`);
      }
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
    record.notes = asSubdocArray(record.notes || []);
    record.save = async () => {
      record.notes = asSubdocArray(record.notes);
      return record;
    };
    record.toObject = () => ({ ...record });
    return record;
  };

  return {
    findOne: (query) => {
      const record = mockClients.find(
        (c) => c.user.toString() === String(query.user)
      );
      const result = record ? hydrate(record) : null;
      return Object.assign(Promise.resolve(result), {
        populate: async () => result,
      });
    },
    create: async ({ user }) => {
      const record = hydrate({ _id: oid(`client-doc-${user}`), user, notes: [] });
      mockClients.push(record);
      return record;
    },
  };
});

const clientController = require("../../src/controllers/client/clientController");

const CLIENT = oid("client-user-1");
const LAWYER_A = oid("lawyer-a");
const LAWYER_B = oid("lawyer-b");

const user = (id, role) => ({ _id: id, role });

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

const nextError = () => jest.fn();

const seed = () => {
  mockClients.length = 0;
  mockCaseLinks.length = 0;
  mockAppointmentLinks.length = 0;
  mockUsers.length = 0;

  mockUsers.push({ _id: CLIENT, fullName: "A Client" });
  mockCaseLinks.push({
    _id: "case-1",
    client: idOf(CLIENT),
    assignedLawyer: idOf(LAWYER_A),
    selectedLawyer: idOf(LAWYER_A),
  });
};

const addNote = async (asUser, body, clientId = "client-user-1") => {
  const res = makeRes();
  await clientController.addNote(
    makeReq({ params: { id: clientId }, body, user: asUser }),
    res,
    nextError()
  );
  return res;
};

const getNotes = async (asUser, query = {}) => {
  const res = makeRes();
  await clientController.getNotes(
    makeReq({ params: { id: "client-user-1" }, query, user: asUser }),
    res,
    nextError()
  );
  return res;
};

beforeEach(seed);

describe("engagement check", () => {
  test("an advocate with no relationship to the client is turned away", async () => {
    const res = await getNotes(user(LAWYER_B, "lawyer"));
    expect(res.statusCode).toBe(404);
  });

  test("and cannot write a note onto that client's record either", async () => {
    const res = await addNote(user(LAWYER_B, "lawyer"), { text: "Injected" });

    expect(res.statusCode).toBe(404);
    expect(mockClients).toHaveLength(0);
  });

  test("a client cannot read another user's notes", async () => {
    const res = await getNotes(user(oid("some-client"), "client"));
    expect(res.statusCode).toBe(403);
  });

  test("a consultation alone is enough of a relationship", async () => {
    mockCaseLinks.length = 0;
    mockAppointmentLinks.push({
      client: idOf(CLIENT),
      lawyer: idOf(LAWYER_B),
    });

    const res = await getNotes(user(LAWYER_B, "lawyer"));
    expect(res.body.success).toBe(true);
  });

  test("getClientById refuses an advocate who does not act for the client", async () => {
    const res = makeRes();
    await clientController.getClientById(
      makeReq({
        params: { id: "client-user-1" },
        user: user(LAWYER_B, "lawyer"),
      }),
      res,
      nextError()
    );
    expect(res.statusCode).toBe(404);
  });
});

describe("addNote", () => {
  test("an empty note is rejected", async () => {
    const res = await addNote(user(LAWYER_A, "lawyer"), { text: "   " });
    expect(res.statusCode).toBe(400);
  });

  test("the advocate's note is stored against them", async () => {
    const res = await addNote(user(LAWYER_A, "lawyer"), {
      text: "Called the client about the sale deed.",
      title: "Call",
    });

    expect(res.statusCode).toBe(201);
    expect(mockClients[0].notes).toHaveLength(1);
    expect(mockClients[0].notes[0].title).toBe("Call");
    expect(idOf(mockClients[0].notes[0].lawyer)).toBe(idOf(LAWYER_A));
  });

  test("the response carries only the new note, not the whole profile", async () => {
    const res = await addNote(user(LAWYER_A, "lawyer"), { text: "Note" });
    expect(res.body.data.notes).toBeUndefined();
    expect(res.body.data.text).toBe("Note");
  });

  test("a note cannot be filed against a case the advocate is not on", async () => {
    const res = await addNote(user(LAWYER_A, "lawyer"), {
      text: "Note",
      caseId: "case-belonging-to-someone-else",
    });

    expect(res.statusCode).toBe(404);
    expect(mockClients).toHaveLength(0);
  });

  test("a note may be filed against the advocate's own case", async () => {
    const res = await addNote(user(LAWYER_A, "lawyer"), {
      text: "Note",
      caseId: "case-1",
    });

    expect(res.statusCode).toBe(201);
    expect(mockClients[0].notes[0].case).toBe("case-1");
  });
});

describe("getNotes privacy", () => {
  beforeEach(async () => {
    await addNote(user(LAWYER_A, "lawyer"), { text: "Lawyer A's note" });
    mockClients[0].notes.push({
      _id: oid("note-b"),
      lawyer: LAWYER_B,
      text: "Lawyer B's note",
      date: new Date(),
    });
  });

  test("an advocate sees only their own notes on a shared client", async () => {
    mockAppointmentLinks.push({
      client: idOf(CLIENT),
      lawyer: idOf(LAWYER_B),
    });

    const forA = await getNotes(user(LAWYER_A, "lawyer"));
    expect(forA.body.data).toHaveLength(1);
    expect(forA.body.data[0].text).toBe("Lawyer A's note");

    const forB = await getNotes(user(LAWYER_B, "lawyer"));
    expect(forB.body.data).toHaveLength(1);
    expect(forB.body.data[0].text).toBe("Lawyer B's note");
  });

  test("a note with no author does not take the request down", async () => {
    mockClients[0].notes.push({
      _id: oid("orphan"),
      lawyer: null,
      text: "Orphaned",
      date: new Date(),
    });

    const res = await getNotes(user(LAWYER_A, "lawyer"));
    expect(res.body.success).toBe(true);
    expect(res.body.data).toHaveLength(1);
  });

  test("caseId narrows the list to one matter", async () => {
    await addNote(user(LAWYER_A, "lawyer"), {
      text: "Filed against case-1",
      caseId: "case-1",
    });

    const res = await getNotes(user(LAWYER_A, "lawyer"), { caseId: "case-1" });
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0].text).toBe("Filed against case-1");
  });
});

describe("updateNote and deleteNote are author-only", () => {
  let noteId;

  beforeEach(async () => {
    await addNote(user(LAWYER_A, "lawyer"), { text: "Original" });
    noteId = mockClients[0].notes[0]._id.toString();

    mockAppointmentLinks.push({
      client: idOf(CLIENT),
      lawyer: idOf(LAWYER_B),
    });
  });

  const update = async (asUser, body) => {
    const res = makeRes();
    await clientController.updateNote(
      makeReq({
        params: { id: "client-user-1", noteId },
        body,
        user: asUser,
      }),
      res,
      nextError()
    );
    return res;
  };

  test("another advocate cannot edit the note", async () => {
    const res = await update(user(LAWYER_B, "lawyer"), { text: "Tampered" });

    expect(res.statusCode).toBe(404);
    expect(mockClients[0].notes[0].text).toBe("Original");
  });

  test("another advocate cannot delete the note", async () => {
    const res = makeRes();
    await clientController.deleteNote(
      makeReq({
        params: { id: "client-user-1", noteId },
        user: user(LAWYER_B, "lawyer"),
      }),
      res,
      nextError()
    );

    expect(res.statusCode).toBe(404);
    expect(mockClients[0].notes).toHaveLength(1);
  });

  test("the author can edit their own note", async () => {
    const res = await update(user(LAWYER_A, "lawyer"), { text: "Revised" });

    expect(res.body.success).toBe(true);
    expect(mockClients[0].notes[0].text).toBe("Revised");
  });

  test("an empty edit is rejected rather than blanking the note", async () => {
    const res = await update(user(LAWYER_A, "lawyer"), { text: "  " });

    expect(res.statusCode).toBe(400);
    expect(mockClients[0].notes[0].text).toBe("Original");
  });

  test("the author can delete their own note", async () => {
    const res = makeRes();
    await clientController.deleteNote(
      makeReq({
        params: { id: "client-user-1", noteId },
        user: user(LAWYER_A, "lawyer"),
      }),
      res,
      nextError()
    );

    expect(res.body.success).toBe(true);
    expect(mockClients[0].notes).toHaveLength(0);
  });
});
