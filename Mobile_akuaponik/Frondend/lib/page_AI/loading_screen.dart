import 'package:flutter/material.dart';
import 'package:projekakuaponik/helper/navbar.dart';
import 'dart:async';
import '../helper/config.dart';
import '../helper/notification_service.dart';
import '../main.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({Key? key}) : super(key: key);

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.7, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();
    _inisialisasiDanNavigasi();
  }

  Future<void> _inisialisasiDanNavigasi() async {
    final waktuMulai = DateTime.now();

    try {
      await AppConfig.loadConfig();
      await NotificationService.initialize();
      await requestPermissions();

      NotificationService.subscribeToTopic('bahaya_alerts');
    } catch (e) {
      debugPrint("Gagal memuat konfigurasi: $e");
    }

    final durasiBerjalan = DateTime.now().difference(waktuMulai);
    final sisaWaktuTunggu = const Duration(seconds: 4) - durasiBerjalan;

    if (sisaWaktuTunggu.inMilliseconds > 0) {
      await Future.delayed(sisaWaktuTunggu);
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainNavigation()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 19, 109, 79),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..scale(_scaleAnimation.value),
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/logo_apps.png',
                        width: 170,
                        height: 170,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  const Text(
                    'AKUAPONIK MONITOR',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 0),
                  Text(
                    'By Ilyan Habib Maulana',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.teal.shade200,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  width: 200,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Stack(
                    children: [
                      FractionallySizedBox(
                        widthFactor: _controller.value,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.teal.shade300,
                                Colors.teal.shade500,
                                const Color(0xFF0A3D2F),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: -3,
                        child: Transform.translate(
                          offset: Offset(-200 * (1 - _controller.value), 0),
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.teal.shade100,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.teal.shade300,
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            _buildPulsingText(),
          ],
        ),
      ),
    );
  }

  Widget _buildPulsingText() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulseValue = 0.5 + 0.5 * _controller.value;
        return Opacity(
          opacity: 0.5 + 0.5 * _controller.value,
          child: Text(
            'Menyiapkan dashboard...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(pulseValue),
            ),
          ),
        );
      },
    );
  }
}
