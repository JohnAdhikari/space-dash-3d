import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'math3d.dart';

/// A unit box mesh (local space, centered at origin, half-extent 1).
class BoxMesh {
  static const List<Vec3> corners = [
    Vec3(-1, -1, -1), // 0
    Vec3(1, -1, -1), //  1
    Vec3(1, 1, -1), //   2
    Vec3(-1, 1, -1), //  3
    Vec3(-1, -1, 1), //  4
    Vec3(1, -1, 1), //   5
    Vec3(1, 1, 1), //    6
    Vec3(-1, 1, 1), //   7
  ];

  static const List<List<int>> faces = [
    [4, 5, 6, 7], // +Z
    [1, 0, 3, 2], // -Z
    [5, 1, 2, 6], // +X
    [0, 4, 7, 3], // -X
    [7, 6, 2, 3], // +Y
    [0, 1, 5, 4], // -Y
  ];

  static const List<Vec3> normals = [
    Vec3(0, 0, 1),
    Vec3(0, 0, -1),
    Vec3(1, 0, 0),
    Vec3(-1, 0, 0),
    Vec3(0, 1, 0),
    Vec3(0, -1, 0),
  ];
}

/// A 3D box placed in the world.
class MeshInstance {
  final Vec3 pos;
  double rotY;
  double rotX;
  final Vec3 size;
  Color color;

  MeshInstance({
    required this.pos,
    this.rotY = 0,
    this.rotX = 0,
    this.size = const Vec3(1, 1, 1),
    required this.color,
  });
}

/// A projected, shaded 2D face ready to be drawn (depth-sortable).
class DrawFace {
  final double depth;
  final ui.Path path;
  final Color fill;
  final Color edge;
  DrawFace(this.depth, this.path, this.fill, this.edge);
}

/// Projects + shades box meshes into depth-sortable faces.
class Renderer {
  static const Vec3 _lightDir = Vec3(0.45, 0.85, 0.3);

  static Color shade(Color color, double b) => Color.fromARGB(
        255,
        (color.r * 255 * b).round().clamp(0, 255),
        (color.g * 255 * b).round().clamp(0, 255),
        (color.b * 255 * b).round().clamp(0, 255),
      );

  static List<DrawFace> buildBoxFaces(
    Camera cam,
    double width,
    double height,
    List<MeshInstance> boxes, {
    Color fogColor = const Color(0xFF0B1230),
  }) {
    final faces = <DrawFace>[];
    if (boxes.isEmpty) return faces;
    final light = _lightDir.norm();

    for (final inst in boxes) {
      final half = inst.size * 0.5;
      final cy = math.cos(inst.rotY), sy = math.sin(inst.rotY);
      final cx = math.cos(inst.rotX), sx = math.sin(inst.rotX);

      final world = List<Vec3>.generate(8, (i) {
        final c = BoxMesh.corners[i];
        final lx = c.x * half.x;
        final ly = c.y * half.y;
        final lz = c.z * half.z;
        var rx = lx * cy - lz * sy;
        var rz = lx * sy + lz * cy;
        final ry = ly * cx - rz * sx;
        rz = ly * sx + rz * cx;
        return inst.pos + Vec3(rx, ry, rz);
      });

      for (int f = 0; f < 6; f++) {
        final idx = BoxMesh.faces[f];
        final n = BoxMesh.normals[f];
        final nx = n.x * cy - n.z * sy;
        final nz = n.x * sy + n.z * cy;
        final ny = n.y * cx - nz * sx;
        final nzz = n.y * sx + nz * cx;
        final worldN = Vec3(nx, ny, nzz);

        final c0 = world[idx[0]];
        final c2 = world[idx[2]];
        final center = (c0 + c2) * 0.5;

        if (worldN.dot(cam.pos - center) <= 0) continue;

        final pts = <Offset>[];
        var ok = true;
        for (final ci in idx) {
          final (sx2, sy2, _) = cam.project(world[ci], width, height);
          if (sx2.isNaN) {
            ok = false;
            break;
          }
          pts.add(Offset(sx2, sy2));
        }
        if (!ok) continue;

        final path = ui.Path()..moveTo(pts[0].dx, pts[0].dy);
        for (int i = 1; i < 4; i++) {
          path.lineTo(pts[i].dx, pts[i].dy);
        }
        path.close();

        final b = 0.42 + 0.58 * math.max(0.0, worldN.dot(light));
        var fill = shade(inst.color, b);

        final dist = cam.depth(center);
        final fog = ((dist - 5) / 34).clamp(0.0, 0.82);
        if (fog > 0) fill = Color.lerp(fill, fogColor, fog)!;

        final edge = Color.lerp(fill, Colors.black, 0.32)!;
        faces.add(DrawFace(dist, path, fill, edge));
      }
    }

    faces.sort((a, b) => b.depth.compareTo(a.depth));
    return faces;
  }

  static void drawFaces(Canvas canvas, List<DrawFace> faces) {
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round;

    for (final face in faces) {
      fillPaint.color = face.fill;
      canvas.drawPath(face.path, fillPaint);
      edgePaint.color = face.edge;
      canvas.drawPath(face.path, edgePaint);
    }
  }
}
