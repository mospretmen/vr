// The Harmony Compass graph — a faithful port of the Swift core
// (packages/GuitarCore/Sources/MusicTheory/HarmonyWheel.swift). Columns are
// ordered in fifths; every column carries a major key, its relative minor,
// the dominant that serves them, and the diminished of their family.
// Parity with the Swift graph is pinned in compass.test.ts.

export type Ring = "majorKey" | "relativeMinor" | "dominant" | "diminished";

export type MoveKind =
  | "resolve"
  | "deceptive"
  | "toDominant"
  | "fifthSharpward"
  | "fifthFlatward"
  | "relative"
  | "twoFive"
  | "passingDim"
  | "soften"
  | "tritoneSub"
  | "deepen"
  | "dimFamily";

export interface CompassNode {
  ring: Ring;
  index: number;
  /** Pitch class of the chord root, 0 = C. */
  root: number;
  /** Display label with conventional spelling (B♭, not A♯). */
  label: string;
  id: string;
}

export interface Move {
  kind: MoveKind;
  from: CompassNode;
  to: CompassNode;
}

/** Spokes in fifths order, pitch class of each column's major key. */
export const SPOKES = [0, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5] as const;

const SHARP_NAMES = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"];
const FLAT_NAMES = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"];

/** Flat-side key columns spell flat (E♭, A♭, B♭, D♭); F♯ stays sharp. */
const FLAT_SIDE_KEYS = new Set([1, 8, 3, 10]);

function name(pc: number, flat: boolean): string {
  return (flat ? FLAT_NAMES : SHARP_NAMES)[((pc % 12) + 12) % 12];
}

function mod12(n: number): number {
  return ((n % 12) + 12) % 12;
}

export function node(ring: Ring, index: number): CompassNode {
  const i = mod12(index);
  const key = SPOKES[i];
  const flat = FLAT_SIDE_KEYS.has(key);
  let root: number;
  let label: string;
  switch (ring) {
    case "majorKey":
      root = key;
      label = name(root, flat);
      break;
    case "relativeMinor":
      root = mod12(key - 3);
      label = `${name(root, flat)}m`;
      break;
    case "dominant":
      root = mod12(key + 4);
      label = `${name(root, false)}7`;
      break;
    case "diminished":
      root = mod12(key + 8);
      label = `${name(root, false)}°7`;
      break;
  }
  return { ring, index: i, root, label, id: `${ring}:${i}` };
}

export const ALL_NODES: CompassNode[] = (
  ["majorKey", "relativeMinor", "dominant", "diminished"] as Ring[]
).flatMap((ring) => Array.from({ length: 12 }, (_, i) => node(ring, i)));

/** Every legal departure from a node — mirrors HarmonyWheel.moves(from:). */
export function movesFrom(n: CompassNode): Move[] {
  const out: Move[] = [];
  const add = (kind: MoveKind, ring: Ring, index: number) =>
    out.push({ kind, from: n, to: node(ring, index) });
  const i = n.index;

  switch (n.ring) {
    case "majorKey":
      add("relative", "relativeMinor", i);
      add("toDominant", "dominant", i); //            C → E7 (V7 of the relative minor)
      add("toDominant", "dominant", i + 9); //        C → G7 (its own V7)
      add("toDominant", "dominant", i + 10); //       C → D7 (V7 of V)
      add("toDominant", "dominant", i + 7); //        C → F7 (IV7 — blues)
      add("twoFive", "relativeMinor", i + 11); //     C → Dm (its ii)
      add("tritoneSub", "dominant", i + 3); //        C → D♭7 (sub of its V7)
      add("fifthSharpward", "majorKey", i + 1);
      add("fifthFlatward", "majorKey", i + 11);
      add("passingDim", "diminished", i + 11); //     F → F♯°7 (walk up)
      add("deepen", "diminished", i + 9); //          A → G♯°7 (its own vii°7)
      break;
    case "relativeMinor":
      add("relative", "majorKey", i);
      add("toDominant", "dominant", i); //            Am → E7
      add("twoFive", "dominant", i + 10); //          Am as ii → D7
      add("tritoneSub", "dominant", i + 6); //        Am → B♭7 (sub of its V7)
      add("fifthSharpward", "relativeMinor", i + 1);
      add("fifthFlatward", "relativeMinor", i + 11);
      add("passingDim", "diminished", i + 2); //      Gm → G♯°7 (walk up)
      add("deepen", "diminished", i); //              Am → G♯°7 (its vii°7)
      break;
    case "dominant":
      add("resolve", "relativeMinor", i); //          E7 → Am
      add("resolve", "majorKey", i + 3); //           E7 → A
      add("deceptive", "relativeMinor", i + 3); //    E7 → F♯m
      add("soften", "relativeMinor", i + 1); //       D7 → Dm (same root, now the ii)
      add("deepen", "diminished", i); //              E7 → G♯°7 (7♭9)
      add("tritoneSub", "dominant", i + 6); //        E7 ↔ B♭7
      add("tritoneSub", "majorKey", i + 9); //        as a sub: E7 → E♭
      add("tritoneSub", "relativeMinor", i + 6); //   as a sub: E7 → E♭m
      add("fifthFlatward", "dominant", i + 11); //    E7 → A7 (the dominant chain)
      add("fifthSharpward", "dominant", i + 1); //    E7 → B7 (V7 of my V7)
      break;
    case "diminished":
      add("resolve", "relativeMinor", i); //          G♯°7 → Am
      add("resolve", "majorKey", i + 3); //           G♯°7 → A
      add("resolve", "dominant", i); //               back up into E7 (7♭9)
      add("dimFamily", "diminished", i + 3);
      add("dimFamily", "diminished", i + 6);
      add("dimFamily", "diminished", i + 9);
      break;
  }
  return out;
}

export const ALL_MOVES: Move[] = ALL_NODES.flatMap(movesFrom);

const DIRECTED = new Set(ALL_MOVES.map((m) => `${m.from.id}>${m.to.id}`));

/** True when any move also runs the opposite direction (⇄). */
export function isTwoWay(m: Move): boolean {
  return DIRECTED.has(`${m.to.id}>${m.from.id}`);
}

/** Plain-English card line per move — the player's wording from the app. */
export function describe(m: Move): string {
  const to = m.to.label;
  switch (m.kind) {
    case "resolve":
      return `→ ${to}: resolve — the tension releases home.`;
    case "deceptive":
      return `→ ${to}: deceptive — slips to the relative instead of home.`;
    case "toDominant": {
      if (m.from.ring === "majorKey") {
        switch (mod12(m.to.index - m.from.index)) {
          case 0: return `→ ${to}: V7 of the relative minor (its III7).`;
          case 9: return `→ ${to}: its own V7 — the straight tension home.`;
          case 10: return `→ ${to}: V7 of V — two steps of tension.`;
          case 7: return `→ ${to}: IV7 — blues color; also slides a half-step into the minor below it.`;
        }
      }
      return `→ ${to}: raise tension on its dominant.`;
    }
    case "twoFive":
      return m.from.ring === "majorKey"
        ? `→ ${to}: your ii — the first step of ii–V–I home.`
        : `→ ${to}: ii–V — you're the ii; this is your V.`;
    case "fifthSharpward":
      return m.from.ring === "dominant" && m.to.ring === "dominant"
        ? `→ ${to}: back up the chain — the V7 of your V7.`
        : `→ ${to}: up a fifth — to the dominant side (its V).`;
    case "fifthFlatward":
      return m.from.ring === "dominant" && m.to.ring === "dominant"
        ? `→ ${to}: the dominant chain — resolve down a fifth, stay dominant.`
        : `→ ${to}: up a fourth — to the subdominant side (its IV).`;
    case "relative":
      return `→ ${to}: relative switch — same notes, new home.`;
    case "passingDim":
      return `→ ${to}: chromatic walk-up through the passing dim.`;
    case "soften":
      return `→ ${to}: soften — same root, the dominant relaxes into the ii of a coming ii–V.`;
    case "tritoneSub": {
      if (m.from.ring === "dominant" && m.to.ring === "dominant")
        return `→ ${to}: tritone sub — same 3rd & 7th, slides down a half-step into the same home.`;
      if (m.from.ring === "dominant")
        return `→ ${to}: resolve home — the sub lands a half-step down.`;
      return `→ ${to}: sub of your V7 (♭II7) — then it slides a half-step back home.`;
    }
    case "deepen":
      return m.from.ring === "dominant"
        ? `→ ${to}: darken into the 7♭9 diminished.`
        : `→ ${to}: your vii°7 — leading-tone tension that resolves right back.`;
    case "dimFamily":
      return `→ ${to}: same four notes respelled — pivot a minor third.`;
  }
}

/** Sounding pitch classes for a node's chord, for the demo pads. */
export function chordPitchClasses(n: CompassNode): number[] {
  const intervals =
    n.ring === "majorKey" ? [0, 4, 7]
    : n.ring === "relativeMinor" ? [0, 3, 7]
    : n.ring === "dominant" ? [0, 4, 7, 10]
    : [0, 3, 6, 9];
  return intervals.map((s) => mod12(n.root + s));
}
