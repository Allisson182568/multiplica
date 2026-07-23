import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'gd_card.dart';
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nomeCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _telCtrl   = TextEditingController();
  String _roleSlct = 'cliente';
  bool _loading    = false;
  bool _obscure    = true;

  final _supabase = Supabase.instance.client;

  static const _roles = [
    ('cliente',     'Cliente',     'Acompanha o andamento da obra', Icons.person_rounded),
    ('engenheiro',  'Engenheiro',  'Gerencia e atualiza etapas',    Icons.engineering_rounded),
    ('outro',       'Pedreiro / Operário', 'Executa e registra atividades', Icons.construction_rounded),
  ];

  Future<void> _cadastrar() async {
    if (_nomeCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty || _senhaCtrl.text.length < 6) {
      _snack('Preencha todos os campos. Senha mínima: 6 caracteres.', AppTheme.error);
      return;
    }
    setState(() => _loading = true);
    try {
      // Cria auth user
      final res = await _supabase.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _senhaCtrl.text,
      );

      if (res.user == null) throw Exception('Erro ao criar conta');

      // Insere na tabela usuarios com status pendente
      await _supabase.schema('grupo_dantas').from('usuarios').insert({
        'auth_id':          res.user!.id,
        'nome':             _nomeCtrl.text.trim(),
        'email':            _emailCtrl.text.trim(),
        'telefone':         _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim(),
        'role':             'cliente', // role padrão até aprovação
        'role_solicitado':  _roleSlct,
        'status_aprovacao': 'pendente',
        'ativo':            false,
      });

      if (mounted) context.go('/aguardando-aprovacao');
    } on AuthException catch (e) {
      _snack(e.message, AppTheme.error);
    } catch (e) {
      _snack('Erro: $e', AppTheme.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color cor) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: cor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/login'),
        ),
        title: const Text('Criar Conta'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header
          ShaderMask(
            shaderCallback: (b) => AppTheme.goldGradient.createShader(b),
            child: const Text('Solicitar Acesso', style: TextStyle(
              color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800,
            )),
          ).animate().fadeIn(),
          const SizedBox(height: 4),
          const Text(
            'Seu cadastro será analisado pelo administrador antes de liberar o acesso.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
          ).animate(delay: 100.ms).fadeIn(),
          const SizedBox(height: 28),

          // Campos
          _field(_nomeCtrl,  'Nome completo *',   Icons.person_outlined),
          const SizedBox(height: 14),
          _field(_emailCtrl, 'E-mail *',           Icons.email_outlined,
            type: TextInputType.emailAddress),
          const SizedBox(height: 14),
          _field(_telCtrl,   'Telefone (opcional)', Icons.phone_outlined,
            type: TextInputType.phone),
          const SizedBox(height: 14),
          TextField(
            controller: _senhaCtrl,
            obscureText: _obscure,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Senha * (mínimo 6 caracteres)',
              prefixIcon: const Icon(Icons.lock_outlined, color: AppTheme.textMuted, size: 18),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppTheme.textMuted, size: 18),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Seleção de tipo
          Text('Qual é seu papel na obra? *',
            style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('O administrador poderá alterar após aprovação.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          const SizedBox(height: 12),
          ..._roles.asMap().entries.map((entry) {
            final i = entry.key;
            final (value, label, desc, icon) = entry.value;
            final sel = _roleSlct == value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => setState(() => _roleSlct = value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: sel ? AppTheme.gold.withOpacity(0.08) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: sel ? AppTheme.gold : AppTheme.cardBorder,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Container(width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: (sel ? AppTheme.gold : AppTheme.textMuted).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: sel ? AppTheme.gold : AppTheme.textMuted, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label, style: TextStyle(
                        color: sel ? AppTheme.gold : AppTheme.textPrimary,
                        fontWeight: FontWeight.w600, fontSize: 14,
                      )),
                      Text(desc, style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 11,
                      )),
                    ])),
                    if (sel) const Icon(Icons.check_circle_rounded,
                      color: AppTheme.gold, size: 20),
                  ]),
                ).animate(delay: (i * 50).ms).fadeIn(),
              ),
            );
          }),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _cadastrar,
              child: _loading
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.background))
                : const Text('SOLICITAR ACESSO',
                    style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Já tenho conta — Entrar',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          )),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: c, keyboardType: type,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 18),
      ),
    );
  }
}
