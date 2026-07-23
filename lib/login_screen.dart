import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'multiplika_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  bool _loading = false, _obscure = true;
  final _supabase = Supabase.instance.client;

  Future<void> _login() async {
    if (_emailCtrl.text.isEmpty || _senhaCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      await _supabase.auth.signInWithPassword(
        email: _emailCtrl.text.trim(), password: _senhaCtrl.text);
      if (!mounted) return;
      final uid = _supabase.auth.currentUser?.id;
      final row = await _supabase.schema('grupo_dantas').from('usuarios')
        .select('status_aprovacao').eq('auth_id', uid!).maybeSingle();
      if (!mounted) return;
      if (row == null || row['status_aprovacao'] == 'aprovado') {
        context.go('/dashboard');
      } else if (row['status_aprovacao'] == 'rejeitado') {
        await _supabase.auth.signOut();
        _snack('Acesso negado. Contate o administrador.', AppTheme.error);
      } else {
        context.go('/aguardando-aprovacao');
      }
    } on AuthException {
      _snack('E-mail ou senha inválidos', AppTheme.error);
    } catch (e) {
      _snack('Erro: $e', AppTheme.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color cor) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: cor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(children: [
        Positioned(top: -100, right: -100,
          child: Container(width: 400, height: 400,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFFB87333).withOpacity(0.06), Colors.transparent])))),
        SafeArea(child: Center(child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              // Logo Multiplika
              MultiplicaLogo(size: 200)
                  .animate().scale(delay: 200.ms, duration: 700.ms, curve: Curves.elasticOut),

              // Campos
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'E-mail',
                  prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textMuted, size: 18)),
              ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.2),
              const SizedBox(height: 14),
              TextField(
                controller: _senhaCtrl,
                obscureText: _obscure,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock_outlined, color: AppTheme.textMuted, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppTheme.textMuted, size: 18),
                    onPressed: () => setState(() => _obscure = !_obscure))),
                onSubmitted: (_) => _login(),
              ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.2),
              const SizedBox(height: 28),

              SizedBox(width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB87333),
                    foregroundColor: Colors.white,
                  ),
                  child: _loading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('ENTRAR', style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 2))))
              .animate(delay: 600.ms).fadeIn().slideY(begin: 0.2),
              const SizedBox(height: 20),

              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Não tem conta? ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                GestureDetector(
                  onTap: () => context.go('/cadastro'),
                  child: const Text('Solicitar acesso', style: TextStyle(
                    color: Color(0xFFB87333), fontSize: 13, fontWeight: FontWeight.w700))),
              ]).animate(delay: 700.ms).fadeIn(),
            ]),
          ),
        ))),
      ]),
    );
  }
}
