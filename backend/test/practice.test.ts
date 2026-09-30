import { randomUUID } from "node:crypto";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import type { FastifyInstance } from "fastify";
import { buildApp } from "../src/app";
import type { PracticeMode, PracticeSummary } from "../src/practice/repo";

let app: FastifyInstance;

beforeAll(() => {
  app = buildApp();
});

afterAll(async () => {
  await app.close();
});

interface WireSession {
  id: string;
  startedAt: string;
  durationS: number;
  mode: PracticeMode;
}

function session(
  startedAt: string,
  durationS: number,
  mode: PracticeMode,
): WireSession {
  return { id: randomUUID(), startedAt, durationS, mode };
}

async function postSessions(deviceId: string, sessions: WireSession[]) {
  return app.inject({
    method: "POST",
    url: "/v1/practice-sessions",
    headers: { "x-device-id": deviceId },
    payload: { sessions },
  });
}

async function getSummary(deviceId: string) {
  return app.inject({
    method: "GET",
    url: "/v1/practice-sessions/summary",
    headers: { "x-device-id": deviceId },
  });
}

describe("POST /v1/practice-sessions + GET /v1/practice-sessions/summary", () => {
  it("accepts batches, isolates devices, and computes summary math", async () => {
    const deviceA = randomUUID();
    const deviceB = randomUUID();

    // Device A: two sessions across two UTC days (the second uses a +02:00
    // offset that lands on the previous UTC day).
    const aSessions = [
      session("2026-03-01T10:00:00.000Z", 600, "scale"),
      session("2026-03-02T01:00:00.000+02:00", 300, "backingTrack"), // UTC 2026-03-01
      session("2026-03-05T09:30:00.000Z", 900, "scale"),
    ];
    const postA = await postSessions(deviceA, aSessions);
    expect(postA.statusCode).toBe(200);
    expect(postA.json()).toEqual({ accepted: 3 });

    // Device B: one session, same window.
    const bSessions = [session("2026-03-01T12:00:00.000Z", 120, "listen")];
    const postB = await postSessions(deviceB, bSessions);
    expect(postB.statusCode).toBe(200);
    expect(postB.json()).toEqual({ accepted: 1 });

    const resA = await getSummary(deviceA);
    expect(resA.statusCode).toBe(200);
    const summaryA = resA.json<PracticeSummary>();
    expect(summaryA.totalTimeS).toBe(1800);
    expect(summaryA.sessionCount).toBe(3);
    expect(summaryA.timeByMode).toEqual({ scale: 1500, backingTrack: 300 });
    expect(summaryA.days).toEqual(["2026-03-01", "2026-03-05"]);

    // Device B sees only its own session.
    const resB = await getSummary(deviceB);
    expect(resB.statusCode).toBe(200);
    const summaryB = resB.json<PracticeSummary>();
    expect(summaryB.totalTimeS).toBe(120);
    expect(summaryB.sessionCount).toBe(1);
    expect(summaryB.timeByMode).toEqual({ listen: 120 });
    expect(summaryB.days).toEqual(["2026-03-01"]);
  });

  it("is idempotent: re-posting the same batch counts accepted but leaves totals unchanged", async () => {
    const deviceId = randomUUID();
    const batch = [
      session("2026-04-01T08:00:00.000Z", 240, "chord"),
      session("2026-04-02T08:00:00.000Z", 360, "exercise"),
    ];

    const first = await postSessions(deviceId, batch);
    expect(first.statusCode).toBe(200);
    expect(first.json()).toEqual({ accepted: 2 });

    const retry = await postSessions(deviceId, batch);
    expect(retry.statusCode).toBe(200);
    expect(retry.json()).toEqual({ accepted: 2 });

    const summary = (await getSummary(deviceId)).json<PracticeSummary>();
    expect(summary.totalTimeS).toBe(600);
    expect(summary.sessionCount).toBe(2);
    expect(summary.timeByMode).toEqual({ chord: 240, exercise: 360 });
    expect(summary.days).toEqual(["2026-04-01", "2026-04-02"]);
  });

  it("returns an empty summary for a device with no sessions", async () => {
    const res = await getSummary(randomUUID());
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({
      totalTimeS: 0,
      sessionCount: 0,
      timeByMode: {},
      days: [],
    });
  });

  it("400s when x-device-id is missing", async () => {
    const post = await app.inject({
      method: "POST",
      url: "/v1/practice-sessions",
      payload: { sessions: [session("2026-03-01T10:00:00.000Z", 60, "scale")] },
    });
    expect(post.statusCode).toBe(400);
    expect(post.json<{ statusCode: number }>().statusCode).toBe(400);

    const get = await app.inject({
      method: "GET",
      url: "/v1/practice-sessions/summary",
    });
    expect(get.statusCode).toBe(400);
    expect(get.json<{ statusCode: number }>().statusCode).toBe(400);
  });

  it("400s when x-device-id is not a UUID", async () => {
    const res = await postSessions("not-a-uuid", [
      session("2026-03-01T10:00:00.000Z", 60, "scale"),
    ]);
    expect(res.statusCode).toBe(400);
    expect(res.json<{ statusCode: number }>().statusCode).toBe(400);
  });

  it("400s on a mode outside the enum", async () => {
    const res = await app.inject({
      method: "POST",
      url: "/v1/practice-sessions",
      headers: { "x-device-id": randomUUID() },
      payload: {
        sessions: [
          {
            id: randomUUID(),
            startedAt: "2026-03-01T10:00:00.000Z",
            durationS: 60,
            mode: "shredding",
          },
        ],
      },
    });
    expect(res.statusCode).toBe(400);
    expect(res.json<{ statusCode: number }>().statusCode).toBe(400);
  });

  it("400s on batches larger than 500 sessions", async () => {
    const sessions = Array.from({ length: 501 }, () =>
      session("2026-03-01T10:00:00.000Z", 60, "scale"),
    );
    const res = await postSessions(randomUUID(), sessions);
    expect(res.statusCode).toBe(400);
    expect(res.json<{ statusCode: number }>().statusCode).toBe(400);
  });
});
