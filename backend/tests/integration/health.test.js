const http = require("http");
const app = require("../../src/app");

describe("API Health & Connectivity Integration Tests", () => {
  let server;
  let port;

  beforeAll((done) => {
    server = http.createServer(app);
    server.listen(0, () => {
      port = server.address().port;
      done();
    });
  });

  afterAll((done) => {
    if (server) {
      server.close(done);
    } else {
      done();
    }
  });

  it("GET / should return 200 with server health status", (done) => {
    http.get(`http://localhost:${port}/`, (res) => {
      expect(res.statusCode).toBe(200);
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        const body = JSON.parse(data);
        expect(body.success).toBe(true);
        expect(body.message).toContain("Running Successfully");
        done();
      });
    });
  });

  it("GET /api should return 200 with API status", (done) => {
    http.get(`http://localhost:${port}/api`, (res) => {
      expect(res.statusCode).toBe(200);
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        const body = JSON.parse(data);
        expect(body.success).toBe(true);
        done();
      });
    });
  });
});
