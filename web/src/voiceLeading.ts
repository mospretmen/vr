// Minimal-motion voice leading — port of the Swift VoiceLeading engine.
// Every departing tone routes to an arriving tone; total motion minimized,
// common tones preferred on ties, every arriving tone covered.
import { chordPitchClasses, type CompassNode } from "./compass";

export interface VoiceMove {
  from: number;
  to: number;
  /** Signed shortest motion in semitones, -5…+6 (0 = common tone). */
  semitones: number;
}

export function distance(from: number, to: number): number {
  const up = (((to - from) % 12) + 12) % 12;
  return up > 6 ? up - 12 : up;
}

export function voiceMoves(from: CompassNode, to: CompassNode): VoiceMove[] {
  const a = chordPitchClasses(from);
  const b = chordPitchClasses(to);
  let best: number[] | null = null;
  let bestCost = Infinity;
  let bestCommon = -1;

  const assignment = new Array<number>(a.length).fill(0);
  const recurse = (i: number) => {
    if (i === a.length) {
      if (a.length >= b.length && new Set(assignment).size < b.length) return;
      let cost = 0;
      let common = 0;
      for (let j = 0; j < a.length; j++) {
        const d = distance(a[j], b[assignment[j]]);
        cost += Math.abs(d);
        if (d === 0) common++;
      }
      if (cost < bestCost || (cost === bestCost && common > bestCommon)) {
        bestCost = cost;
        bestCommon = common;
        best = [...assignment];
      }
      return;
    }
    for (let j = 0; j < b.length; j++) {
      assignment[i] = j;
      recurse(i + 1);
    }
  };
  recurse(0);
  if (!best) return [];
  const chosen: number[] = best;
  return a.map((pc, i) => ({
    from: pc,
    to: b[chosen[i]],
    semitones: distance(pc, b[chosen[i]]),
  }));
}
