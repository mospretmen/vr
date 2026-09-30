import { PracticeStats } from "./components/PracticeStats";
import { TrackLibrary } from "./components/TrackLibrary";

interface PlaceholderCardProps {
  title: string;
  description: string;
}

function PlaceholderCard({ title, description }: PlaceholderCardProps) {
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

        <section className="mt-16">
          <h2 className="text-lg font-semibold text-zinc-100">
            Track Library
          </h2>
          <p className="mt-1 text-sm text-zinc-400">
            Backing tracks with chord timelines for in-headset overlays.
          </p>
          <div className="mt-6">
            <TrackLibrary />
          </div>
        </section>

        <section className="mt-12 grid gap-6 sm:grid-cols-2">
          <PracticeStats />
          <PlaceholderCard
            title="Account"
            description="Profile and sync settings for your Vision Pro."
          />
        </section>
      </div>
    </main>
  );
}
