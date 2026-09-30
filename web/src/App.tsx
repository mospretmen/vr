interface CardProps {
  title: string;
  description: string;
}

function Card({ title, description }: CardProps) {
  return (
    <div className="rounded-xl border border-zinc-800 bg-zinc-900/60 p-6 transition-colors hover:border-zinc-700">
      <h2 className="text-lg font-semibold text-zinc-100">{title}</h2>
      <p className="mt-2 text-sm text-zinc-400">{description}</p>
    </div>
  );
}

export default function App() {
  return (
    <main className="min-h-screen bg-zinc-950 text-zinc-100">
      <div className="mx-auto max-w-4xl px-6 py-24">
        <header>
          <h1 className="text-5xl font-bold tracking-tight">Fretspace</h1>
          <p className="mt-3 text-lg text-zinc-400">
            See the fretboard. In the room.
          </p>
        </header>

        <section className="mt-16 grid gap-6 sm:grid-cols-3">
          <Card
            title="Practice Stats"
            description="Session history, streaks, and time on the fretboard."
          />
          <Card
            title="Track Library"
            description="Backing tracks with chord timelines for in-headset overlays."
          />
          <Card
            title="Account"
            description="Profile and sync settings for your Vision Pro."
          />
        </section>
      </div>
    </main>
  );
}
