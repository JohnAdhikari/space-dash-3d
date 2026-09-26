import 'dart:math' as math;

/// Minimal 3D vector.
class Vec3 {
  final double x, y, z;
  const Vec3(this.x, this.y, this.z);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);
  Vec3 operator -() => Vec3(-x, -y, -z);

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;
  Vec3 cross(Vec3 o) => Vec3(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );
  double len() => math.sqrt(x * x + y * y + z * z);
  Vec3 norm() {
    final l = len();
    if (l < 1e-9) return this;
    return Vec3(x / l, y / l, z / l);
  }

  Vec3 lerp(Vec3 b, double t) => Vec3(x + (b.x - x) * t, y + (b.y - y) * t, z + (b.z - z) * t);

  @override
  String toString() => '($x, $y, $z)';
}

/// A fixed, axis-aligned pinhole camera.
///
/// Conventions (the standard, intuitive setup):
///   +X right, +Y **up**, -Z into the screen (forward).
/// The camera sits above the ground (y > 0) looking forward, so the
/// ground plane renders in the lower half of the screen and the sky above.
class Camera {
  final Vec3 pos;
  final double fovYDeg;
  final double _near;

  Camera({Vec3? pos, this.fovYDeg = 64, this._near = 0.1})
      : pos = pos ?? const Vec3(0, 1.9, 5);

  double get focal => 1 / math.tan(fovYDeg * math.pi / 360); // focal in "world units -> px per unit"

  /// Projects a world point to screen coordinates.
  /// Returns (sx, sy, scale) where scale = screen pixels per world unit.
  (double, double, double) project(Vec3 p, double width, double height) {
    final depth = pos.z - p.z; // positive when point is in front of the camera
    if (depth < _near) return (double.nan, double.nan, 0);
    final f = focal * height * 0.5;
    final sx = width / 2 + (p.x - pos.x) * f / depth;
    final sy = height / 2 - (p.y - pos.y) * f / depth; // -Y on screen = up in world
    final scale = f / depth;
    return (sx, sy, scale);
  }

  /// Screen-space distance from the camera to a world point (for depth sorting).
  double depth(Vec3 p) => (p - pos).len();
}
