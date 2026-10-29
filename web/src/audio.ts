// The instrument: real sampled nylon-string guitar (FluidR3 soundfont
// notes, MIT, vendored in /samples/guitar/<midi>.mp3), with the old
// Karplus–Strong pluck as an instant fallback while a sample decodes.
// Every path runs through one mastering bus.

let ctx: AudioContext | null = null;
let master: AudioNode | null = null;

function context(): AudioContext {
  ctx ??= new AudioContext();
  if (ctx.state === "suspended") void ctx.resume();
  return ctx;
}

/** Gentle glue: light compression, a soft top, a little body. */
function masterBus(ac: AudioContext): AudioNode {
  if (master) return master;
  const comp = ac.createDynamicsCompressor();
  comp.threshold.value = -16;
  comp.knee.value = 24;
  comp.ratio.value = 2.5;
  comp.attack.value = 0.004;
  comp.release.value = 0.2;
  const tone = ac.createBiquadFilter();
  tone.type = "lowpass";
  tone.frequency.value = 7200;
  tone.Q.value = 0.3;
  const trim = ac.createGain();
  trim.gain.value = 0.95;
  comp.connect(tone);
  tone.connect(trim);
  trim.connect(ac.destination);
  master = comp;
  return master;
}

// ---- Sampled guitar ----

const SAMPLE_LO = 40; // E2
const SAMPLE_HI = 84; // C6
const samples = new Map<number, AudioBuffer>();
const loading = new Map<number, Promise<AudioBuffer | null>>();

function sampleMidi(midi: number): number {
  return Math.max(SAMPLE_LO, Math.min(SAMPLE_HI, midi));
}

function loadSample(midi: number): Promise<AudioBuffer | null> {
  const m = sampleMidi(midi);
  const cached = loading.get(m);
  if (cached) return cached;
  const p = fetch(`${import.meta.env.BASE_URL}samples/guitar/${m}.mp3`)
    .then((r) => (r.ok ? r.arrayBuffer() : Promise.reject(new Error(String(r.status)))))
    .then((buf) => context().decodeAudioData(buf))
    .then((audio) => {
      samples.set(m, audio);
      return audio;
    })
    .catch(() => null);
  loading.set(m, p);
  return p;
}

/** Warm the whole range once the user first makes sound. */
let warmed = false;
function warm() {
  if (warmed) return;
  warmed = true;
  let delay = 0;
  for (let m = SAMPLE_LO; m <= SAMPLE_HI; m++) {
    setTimeout(() => void loadSample(m), delay);
    delay += 60;
  }
}

// ---- Karplus–Strong fallback (kept from the synth era) ----

function pluckBuffer(
  ac: AudioContext, midi: number, seconds: number, amplitude: number,
): AudioBuffer {
  const sampleRate = ac.sampleRate;
  const frequency = 440 * Math.pow(2, (midi - 69) / 12);
  const period = Math.max(2, Math.round(sampleRate / frequency));
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

// ---- One voice ----

/** Play one note at `when` for roughly `seconds`, amplitude 0..1. */
function playNote(
  ac: AudioContext, midi: number, when: number, seconds: number, amplitude: number,
) {
  warm();
  const sample = samples.get(sampleMidi(midi));
  const source = ac.createBufferSource();
  const gain = ac.createGain();
  if (sample) {
    source.buffer = sample;
    // Micro-pitch for midi outside the sampled range.
    const diff = midi - sampleMidi(midi);
    if (diff !== 0) source.playbackRate.value = Math.pow(2, diff / 12);
    gain.gain.setValueAtTime(amplitude, when);
    const release = Math.max(when + 0.05, when + seconds - 0.06);
    gain.gain.setValueAtTime(amplitude, release);
    gain.gain.linearRampToValueAtTime(0.0001, when + seconds + 0.08);
  } else {
    void loadSample(midi);
    source.buffer = pluckBuffer(ac, midi, seconds, amplitude);
    gain.gain.value = 1;
  }
  source.connect(gain);
  gain.connect(masterBus(ac));
  source.start(when);
  source.stop(when + seconds + 0.12);
}

// ---- Public voice API (unchanged signatures) ----

/** Strum a chord: one pluck per voice, staggered like a pick sweep. */
export function strum(midis: number[], seconds = 1.8, stagger = 0.018) {
  const ac = context();
  const now = ac.currentTime + 0.02;
  const amplitude = 0.75 / Math.sqrt(Math.max(midis.length, 1));
  midis.forEach((midi, voice) => {
    playNote(ac, midi, now + voice * stagger, seconds, amplitude);
  });
}

/** Play notes one after another — swung like a player, last note rings. */
export function playRun(midis: number[], noteSeconds = 0.26) {
  const ac = context();
  const start = ac.currentTime + 0.02;
  // Swing: long-short eighth pairs; the final note gets room to ring.
  let t = start;
  midis.forEach((midi, i) => {
    const last = i === midis.length - 1;
    const dur = last ? noteSeconds * 5 : noteSeconds * (i % 2 === 0 ? 1.18 : 0.82);
    playNote(ac, midi, t, last ? dur : dur * 2.2, last ? 0.62 : 0.55);
    t += dur;
  });
}

/** Strum chords in sequence — a progression or a compass walk. */
export function playProgression(chords: number[][], eachSeconds = 0.9) {
  const ac = context();
  const start = ac.currentTime + 0.02;
  chords.forEach((midis, step) => {
    const amplitude = 0.68 / Math.sqrt(Math.max(midis.length, 1));
    midis.forEach((midi, voice) => {
      playNote(ac, midi, start + step * eachSeconds + voice * 0.016,
               eachSeconds * 1.5, amplitude);
    });
  });
}
