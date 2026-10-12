// Karplus–Strong plucked strings for the web — the same physical-modeling
// voice as the visionOS app (zero samples), rendered into buffers.

let ctx: AudioContext | null = null;

function context(): AudioContext {
  ctx ??= new AudioContext();
  if (ctx.state === "suspended") void ctx.resume();
  return ctx;
}

/** Render one plucked note into a mono AudioBuffer. */
function pluckBuffer(
  ac: AudioContext, midi: number, seconds: number, amplitude: number,
): AudioBuffer {
  const sampleRate = ac.sampleRate;
  const frequency = 440 * Math.pow(2, (midi - 69) / 12);
  const period = Math.max(2, Math.round(sampleRate / frequency));
  const delay = Float32Array.from({ length: period }, () => Math.random() * 2 - 1);
  const frames = Math.floor(sampleRate * seconds);
  const buffer = ac.createBuffer(1, frames, sampleRate);
  const out = buffer.getChannelData(0);
  let index = 0;
  const damping = 0.996;
  for (let frame = 0; frame < frames; frame++) {
    const next = (index + 1) % period;
    const sample = delay[index];
    delay[index] = damping * 0.5 * (delay[index] + delay[next]);
    index = next;
    const tail = seconds - frame / sampleRate;
    const env = tail < 0.05 ? tail / 0.05 : 1;
    out[frame] = sample * amplitude * env;
  }
  return buffer;
}

function schedule(ac: AudioContext, buffer: AudioBuffer, when: number) {
  const source = ac.createBufferSource();
  source.buffer = buffer;
  source.connect(ac.destination);
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
