// Karplus–Strong plucked strings for the web — the same physical-modeling
// voice as the visionOS app (zero samples), rendered into buffers.

let ctx: AudioContext | null = null;
let master: AudioNode | null = null;

function context(): AudioContext {
  ctx ??= new AudioContext();
  if (ctx.state === "suspended") void ctx.resume();
  return ctx;
}

/** Shared mastering chain: gentle compression into a soft top-end rolloff —
 *  takes the wiry edge off the raw string model. */
function masterBus(ac: AudioContext): AudioNode {
  if (master) return master;
  const comp = ac.createDynamicsCompressor();
  comp.threshold.value = -18;
  comp.knee.value = 24;
  comp.ratio.value = 3;
  comp.attack.value = 0.004;
  comp.release.value = 0.18;
  const tone = ac.createBiquadFilter();
  tone.type = "lowpass";
  tone.frequency.value = 3800;
  tone.Q.value = 0.4;
  const warmth = ac.createBiquadFilter();
  warmth.type = "peaking";
  warmth.frequency.value = 180;
  warmth.gain.value = 2.5;
  warmth.Q.value = 0.8;
  const trim = ac.createGain();
  trim.gain.value = 0.9;
  comp.connect(tone);
  tone.connect(warmth);
  warmth.connect(trim);
  trim.connect(ac.destination);
  master = comp;
  return master;
}

/** Render one plucked note into a mono AudioBuffer. */
function pluckBuffer(
  ac: AudioContext, midi: number, seconds: number, amplitude: number,
): AudioBuffer {
  const sampleRate = ac.sampleRate;
  const frequency = 440 * Math.pow(2, (midi - 69) / 12);
  const period = Math.max(2, Math.round(sampleRate / frequency));
  // Low-passed excitation (three smoothing passes): a felt-pick attack
  // instead of a white-noise snap.
  const delay = Float32Array.from({ length: period }, () => Math.random() * 2 - 1);
  for (let pass = 0; pass < 3; pass++) {
    let prev = delay[period - 1];
    for (let i = 0; i < period; i++) {
      const cur = delay[i];
      delay[i] = 0.5 * (cur + prev);
      prev = cur;
    }
  }
  const frames = Math.floor(sampleRate * seconds);
  const buffer = ac.createBuffer(1, frames, sampleRate);
  const out = buffer.getChannelData(0);
  let index = 0;
  // High strings decay faster than wound bass strings — like a real neck.
  const damping = Math.min(0.9985, Math.max(0.988, 0.9995 - (midi - 40) * 0.00022));
  const attackFrames = sampleRate * 0.004;
  for (let frame = 0; frame < frames; frame++) {
    const next = (index + 1) % period;
    const sample = delay[index];
    delay[index] = damping * 0.5 * (delay[index] + delay[next]);
    index = next;
    const tail = seconds - frame / sampleRate;
    let env = tail < 0.08 ? tail / 0.08 : 1;
    if (frame < attackFrames) env *= frame / attackFrames;
    out[frame] = sample * amplitude * env;
  }
  return buffer;
}

function schedule(ac: AudioContext, buffer: AudioBuffer, when: number) {
  const source = ac.createBufferSource();
  source.buffer = buffer;
  source.connect(masterBus(ac));
  source.start(when);
}

/** Strum a chord: one pluck per voice, staggered like a pick sweep. */
export function strum(midis: number[], seconds = 1.4, stagger = 0.016) {
  const ac = context();
  const now = ac.currentTime + 0.02;
  const amplitude = 0.6 / Math.sqrt(Math.max(midis.length, 1));
  midis.forEach((midi, voice) => {
    schedule(ac, pluckBuffer(ac, midi, seconds, amplitude), now + voice * stagger);
  });
}

/** Play notes one after another — runs, arpeggios, phrases. */
export function playRun(midis: number[], noteSeconds = 0.24) {
  const ac = context();
  const start = ac.currentTime + 0.02;
  midis.forEach((midi, i) => {
    schedule(ac, pluckBuffer(ac, midi, noteSeconds * 3.2, 0.5),
             start + i * noteSeconds);
  });
}

/** Strum chords in sequence — a progression or a compass walk. */
export function playProgression(chords: number[][], eachSeconds = 0.85) {
  const ac = context();
  const start = ac.currentTime + 0.02;
  chords.forEach((midis, step) => {
    const amplitude = 0.55 / Math.sqrt(Math.max(midis.length, 1));
    midis.forEach((midi, voice) => {
      schedule(ac, pluckBuffer(ac, midi, eachSeconds * 1.4, amplitude),
               start + step * eachSeconds + voice * 0.014);
    });
  });
}
