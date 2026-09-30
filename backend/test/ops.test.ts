import { describe, expect, it } from "vitest";
import { buildApp } from "../src/app";
import { loadConfig } from "../src/config";

describe("centralized error handler", () => {
  it("returns { error, statusCode } and surfaces the message outside production", async () => {
    const app = buildApp();
    app.get("/boom", async () => {
      throw new Error("kaboom");
    });

    const res = await app.inject({ method: "GET", url: "/boom" });
    expect(res.statusCode).toBe(500);
    expect(res.json()).toEqual({ error: "kaboom", statusCode: 500 });
    await app.close();
  });

  it("does not leak internals for 5xx in production", async () => {
    const app = buildApp({
      config: loadConfig({ NODE_ENV: "production" }),
      logger: false,
    });
    app.get("/boom", async () => {
      throw new Error("secret connection string");
    });

    const res = await app.inject({ method: "GET", url: "/boom" });
    expect(res.statusCode).toBe(500);
    expect(res.json()).toEqual({
      error: "internal_server_error",
      statusCode: 500,
    });
    expect(res.body).not.toContain("secret");
    await app.close();
  });

  it("preserves the statusCode of thrown HTTP errors", async () => {
    const app = buildApp();
    app.get("/teapot", async () => {
      const err = new Error("i_am_a_teapot") as Error & { statusCode: number };
      err.statusCode = 418;
      throw err;
    });

    const res = await app.inject({ method: "GET", url: "/teapot" });
    expect(res.statusCode).toBe(418);
    expect(res.json()).toEqual({ error: "i_am_a_teapot", statusCode: 418 });
    await app.close();
  });
});

describe("not-found handler", () => {
  it("returns { error: 'not_found', statusCode: 404 } for unknown routes", async () => {
    const app = buildApp();
    const res = await app.inject({ method: "GET", url: "/no/such/route" });
    expect(res.statusCode).toBe(404);
    expect(res.json()).toEqual({ error: "not_found", statusCode: 404 });
    await app.close();
  });
});

describe("security / ops middleware", () => {
  it("sends rate-limit headers on responses", async () => {
    const app = buildApp();
    const res = await app.inject({ method: "GET", url: "/v1/tracks" });
    expect(res.statusCode).toBe(200);
    expect(res.headers["x-ratelimit-limit"]).toBeDefined();
    expect(Number(res.headers["x-ratelimit-limit"])).toBe(300);
    expect(res.headers["x-ratelimit-remaining"]).toBeDefined();
    expect(res.headers["x-ratelimit-reset"]).toBeDefined();
    await app.close();
  });

  it("sends helmet security headers", async () => {
    const app = buildApp();
    const res = await app.inject({ method: "GET", url: "/health" });
    expect(res.headers["x-content-type-options"]).toBe("nosniff");
    await app.close();
  });

  it("allows configured CORS origins", async () => {
    const app = buildApp({
      config: loadConfig({
        NODE_ENV: "test",
        CORS_ORIGIN: "https://app.example.com",
      }),
    });
    const res = await app.inject({
      method: "GET",
      url: "/health",
      headers: { origin: "https://app.example.com" },
    });
    expect(res.headers["access-control-allow-origin"]).toBe(
      "https://app.example.com",
    );
    await app.close();
  });
});
