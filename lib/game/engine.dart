import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'math3d.dart';

enum GState { menu, playing, paused, gameOver }

class Ship {
  Vec3 pos = const Vec3(0, 1.7, 0);
  Vec3 target = const Vec3(0, 1.7, 0);
  double bank = 0;
  double pitch = 0;
  double invuln = 0;
  double thrustPulse = 0;
}

class Asteroid {
  Vec3 pos;
  final double size;
  double rotY, rotX;
  final double rotYSpeed, rotXSpeed;
  final double vx;
  final Color color;
  Asteroid({
    required this.pos,
    required this.size,
    required this.color,
    this.vx = 0,
  })  : rotY = math.Random().nextDouble() * 6.28,
        rotX = math.Random().nextDouble() * 6.28,
        rotYSpeed = (math.Random().nextDouble() - 0.5) * 3,
        rotXSpeed = (math.Random().nextDouble() - 0.5) * 3;
}

class Gem {
  Vec3 pos;
  double rot = 0;
  bool taken = false;
  Gem({required this.pos});
}

class PowerUp {
  final String kind; // shield | magnet | slow
  Vec3 pos;
  double rot = 0;
  bool taken = false;
  PowerUp({required this.kind, required this.pos});
}

class Particle {
  double sx, sy;
  double vx, vy;
  double life;
  final double maxLife;
  final double size;
  final Color color;
  Particle({
    required this.sx,
    required this.sy,
    required this.vx,
    required this.vy,
    required this.life,
    required this.size,
    required this.color,
  }) : maxLife = life;
}

class Popup {
  double sx, sy;
  final String text;
  double life;
  final double maxLife;
  final Color color;
  Popup({
    required this.sx,
    required this.sy,
    required this.text,
    required this.color,
  })  : life = 1.4,
        maxLife = 1.4;
}

class Engine {
  GState state = GState.menu;
  final Camera camera = Camera();

  final Ship ship = Ship();
  final List<Asteroid> asteroids = [];
  final List<Gem> gems = [];
  final List<PowerUp> powers = [];
  final List<Particle> particles = [];
  final List<Popup> popups = [];
  final math.Random rng = math.Random();

  double width = 400;
  double height = 800;

  double speed = 10;
  double time = 0;
  double distance = 0;
  int score = 0;
  int best = 0;
  int combo = 0;
  double comboTimer = 0;
  int lives = 3;
  int level = 1;
  int gemsCollected = 0;

  String? activePower;
  double powerTime = 0;

  double shake = 0;
  double hitStop = 0;
  double spawnTimer = 0;
  double spawnInterval = 1.5;
  double gridOffset = 0;

  SharedPreferences? prefs;

  double difficulty = 1.0; // set before start() from difficulty setting

  static const double minX = -4.2, maxX = 4.2;
  static const double minY = 0.55, maxY = 3.3;

  // ---- setup ----

  Future<void> loadBest() async {
    prefs = await SharedPreferences.getInstance();
    best = prefs?.getInt('best') ?? 0;
  }

  Future<void> saveBest() async {
    if (prefs != null && score > (prefs?.getInt('best') ?? 0)) {
      await prefs?.setInt('best', score);
      best = score;
    }
  }

  void resize(double w, double h) {
    width = w;
    height = h;
  }

  // ---- input ----

  void setTouch(double sx, double sy) {
    final depth = camera.pos.z; // ship plane is z = 0
    final f = camera.focal * height * 0.5;
    var wx = camera.pos.x + (sx - width / 2) * depth / f;
    var wy = camera.pos.y - (sy - height / 2) * depth / f;
    wx = wx.clamp(minX, maxX);
    wy = wy.clamp(minY, maxY);
    ship.target = Vec3(wx, wy, 0);
  }

  // ---- lifecycle ----

  void start() {
    state = GState.playing;
    asteroids.clear();
    gems.clear();
    powers.clear();
    particles.clear();
    popups.clear();
    ship.pos = const Vec3(0, 1.7, 0);
    ship.target = const Vec3(0, 1.7, 0);
    ship.invuln = 1.2;
    ship.bank = 0;
    speed = 10;
    time = 0;
    distance = 0;
    score = 0;
    combo = 0;
    comboTimer = 0;
    lives = 3;
    level = 1;
    gemsCollected = 0;
    activePower = null;
    powerTime = 0;
    shake = 0;
    hitStop = 0;
    spawnTimer = 1.2;
    spawnInterval = 1.5;
  }

  void gameOver() {
    state = GState.gameOver;
    saveBest();
  }

  // ---- main loop ----

  void update(double dt) {
    // fx that always animate (unless paused)
    if (state != GState.paused) {
      _updateFx(dt);
      shake = math.max(0.0, shake - dt * 2.0);
      if (hitStop > 0) {
        hitStop -= dt;
        return; // world frozen during hit-stop
      }
    }

    if (state != GState.playing) return;

    time += dt;
    distance += speed * dt;
    gridOffset = (gridOffset + speed * dt) % 8;

    // difficulty
    speed = math.min(30, (9 + time * 0.55 + level * 0.5) * difficulty);
    level = 1 + (time / 16).floor();
    spawnInterval = math.max(0.55, 1.5 - time * 0.012);

    // combos
    if (combo > 0) {
      comboTimer -= dt;
      if (comboTimer <= 0) combo = 0;
    }

    // power timers
    if (activePower != null) {
      powerTime -= dt;
      if (powerTime <= 0) activePower = null;
    }

    // ship follow
    ship.pos = ship.pos.lerp(ship.target, math.min(1, dt * 11));
    final dxv = ship.target.x - ship.pos.x;
    final dyv = ship.target.y - ship.pos.y;
    ship.bank = (ship.bank + (dxv * -0.85 - ship.bank) * math.min(1, dt * 8));
    ship.pitch = (ship.pitch + (dyv * 0.5 - ship.pitch) * math.min(1, dt * 8));
    ship.thrustPulse += dt;
    if (ship.invuln > 0) ship.invuln -= dt;

    final slow = activePower == 'slow' ? 0.55 : 1.0;
    final move = speed * slow;

    // move + rotate entities
    for (final a in asteroids) {
      a.pos = Vec3(a.pos.x, a.pos.y, a.pos.z + move * dt);
      a.rotY += a.rotYSpeed * dt;
      a.rotX += a.rotXSpeed * dt;
      if (a.vx != 0) {
        final nx = a.pos.x + a.vx * dt;
        a.pos = Vec3(nx.clamp(-5.2, 5.2), a.pos.y, a.pos.z);
      }
    }
    for (final g in gems) {
      g.pos = Vec3(g.pos.x, g.pos.y, g.pos.z + move * dt);
      g.rot += dt * 3.4;
    }
    for (final p in powers) {
      p.pos = Vec3(p.pos.x, p.pos.y, p.pos.z + move * dt);
      p.rot += dt * 2.6;
    }

    asteroids.removeWhere((a) => a.pos.z > 0);
    gems.removeWhere((g) => g.pos.z > 0);
    powers.removeWhere((p) => p.pos.z > 0);

    // magnet attracts gems
    if (activePower == 'magnet') {
      for (final g in gems) {
        if (g.taken || g.pos.z > -25) continue;
        g.pos = g.pos.lerp(ship.pos, math.min(1, dt * 7));
      }
    }

    // engine trail
    _spawnEngineTrail();

    // collisions
    _collide();

    // spawn
    spawnTimer -= dt;
    while (spawnTimer <= 0) {
      spawnTimer += spawnInterval;
      _spawnPattern();
    }
  }

  void _updateFx(double dt) {
    for (final p in particles) {
      p.sx += p.vx * dt;
      p.sy += p.vy * dt;
      p.vy += 240 * dt;
      p.life -= dt * 1.3;
    }
    particles.removeWhere((p) => p.life <= 0);

    for (final pop in popups) {
      pop.sy -= 46 * dt;
      pop.life -= dt;
    }
    popups.removeWhere((p) => p.life <= 0);
  }

  // ---- fx helpers ----

  (double, double, double) screenOf(Vec3 world) =>
      camera.project(world, width, height);

  void _spawnEngineTrail() {
    final (sx, sy, _) = screenOf(ship.pos);
    if (sx.isNaN) return;
    for (int i = 0; i < 2; i++) {
      particles.add(Particle(
        sx: sx + (rng.nextDouble() - 0.5) * 10,
        sy: sy + (rng.nextDouble() - 0.5) * 10,
        vx: (rng.nextDouble() - 0.5) * 30,
        vy: 34 + rng.nextDouble() * 40,
        life: 0.3 + rng.nextDouble() * 0.2,
        size: 2.5 + rng.nextDouble() * 2.5,
        color: rng.nextBool()
            ? const Color(0xFF7DF9FF)
            : const Color(0xFFFF9E5E),
      ));
    }
  }

  void explodeAt(Vec3 world, {int count = 26, Color? color}) {
    final (sx, sy, _) = screenOf(world);
    if (sx.isNaN) return;
    final colors = color == null
        ? [const Color(0xFF57D6FF), const Color(0xFFE0525F), Colors.amber, Colors.white]
        : [color, Colors.white, const Color(0xFFFFB74D)];
    for (int i = 0; i < count; i++) {
      final ang = rng.nextDouble() * 6.2832;
      final sp = 80 + rng.nextDouble() * 280;
      particles.add(Particle(
        sx: sx,
        sy: sy,
        vx: math.cos(ang) * sp,
        vy: math.sin(ang) * sp,
        life: 0.4 + rng.nextDouble() * 0.5,
        size: 2 + rng.nextDouble() * 3,
        color: colors[rng.nextInt(colors.length)],
      ));
    }
  }

  void addPopup(String text, Vec3 world, {Color color = Colors.amber}) {
    final (sx, sy, _) = screenOf(world);
    if (sx.isNaN) return;
    popups.add(Popup(sx: sx, sy: sy, text: text, color: color));
  }

  // ---- collisions ----

  void _collide() {
    final r = 0.52; // player radius

    for (final a in asteroids) {
      if (a.pos.z < -2.0 || a.pos.z > 0) continue;
      final ar = 0.55 * a.size;
      if ((a.pos.x - ship.pos.x).abs() < r + ar &&
          (a.pos.y - ship.pos.y).abs() < r + ar) {
        _hitAsteroid(a);
      }
    }

    for (final g in gems) {
      if (g.taken) continue;
      if (g.pos.z < -2.0 || g.pos.z > 0) continue;
      if ((g.pos.x - ship.pos.x).abs() < 0.95 &&
          (g.pos.y - ship.pos.y).abs() < 0.95) {
        g.taken = true;
        gemsCollected++;
        combo++;
        comboTimer = 3.0;
        final gain = combo;
        score += gain;
        addPopup('+$gain', g.pos,
            color: combo >= 5 ? const Color(0xFFFFD54F) : Colors.white);
        explodeAt(g.pos, count: 8, color: const Color(0xFFFFD54F));
      }
    }

    for (final p in powers) {
      if (p.taken) continue;
      if (p.pos.z < -2.0 || p.pos.z > 0) continue;
      if ((p.pos.x - ship.pos.x).abs() < 0.95 &&
          (p.pos.y - ship.pos.y).abs() < 0.95) {
        p.taken = true;
        activePower = p.kind;
        powerTime = 8.0;
        addPopup(_powerLabel(p.kind), p.pos, color: _powerColor(p.kind));
      }
    }
  }

  void _hitAsteroid(Asteroid a) {
    if (activePower == 'shield') {
      activePower = null;
      powerTime = 0;
      combo = 0;
      comboTimer = 0;
      a.pos = Vec3(a.pos.x, a.pos.y, 10); // remove
      explodeAt(a.pos, color: const Color(0xFF90A4AE));
      addPopup('SHIELD!', a.pos, color: const Color(0xFF7DF9FF));
      shake = 0.55;
      return;
    }
    if (ship.invuln > 0) return;

    hitStop = 0.16;
    shake = 1;
    combo = 0;
    comboTimer = 0;
    explodeAt(ship.pos, color: const Color(0xFF57D6FF));
    explodeAt(a.pos, color: const Color(0xFFE0525F));
    lives--;
    if (lives <= 0) {
      gameOver();
    } else {
      ship.invuln = 2.2;
    }
  }

  String _powerLabel(String kind) => switch (kind) {
        'shield' => '🛡 SHIELD',
        'magnet' => '🧲 MAGNET',
        _ => '⏳ SLOW-MO',
      };

  Color _powerColor(String kind) => switch (kind) {
        'shield' => const Color(0xFF7DF9FF),
        'magnet' => const Color(0xFFF472B6),
        _ => const Color(0xFFFFA726),
      };

  // ---- spawning ----

  void _spawnPattern() {
    final roll = rng.nextDouble();
    if (roll < 0.48) {
      _spawnGemLine();
    } else if (roll < 0.86) {
      _spawnRocks();
    } else {
      _spawnPower();
    }
  }

  void _spawnGemLine() {
    final horizontal = rng.nextBool();
    final baseX = (rng.nextDouble() * 2 - 1) * 3.2;
    final baseY = 1.0 + rng.nextDouble() * 2.0;
    final count = 4 + rng.nextInt(2);
    for (int i = 0; i < count; i++) {
      final x = horizontal ? baseX + (i - count / 2) * 1.05 : baseX + (rng.nextDouble() - 0.5) * 0.6;
      final y = horizontal ? baseY + (rng.nextDouble() - 0.5) * 0.4 : baseY + (i - count / 2) * 1.05;
      gems.add(Gem(
        pos: Vec3(x.clamp(minX + 0.4, maxX - 0.4),
            y.clamp(minY + 0.4, maxY - 0.4), -72 - rng.nextDouble() * 4),
      ));
    }
  }

  void _spawnRocks() {
    final n = 1 + (rng.nextDouble() < time * 0.03 ? 1 : 0);
    for (int i = 0; i < n; i++) {
      final x = (rng.nextDouble() * 2 - 1) * 4.6;
      final y = 0.6 + rng.nextDouble() * 2.9;
      final size = 0.75 + rng.nextDouble() * 0.7;
      final moving = time > 20 && rng.nextDouble() < 0.3;
      asteroids.add(Asteroid(
        pos: Vec3(x, y, -70 - rng.nextDouble() * 6),
        size: size,
        color: rng.nextBool()
            ? const Color(0xFF9AA7B5)
            : const Color(0xFFB08968),
        vx: moving ? (rng.nextBool() ? 1.4 : -1.4) : 0,
      ));
    }
  }

  void _spawnPower() {
    if (activePower != null && rng.nextDouble() < 0.5) {
      _spawnGemLine();
      return;
    }
    const kinds = ['shield', 'magnet', 'slow'];
    powers.add(PowerUp(
      kind: kinds[rng.nextInt(3)],
      pos: Vec3(
        (rng.nextDouble() * 2 - 1) * 3.4,
        0.9 + rng.nextDouble() * 2.2,
        -72,
      ),
    ));
  }
}
