import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'gd_card.dart';

// ── Notificações ─────────────────────────────────────────────

class NotificacoesScreen extends StatefulWidget {
  const NotificacoesScreen({super.key});
  @override
  State<NotificacoesScreen> createState() => _NotificacoesScreenState();
}

class _NotificacoesScreenState extends State<NotificacoesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notifs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final uid = _supabase.auth.currentUser?.id;
      final usuarioRow = await _supabase.schema('grupo_dantas').from('usuarios')
        .select('id').eq('auth_id', uid!).maybeSingle();
      if (usuarioRow == null) { setState(() => _loading = false); return; }

      final data = await _supabase.schema('grupo_dantas').from('notificacoes')
        .select().eq('usuario_id', usuarioRow['id'])
        .order('criado_em', ascending: false).limit(50);

      setState(() { _notifs = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _marcarLida(String id) async {
    await _supabase.schema('grupo_dantas').from('notificacoes')
      .update({'lida': true}).eq('id', id);
    _carregar();
  }

  Future<void> _marcarTodasLidas() async {
    final uid = _supabase.auth.currentUser?.id;
    final u = await _supabase.schema('grupo_dantas').from('usuarios')
      .select('id').eq('auth_id', uid!).maybeSingle();
    if (u == null) return;
    await _supabase.schema('grupo_dantas').from('notificacoes')
      .update({'lida': true}).eq('usuario_id', u['id']);
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final naoLidas = _notifs.where((n) => n['lida'] == false).length;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (b) => AppTheme.goldGradient.createShader(b),
          child: const Text('Notificações', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
        actions: [
          if (naoLidas > 0)
            TextButton(
              onPressed: _marcarTodasLidas,
              child: const Text('Marcar todas', style: TextStyle(color: AppTheme.gold, fontSize: 12))),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2))
        : _notifs.isEmpty
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.notifications_none_rounded, color: AppTheme.textMuted, size: 56),
              SizedBox(height: 12),
              Text('Nenhuma notificação', style: TextStyle(color: AppTheme.textSecondary)),
            ]))
          : RefreshIndicator(
              onRefresh: _carregar,
              color: AppTheme.gold,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _notifs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final n = _notifs[i];
                  final lida = n['lida'] == true;
                  return GDCard(
                    onTap: lida ? null : () => _marcarLida(n['id']),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: (lida ? AppTheme.textMuted : AppTheme.gold).withOpacity(0.1),
                          shape: BoxShape.circle),
                        child: Icon(Icons.notifications_rounded,
                          color: lida ? AppTheme.textMuted : AppTheme.gold, size: 18)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(n['titulo'] ?? '',
                            style: TextStyle(
                              color: lida ? AppTheme.textSecondary : AppTheme.textPrimary,
                              fontWeight: lida ? FontWeight.w400 : FontWeight.w600,
                              fontSize: 13))),
                          if (!lida) Container(width: 7, height: 7,
                            decoration: const BoxDecoration(color: AppTheme.gold, shape: BoxShape.circle)),
                        ]),
                        const SizedBox(height: 3),
                        Text(n['mensagem'] ?? '',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4)),
                      ])),
                    ]),
                  ).animate(delay: (i * 40).ms).fadeIn();
                },
              ),
            ),
    );
  }
}

// ── Perfil ────────────────────────────────────────────────────

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});
  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _usuario;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return;
      final row = await _supabase.schema('grupo_dantas').from('usuarios')
        .select().eq('auth_id', uid).maybeSingle();
      setState(() { _usuario = row; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  bool get _isAdmin => _usuario?['role'] == 'admin';

  @override
  Widget build(BuildContext context) {
    final nome  = _usuario?['nome']  as String? ?? 'Usuário';
    final email = _usuario?['email'] as String? ?? '';
    final tel   = _usuario?['telefone'] as String? ?? '';
    final role  = _usuario?['role'] as String? ?? 'cliente';
    final ini   = nome.isNotEmpty ? nome.substring(0, 1).toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Perfil')),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2))
        : ListView(padding: const EdgeInsets.all(20), children: [
            // Avatar
            Center(child: Column(children: [
              Container(width: 88, height: 88,
                decoration: BoxDecoration(gradient: AppTheme.goldGradient, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppTheme.gold.withOpacity(0.3), blurRadius: 20)]),
                child: Center(child: Text(ini, style: const TextStyle(
                  color: AppTheme.background, fontSize: 32, fontWeight: FontWeight.w800)))),
              const SizedBox(height: 12),
              Text(nome, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.gold.withOpacity(0.3))),
                child: Text(_roleLabel(role), style: const TextStyle(
                  color: AppTheme.gold, fontSize: 12, fontWeight: FontWeight.w600))),
            ])),
            const SizedBox(height: 28),

            // Dados
            GDCard(child: Column(children: [
              _item(Icons.person_outline_rounded, 'Nome', nome),
              const Divider(color: AppTheme.cardBorder),
              _item(Icons.email_outlined, 'E-mail', email),
              if (tel.isNotEmpty) ...[
                const Divider(color: AppTheme.cardBorder),
                _item(Icons.phone_outlined, 'Telefone', tel),
              ],
            ])).animate().fadeIn(),
            const SizedBox(height: 16),

            // Botão admin — gerenciar usuários
            if (_isAdmin) ...[
              GDCard(
                onTap: () => context.push('/usuarios'),
                child: Row(children: [
                  Container(width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.manage_accounts_rounded, color: AppTheme.gold, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Gerenciar Usuários',
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                    const Text('Aprovar cadastros e vincular obras',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  ])),
                  const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                ]),
              ).animate(delay: 100.ms).fadeIn(),
              const SizedBox(height: 12),
            ],

            // Logout
            OutlinedButton.icon(
              onPressed: () async {
                await _supabase.auth.signOut();
                if (mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Sair da conta'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.error,
                side: const BorderSide(color: AppTheme.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 0)),
            ).animate(delay: 200.ms).fadeIn(),
          ]),
    );
  }

  Widget _item(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      Icon(icon, color: AppTheme.textMuted, size: 18),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
      ]),
    ]),
  );

  String _roleLabel(String r) {
    switch (r) {
      case 'admin':      return 'Administrador';
      case 'engenheiro': return 'Engenheiro';
      case 'cliente':    return 'Cliente';
      default:           return 'Pedreiro / Operário';
    }
  }
}

// ── Placeholders de módulos ───────────────────────────────────

class EtapasScreen extends StatelessWidget {
  final String obraId;
  const EtapasScreen({super.key, required this.obraId});
  @override Widget build(BuildContext context) => const SizedBox.shrink();
}

class FinanceiroScreen extends StatelessWidget {
  final String obraId;
  const FinanceiroScreen({super.key, required this.obraId});
  @override Widget build(BuildContext context) => const SizedBox.shrink();
}

class DiarioScreen extends StatelessWidget {
  final String obraId;
  const DiarioScreen({super.key, required this.obraId});
  @override Widget build(BuildContext context) => const SizedBox.shrink();
}

class MateriaisScreen extends StatelessWidget {
  final String obraId;
  const MateriaisScreen({super.key, required this.obraId});
  @override Widget build(BuildContext context) => const SizedBox.shrink();
}

class DocumentosScreen extends StatelessWidget {
  final String obraId;
  const DocumentosScreen({super.key, required this.obraId});
  @override Widget build(BuildContext context) => const SizedBox.shrink();
}
