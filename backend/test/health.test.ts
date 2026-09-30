import { describe, expect, it } from "vitest";
import { buildApp } from "../src/app";

interface HealthPayload {
  status: string;
  uptime: number;
  version: string;
}

describe("health endpoints", () => {
  it("GET /health returns 200 with status, uptime and version", async () => {
    const app = buildApp();
    const res = await app.inject({ method: "GET", url: "/health" });
    expect(res.statusCode).toBe(200);

    const body = res.json<HealthPayload>();
    expect(body.status).toBe("ok");
    expect(typeof body.uptime).toBe("number");
    expect(body.uptime).toBeGreaterThanOrEqual(0);
    expect(body.version).toMatch(/^\d+\.\d+\.\d+/);
    await app.close();
  });

  it("GET /healthz serves the same payload shape", async () => {
    const app = buildApp();
    const res = await app.inject({ method: "GET", url: "/healthz" });
    expect(res.statusCode).toBe(200);

    const body = res.json<HealthPayload>();
    expect(body.status).toBe("ok");
    expect(typeof body.uptime).toBe("number");
    expect(typeof body.version).toBe("string");
    await app.close();
  });
});
