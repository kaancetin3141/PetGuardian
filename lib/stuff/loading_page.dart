import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import '../main.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loading Page'),
        centerTitle: true,
      ),
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return CustomPaint(
              painter: PawPainter(
                progress: _animationController.value,
                pawColor: Theme.of(context).colorScheme.primary,
              ),
              child: const SizedBox(
                width: 100,
                height: 100,
              ),
            );
          },
        ),
      ),
    );
  }
}

class PawPainter extends CustomPainter {
  final double progress;
  final Color pawColor;

  PawPainter({required this.progress, required this.pawColor});

  @override
  void paint(Canvas canvas, Size size) {
    double radius = size.width / 4;
    double center = size.width / 2;

    // Draw the pink paw circle
    Paint pinkPaint = Paint()
      ..color = pawColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center, center), radius, pinkPaint);

    // Draw the filling paw circle based on the progress
    Paint fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    double fillHeight = progress * radius * 2;
    Rect fillRect = Rect.fromLTRB(
        center - radius, center, center + radius, center + fillHeight);
    canvas.drawRect(fillRect, fillPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
