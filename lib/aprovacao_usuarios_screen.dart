import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'gd_card.dart';

class AprovacaoUsuariosScreen extends StatefulWidget {
  const AprovacaoUsuariosScreen({super.key});
  @override
  State<AprovacaoUsuariosScreen> createState() => _AprovacaoUsuariosScreenState();
}

class _AprovacaoUsuariosScreenState extends State<AprovacaoUsuariosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _pendentes = [];
  List<Map<String, dynamic>> _aprovados = [];
  List<Map<String, dynamic>> _obras     = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final p = await _supabase.schema('grupo_dantas').from('usuarios')
        .select().eq('status_aprovacao', 'pendente').order('criado_em', ascending: false);
      final a = await _supabase.schema('grupo_dantas').from('usuarios')
        .select().eq('status_aprovacao', 'aprovado').neq('role', 'admin').order('nome');
      final o = await _supabase.schema('grupo_dantas').from('obras')
        .select('id, nome, status').order('nome');
      setState(() {
        _pendentes = List<Map<String, dynamic>>.from(p);
        _aprovados = List<Map<String, dynamic>>.from(a);
        _obras     = List<Map<String, dynamic>>.from(o);
        _loading   = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _snack('Erro: $e', AppTheme.error);
    }
  }

  Future<void> _aprovar(Map<String, dynamic> u, String role) async {
    try {
      final adminRow = await _supabase.schema('grupo_dantas').from('usuarios')
        .select('id').eq('auth_id', _supabase.auth.currentUser!.id).single();
      await _supabase.schema('grupo_dantas').from('usuarios').update({
        'status_aprovacao': 'aprovado', 'role': role,
        'aprovado_por': adminRow['id'],
        'aprovado_em': DateTime.now().toIso8601String(), 'ativo': true,
      }).eq('id', u['id']);
      _snack('${u['nome']} aprovado!', AppTheme.success);
      _carregar();
    } catch (e) { _snack('Erro: $e', AppTheme.error); }
  }

  Future<void> _rejeitar(Map<String, dynamic> u) async {
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rejeitar?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Rejeitar ${u['nome']}?',
          style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Não', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Rejeitar')),
        ],
      ));
    if (ok != true) return;
    try {
      await _supabase.schema('grupo_dantas').from('usuarios')
        .update({'status_aprovacao': 'rejeitado', 'ativo': false}).eq('id', u['id']);
      _snack('Rejeitado.', AppTheme.warning);
      _carregar();
    } catch (e) { _snack('Erro: $e', AppTheme.error); }
  }

  Future<void> _vincularObra(Map<String, dynamic> u) async {
    final vinculadas = await _supabase.schema('grupo_dantas').from('obra_usuarios')
      .select('obra_id').eq('usuario_id', u['id']);
    final selecionadas = Set<String>.from(
      (vinculadas as List).map((o) => o['obra_id'] as String));

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) =>
        DraggableScrollableSheet(
          initialChildSize: 0.7, maxChildSize: 0.95, minChildSize: 0.4, expand: false,
          builder: (_, ctrl) => Column(children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.cardBorder,
                borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Vincular Obras', style: Theme.of(context).textTheme.titleLarge),
                  Text(u['nome'] ?? '',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ])),
                ElevatedButton(
                  onPressed: () async {
                    await _supabase.schema('grupo_dantas').from('obra_usuarios')
                      .delete().eq('usuario_id', u['id']);
                    for (final oId in selecionadas) {
                      await _supabase.schema('grupo_dantas').from('obra_usuarios').insert({
                        'obra_id': oId, 'usuario_id': u['id'], 'role': u['role'] ?? 'cliente',
                      });
                    }
                    if (mounted) Navigator.pop(ctx);
                    _snack('Obras vinculadas!', AppTheme.success);
                  },
                  child: const Text('Salvar')),
              ])),
            const Divider(color: AppTheme.cardBorder),
            Expanded(child: _obras.isEmpty
              ? const Center(child: Text('Nenhuma obra', style: TextStyle(color: AppTheme.textSecondary)))
              : ListView.builder(
                  controller: ctrl,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _obras.length,
                  itemBuilder: (_, i) {
                    final obra = _obras[i];
                    final id = obra['id'] as String;
                    return CheckboxListTile(
                      value: selecionadas.contains(id),
                      onChanged: (v) => setS(() {
                        if (v == true) selecionadas.add(id); else selecionadas.remove(id);
                      }),
                      activeColor: AppTheme.gold,
                      checkColor: AppTheme.background,
                      side: const BorderSide(color: AppTheme.textMuted),
                      title: Text(obra['nome'] ?? '',
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                      subtitle: Text(AppTheme.statusLabel(obra['status'] ?? ''),
                        style: TextStyle(
                          color: AppTheme.statusColor(obra['status'] ?? ''), fontSize: 11)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    );
                  },
                )),
          ]),
        )),
    );
  }

  void _snack(String msg, Color cor) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: cor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (b) => AppTheme.goldGradient.createShader(b),
          child: const Text('Usuários', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _carregar)],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.gold,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.gold,
          dividerColor: AppTheme.cardBorder,
          tabs: [
            Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Pendentes'),
              if (_pendentes.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(10)),
                  child: Text('${_pendentes.length}', style: const TextStyle(
                    color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
              ],
            ])),
            const Tab(text: 'Aprovados'),
          ],
        ),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2))
        : TabBarView(controller: _tabs, children: [
            _buildPendentes(),
            _buildAprovados(),
          ]),
    );
  }

  Widget _buildPendentes() {
    if (_pendentes.isEmpty) return const Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 56),
        SizedBox(height: 12),
        Text('Nenhum cadastro pendente', style: TextStyle(color: AppTheme.textSecondary)),
      ],
    ));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendentes.length,
      itemBuilder: (_, i) {
        final u = _pendentes[i];
        return _PendenteCard(usuario: u,
          onAprovar: (role) => _aprovar(u, role),
          onRejeitar: () => _rejeitar(u),
        ).animate(delay: (i * 60).ms).fadeIn().slideY(begin: 0.1);
      },
    );
  }

  Widget _buildAprovados() {
    if (_aprovados.isEmpty) return const Center(
      child: Text('Nenhum aprovado ainda', style: TextStyle(color: AppTheme.textSecondary)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _aprovados.length,
      itemBuilder: (_, i) {
        final u = _aprovados[i];
        final role = u['role'] as String? ?? 'cliente';
        final cor = role == 'engenheiro' ? AppTheme.info
                  : role == 'cliente'    ? AppTheme.success : AppTheme.warning;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GDCard(child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(gradient: AppTheme.goldGradient, shape: BoxShape.circle),
              child: Center(child: Text(
                (u['nome'] as String? ?? 'U').substring(0,1).toUpperCase(),
                style: const TextStyle(color: AppTheme.background, fontWeight: FontWeight.w800, fontSize: 18)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u['nome'] ?? '', style: Theme.of(context).textTheme.titleMedium),
              Text(u['email'] ?? '', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(_roleLabel(role), style: TextStyle(color: cor, fontSize: 10, fontWeight: FontWeight.w600))),
            ])),
            IconButton(
              icon: const Icon(Icons.link_rounded, color: AppTheme.gold),
              tooltip: 'Vincular obras',
              onPressed: () => _vincularObra(u)),
          ])).animate(delay: (i * 40).ms).fadeIn(),
        );
      },
    );
  }

  String _roleLabel(String r) {
    switch (r) {
      case 'engenheiro': return 'Engenheiro';
      case 'cliente':    return 'Cliente';
      default:           return 'Pedreiro';
    }
  }
}

class _PendenteCard extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final ValueChanged<String> onAprovar;
  final VoidCallback onRejeitar;
  const _PendenteCard({required this.usuario, required this.onAprovar, required this.onRejeitar});
  @override
  State<_PendenteCard> createState() => _PendenteCardState();
}

class _PendenteCardState extends State<_PendenteCard> {
  late String _role;
  @override
  void initState() {
    super.initState();
    _role = widget.usuario['role_solicitado'] as String? ?? 'cliente';
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.usuario;
    return Padding(padding: const EdgeInsets.only(bottom: 12),
      child: GDCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.1), shape: BoxShape.circle,
              border: Border.all(color: AppTheme.warning.withOpacity(0.4))),
            child: Center(child: Text(
              (u['nome'] as String? ?? 'U').substring(0,1).toUpperCase(),
              style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w800, fontSize: 20)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u['nome'] ?? '', style: Theme.of(context).textTheme.titleMedium),
            Text(u['email'] ?? '', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            if (u['telefone'] != null && (u['telefone'] as String).isNotEmpty)
              Text(u['telefone'], style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6)),
            child: const Text('PENDENTE', style: TextStyle(
              color: AppTheme.warning, fontSize: 9, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.info_outline_rounded, size: 13, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          const Text('Solicitou: ', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          Text(_labelRole(u['role_solicitado'] ?? 'cliente'),
            style: const TextStyle(color: AppTheme.gold, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        const Divider(color: AppTheme.cardBorder),
        const SizedBox(height: 8),
        const Text('Aprovar como:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (v, l) in [('cliente', 'Cliente'), ('engenheiro', 'Engenheiro'), ('outro', 'Pedreiro')])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _role = v),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _role == v ? AppTheme.gold.withOpacity(0.15) : AppTheme.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _role == v ? AppTheme.gold : AppTheme.cardBorder),
                      ),
                      child: Center(
                        child: Text(
                          l,
                          style: TextStyle(
                            color: _role == v ? AppTheme.gold : AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ), // <-- Certifique-se de que este parêntese fecha o Expanded corretamente
          ], // <-- Fecha o children da Row
        ) ,// <-- Fecha a Row
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: widget.onRejeitar,
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Rejeitar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.error, side: const BorderSide(color: AppTheme.error),
              padding: const EdgeInsets.symmetric(vertical: 10)))),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton.icon(
            onPressed: () => widget.onAprovar(_role),
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Aprovar'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)))),
        ]),
      ])));
  }

  String _labelRole(String r) {
    switch (r) {
      case 'engenheiro': return 'Engenheiro';
      case 'cliente':    return 'Cliente';
      default:           return 'Pedreiro';
    }
  }
}
