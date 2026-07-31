# 🚀 Space Dash 3D

A simple, addictive **3D runner** built with Flutter — **no game engine, no plugins** (except offline-safe `shared_preferences` for your best score). The 3D is hand-rolled: perspective projection, shaded rotating cubes, depth sorting — all rendered on a `CustomPainter`.

## 🎮 How to Play

Steer your cube left/right to **collect golden gems 🟡** and **dodge red rocks 🔴**. Tap the left/right side of the screen (or drag) to move. Speed and levels ramp up as you go.

**Power-ups**
- 🛡 **Shield** — survives one rock hit
- 🧲 **Magnet** — pulls gems toward you
- ⏳ **Slow-mo** — slows time for a few seconds

**Scoring**
- Each gem adds to your **combo** (x1, x2, x3…) — keep collecting without a hit to multiply
- **Best score** is saved on your device (`shared_preferences`)

**Extras**
- 🧨 Crash **explosion + screen shake**
- 🌍 Scrolling perspective grid floor, starfield, glowing planet
- ⏸ Pause button · levels shown in HUD · fully offline

## ✨ Features

- Real 3D rendering (custom perspective projection + painter's-algorithm depth sorting)
- 60 FPS game loop via `Ticker`
- Responsive to device size, portrait lock, immersive fullscreen
- No internet needed at runtime

## 🧰 Tech Stack

| Layer | Choice |
|---|---|
| Framework | Flutter 3.44 |
| Storage | shared_preferences (best score) |
| Rendering | CustomPainter + manual 3D math |

## 🚀 Build & Run

```bash
flutter pub get
flutter run                       # run on a connected device / emulator
flutter analyze                   # static analysis (clean)
flutter build apk --release       # → build/app/outputs/flutter-apk/app-release.apk
```

## 📲 Install on Android

Copy `build/app/outputs/flutter-apk/app-release.apk` to your phone, allow "install unknown apps", and install. Or plug the phone in (USB debugging) and run `flutter install`.
