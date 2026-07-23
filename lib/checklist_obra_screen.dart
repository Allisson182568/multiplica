import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'gd_card.dart';
import 'obra_context.dart';

class ChecklistObraScreen extends StatefulWidget {
  final String obraId;
  const ChecklistObraScreen({super.key, required this.obraId});
  @override
  State<ChecklistObraScreen> createState() => _ChecklistObraScreenState();
}

class _ChecklistObraScreenState extends State<ChecklistObraScreen>
    with SingleTickerProviderStateMixin {
  final _supa = Supabase.instance.client;
  late TabController _tabs;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _historico = [];
  bool _loading = true;
  String? _obraId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _obraId = widget.obraId.isNotEmpty ? widget.obraId : ObraContext().obraId;
    if (_obraId != null && _obraId!.isNotEmpty) _carregar();
    else setState(() => _loading = false);
  }

  Future<void> _carregar() async {
    if (_obraId == null || _obraId!.isEmpty) return;
    final data = await _supa.schema('grupo_dantas').from('documentos_checklist')
        .select().eq('obra_id', _obraId!).order('fase');
    final hist = await _supa.schema('grupo_dantas').from('checklist_historico')
        .select().eq('obra_id', _obraId!)
        .order('criado_em', ascending: false).limit(50);
    setState(() {
      _items = List<Map<String, dynamic>>.from(data);
      _historico = List<Map<String, dynamic>>.from(hist);
      _loading = false;
    });
  }

  List<Map<String, dynamic>> _por(String fase) => _items.where((d) => d['fase'] == fase).toList();

  Future<void> _toggle(Map<String, dynamic> doc) async {
    final ok = !(doc['concluido'] as bool? ?? false);
    final uid = _supa.auth.currentUser?.id;
    final u = await _supa.schema('grupo_dantas').from('usuarios')
        .select('id, nome').eq('auth_id', uid!).maybeSingle();

    // Atualizar checklist
    await _supa.schema('grupo_dantas').from('documentos_checklist').update({
      'concluido': ok,
      'data_conclusao': ok ? DateTime.now().toIso8601String().substring(0, 10) : null,
      'concluido_por': ok ? (u != null ? u['id'] : null) : null,      'concluido_em': ok ? DateTime.now().toIso8601String() : null,
    }).eq('id', doc['id']);

    // Registrar histórico
    await _supa.schema('grupo_dantas').from('checklist_historico').insert({
      'checklist_id': doc['id'],
      'obra_id': _obraId,
      'usuario_id': u?['id'],
      'usuario_nome': u?['nome'] ?? 'Usuário',
      'acao': ok ? 'marcou' : 'desmarcou',
    });

    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    if (_obraId == null || _obraId!.isEmpty) {
      return Scaffold(backgroundColor: AppTheme.background,
        appBar: AppBar(title: ShaderMask(
          shaderCallback: (b) => AppTheme.goldGradient.createShader(b),
          child: const Text('Checklist de Obra', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)))),
        body: const Center(child: Padding(padding: EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.checklist_rounded, color: AppTheme.textMuted, size: 56),
            SizedBox(height: 16),
            Text('Selecione uma obra', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            Text('Use o seletor na barra lateral.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ]))));
    }

    const fases = ['pre_obra', 'execucao', 'entrega'];
    const labels = ['Pré-Obra', 'Execução', 'Entrega'];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (b) => AppTheme.goldGradient.createShader(b),
          child: const Text('Checklist de Obra', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
        bottom: TabBar(controller: _tabs, labelColor: AppTheme.gold,
          unselectedLabelColor: AppTheme.textMuted, indicatorColor: AppTheme.gold,
          dividerColor: AppTheme.cardBorder, isScrollable: true, tabAlignment: TabAlignment.start,
          tabs: [
            ...List.generate(3, (i) {
              final lista = _por(fases[i]);
              final feitos = lista.where((d) => d['concluido'] == true).length;
              return Tab(child: Text('${labels[i]} $feitos/${lista.length}', style: const TextStyle(fontSize: 11)));
            }),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.history_rounded, size: 14),
              const SizedBox(width: 4),
              Text('Histórico (${_historico.length})', style: const TextStyle(fontSize: 11)),
            ])),
          ]),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2))
        : TabBarView(controller: _tabs, children: [
            ...List.generate(3, (i) => _buildFaseList(fases[i])),
            _buildHistorico(),
          ]),
    );
  }

  Widget _buildFaseList(String fase) {
    final lista = _por(fase);
    if (lista.isEmpty) return const Center(child: Text('Nenhum item nesta fase',
      style: TextStyle(color: AppTheme.textSecondary)));

    final feitos = lista.where((d) => d['concluido'] == true).length;
    final pct = lista.isNotEmpty ? (feitos / lista.length * 100).toInt() : 0;

    return RefreshIndicator(onRefresh: _carregar, color: AppTheme.gold,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        // Barra de progresso
        Container(padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.cardBorder)),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('$feitos de ${lista.length} concluídos', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              Text('$pct%', style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: feitos / lista.length.clamp(1, 999),
                backgroundColor: AppTheme.cardBorder,
                valueColor: const AlwaysStoppedAnimation(AppTheme.gold), minHeight: 6)),
          ])),

        ...lista.asMap().entries.map((e) {
          final i = e.key;
          final doc = e.value;
          final ok = doc['concluido'] == true;
          final obrig = doc['obrigatorio'] == true;
          return Padding(padding: const EdgeInsets.only(bottom: 8),
            child: GDCard(onTap: () => _toggle(doc),
              child: Row(children: [
                AnimatedContainer(duration: const Duration(milliseconds: 200),
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: ok ? AppTheme.success : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: ok ? AppTheme.success : AppTheme.textMuted)),
                  child: ok ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(doc['nome'] ?? '', style: TextStyle(
                    color: ok ? AppTheme.textMuted : AppTheme.textPrimary,
                    fontSize: 13, fontWeight: FontWeight.w500,
                    decoration: ok ? TextDecoration.lineThrough : null)),
                  Row(children: [
                    if (obrig) Container(
                      margin: const EdgeInsets.only(top: 3, right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: const Text('OBRIGATÓRIO', style: TextStyle(color: AppTheme.error, fontSize: 8, fontWeight: FontWeight.w700))),
                    if (ok && doc['concluido_em'] != null)
                      Text(_fmtDataHora(doc['concluido_em']),
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                  ]),
                ])),
                if (ok) const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 18),
              ])).animate(delay: Duration(milliseconds: i * 40)).fadeIn());
        }),
      ]));
  }

  Widget _buildHistorico() {
    if (_historico.isEmpty) return const Center(child: Text('Nenhuma ação registrada',
      style: TextStyle(color: AppTheme.textSecondary)));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _historico.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final h = _historico[i];
        final acao = h['acao'] as String? ?? '';
        final nome = h['usuario_nome'] as String? ?? 'Usuário';
        final cor = acao == 'marcou' ? AppTheme.success : AppTheme.warning;
        final icone = acao == 'marcou' ? Icons.check_circle_rounded
          : acao == 'foto' ? Icons.camera_alt_rounded : Icons.undo_rounded;

        return GDCard(child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icone, color: cor, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RichText(text: TextSpan(style: const TextStyle(fontSize: 12, height: 1.4), children: [
              TextSpan(text: nome, style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w600)),
              TextSpan(text: ' $acao item', style: const TextStyle(color: AppTheme.textSecondary)),
            ])),
            Text(_fmtDataHora(h['criado_em']),
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
            if (h['comentario'] != null) Text(h['comentario'],
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ])),
        ])).animate(delay: Duration(milliseconds: i * 40)).fadeIn();
      });
  }

  String _fmtDataHora(dynamic d) {
    if (d == null) return '';
    try {
      final dt = DateTime.parse(d.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return d.toString(); }
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }
}
