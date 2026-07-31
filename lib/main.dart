import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'game/engine.dart';
import 'game/painter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const SpaceDashApp());
}

class SpaceDashApp extends StatelessWidget {
  const SpaceDashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Space Dash 3D',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF04050F),
        fontFamily: 'monospace',
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  final Engine engine = Engine();
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  int _difficulty = 1; // 0 easy, 1 normal, 2 hard

  @override
  void initState() {
    super.initState();
    engine.loadBest().then((_) {
      _difficulty = engine.prefs?.getInt('diff') ?? 1;
      if (mounted) setState(() {});
    });
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration now) {
    var dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (dt <= 0) return;
    dt = dt.clamp(0.0, 0.05);
    setState(() => engine.update(dt));
  }

  void _start() {
    engine.difficulty = switch (_difficulty) {
      0 => 0.8,
      2 => 1.25,
      _ => 1.0,
    };
    engine.start();
  }

  void _setDiff(int d) {
    setState(() {
      _difficulty = d;
      engine.prefs?.setInt('diff', d);
    });
  }

  void _handleTap(TapDownDetails d, double w) {
    if (engine.state == GState.menu || engine.state == GState.gameOver) {
      _start();
    } else if (engine.state == GState.paused) {
      setState(() => engine.state = GState.playing);
    } else if (engine.state == GState.playing) {
      engine.setTouch(d.localPosition.dx, d.localPosition.dy);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    engine.resize(w, h);

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _handleTap(d, w),
        onPanUpdate: (d) {
          if (engine.state == GState.playing) {
            engine.setTouch(d.globalPosition.dx, d.globalPosition.dy);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: GamePainter(engine)),
            // vignette
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 1.3,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.38)],
                  ),
                ),
              ),
            ),
            if (engine.state == GState.playing || engine.state == GState.paused)
              _buildHud(w),
            if (engine.state == GState.menu) _buildMenu(),
            if (engine.state == GState.gameOver) _buildGameOver(),
            if (engine.state == GState.paused) _buildPaused(),
          ],
        ),
      ),
    );
  }

  // ---------------- HUD ----------------

  Widget _buildHud(double w) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _hudBlock('SCORE', '${engine.score}', const Color(0xFFFFC53D)),
                const Spacer(),
                _hudBlock('LVL', '${engine.level}', const Color(0xFF7DF9FF)),
                const SizedBox(width: 16),
                _hudBlock('BEST', '${engine.best}', const Color(0xFFB39DFF)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                // lives
                for (int i = 0; i < engine.lives; i++)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Text('❤️', style: TextStyle(fontSize: 16)),
                  ),
                const Spacer(),
                if (engine.combo > 1)
                  Text(
                    'COMBO x${engine.combo}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: Colors.orangeAccent.withValues(alpha: 0.9),
                    ),
                  ),
                if (engine.activePower != null) ...[
                  const SizedBox(width: 10),
                  _powerChip(engine.activePower!, engine.powerTime),
                ],
                const Spacer(),
                IconButton(
                  onPressed: () {
                    setState(() {
                      engine.state =
                          engine.state == GState.playing ? GState.paused : GState.playing;
                    });
                  },
                  icon: Icon(
                    engine.state == GState.paused ? Icons.play_circle : Icons.pause_circle,
                    color: Colors.white70,
                    size: 26,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '✦ ${engine.gemsCollected}',
                    style: const TextStyle(color: Color(0xFFFFC53D), fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hudBlock(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.white38)),
        Text(value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
              shadows: [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 12)],
            )),
      ],
    );
  }

  Widget _powerChip(String power, double seconds) {
    final (emoji, color) = switch (power) {
      'shield' => ('🛡', const Color(0xFF7DF9FF)),
      'magnet' => ('🧲', const Color(0xFFF472B6)),
      _ => ('⏳', const Color(0xFFFFA726)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text('$emoji ${seconds.ceil()}s',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
    );
  }

  // ---------------- menus ----------------

  Widget _panel(Widget child) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 36),
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
      decoration: BoxDecoration(
        color: const Color(0xE60A0F24),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF2A6FAA).withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF00B4FF).withValues(alpha: 0.25), blurRadius: 44),
        ],
      ),
      child: child,
    );
  }

  Widget _buildMenu() {
    return Center(
      child: _panel(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🚀',
                style: TextStyle(fontSize: 44, shadows: [Shadow(color: Colors.cyan, blurRadius: 30)])),
            const SizedBox(height: 8),
            const Text(
              'SPACE DASH',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: Colors.white,
                shadows: [Shadow(color: Color(0xFF00B4FF), blurRadius: 26)],
              ),
            ),
            const Text('3D', style: TextStyle(fontSize: 14, letterSpacing: 8, color: Color(0xFF7DF9FF))),
            const SizedBox(height: 18),
            const Text(
              'drag to fly • dodge rocks 🔴\ncollect gems 🟡 • grab power-ups',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.6, color: Colors.white70),
            ),
            const SizedBox(height: 22),
            _difficultySelector(),
            const SizedBox(height: 24),
            _bigButton('LAUNCH 🚀', () => _start()),
          ],
        ),
      ),
    );
  }

  Widget _difficultySelector() {
    const options = ['EASY', 'NORMAL', 'HARD'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _setDiff(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _difficulty == i
                    ? const Color(0xFF00B4FF).withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: _difficulty == i ? const Color(0xFF00B4FF) : Colors.white24,
                ),
              ),
              child: Text(options[i],
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                    color: _difficulty == i ? const Color(0xFF9BEBFF) : Colors.white60,
                  )),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPaused() {
    return Center(
      child: _panel(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('PAUSED',
                style: TextStyle(
                  fontSize: 26,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                )),
            const SizedBox(height: 16),
            const Text('tap anywhere to resume', style: TextStyle(color: Colors.white60, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOver() {
    final isRecord = engine.score >= engine.best && engine.score > 0;
    return Center(
      child: _panel(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isRecord ? 'NEW RECORD! 🏆' : 'GAME OVER',
                style: TextStyle(
                  fontSize: 26,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w900,
                  color: isRecord ? const Color(0xFFFFC53D) : Colors.white,
                  shadows: [Shadow(color: const Color(0xFFFFC53D).withValues(alpha: 0.5), blurRadius: 18)],
                )),
            const SizedBox(height: 20),
            _statRow('SCORE', '${engine.score}'),
            _statRow('BEST', '${engine.best}'),
            _statRow('GEMS', '${engine.gemsCollected}'),
            _statRow('LEVEL', '${engine.level}'),
            _statRow('DISTANCE', '${(engine.distance / 10).round()} km'),
            const SizedBox(height: 22),
            _bigButton('FLY AGAIN 🔁', _start),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, letterSpacing: 2, color: Colors.white38)),
          Text(value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _bigButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF00B4FF), Color(0xFF7C4DFF)]),
          borderRadius: BorderRadius.circular(99),
          boxShadow: [BoxShadow(color: const Color(0xFF00B4FF).withValues(alpha: 0.4), blurRadius: 20)],
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)),
      ),
    );
  }
}
