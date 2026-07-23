import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'gd_card.dart';
class AguardandoAprovacaoScreen extends StatefulWidget {
  const AguardandoAprovacaoScreen({super.key});
  @override
  State<AguardandoAprovacaoScreen> createState() => _AguardandoAprovacaoScreenState();
}

class _AguardandoAprovacaoScreenState extends State<AguardandoAprovacaoScreen> {
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _verificarAprovacao();
    // Escuta realtime — se admin aprovar, redireciona automaticamente
    _supabase
      .schema('grupo_dantas')
      .from('usuarios')
      .stream(primaryKey: ['id'])
      .eq('auth_id', _supabase.auth.currentUser?.id ?? '')
      .listen((rows) {
        if (rows.isNotEmpty && rows.first['status_aprovacao'] == 'aprovado') {
          if (mounted) context.go('/dashboard');
        }
      });
  }

  Future<void> _verificarAprovacao() async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return;
      final row = await _supabase
        .schema('grupo_dantas')
        .from('usuarios')
        .select('status_aprovacao')
        .eq('auth_id', uid)
        .maybeSingle();
      if (row != null && row['status_aprovacao'] == 'aprovado' && mounted) {
        context.go('/dashboard');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícone animado
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A1810), Color(0xFF2A2410)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppTheme.gold.withOpacity(0.3), width: 2),
                ),
                child: const Center(child: Icon(Icons.hourglass_empty_rounded,
                  color: AppTheme.gold, size: 48)),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 0.95, end: 1.05, duration: 1500.ms, curve: Curves.easeInOut),
              const SizedBox(height: 32),

              ShaderMask(
                shaderCallback: (b) => AppTheme.goldGradient.createShader(b),
                child: const Text('Aguardando\nAprovação', style: TextStyle(
                  color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800,
                  height: 1.2,
                ), textAlign: TextAlign.center),
              ).animate(delay: 200.ms).fadeIn(),
              const SizedBox(height: 16),

              const Text(
                'Seu cadastro foi enviado com sucesso!\n\n'
                'O administrador do Grupo Dantas irá analisar '
                'e liberar seu acesso em breve.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.6),
                textAlign: TextAlign.center,
              ).animate(delay: 300.ms).fadeIn(),
              const SizedBox(height: 32),

              // Indicador de espera
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(children: [
                  SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.gold,
                    )),
                  const SizedBox(width: 12),
                  const Expanded(child: Text(
                    'Verificando aprovação automaticamente...',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  )),
                ]),
              ).animate(delay: 400.ms).fadeIn(),
              const SizedBox(height: 40),

              // Sair
              OutlinedButton.icon(
                onPressed: () async {
                  await _supabase.auth.signOut();
                  if (mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Sair da conta'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.cardBorder),
                ),
              ).animate(delay: 500.ms).fadeIn(),
            ],
          ),
        ),
      ),
    );
  }
}
