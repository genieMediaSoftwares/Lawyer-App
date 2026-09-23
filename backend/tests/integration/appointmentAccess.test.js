process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";
process.env.NODE_ENV = "test";

const mockAppointments = [];

const oid = (value) => ({
  toString: () => value,
  toJSON: () => value,
  _bsontype: "ObjectId",
});

const tomorrow = () => {
  const date = new Date();
  date.setDate(date.getDate() + 1);
  return date.toISOString();
};

jest.mock("../../src/models/Appointment", () => {
  const hydrate = (record) => {
    record.save = async () => record;
    return record;
  };
  return {
    create: async (doc) => {
      const record = hydrate({
        ...doc,
        _id: oid(`appt-${mockAppointments.length + 1}`),
      });
      mockAppointments.push(record);
      return record;
    },
    findById: async (id) =>
      mockAppointments.find((a) => a._id.toString() === String(id)) || null,
    findOne: async (query) =>
      mockAppointments.find((a) => {
        if (a.timeSlot !== query.timeSlot) return false;
        if (!["pending", "confirmed"].includes(a.status)) return false;
        return query.$or.some(
          (clause) =>
            (clause.lawyer && String(a.lawyer) === String(clause.lawyer)) ||
            (clause.client && String(a.client) === String(clause.client))
        );
      }) || null,
    findByIdAndUpdate: async (id, updates) => {
      const record = mockAppointments.find(
        (a) => a._id.toString() === String(id)
      );
      if (!record) return null;
      Object.assign(record, updates);
      return record;
    },
  };
});

jest.mock("../../src/models/Case", () => ({ findById: async () => null }));

jest.mock("../../src/services/notification/notificationService", () => ({
  createAndSendNotification: jest.fn(async () => {}),
}));

jest.mock("../../src/services/googleCalendarService", () => ({
  createOrUpdateEvent: jest.fn(async () => {}),
  deleteEvent: jest.fn(async () => {}),
}));

const appointmentController = require("../../src/controllers/appointment/appointmentController");

const CLIENT = oid("client-1");
const OTHER_CLIENT = oid("client-2");
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

const call = async (handler, req) => {
  const res = makeRes();
  await appointmentController[handler](
    { params: {}, body: {}, query: {}, ...req },
    res,
    (err) => {
      throw err;
    }
  );
  return res;
};

beforeEach(() => {
  mockAppointments.length = 0;
});

describe("POST /appointments", () => {
  it("refuses a booking without a date or time slot", async () => {
    const res = await call("createAppointment", {
      user: { _id: CLIENT, role: "client" },
      body: { lawyer: LAWYER.toString() },
    });

    expect(res.statusCode).toBe(400);
    expect(mockAppointments).toHaveLength(0);
  });

  it("refuses a slot in the past", async () => {
    const res = await call("createAppointment", {
      user: { _id: CLIENT, role: "client" },
      body: {
        lawyer: LAWYER.toString(),
        date: "2020-01-01T10:00:00.000Z",
        timeSlot: "10:00 AM",
      },
    });

    expect(res.statusCode).toBe(400);
  });

  it("books a valid future slot", async () => {
    const res = await call("createAppointment", {
      user: { _id: CLIENT, role: "client" },
      body: {
        lawyer: LAWYER.toString(),
        date: tomorrow(),
        timeSlot: "10:00 AM",
        mode: "Chat",
      },
    });

    expect(res.statusCode).toBe(201);
    expect(mockAppointments).toHaveLength(1);
  });

  it("refuses a second booking for the same advocate and slot", async () => {
    const body = {
      lawyer: LAWYER.toString(),
      date: tomorrow(),
      timeSlot: "10:00 AM",
    };
    await call("createAppointment", {
      user: { _id: CLIENT, role: "client" },
      body,
    });

    const res = await call("createAppointment", {
      user: { _id: OTHER_CLIENT, role: "client" },
      body,
    });

    expect(res.statusCode).toBe(409);
    expect(mockAppointments).toHaveLength(1);
  });
});

describe("appointment access control", () => {
  const book = async () => {
    await call("createAppointment", {
      user: { _id: CLIENT, role: "client" },
      body: {
        lawyer: LAWYER.toString(),
        date: tomorrow(),
        timeSlot: "11:00 AM",
      },
    });
    return mockAppointments[0]._id.toString();
  };

  it("stops a stranger changing the status", async () => {
    const id = await book();

    const res = await call("updateStatus", {
      user: { _id: OTHER_CLIENT, role: "client" },
      params: { id },
      body: { status: "cancelled" },
    });

    expect(res.statusCode).toBe(403);
    expect(mockAppointments[0].status).toBe("confirmed");
  });

  it("stops a stranger rescheduling, and never lets participants reassign people", async () => {
    const id = await book();

    const stranger = await call("updateAppointment", {
      user: { _id: OTHER_CLIENT, role: "client" },
      params: { id },
      body: { timeSlot: "9:00 PM" },
    });
    expect(stranger.statusCode).toBe(403);

    await call("updateAppointment", {
      user: { _id: CLIENT, role: "client" },
      params: { id },
      body: { timeSlot: "2:00 PM", client: OTHER_CLIENT.toString() },
    });

    expect(mockAppointments[0].timeSlot).toBe("2:00 PM");
    expect(String(mockAppointments[0].client)).toBe(CLIENT.toString());
  });

  it("stops a stranger cancelling", async () => {
    const id = await book();

    const res = await call("deleteAppointment", {
      user: { _id: OTHER_CLIENT, role: "client" },
      params: { id },
    });

    expect(res.statusCode).toBe(403);
    expect(mockAppointments[0].status).toBe("confirmed");
  });

  it("lets the advocate confirm their own appointment", async () => {
    const id = await book();

    const res = await call("updateStatus", {
      user: { _id: LAWYER, role: "lawyer" },
      params: { id },
      body: { status: "completed" },
    });

    expect(res.statusCode).toBe(200);
    expect(mockAppointments[0].status).toBe("completed");
  });
});
