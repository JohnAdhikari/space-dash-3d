import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'engine.dart';
import 'math3d.dart';
import 'renderer.dart';

class _DrawOp {
  final double depth;
  final void Function() run;
  _DrawOp(this.depth, this.run);
}

class GamePainter extends CustomPainter {
  final Engine e;
  GamePainter(this.e);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final now = DateTime.now().millisecondsSinceEpoch / 1000;

    canvas.save();

    // screen shake
    if (e.shake > 0) {
      canvas.translate(
        math.sin(now * 91) * e.shake * 9,
        math.cos(now * 73) * e.shake * 7,
      );
    }

    _paintSky(canvas, w, h, now);
    _paintMountains(canvas, w, h);
    _paintGround(canvas, w, h);

    // ---------- depth-sorted scene ----------
    final boxes = <MeshInstance>[];

    // asteroids
    for (final a in e.asteroids) {
      boxes.add(MeshInstance(
        pos: a.pos,
        rotY: a.rotY,
        rotX: a.rotX,
        size: Vec3(a.size, a.size, a.size * 1.1),
        color: a.color,
      ));
    }

    // ship (skip during invulnerability blink)
    final drawShip =
        !(e.ship.invuln > 0 && now % 0.16 < 0.08) && e.state != GState.menu;
    if (drawShip) _buildShipMesh(e, boxes);

    final faces = Renderer.buildBoxFaces(e.camera, w, h, boxes);

    // billboards (gems + power-ups)
    final ops = <_DrawOp>[];
    for (final f in faces) {
      ops.add(_DrawOp(f.depth, () => _drawFace(canvas, f)));
    }
    for (final g in e.gems) {
      if (!g.taken) ops.add(_DrawOp(e.camera.depth(g.pos), () => _drawGem(canvas, w, h, g)));
    }
    for (final p in e.powers) {
      if (!p.taken) ops.add(_DrawOp(e.camera.depth(p.pos), () => _drawPower(canvas, w, h, p)));
    }
    if (drawShip) {
      ops.add(_DrawOp(e.camera.depth(e.ship.pos), () => _drawShield(canvas, w, h)));
    }

    ops.sort((a, b) => b.depth.compareTo(a.depth));
    for (final op in ops) {
      op.run();
    }

    // ---------- 2D fx on top ----------
    for (final p in e.particles) {
      final a = (p.life / p.maxLife).clamp(0.0, 1.0);
      if (p.size > 5) {
        canvas.drawCircle(
          Offset(p.sx, p.sy),
          p.size,
          Paint()
            ..color = p.color.withValues(alpha: a * 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
      canvas.drawCircle(
        Offset(p.sx, p.sy),
        p.size,
        Paint()..color = p.color.withValues(alpha: a),
      );
    }

    for (final pop in e.popups) {
      final a = (pop.life / pop.maxLife).clamp(0.0, 1.0);
      _drawText(canvas, pop.text, Offset(pop.sx, pop.sy), pop.color.withValues(alpha: a), 20);
    }

    if (e.speed > 16 && e.state == GState.playing) {
      _paintSpeedLines(canvas, w, h, now);
    }

    canvas.restore();
  }

  // ------------------- ship -------------------

  void _buildShipMesh(Engine e, List<MeshInstance> boxes) {
    final ship = e.ship;
    final cosB = math.cos(ship.bank), sinB = math.sin(ship.bank);

    // apply roll (bank) to an offset in the X-Y plane
    (double, double) roll(double dx, double dy) =>
        (dx * cosB - dy * sinB, dx * sinB + dy * cosB);

    final (wlx, wly) = roll(-0.78, -0.1);
    final (wrx, wry) = roll(0.78, -0.1);
    final (nx, ny) = roll(0.0, 0.25);

    // hull
    boxes.add(MeshInstance(
      pos: ship.pos,
      rotX: ship.pitch,
      rotY: ship.bank * 0.35,
      size: const Vec3(0.9, 0.45, 1.05),
      color: const Color(0xFF4FD1FF),
    ));
    // nose
    boxes.add(MeshInstance(
      pos: ship.pos + Vec3(nx, ny, -0.72),
      rotX: ship.pitch,
      rotY: ship.bank * 0.35,
      size: const Vec3(0.4, 0.28, 0.5),
      color: const Color(0xFF8BE9FF),
    ));
    // wings
    boxes.add(MeshInstance(
      pos: ship.pos + Vec3(wlx, wly, 0.1),
      rotX: ship.pitch,
      rotY: ship.bank * 0.35,
      size: const Vec3(0.7, 0.12, 0.4),
      color: const Color(0xFF2E9BD6),
    ));
    boxes.add(MeshInstance(
      pos: ship.pos + Vec3(wrx, wry, 0.1),
      rotX: ship.pitch,
      rotY: ship.bank * 0.35,
      size: const Vec3(0.7, 0.12, 0.4),
      color: const Color(0xFF2E9BD6),
    ));
    // tail fins
    boxes.add(MeshInstance(
      pos: ship.pos + Vec3(wlx * 0.6, wly + 0.1, 0.5),
      rotX: ship.pitch,
      rotY: ship.bank * 0.35,
      size: const Vec3(0.2, 0.28, 0.2),
      color: const Color(0xFF1F6F9F),
    ));
    boxes.add(MeshInstance(
      pos: ship.pos + Vec3(wrx * 0.6, wry + 0.1, 0.5),
      rotX: ship.pitch,
      rotY: ship.bank * 0.35,
      size: const Vec3(0.2, 0.28, 0.2),
      color: const Color(0xFF1F6F9F),
    ));
  }

  void _drawShield(Canvas canvas, double w, double h) {
    if (e.activePower != 'shield') return;
    final (sx, sy, sc) = e.camera.project(e.ship.pos, w, h);
    if (sx.isNaN) return;
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    final pulse = 0.5 + 0.5 * math.sin(now * 6);
    final r = 34 + sc * 0.02 + pulse * 3;
    canvas.drawCircle(
      Offset(sx, sy),
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + pulse * 1.5
        ..color = const Color(0xFF7DF9FF).withValues(alpha: 0.5 + pulse * 0.4),
    );
    canvas.drawCircle(
      Offset(sx, sy),
      r,
      Paint()..color = const Color(0xFF7DF9FF).withValues(alpha: 0.08),
    );
  }

  // ------------------- world -------------------

  void _paintSky(Canvas canvas, double w, double h, double now) {
    final rect = Offset.zero & Size(w, h);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF04050F), Color(0xFF0B1230), Color(0xFF1A2350)],
          stops: [0.0, 0.62, 1.0],
        ).createShader(rect),
    );

    // stars
    for (int i = 0; i < 70; i++) {
      final sx = (i * 137.5) % 97 / 97;
      final sy = (i * 89.3) % 55 / 55;
      final tw = 0.5 + 0.5 * math.sin(now * 2 + i);
      canvas.drawCircle(
        Offset(sx * w, sy * h * 0.7),
        0.7 + (i % 3) * 0.5,
        Paint()..color = Colors.white.withValues(alpha: (0.2 + 0.6 * tw).clamp(0, 1)),
      );
    }

    // sun / planet
    final sunC = Offset(w * 0.8, h * 0.16);
    canvas.drawCircle(
      sunC,
      34,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFF3C4), Color(0xFF7C6CF0), Color(0x00221B4A)],
        ).createShader(Rect.fromCircle(center: sunC, radius: 90)),
    );
  }

  void _paintMountains(Canvas canvas, double w, double h) {
    final base = h * 0.52;
    final sky = Paint()..color = const Color(0xFF0E1638);
    final path = ui.Path()..moveTo(0, base);
    // left range
    path.lineTo(w * 0.12, base - h * 0.10);
    path.lineTo(w * 0.22, base - h * 0.02);
    path.lineTo(w * 0.34, base - h * 0.13);
    path.lineTo(w * 0.5, base - h * 0.03);
    // right range
    path.lineTo(w * 0.62, base - h * 0.12);
    path.lineTo(w * 0.78, base - h * 0.02);
    path.lineTo(w * 0.9, base - h * 0.09);
    path.lineTo(w, base - h * 0.03);
    path.lineTo(w, base);
    path.close();
    canvas.drawPath(path, sky);
  }

  void _paintGround(Canvas canvas, double w, double h) {
    // horizon line
    final (hx, hy, _) = e.camera.project(const Vec3(0, 0, -60), w, h);
    if (hx.isNaN) return;
    canvas.drawRect(
      Rect.fromLTWH(0, hy, w, h - hy),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF151C3C), Color(0xFF0A0F24)],
        ).createShader(Rect.fromLTWH(0, hy, w, h - hy)),
    );

    // moving grid
    final line = Paint()
      ..color = const Color(0xFF2A6FAA).withValues(alpha: 0.5)
      ..strokeWidth = 1.3;

    for (int i = 0; i < 18; i++) {
      final z = -64 + ((i * 8 + e.gridOffset * 8) % 66);
      if (z > 3) continue;
      final (x1, y1, _) = e.camera.project(Vec3(-11, 0, z), w, h);
      final (x2, y2, _) = e.camera.project(Vec3(11, 0, z), w, h);
      if (x1.isNaN) continue;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), line);
    }

    final vline = Paint()
      ..color = const Color(0xFF2A6FAA).withValues(alpha: 0.28)
      ..strokeWidth = 1;
    for (double x = -10; x <= 10; x += 2) {
      final (a1, b1, _) = e.camera.project(Vec3(x, 0, -4), w, h);
      final (a2, b2, _) = e.camera.project(Vec3(x, 0, -64), w, h);
      if (a1.isNaN) continue;
      canvas.drawLine(Offset(a1, b1), Offset(a2, b2), vline);
    }

    // horizon glow
    canvas.drawRect(
      Rect.fromLTWH(0, hy - 14, w, 30),
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0x00000000),
            const Color(0x2200B4FF),
            const Color(0x00000000),
          ],
        ).createShader(Rect.fromLTWH(0, hy - 14, w, 30)),
    );
  }

  void _paintSpeedLines(Canvas canvas, double w, double h, double now) {
    final strength = ((e.speed - 16) / 14).clamp(0.0, 1.0);
    final c = Offset(w / 2, h / 2);
    for (int i = 0; i < 12; i++) {
      final a = i / 12 * 6.2832 + now * 0.1;
      final r1 = math.min(w, h) * 0.35;
      final r2 = r1 + 40 + 120 * strength;
      canvas.drawLine(
        c + Offset(math.cos(a) * r1, math.sin(a) * r1),
        c + Offset(math.cos(a) * r2, math.sin(a) * r2),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.05 + 0.1 * strength)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  // ------------------- billboards -------------------

  void _drawGem(Canvas canvas, double w, double h, Gem g) {
    final (sx, sy, sc) = e.camera.project(g.pos, w, h);
    if (sx.isNaN) return;
    final radius = (10 + sc * 0.03) * (0.92 + 0.16 * math.sin(g.rot * 2));
    if (radius < 1.5) return;

    final glow = Paint()
      ..color = const Color(0xFFFFC53D).withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(sx, sy), radius * 1.7, glow);

    final path = ui.Path()
      ..moveTo(sx, sy - radius)
      ..lineTo(sx + radius * 0.72, sy)
      ..lineTo(sx, sy + radius)
      ..lineTo(sx - radius * 0.72, sy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF3B0), Color(0xFFFFB300)],
        ).createShader(Rect.fromCircle(center: Offset(sx, sy), radius: radius)),
    );
    canvas.drawCircle(
      Offset(sx - radius * 0.28, sy - radius * 0.32),
      radius * 0.16,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  void _drawPower(Canvas canvas, double w, double h, PowerUp p) {
    final (sx, sy, sc) = e.camera.project(p.pos, w, h);
    if (sx.isNaN) return;
    final radius = 13 + sc * 0.03;
    if (radius < 2) return;

    final color = switch (p.kind) {
      'shield' => const Color(0xFF7DF9FF),
      'magnet' => const Color(0xFFF472B6),
      _ => const Color(0xFFFFA726),
    };

    final glow = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(sx, sy), radius * 1.9, glow);

    final path = ui.Path();
    for (int i = 0; i < 6; i++) {
      final a = i / 6 * 6.2832;
      final px = sx + math.cos(a) * radius;
      final py = sy + math.sin(a) * radius;
      i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.22));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: 0.9),
    );

    final emoji = switch (p.kind) {
      'shield' => '🛡',
      'magnet' => '🧲',
      _ => '⏳',
    };
    _drawText(canvas, emoji, Offset(sx, sy - radius * 0.5), Colors.white, radius * 0.9);
  }

  // ------------------- utils -------------------

  void _drawFace(Canvas canvas, DrawFace f) {
    canvas.drawPath(
      f.path,
      Paint()
        ..style = PaintingStyle.fill
        ..color = f.fill,
    );
    canvas.drawPath(
      f.path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round
        ..color = f.edge,
    );
  }

  void _drawText(Canvas canvas, String text, Offset at, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w800,
          color: color,
          fontFamily: 'monospace',
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 300);
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
