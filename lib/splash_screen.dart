import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'multiplika_logo.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) { context.go('/login'); return; }
    try {
      final row = await Supabase.instance.client
        .schema('grupo_dantas').from('usuarios')
        .select('status_aprovacao').eq('auth_id', session.user.id).maybeSingle();
      if (!mounted) return;
      if (row == null || row['status_aprovacao'] == 'aprovado') {
        context.go('/dashboard');
      } else {
        context.go('/aguardando-aprovacao');
      }
    } catch (_) {
      if (mounted) context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(children: [
        // Glow de fundo
        Positioned(top: -80, right: -80,
          child: Container(width: 400, height: 400,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFFB87333).withOpacity(0.07),
                Colors.transparent])))),
        Positioned(bottom: -120, left: -80,
          child: Container(width: 500, height: 500,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFFB87333).withOpacity(0.05),
                Colors.transparent])))),

        SafeArea(child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            // Logo animado
            MultiplicaLogo(size: 120)
              .animate()
              .scale(delay: 200.ms, duration: 700.ms, curve: Curves.elasticOut),

            const SizedBox(height: 28),

            // Nome
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [Color(0xFFB87333), Color(0xFFD4A843)],
              ).createShader(b),
              child: const Text('MULTIPLIKA', style: TextStyle(
                color: Colors.white, fontSize: 32,
                fontWeight: FontWeight.w800, letterSpacing: 5)),
            ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.3),

            const SizedBox(height: 6),

            const Text('INCORPORADORA', style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 14,
              letterSpacing: 4, fontWeight: FontWeight.w300))
            .animate(delay: 500.ms).fadeIn(),

            const SizedBox(height: 8),

            const Text('SOLIDEZ EM CADA PILAR', style: TextStyle(
              color: AppTheme.textMuted, fontSize: 10, letterSpacing: 3))
            .animate(delay: 600.ms).fadeIn(),

            const SizedBox(height: 60),

            // Loading dots
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (int i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(width: 6, height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFB87333), shape: BoxShape.circle))
                  .animate(onPlay: (c) => c.repeat())
                  .fadeIn(delay: (i * 200).ms, duration: 400.ms)
                  .fadeOut(delay: (i * 200 + 400).ms, duration: 400.ms),
                ),
            ]).animate(delay: 700.ms).fadeIn(),
          ]),
        )),
      ]),
    );
  }
}
