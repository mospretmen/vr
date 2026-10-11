// Marketing sections for the Vision Pro flagship: the 3D compass story,
// the planned pricing split, and the waitlist that feeds Neon.
import { useState, type FormEvent } from "react";

export function VisionProSection() {
  return (
    <section id="visionpro" className="scroll-mt-20 border-t border-line">
      <div className="mx-auto max-w-6xl px-4 py-20 sm:px-6 sm:py-24">
        <div className="grid items-center gap-10 lg:grid-cols-2">
          <div>
            <p className="inline-flex items-center gap-2 rounded-full border border-accent/25 bg-accent-strong/10 px-3.5 py-1.5 text-xs font-medium tracking-wide text-accent">
              Flagship · Apple Vision Pro
            </p>
            <h2 className="mt-5 font-display text-3xl font-bold tracking-tight text-balance sm:text-4xl">
              In the headset, harmony has depth.
            </h2>
            <p className="mt-4 text-base leading-relaxed text-ink-dim">
              The volumetric compass turns tension into literal space: keys
              and their relative minors float nearest you, the dominants that
              pull on them sit a hand-depth behind, and the diminished
              families rest deepest — a funnel of tension you can reach into.
              Tap any chord mid-air: it sounds, and its pathways light up
              across the depth.
            </p>
            <ul className="mt-6 space-y-3 text-sm text-ink/90">
              {[
                "2D and volumetric 3D compass — switch with one tap",
                "Scale and chord windows with real wood-and-steel fretboards",
                "Voice leading drawn between any two chords, with sound",
                "Every grip from published chord charts, arpeggiated on tap",
              ].map((line) => (
                <li key={line} className="flex items-start gap-2.5">
                  <span className="mt-1.5 size-1.5 shrink-0 rounded-full bg-accent" />
                  {line}
                </li>
              ))}
            </ul>
          </div>
          <FunnelDiagram />
        </div>
      </div>
    </section>
  );
}

/** Stylized side-view of the 3D tension funnel. */
function FunnelDiagram() {
  return (
    <svg
      viewBox="0 0 420 320"
      className="w-full max-w-md justify-self-center"
      role="img"
      aria-label="The 3D compass: keys in front, dominants behind, diminisheds deepest"
    >
      <defs>
        <linearGradient id="depth" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0" stopColor="#60a5fa" stopOpacity="0.9" />
          <stop offset="0.55" stopColor="#fb923c" stopOpacity="0.75" />
          <stop offset="1" stopColor="#c084fc" stopOpacity="0.7" />
        </linearGradient>
      </defs>
      <ellipse cx="110" cy="160" rx="54" ry="128" fill="none" stroke="#60a5fa" strokeWidth="2.5" opacity="0.9" />
      <ellipse cx="250" cy="160" rx="36" ry="84" fill="none" stroke="#fb923c" strokeWidth="2.5" opacity="0.85" />
      <ellipse cx="340" cy="160" rx="20" ry="46" fill="none" stroke="#c084fc" strokeWidth="2.5" opacity="0.85" />
      <path d="M 118 52 Q 230 60 332 118" stroke="url(#depth)" strokeWidth="1.6" fill="none" opacity="0.8" />
      <path d="M 118 268 Q 230 260 332 202" stroke="url(#depth)" strokeWidth="1.6" fill="none" opacity="0.8" />
      <path d="M 160 160 L 322 160" stroke="url(#depth)" strokeWidth="1.6" opacity="0.8" />
      {[
        [110, 36, "#60a5fa"], [110, 284, "#60a5fa"], [58, 100, "#60a5fa"], [162, 100, "#60a5fa"],
        [58, 222, "#60a5fa"], [162, 222, "#60a5fa"],
        [250, 80, "#fb923c"], [250, 240, "#fb923c"], [216, 160, "#fb923c"], [284, 160, "#fb923c"],
        [340, 118, "#c084fc"], [340, 202, "#c084fc"],
      ].map(([x, y, c], i) => (
        <circle key={i} cx={x as number} cy={y as number} r="7" fill={c as string} />
      ))}
      <text x="110" y="310" textAnchor="middle" fill="#94a3b8" fontSize="11">keys · nearest</text>
      <text x="250" y="310" textAnchor="middle" fill="#94a3b8" fontSize="11">dominants</text>
      <text x="345" y="310" textAnchor="middle" fill="#94a3b8" fontSize="11">dim · deepest</text>
    </svg>
  );
}

export function PricingSection() {
  return (
    <section id="pricing" className="scroll-mt-20 border-t border-line">
      <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
        <h2 className="font-display text-2xl font-bold tracking-tight sm:text-3xl">
          Simple plan, one engine everywhere.
        </h2>
        <p className="mt-2 max-w-2xl text-sm text-ink-dim sm:text-base">
          Final pricing lands with the App Store release — early waitlist
          members get the founding price.
        </p>
        <div className="mt-8 grid max-w-3xl gap-4 sm:grid-cols-2">
          <div className="rounded-2xl border border-line bg-raise p-6">
            <h3 className="font-display text-lg font-semibold">Explore — free</h3>
            <ul className="mt-3 space-y-2 text-sm text-ink-dim">
              <li>The 2D Harmony Compass, every pathway</li>
              <li>Hear any chord and its resolutions</li>
              <li>Core scales on the fretboard</li>
            </ul>
          </div>
          <div className="rounded-2xl border border-accent/40 bg-raise p-6">
            <h3 className="font-display text-lg font-semibold text-accent">Pro</h3>
            <ul className="mt-3 space-y-2 text-sm text-ink-dim">
              <li>The volumetric 3D compass on Vision Pro</li>
              <li>Full grip dictionary, shells, drop-2, inversions</li>
              <li>Voice leading, alterations, all 20 scales</li>
              <li>Progression tools as they land</li>
            </ul>
          </div>
        </div>
      </div>
    </section>
  );
}

export function WaitlistSection() {
  const [email, setEmail] = useState("");
  const [platform, setPlatform] = useState("visionpro");
  const [state, setState] = useState<"idle" | "sending" | "done" | "error">("idle");

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setState("sending");
    try {
      const res = await fetch("/.netlify/functions/waitlist", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, platform }),
      });
      setState(res.ok ? "done" : "error");
    } catch {
      setState("error");
    }
  };

  return (
    <section id="waitlist" className="scroll-mt-20 border-t border-line">
      <div className="mx-auto max-w-3xl px-4 py-16 text-center sm:px-6 sm:py-20">
        <h2 className="font-display text-2xl font-bold tracking-tight sm:text-3xl">
          Be first on the fretboard.
        </h2>
        <p className="mx-auto mt-2 max-w-xl text-sm text-ink-dim sm:text-base">
          One email when it ships — and the founding price when pricing lands.
        </p>
        {state === "done" ? (
          <p className="mt-8 text-base font-medium text-accent">
            You're on the list. See you at the first downbeat.
          </p>
        ) : (
          <form
            onSubmit={submit}
            className="mx-auto mt-8 flex max-w-xl flex-col gap-3 sm:flex-row"
          >
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="you@example.com"
              className="flex-1 rounded-xl border border-line bg-fill-soft px-4 py-3 text-sm text-ink placeholder:text-ink-mute focus:border-accent/60 focus:outline-none"
            />
            <select
              value={platform}
              onChange={(e) => setPlatform(e.target.value)}
              className="rounded-xl border border-line bg-fill-soft px-3 py-3 text-sm text-ink focus:outline-none"
              aria-label="Preferred platform"
            >
              <option value="visionpro">Vision Pro</option>
              <option value="ios">iOS</option>
              <option value="web">Web</option>
            </select>
            <button
              type="submit"
              disabled={state === "sending"}
              className="rounded-xl bg-accent px-5 py-3 text-sm font-semibold text-base transition-opacity hover:opacity-90 disabled:opacity-50"
            >
              {state === "sending" ? "Joining…" : "Join the waitlist"}
            </button>
          </form>
        )}
        {state === "error" && (
          <p className="mt-3 text-sm text-red-400">
            That didn't go through — try again in a moment.
          </p>
        )}
      </div>
    </section>
  );
}
