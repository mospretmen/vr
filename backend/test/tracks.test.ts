import { afterAll, beforeAll, describe, expect, it } from "vitest";
import type { FastifyInstance } from "fastify";
import { buildApp } from "../src/app";
import type { Timeline, Track } from "../src/tracks/repo";

let app: FastifyInstance;

beforeAll(() => {
  app = buildApp();
});

afterAll(async () => {
  await app.close();
});

describe("GET /v1/tracks", () => {
  it("returns 4 seeded tracks in the wire format", async () => {
    const res = await app.inject({ method: "GET", url: "/v1/tracks" });
    expect(res.statusCode).toBe(200);

    const tracks = res.json<Track[]>();
    expect(tracks).toHaveLength(4);

    for (const track of tracks) {
      expect(typeof track.id).toBe("string");
      expect(typeof track.title).toBe("string");
      expect(track.artist).toBeNull();
      expect(track.bpm).toBe(120);
      expect(track.key).not.toBeNull();
      expect(typeof track.key?.root).toBe("number");
      expect(typeof track.key?.type.name).toBe("string");
      expect(Array.isArray(track.key?.type.intervals)).toBe(true);
    }
  });
});

describe("GET /v1/tracks/:id/timeline", () => {
  it("serves the A blues timeline with 12 bars of 2000ms", async () => {
    const res = await app.inject({
      method: "GET",
      url: "/v1/tracks/blues-a/timeline",
    });
    expect(res.statusCode).toBe(200);

    const timeline = res.json<Timeline>();
    expect(timeline.events).toHaveLength(12);

    const first = timeline.events[0]!;
    expect(first.startMs).toBe(0);
    expect(first.durationMs).toBe(2000);
    expect(first.chord.root).toBe(9); // A
    expect(first.chord.quality.symbol).toBe("7");
    expect(first.chord.quality.name).toBe("Dominant 7");
    expect(first.chord.quality.intervals).toEqual([0, 4, 7, 10]);

    // Bars 5-6 and bar 10 are D7 (IV), roots as pitch class 2.
    for (const bar of [5, 6, 10]) {
      expect(timeline.events[bar - 1]!.chord.root).toBe(2);
      expect(timeline.events[bar - 1]!.chord.quality.symbol).toBe("7");
    }

    // Bars 9 and 12 are E7 (V), pitch class 4.
    for (const bar of [9, 12]) {
      expect(timeline.events[bar - 1]!.chord.root).toBe(4);
      expect(timeline.events[bar - 1]!.chord.quality.symbol).toBe("7");
    }

    // Events tile the 12 bars contiguously.
    timeline.events.forEach((event, i) => {
      expect(event.startMs).toBe(i * 2000);
      expect(event.durationMs).toBe(2000);
    });

    expect(timeline.key).toEqual({
      root: 9,
      type: { name: "Blues", intervals: [0, 3, 5, 6, 7, 10] },
    });
  });

  it("serves the ii-V-I in C with the expected chords and key", async () => {
    const res = await app.inject({
      method: "GET",
      url: "/v1/tracks/ii-v-i-c/timeline",
    });
    expect(res.statusCode).toBe(200);

    const timeline = res.json<Timeline>();
    expect(timeline.events).toHaveLength(4);
    expect(
      timeline.events.map((e) => [e.chord.root, e.chord.quality.symbol]),
    ).toEqual([
      [2, "m7"],
      [7, "7"],
      [0, "maj7"],
      [0, "maj7"],
    ]);
    expect(timeline.key).toEqual({
      root: 0,
      type: { name: "Major (Ionian)", intervals: [0, 2, 4, 5, 7, 9, 11] },
    });
  });

  it("404s with {error:'not_found'} for unknown track ids", async () => {
    const res = await app.inject({
      method: "GET",
      url: "/v1/tracks/nope/timeline",
    });
    expect(res.statusCode).toBe(404);
    expect(res.json()).toEqual({ error: "not_found" });
  });

  it("400s on track ids longer than 64 characters", async () => {
    const res = await app.inject({
      method: "GET",
      url: `/v1/tracks/${"a".repeat(80)}/timeline`,
    });
    expect(res.statusCode).toBe(400);

    const body = res.json<{ error: string; statusCode: number }>();
    expect(body.statusCode).toBe(400);
    expect(typeof body.error).toBe("string");
  });

  it("400s on track ids with characters outside [A-Za-z0-9_-]", async () => {
    const res = await app.inject({
      method: "GET",
      url: "/v1/tracks/bad%24id/timeline", // decodes to "bad$id"
    });
    expect(res.statusCode).toBe(400);
    expect(res.json<{ statusCode: number }>().statusCode).toBe(400);
  });
});
