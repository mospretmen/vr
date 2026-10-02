# Testing Fretspace on Apple Vision Pro

## One-time setup (current blocker → first build)

1. **Accept the Xcode license** (the only step Claude can't do unattended):
   ```sh
   sudo xcodebuild -license accept
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```
2. **Install the visionOS platform** (~8 GB, one time):
   ```sh
   xcodebuild -downloadPlatform visionOS
   ```
3. **Generate and open the project:**
   ```sh
   cd apps/FretspaceVision && xcodegen generate && open FretspaceVision.xcodeproj
   ```
4. In Xcode → Settings → Accounts, sign in with the Apple ID. A free
   account can install to your own device (7-day re-sign); the $99/yr
   Apple Developer Program removes that limit and unlocks TestFlight.

## Tier 1 — visionOS Simulator (first stop, no headset needed)

Product → Destination → *Apple Vision Pro* simulator → Run. What works:
all windows (control panel, chart), the immersive space in a simulated
room, overlay rendering after a *simulated* calibration. What doesn't:
real hand-tracking pinches (simulator sends synthetic gestures), the mic
pipeline, and real-world passthrough. Good for UI iteration and crash
hunting; not for calibration feel.

## Tier 2 — Your Vision Pro over Wi-Fi (the real test)

1. On the headset: **Settings → Privacy & Security → Developer Mode → on**
   (reboot prompt). Both devices on the same Wi-Fi.
2. Xcode → Window → Devices and Simulators: the headset appears; pair
   (code shown in the headset).
3. Select the device as destination → Run. First install asks you to
   trust the developer profile on-device (Settings → General → VPN &
   Device Management).
4. First-session manual test script:
   - Calibrate: pinch nut, pinch 12th fret → overlay locks on; verify
     scale-length readout matches your guitar (25.5" Strat ≈ 648 mm).
   - Walk around the guitar: overlay should stay glued (world anchoring).
   - Relaunch the app: calibration should restore with no pinching.
   - Scale/box/voicing modes, lefty toggle, chart panel mirroring.
   - Listen mode with real strumming: chord symbol + aura (expect to
     tune thresholds; log output is in Console.app under subsystem
     `com.gabrielmotta.fretspace`).

## Tier 3 — TestFlight (friends & future customers)

Needs the paid developer account: archive → App Store Connect upload →
internal testers (instant) or external testers (one-time beta review).
This is the path for guitarist beta feedback before launch.

## Backend/web while testing

```sh
cd backend && npm run dev          # http://localhost:3000, in-memory data
cd web && npm run dev              # http://localhost:5173
```
On-device app → local backend: set the clients' baseURL to your Mac's
LAN IP (TODO: build-config override; currently localhost in
TrackLibraryClient/PracticeSyncClient — works in simulator as-is).
