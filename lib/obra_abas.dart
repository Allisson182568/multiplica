import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'gd_card.dart';

// ─────────────────────────────────────────────────────────────
// ABA: ETAPAS (editável por engenheiro/mestre)
// ─────────────────────────────────────────────────────────────

class TabEtapasImpl extends StatefulWidget {
  final String obraId, role;
  final SupabaseClient supa;
  const TabEtapasImpl({super.key, required this.obraId, required this.supa, required this.role});
  @override State<TabEtapasImpl> createState() => _TabEtapasImplState();
}

class _TabEtapasImplState extends State<TabEtapasImpl> {
  List<Map<String, dynamic>> _etapas = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _carregar(); }

  Future<void> _carregar() async {
    final data = await widget.supa.schema('grupo_dantas').from('etapas')
        .select().eq('obra_id', widget.obraId).order('ordem');
    setState(() { _etapas = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  Future<void> _editar(Map<String, dynamic> etapa) async {
    final ctrl = TextEditingController(
        text: (etapa['progresso_percentual'] as num?)?.toInt().toString() ?? '0');
    String status = etapa['status'] as String? ?? 'em_andamento';
    DateTime? dataFimPrev;
    if (etapa['data_fim_prevista'] != null) {
      try { dataFimPrev = DateTime.parse(etapa['data_fim_prevista']); } catch (_) {}
    }

    await showModalBottomSheet(
      context: context, backgroundColor: AppTheme.surface, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Atualizar: ${etapa['nome']}', style: const TextStyle(
            color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 16),
          TextField(controller: ctrl, keyboardType: TextInputType.number,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(labelText: 'Progresso (%)', suffixText: '%')),
          const SizedBox(height: 12),
          const Text('Status', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final s in ['nao_iniciada','em_andamento','concluida','atrasada','pausada'])
              ChoiceChip(
                label: Text(AppTheme.statusLabel(s), style: const TextStyle(fontSize: 11)),
                selected: status == s,
                selectedColor: AppTheme.gold.withOpacity(0.2),
                backgroundColor: AppTheme.surfaceAlt,
                side: BorderSide(color: status == s ? AppTheme.gold : AppTheme.cardBorder),
                labelStyle: TextStyle(color: status == s ? AppTheme.gold : AppTheme.textSecondary),
                onSelected: (_) => setS(() => status = s)),
          ]),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(context: context,
                initialDate: dataFimPrev ?? DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 730)),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.dark(
                    primary: AppTheme.gold, onPrimary: AppTheme.background,
                    surface: AppTheme.surface)), child: child!));
              if (d != null) setS(() => dataFimPrev = d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: dataFimPrev != null
                  ? AppTheme.gold.withOpacity(0.5) : AppTheme.cardBorder)),
              child: Row(children: [
                Icon(Icons.calendar_today_rounded, size: 16,
                  color: dataFimPrev != null ? AppTheme.gold : AppTheme.textMuted),
                const SizedBox(width: 8),
                Text(dataFimPrev == null ? 'Definir prazo de entrega'
                  : 'Prazo: ${_fmtData(dataFimPrev!.toIso8601String())}',
                  style: TextStyle(color: dataFimPrev != null
                    ? AppTheme.textPrimary : AppTheme.textMuted, fontSize: 13)),
              ])),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 48,
            child: ElevatedButton(
              onPressed: () async {
                final prog = double.tryParse(ctrl.text) ?? 0;
                await widget.supa.schema('grupo_dantas').from('etapas').update({
                  'progresso_percentual': prog.clamp(0, 100),
                  'status': status,
                  if (dataFimPrev != null)
                    'data_fim_prevista': dataFimPrev!.toIso8601String().substring(0, 10),
                  if (status == 'em_andamento' && etapa['data_inicio_real'] == null)
                    'data_inicio_real': DateTime.now().toIso8601String().substring(0, 10),
                  if (status == 'concluida')
                    'data_fim_real': DateTime.now().toIso8601String().substring(0, 10),
                }).eq('id', etapa['id']);
                Navigator.pop(ctx);
                _carregar();
              },
              child: const Text('Salvar', style: TextStyle(fontWeight: FontWeight.w700)))),
        ]))));
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.role != 'cliente';
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2));

    return RefreshIndicator(onRefresh: _carregar, color: AppTheme.gold,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _etapas.length,
        itemBuilder: (_, i) {
          final et = _etapas[i];
          final status = et['status'] as String? ?? 'nao_iniciada';
          final prog = (et['progresso_percentual'] as num?)?.toDouble() ?? 0;
          final cor = AppTheme.statusColor(status);
          final isLast = i == _etapas.length - 1;
          bool atrasada = false;
          if (et['data_fim_prevista'] != null && status != 'concluida') {
            try { atrasada = DateTime.parse(et['data_fim_prevista']).isBefore(DateTime.now()); } catch (_) {}
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: cor.withOpacity(0.15), border: Border.all(color: cor, width: 2)),
                child: Center(child: status == 'concluida'
                  ? Icon(Icons.check_rounded, color: cor, size: 18)
                  : Text('${et['ordem']}', style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w700)))),
              if (!isLast) Container(width: 2, height: 50,
                color: status == 'concluida' ? cor.withOpacity(0.4) : AppTheme.cardBorder),
            ]),
            const SizedBox(width: 10),
            Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 8),
              child: GDCard(
                onTap: canEdit ? () => _editar(et) : null,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(et['nome'] ?? '', style: const TextStyle(
                      color: AppTheme.textPrimary, fontWeight: FontWeight.w600))),
                    if (atrasada) _chip('ATRASADA', AppTheme.error),
                    const SizedBox(width: 4),
                    _chip(AppTheme.statusLabel(status), cor),
                  ]),
                  if (et['data_fim_prevista'] != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.calendar_today_rounded, size: 11,
                        color: atrasada ? AppTheme.error : AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text('Prazo: ${_fmtData(et['data_fim_prevista'])}',
                        style: TextStyle(color: atrasada ? AppTheme.error : AppTheme.textMuted, fontSize: 11)),
                    ]),
                  ],
                  if (prog > 0) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(value: prog / 100,
                          backgroundColor: AppTheme.cardBorder,
                          valueColor: AlwaysStoppedAnimation(cor), minHeight: 4))),
                      const SizedBox(width: 8),
                      Text('${prog.toInt()}%', style: TextStyle(
                        color: cor, fontSize: 11, fontWeight: FontWeight.w700)),
                    ]),
                  ],
                  if (canEdit) ...[
                    const SizedBox(height: 4),
                    const Row(children: [
                      Icon(Icons.edit_rounded, size: 11, color: AppTheme.textMuted),
                      SizedBox(width: 4),
                      Text('Toque para atualizar', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                    ]),
                  ],
                ])).animate(delay: Duration(milliseconds: i * 50)).fadeIn())),
          ]);
        }));
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)));

  String _fmtData(String? d) {
    if (d == null) return '—';
    try {
      final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    } catch (_) { return d; }
  }
}

// ─────────────────────────────────────────────────────────────
// ABA: DOCUMENTOS CHECKLIST
// ─────────────────────────────────────────────────────────────

class TabDocumentosImpl extends StatefulWidget {
  final String obraId, role;
  final SupabaseClient supa;
  const TabDocumentosImpl({super.key, required this.obraId, required this.supa, required this.role});
  @override State<TabDocumentosImpl> createState() => _TabDocumentosImplState();
}

class _TabDocumentosImplState extends State<TabDocumentosImpl>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _docs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); _carregar(); }

  Future<void> _carregar() async {
    final data = await widget.supa.schema('grupo_dantas').from('documentos_checklist')
        .select().eq('obra_id', widget.obraId).order('fase');
    setState(() { _docs = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  List<Map<String, dynamic>> _por(String fase) =>
      _docs.where((d) => d['fase'] == fase).toList();

  Future<void> _toggle(Map<String, dynamic> doc) async {
    if (widget.role == 'cliente') return;
    final ok = !(doc['concluido'] as bool? ?? false);
    await widget.supa.schema('grupo_dantas').from('documentos_checklist').update({
      'concluido': ok,
      'data_conclusao': ok ? DateTime.now().toIso8601String().substring(0, 10) : null,
    }).eq('id', doc['id']);
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2));
    const fases = ['pre_obra', 'execucao', 'entrega'];
    const labels = ['Pré-Obra', 'Execução', 'Entrega'];

    return Column(children: [
      Container(color: AppTheme.surface, child: TabBar(
        controller: _tabs, labelColor: AppTheme.gold,
        unselectedLabelColor: AppTheme.textMuted, indicatorColor: AppTheme.gold,
        dividerColor: AppTheme.cardBorder,
        tabs: List.generate(3, (i) {
          final lista = _por(fases[i]);
          final feitos = lista.where((d) => d['concluido'] == true).length;
          return Tab(child: Text('${labels[i]} $feitos/${lista.length}',
            style: const TextStyle(fontSize: 11)));
        }))),
      Expanded(child: TabBarView(controller: _tabs,
        children: List.generate(3, (i) {
          final lista = _por(fases[i]);
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lista.length,
            itemBuilder: (_, j) {
              final doc = lista[j];
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
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                          child: const Text('OBRIGATÓRIO', style: TextStyle(
                            color: AppTheme.error, fontSize: 8, fontWeight: FontWeight.w700))),
                        if (ok && doc['data_conclusao'] != null)
                          Text('${_fmtData(doc['data_conclusao'])}',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                      ]),
                    ])),
                    if (ok) const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 18),
                  ])).animate(delay: Duration(milliseconds: j * 40)).fadeIn());
            });
        }))),
    ]);
  }

  String _fmtData(String? d) {
    if (d == null) return '—';
    try {
      final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    } catch (_) { return d; }
  }

  @override void dispose() { _tabs.dispose(); super.dispose(); }
}

// ─────────────────────────────────────────────────────────────
// ABA: DIÁRIO DE OBRA
// ─────────────────────────────────────────────────────────────

class TabDiarioImpl extends StatefulWidget {
  final String obraId, role;
  final SupabaseClient supa;
  const TabDiarioImpl({super.key, required this.obraId, required this.supa, required this.role});
  @override State<TabDiarioImpl> createState() => _TabDiarioImplState();
}

class _TabDiarioImplState extends State<TabDiarioImpl> {
  List<Map<String, dynamic>> _registros = [];
  bool _loading = true;

  @override void initState() { super.initState(); _carregar(); }

  Future<void> _carregar() async {
    final data = await widget.supa.schema('grupo_dantas').from('diario_obra')
        .select().eq('obra_id', widget.obraId)
        .order('data', ascending: false).limit(50);
    setState(() { _registros = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  Future<void> _add() async {
    final descCtrl = TextEditingController();
    final probCtrl = TextEditingController();
    final proxCtrl = TextEditingController();
    final eqCtrl   = TextEditingController(text: '0');
    String clima = 'Ensolarado';

    await showModalBottomSheet(
      context: context, backgroundColor: AppTheme.surface, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) =>
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Novo Registro Diário', style: TextStyle(
              color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
            Text(DateTime.now().toString().substring(0, 10),
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 14),
            const Text('Clima', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final c in ['Ensolarado', 'Nublado', 'Chuvoso', 'Parcialmente nublado'])
                ChoiceChip(
                  label: Text(c, style: const TextStyle(fontSize: 11)),
                  selected: clima == c,
                  selectedColor: AppTheme.gold.withOpacity(0.2),
                  backgroundColor: AppTheme.surfaceAlt,
                  side: BorderSide(color: clima == c ? AppTheme.gold : AppTheme.cardBorder),
                  labelStyle: TextStyle(color: clima == c ? AppTheme.gold : AppTheme.textSecondary),
                  onSelected: (_) => setS(() => clima = c)),
            ]),
            const SizedBox(height: 10),
            TextField(controller: eqCtrl, keyboardType: TextInputType.number,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Operários presentes')),
            const SizedBox(height: 10),
            TextField(controller: descCtrl, maxLines: 3,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Atividades realizadas *', alignLabelWithHint: true)),
            const SizedBox(height: 10),
            TextField(controller: probCtrl, maxLines: 2,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Problemas encontrados (opcional)', alignLabelWithHint: true)),
            const SizedBox(height: 10),
            TextField(controller: proxCtrl, maxLines: 2,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Próximos passos', alignLabelWithHint: true)),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  if (descCtrl.text.trim().isEmpty) return;
                  final uid = widget.supa.auth.currentUser?.id;
                  final u = await widget.supa.schema('grupo_dantas').from('usuarios')
                      .select('id').eq('auth_id', uid!).maybeSingle();
                  await widget.supa.schema('grupo_dantas').from('diario_obra').insert({
                    'obra_id': widget.obraId,
                    'data': DateTime.now().toIso8601String().substring(0, 10),
                    'clima': clima,
                    'equipe_presente': int.tryParse(eqCtrl.text) ?? 0,
                    'descricao': descCtrl.text.trim(),
                    'problemas_encontrados': probCtrl.text.trim().isEmpty ? null : probCtrl.text.trim(),
                    'proximo_passo': proxCtrl.text.trim().isEmpty ? null : proxCtrl.text.trim(),
                    'autor_id': u?['id'],
                  });
                  Navigator.pop(ctx);
                  _carregar();
                },
                child: const Text('Salvar Registro', style: TextStyle(fontWeight: FontWeight.w700)))),
          ]))));
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.role != 'cliente';
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: canEdit ? FloatingActionButton.extended(
        onPressed: _add, backgroundColor: AppTheme.gold, foregroundColor: AppTheme.background,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo Registro', style: TextStyle(fontWeight: FontWeight.w700))) : null,
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2))
        : _registros.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.menu_book_rounded, color: AppTheme.textMuted, size: 56),
              const SizedBox(height: 12),
              const Text('Nenhum registro', style: TextStyle(color: AppTheme.textSecondary)),
              if (canEdit) const Text('Toque em + para adicionar',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ]))
          : RefreshIndicator(onRefresh: _carregar, color: AppTheme.gold,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _registros.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final r = _registros[i];
                  final clima = r['clima'] as String? ?? '';
                  return GDCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(_fmtData(r['data']), style: const TextStyle(
                        color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                      Row(children: [
                        Icon(_climaIcon(clima), size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(clima, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ]),
                    ]),
                    if ((r['equipe_presente'] as int? ?? 0) > 0) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.group_rounded, size: 12, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text('${r['equipe_presente']} operários',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      ]),
                    ],
                    const SizedBox(height: 8),
                    Text(r['descricao'] ?? '', style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13, height: 1.4)),
                    if (r['problemas_encontrados'] != null) ...[
                      const SizedBox(height: 8),
                      Container(padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.warning.withOpacity(0.2))),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.warning_rounded, color: AppTheme.warning, size: 14),
                          const SizedBox(width: 6),
                          Expanded(child: Text(r['problemas_encontrados'], style: const TextStyle(
                            color: AppTheme.warning, fontSize: 12, height: 1.3))),
                        ])),
                    ],
                    if (r['proximo_passo'] != null) ...[
                      const SizedBox(height: 6),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.arrow_forward_rounded, size: 13, color: AppTheme.info),
                        const SizedBox(width: 4),
                        Expanded(child: Text(r['proximo_passo'], style: const TextStyle(
                          color: AppTheme.info, fontSize: 12))),
                      ]),
                    ],
                  ])).animate(delay: Duration(milliseconds: i * 40)).fadeIn();
                })));
  }

  IconData _climaIcon(String c) {
    if (c.contains('Chuv')) return Icons.umbrella_rounded;
    if (c.contains('Nublado')) return Icons.cloud_rounded;
    return Icons.wb_sunny_rounded;
  }

  String _fmtData(String? d) {
    if (d == null) return '—';
    try {
      final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    } catch (_) { return d; }
  }
}

// ─────────────────────────────────────────────────────────────
// ABA: SOLICITAÇÕES DE MATERIAL
// ─────────────────────────────────────────────────────────────

class TabMateriaisImpl extends StatefulWidget {
  final String obraId, role;
  final SupabaseClient supa;
  const TabMateriaisImpl({super.key, required this.obraId, required this.supa, required this.role});
  @override State<TabMateriaisImpl> createState() => _TabMateriaisImplState();
}

class _TabMateriaisImplState extends State<TabMateriaisImpl> {
  List<Map<String, dynamic>> _sols = [];
  bool _loading = true;

  @override void initState() { super.initState(); _carregar(); }

  Future<void> _carregar() async {
    final data = await widget.supa.schema('grupo_dantas').from('solicitacoes_material')
        .select().eq('obra_id', widget.obraId).order('criado_em', ascending: false);
    setState(() { _sols = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  Future<void> _nova() async {
    final nomeCtrl = TextEditingController();
    final qtdCtrl  = TextEditingController();
    final unCtrl   = TextEditingController(text: 'un');
    final obsCtrl  = TextEditingController();
    String urg = 'normal';
    DateTime? dataNec;

    await showModalBottomSheet(
      context: context, backgroundColor: AppTheme.surface, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) =>
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Solicitar Material', style: TextStyle(
              color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 14),
            TextField(controller: nomeCtrl, style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Nome do material *')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: qtdCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Quantidade *'))),
              const SizedBox(width: 10),
              SizedBox(width: 80, child: TextField(controller: unCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Unidade'))),
            ]),
            const SizedBox(height: 12),
            const Text('Urgência', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final u in [
                ('baixa','Baixa',AppTheme.info),
                ('normal','Normal',AppTheme.success),
                ('alta','Alta',AppTheme.warning),
                ('urgente','Urgente',AppTheme.error),
              ]) ChoiceChip(
                label: Text(u.$2, style: const TextStyle(fontSize: 11)),
                selected: urg == u.$1,
                selectedColor: (u.$3 as Color).withOpacity(0.2),
                backgroundColor: AppTheme.surfaceAlt,
                side: BorderSide(color: urg == u.$1 ? (u.$3 as Color) : AppTheme.cardBorder),
                labelStyle: TextStyle(color: urg == u.$1 ? (u.$3 as Color) : AppTheme.textSecondary),
                onSelected: (_) => setS(() => urg = u.$1)),
            ]),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(context: context,
                  initialDate: DateTime.now().add(const Duration(days: 3)),
                  firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.dark(
                      primary: AppTheme.gold, onPrimary: AppTheme.background,
                      surface: AppTheme.surface)), child: child!));
                if (d != null) setS(() => dataNec = d);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: dataNec != null
                    ? AppTheme.gold.withOpacity(0.5) : AppTheme.cardBorder)),
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 16,
                    color: dataNec != null ? AppTheme.gold : AppTheme.textMuted),
                  const SizedBox(width: 8),
                  Text(dataNec == null ? 'Data necessária na obra'
                    : 'Necessário em: ${dataNec!.day.toString().padLeft(2,'0')}/${dataNec!.month.toString().padLeft(2,'0')}/${dataNec!.year}',
                    style: TextStyle(color: dataNec != null ? AppTheme.textPrimary : AppTheme.textMuted, fontSize: 13)),
                ])),
            ),
            const SizedBox(height: 10),
            TextField(controller: obsCtrl, maxLines: 2, style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Observações (opcional)', alignLabelWithHint: true)),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  if (nomeCtrl.text.trim().isEmpty || qtdCtrl.text.isEmpty) return;
                  final uid = widget.supa.auth.currentUser?.id;
                  final u = await widget.supa.schema('grupo_dantas').from('usuarios')
                      .select('id').eq('auth_id', uid!).maybeSingle();
                  await widget.supa.schema('grupo_dantas').from('solicitacoes_material').insert({
                    'obra_id': widget.obraId,
                    'solicitante_id': u?['id'],
                    'nome': nomeCtrl.text.trim(),
                    'quantidade': double.tryParse(qtdCtrl.text.replaceAll(',', '.')) ?? 1,
                    'unidade': unCtrl.text.trim().isEmpty ? 'un' : unCtrl.text.trim(),
                    'urgencia': urg,
                    'status': 'pendente',
                    'data_necessidade': dataNec?.toIso8601String().substring(0, 10),
                    'observacoes': obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
                  });
                  Navigator.pop(ctx);
                  _carregar();
                },
                child: const Text('Enviar Solicitação', style: TextStyle(fontWeight: FontWeight.w700)))),
          ]))));
  }

  Future<void> _atualizarStatus(Map<String, dynamic> sol) async {
    if (widget.role != 'admin' && widget.role != 'engenheiro') return;
    final status = sol['status'] as String? ?? 'pendente';

    final opcoes = <(String, String, Color)>[];
    if (status == 'pendente') {
      opcoes.addAll([('validado', 'Validar', AppTheme.success), ('rejeitado_eng', 'Rejeitar', AppTheme.error)]);
    } else if (status == 'validado' && widget.role == 'admin') {
      opcoes.addAll([('aprovado', 'Aprovar compra', AppTheme.success), ('rejeitado_gestor', 'Rejeitar', AppTheme.error)]);
    } else if (status == 'aprovado') {
      opcoes.add(('comprado', 'Marcar comprado', AppTheme.info));
    } else if (status == 'comprado') {
      opcoes.add(('entregue', 'Confirmar entrega', AppTheme.success));
    }
    if (opcoes.isEmpty) return;

    String? novoStatus;
    final motivoCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context, backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(sol['nome'] ?? '', style: const TextStyle(
            color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
          Text('${sol['quantidade']} ${sol['unidade']}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 14),
          ...opcoes.map((op) => Padding(padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  novoStatus = op.$1;
                  if (!novoStatus!.contains('rejeitado')) {
                    await _salvarStatus(sol['id'], novoStatus!, motivoCtrl.text);
                    Navigator.pop(ctx);
                  } else { setS(() {}); }
                },
                style: ElevatedButton.styleFrom(backgroundColor: op.$3, foregroundColor: Colors.white),
                child: Text(op.$2, style: const TextStyle(fontWeight: FontWeight.w700)))))),
          if (novoStatus != null && novoStatus!.contains('rejeitado')) ...[
            TextField(controller: motivoCtrl, style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Motivo da rejeição')),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: 44,
              child: ElevatedButton(
                onPressed: () async {
                  await _salvarStatus(sol['id'], novoStatus!, motivoCtrl.text);
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                child: const Text('Confirmar Rejeição'))),
          ],
        ]))));

    _carregar();
  }

  Future<void> _salvarStatus(String id, String status, String motivo) async {
    await widget.supa.schema('grupo_dantas').from('solicitacoes_material').update({
      'status': status,
      if (status.contains('rejeitado') && motivo.isNotEmpty) 'motivo_rejeicao': motivo,
      if (status == 'validado' || status == 'rejeitado_eng')
        'data_aprovacao_eng': DateTime.now().toIso8601String(),
      if (status == 'aprovado' || status == 'rejeitado_gestor')
        'data_aprovacao_gest': DateTime.now().toIso8601String(),
      if (status == 'entregue')
        'data_entrega_real': DateTime.now().toIso8601String().substring(0, 10),
    }).eq('id', id);
  }

  @override
  Widget build(BuildContext context) {
    final canSolicitar = widget.role != 'cliente';
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: canSolicitar ? FloatingActionButton.extended(
        onPressed: _nova, backgroundColor: AppTheme.gold, foregroundColor: AppTheme.background,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Solicitar', style: TextStyle(fontWeight: FontWeight.w700))) : null,
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2))
        : _sols.isEmpty
          ? const Center(child: Text('Nenhuma solicitação', style: TextStyle(color: AppTheme.textSecondary)))
          : RefreshIndicator(onRefresh: _carregar, color: AppTheme.gold,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _sols.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final s = _sols[i];
                  final status = s['status'] as String? ?? 'pendente';
                  final urg = s['urgencia'] as String? ?? 'normal';
                  final cor = _statusColor(status);
                  final urgCor = _urgColor(urg);
                  bool atrasado = false;
                  if (s['data_necessidade'] != null && status != 'entregue') {
                    try { atrasado = DateTime.parse(s['data_necessidade']).isBefore(DateTime.now()); } catch (_) {}
                  }
                  return GDCard(onTap: () => _atualizarStatus(s),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(s['nome'] ?? '', style: const TextStyle(
                        color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14))),
                      if (atrasado) _chip('ATRASADO', AppTheme.error),
                      const SizedBox(width: 4),
                      _chip(_statusLabel(status), cor),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text('${s['quantidade']} ${s['unidade']}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      const SizedBox(width: 10),
                      _chip(urg.toUpperCase(), urgCor),
                      if (s['data_necessidade'] != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.calendar_today_rounded, size: 11,
                          color: atrasado ? AppTheme.error : AppTheme.textMuted),
                        const SizedBox(width: 3),
                        Text(_fmtData(s['data_necessidade']), style: TextStyle(
                          color: atrasado ? AppTheme.error : AppTheme.textMuted, fontSize: 11)),
                      ],
                    ]),
                    if (s['motivo_rejeicao'] != null) ...[
                      const SizedBox(height: 6),
                      Container(padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8)),
                        child: Text('Rejeitado: ${s['motivo_rejeicao']}',
                          style: const TextStyle(color: AppTheme.error, fontSize: 11))),
                    ],
                    const SizedBox(height: 10),
                    _PipelineStatus(status: status),
                  ])).animate(delay: Duration(milliseconds: i * 40)).fadeIn();
                })));
  }

  Widget _chip(String l, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
    child: Text(l, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w700)));

  Color _statusColor(String s) {
    switch (s) {
      case 'aprovado': case 'entregue': return AppTheme.success;
      case 'rejeitado_eng': case 'rejeitado_gestor': return AppTheme.error;
      case 'comprado': return AppTheme.info;
      case 'validado': return AppTheme.warning;
      default: return AppTheme.textMuted;
    }
  }

  String _statusLabel(String s) {
    const m = {'pendente':'Pendente','validado':'Validado','rejeitado_eng':'Rejeitado',
      'aprovado':'Aprovado','rejeitado_gestor':'Rejeitado','comprado':'Comprado','entregue':'Entregue'};
    return m[s] ?? s;
  }

  Color _urgColor(String u) {
    switch (u) {
      case 'urgente': return AppTheme.error;
      case 'alta': return AppTheme.warning;
      case 'baixa': return AppTheme.info;
      default: return AppTheme.success;
    }
  }

  String _fmtData(String? d) {
    if (d == null) return '—';
    try {
      final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    } catch (_) { return d; }
  }
}

// Pipeline de aprovação visual
class _PipelineStatus extends StatelessWidget {
  final String status;
  const _PipelineStatus({required this.status});

  static const steps = [
    ('pendente', 'Solicitado'),
    ('validado', 'Validado'),
    ('aprovado', 'Aprovado'),
    ('comprado', 'Comprado'),
    ('entregue', 'Entregue'),
  ];

  int get _idx {
    for (int i = 0; i < steps.length; i++) {
      if (steps[i].$1 == status) return i;
    }
    return status.contains('rejeitado') ? -1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_idx < 0) return Row(children: [
      const Icon(Icons.cancel_rounded, color: AppTheme.error, size: 14),
      const SizedBox(width: 6),
      const Text('Rejeitado', style: TextStyle(color: AppTheme.error, fontSize: 11)),
    ]);

    return Row(children: steps.asMap().entries.map((e) {
      final i = e.key;
      final done = i <= _idx;
      final active = i == _idx;
      return Expanded(child: Row(children: [
        Column(children: [
          Container(width: active ? 10 : 7, height: active ? 10 : 7,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: done ? AppTheme.gold : AppTheme.cardBorder,
              border: active ? Border.all(color: AppTheme.gold, width: 2) : null)),
          const SizedBox(height: 2),
          Text(e.value.$2, style: TextStyle(
            color: done ? AppTheme.gold : AppTheme.textMuted,
            fontSize: 8, fontWeight: active ? FontWeight.w700 : FontWeight.w400),
            textAlign: TextAlign.center),
        ]),
        if (i < steps.length - 1) Expanded(child: Container(
          height: 1, color: done && i < _idx ? AppTheme.gold : AppTheme.cardBorder)),
      ]));
    }).toList());
  }
}

// ─────────────────────────────────────────────────────────────
// ABA: FINANCEIRO
// ─────────────────────────────────────────────────────────────

class TabFinanceiroImpl extends StatefulWidget {
  final String obraId;
  final SupabaseClient supa;
  const TabFinanceiroImpl({super.key, required this.obraId, required this.supa});
  @override State<TabFinanceiroImpl> createState() => _TabFinanceiroImplState();
}

class _TabFinanceiroImplState extends State<TabFinanceiroImpl> {
  List<Map<String, dynamic>> _transacoes = [];
  double _orcamento = 0, _realizado = 0;
  bool _loading = true;

  @override void initState() { super.initState(); _carregar(); }

  Future<void> _carregar() async {
    final obra = await widget.supa.schema('grupo_dantas').from('obras')
        .select('orcamento_total, custo_realizado').eq('id', widget.obraId).single();
    final trans = await widget.supa.schema('grupo_dantas').from('transacoes')
        .select().eq('obra_id', widget.obraId)
        .order('data_transacao', ascending: false).limit(50);
    setState(() {
      _orcamento  = (obra['orcamento_total'] as num?)?.toDouble() ?? 0;
      _realizado  = (obra['custo_realizado'] as num?)?.toDouble() ?? 0;
      _transacoes = List<Map<String, dynamic>>.from(trans);
      _loading    = false;
    });
  }

  Future<void> _add() async {
    final descCtrl  = TextEditingController();
    final valorCtrl = TextEditingController();
    final catCtrl   = TextEditingController(text: 'Materiais');
    String tipo = 'despesa';

    await showModalBottomSheet(
      context: context, backgroundColor: AppTheme.surface, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) =>
        Padding(padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Nova Transação', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 14),
            Row(children: [
              for (final t in [('despesa','Despesa',AppTheme.error),('receita','Receita',AppTheme.success)])
                Expanded(child: Padding(padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(onTap: () => setS(() => tipo = t.$1),
                    child: AnimatedContainer(duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: tipo == t.$1 ? (t.$3 as Color).withOpacity(0.15) : AppTheme.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: tipo == t.$1 ? (t.$3 as Color) : AppTheme.cardBorder)),
                      child: Center(child: Text(t.$2, style: TextStyle(
                        color: tipo == t.$1 ? (t.$3 as Color) : AppTheme.textSecondary,
                        fontWeight: FontWeight.w600)))))))
            ]),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Descrição *')),
            const SizedBox(height: 10),
            TextField(controller: valorCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Valor (R\$) *',
                prefixIcon: Icon(Icons.attach_money_rounded, color: AppTheme.textMuted, size: 18))),
            const SizedBox(height: 10),
            TextField(controller: catCtrl, style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Categoria')),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  if (descCtrl.text.isEmpty || valorCtrl.text.isEmpty) return;
                  final uid = widget.supa.auth.currentUser?.id;
                  final u = await widget.supa.schema('grupo_dantas').from('usuarios')
                      .select('id').eq('auth_id', uid!).maybeSingle();
                  await widget.supa.schema('grupo_dantas').from('transacoes').insert({
                    'obra_id': widget.obraId,
                    'tipo': tipo,
                    'categoria': catCtrl.text.trim().isEmpty ? 'Geral' : catCtrl.text.trim(),
                    'descricao': descCtrl.text.trim(),
                    'valor': double.tryParse(valorCtrl.text.replaceAll(',', '.')) ?? 0,
                    'data_transacao': DateTime.now().toIso8601String().substring(0, 10),
                    'responsavel_id': u?['id'],
                  });
                  // Atualizar custo_realizado na obra
                  if (tipo == 'despesa') {
                    await widget.supa.schema('grupo_dantas').from('obras')
                        .update({'custo_realizado': _realizado + (double.tryParse(valorCtrl.text.replaceAll(',', '.')) ?? 0)})
                        .eq('id', widget.obraId);
                  }
                  Navigator.pop(ctx);
                  _carregar();
                },
                child: const Text('Salvar', style: TextStyle(fontWeight: FontWeight.w700)))),
          ]))));
  }

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    final saldo  = _orcamento - _realizado;
    final varPct = _orcamento > 0 ? (_realizado / _orcamento * 100).clamp(0.0, 999.0) : 0.0;
    final barColor = varPct > 100 ? AppTheme.error : varPct > 80 ? AppTheme.warning : AppTheme.success;

    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add, backgroundColor: AppTheme.gold, foregroundColor: AppTheme.background,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Lançar', style: TextStyle(fontWeight: FontWeight.w700))),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2))
        : RefreshIndicator(onRefresh: _carregar, color: AppTheme.gold,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
              // Cards de resumo
              Row(children: [
                Expanded(child: _FinCard('Orçamento', _fmt(_orcamento), AppTheme.gold)),
                const SizedBox(width: 10),
                Expanded(child: _FinCard('Realizado', _fmt(_realizado), AppTheme.warning)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _FinCard('Saldo',
                  _fmt(saldo), saldo >= 0 ? AppTheme.success : AppTheme.error)),
                const SizedBox(width: 10),
                Expanded(child: _FinCard('Utilizado', '${varPct.toStringAsFixed(1)}%', barColor)),
              ]),
              const SizedBox(height: 14),
              ClipRRect(borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (varPct / 100).clamp(0.0, 1.0),
                  backgroundColor: AppTheme.cardBorder,
                  valueColor: AlwaysStoppedAnimation(barColor),
                  minHeight: 8)),
              if (varPct > 100) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.error_rounded, color: AppTheme.error, size: 14),
                  const SizedBox(width: 6),
                  Text('Orçamento estourado em ${(varPct - 100).toStringAsFixed(1)}%',
                    style: const TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ],
              const SizedBox(height: 20),
              const Text('Lançamentos', style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 10),
              if (_transacoes.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Nenhum lançamento ainda',
                    style: TextStyle(color: AppTheme.textSecondary))))
              else ..._transacoes.asMap().entries.map((e) {
                final i = e.key;
                final t = e.value;
                final isPos = t['tipo'] == 'receita';
                final val   = (t['valor'] as num?)?.toDouble() ?? 0;
                return Padding(padding: const EdgeInsets.only(bottom: 8),
                  child: GDCard(child: Row(children: [
                    Container(width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: (isPos ? AppTheme.success : AppTheme.error).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                      child: Icon(isPos ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: isPos ? AppTheme.success : AppTheme.error, size: 18)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t['descricao'] ?? '', style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                      Text('${t['categoria'] ?? ''} · ${_fmtData(t['data_transacao'])}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ])),
                    Text('${isPos ? '+' : '-'}${_fmt(val)}', style: TextStyle(
                      color: isPos ? AppTheme.success : AppTheme.error,
                      fontWeight: FontWeight.w700, fontSize: 13)),
                  ])).animate(delay: Duration(milliseconds: i * 40)).fadeIn());
              }),
            ])));
  }

  String _fmtData(String? d) {
    if (d == null) return '—';
    try { final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    } catch (_) { return d; }
  }
}

class _FinCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _FinCard(this.label, this.value, this.color);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.25))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
    ]));
}

// ─────────────────────────────────────────────────────────────
// ABA: NOTAS FISCAIS
// ─────────────────────────────────────────────────────────────

class TabNotasFiscaisImpl extends StatefulWidget {
  final String obraId;
  final SupabaseClient supa;
  const TabNotasFiscaisImpl({super.key, required this.obraId, required this.supa});
  @override State<TabNotasFiscaisImpl> createState() => _TabNotasFiscaisImplState();
}

class _TabNotasFiscaisImplState extends State<TabNotasFiscaisImpl> {
  List<Map<String, dynamic>> _nfs = [];
  bool _loading = true;

  @override void initState() { super.initState(); _carregar(); }

  Future<void> _carregar() async {
    final data = await widget.supa.schema('grupo_dantas').from('notas_fiscais')
        .select().eq('obra_id', widget.obraId).order('data_emissao', ascending: false);
    setState(() { _nfs = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  Future<void> _add() async {
    final numCtrl  = TextEditingController();
    final emiCtrl  = TextEditingController();
    final cnpjCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final valCtrl  = TextEditingController();
    String cat = 'material';

    await showModalBottomSheet(
      context: context, backgroundColor: AppTheme.surface, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) =>
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Registrar Nota Fiscal', style: TextStyle(
              color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 14),
            TextField(controller: numCtrl, style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Número da NF')),
            const SizedBox(height: 10),
            TextField(controller: emiCtrl, style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Emitente *')),
            const SizedBox(height: 10),
            TextField(controller: cnpjCtrl, keyboardType: TextInputType.number,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'CNPJ')),
            const SizedBox(height: 10),
            TextField(controller: descCtrl, style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Descrição *')),
            const SizedBox(height: 10),
            TextField(controller: valCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Valor (R\$) *',
                prefixIcon: Icon(Icons.attach_money_rounded, color: AppTheme.textMuted, size: 18))),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              for (final c in ['material','servico','equipamento','outro'])
                ChoiceChip(
                  label: Text(c, style: const TextStyle(fontSize: 11)), selected: cat == c,
                  selectedColor: AppTheme.gold.withOpacity(0.2), backgroundColor: AppTheme.surfaceAlt,
                  side: BorderSide(color: cat == c ? AppTheme.gold : AppTheme.cardBorder),
                  labelStyle: TextStyle(color: cat == c ? AppTheme.gold : AppTheme.textSecondary),
                  onSelected: (_) => setS(() => cat = c)),
            ]),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  if (emiCtrl.text.isEmpty || descCtrl.text.isEmpty || valCtrl.text.isEmpty) return;
                  final uid = widget.supa.auth.currentUser?.id;
                  final u = await widget.supa.schema('grupo_dantas').from('usuarios')
                      .select('id').eq('auth_id', uid!).maybeSingle();
                  await widget.supa.schema('grupo_dantas').from('notas_fiscais').insert({
                    'obra_id': widget.obraId,
                    'numero': numCtrl.text.trim().isEmpty ? null : numCtrl.text.trim(),
                    'emitente': emiCtrl.text.trim(),
                    'cnpj_emitente': cnpjCtrl.text.trim().isEmpty ? null : cnpjCtrl.text.trim(),
                    'descricao': descCtrl.text.trim(),
                    'valor': double.tryParse(valCtrl.text.replaceAll(',', '.')) ?? 0,
                    'data_emissao': DateTime.now().toIso8601String().substring(0, 10),
                    'categoria': cat, 'status': 'pendente', 'criado_por': u?['id'],
                  });
                  Navigator.pop(ctx);
                  _carregar();
                },
                child: const Text('Salvar NF', style: TextStyle(fontWeight: FontWeight.w700)))),
          ]))));
  }

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  Widget _buildBody(double total) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2));
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: GDCard(
          gradient: AppTheme.cardGradient,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Total em NFs', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              Text(_fmt(total), style: const TextStyle(
                color: AppTheme.gold, fontSize: 22, fontWeight: FontWeight.w800)),
            ]),
            Text('${_nfs.length} notas', style: const TextStyle(color: AppTheme.textMuted)),
          ]),
        ),
      ),
      Expanded(
        child: _nfs.isEmpty
          ? const Center(child: Text('Nenhuma NF registrada',
              style: TextStyle(color: AppTheme.textSecondary)))
          : RefreshIndicator(
              onRefresh: _carregar,
              color: AppTheme.gold,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                itemCount: _nfs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final nf = _nfs[i];
                  final val = (nf['valor'] as num?)?.toDouble() ?? 0;
                  return GDCard(
                    child: Row(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.gold.withOpacity(0.2))),
                        child: const Center(child: Text('NF', style: TextStyle(
                          color: AppTheme.gold, fontSize: 11, fontWeight: FontWeight.w800)))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(nf['emitente'] ?? '', style: const TextStyle(
                          color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('${nf['descricao'] ?? ''} · ${_fmtData(nf['data_emissao'])}',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (nf['numero'] != null)
                          Text('Nº ${nf['numero']}',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(_fmt(val), style: const TextStyle(
                          color: AppTheme.gold, fontWeight: FontWeight.w700, fontSize: 13)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.info.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4)),
                          child: Text(nf['categoria'] ?? '', style: const TextStyle(
                            color: AppTheme.info, fontSize: 9))),
                      ]),
                    ]),
                  ).animate(delay: Duration(milliseconds: i * 40)).fadeIn();
                },
              ),
            ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final total = _nfs.fold(0.0, (s, n) => s + ((n['valor'] as num?)?.toDouble() ?? 0));
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: AppTheme.gold,
        foregroundColor: AppTheme.background,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova NF', style: TextStyle(fontWeight: FontWeight.w700))),
      body: _buildBody(total),
    );
  }

  String _fmtData(String? d) {
    if (d == null) return '—';
    try { final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    } catch (_) { return d; }
  }
}

// ─────────────────────────────────────────────────────────────
// ABA: ALERTAS
// ─────────────────────────────────────────────────────────────

class TabAlertasImpl extends StatefulWidget {
  final String obraId;
  final SupabaseClient supa;
  const TabAlertasImpl({super.key, required this.obraId, required this.supa});
  @override State<TabAlertasImpl> createState() => _TabAlertasImplState();
}

class _TabAlertasImplState extends State<TabAlertasImpl> {
  List<Map<String, dynamic>> _alertas = [];
  bool _loading = true;

  @override void initState() { super.initState(); _carregar(); }

  Future<void> _carregar() async {
    final data = await widget.supa.schema('grupo_dantas').from('alertas')
        .select().eq('obra_id', widget.obraId).eq('resolvido', false)
        .order('criado_em', ascending: false);
    setState(() { _alertas = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  Future<void> _resolver(String id) async {
    await widget.supa.schema('grupo_dantas').from('alertas').update({
      'resolvido': true, 'resolvido_em': DateTime.now().toIso8601String(),
    }).eq('id', id);
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2));

    if (_alertas.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 64),
        SizedBox(height: 16),
        Text('Nenhum alerta ativo!',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
        SizedBox(height: 4),
        Text('Tudo em ordem por aqui.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
      ]));
    }

    return RefreshIndicator(onRefresh: _carregar, color: AppTheme.gold,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _alertas.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final a = _alertas[i];
          final sev = a['severidade'] as String? ?? 'warning';
          final cor = sev == 'critical' ? AppTheme.error
            : sev == 'warning' ? AppTheme.warning : AppTheme.info;
          final icon = sev == 'critical'
            ? Icons.error_rounded : Icons.warning_amber_rounded;

          return GDCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(
                color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: cor, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(a['titulo'] ?? '', style: TextStyle(
                  color: cor, fontWeight: FontWeight.w700, fontSize: 13))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(sev.toUpperCase(),
                    style: TextStyle(color: cor, fontSize: 9, fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 4),
              Text(a['descricao'] ?? '', style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12, height: 1.4)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _resolver(a['id']),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.success.withOpacity(0.3))),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_rounded, color: AppTheme.success, size: 14),
                    SizedBox(width: 6),
                    Text('Marcar como resolvido', style: TextStyle(
                      color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]))),
            ])),
          ])).animate(delay: Duration(milliseconds: i * 50)).fadeIn();
        }));
  }
}

// ─────────────────────────────────────────────────────────────
// ABA: EQUIPE
// ─────────────────────────────────────────────────────────────

class TabEquipeImpl extends StatefulWidget {
  final String obraId;
  final SupabaseClient supa;
  const TabEquipeImpl({super.key, required this.obraId, required this.supa});
  @override State<TabEquipeImpl> createState() => _TabEquipeImplState();
}

class _TabEquipeImplState extends State<TabEquipeImpl> {
  List<Map<String, dynamic>> _equipe = [];
  bool _loading = true;

  @override void initState() { super.initState(); _carregar(); }

  Future<void> _carregar() async {
    final data = await widget.supa.schema('grupo_dantas').from('obra_usuarios')
        .select('role, usuarios(id, nome, email, role, telefone)')
        .eq('obra_id', widget.obraId);
    setState(() { _equipe = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2));

    if (_equipe.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.people_outline_rounded, color: AppTheme.textMuted, size: 56),
          SizedBox(height: 16),
          Text('Nenhum membro vinculado', style: TextStyle(
            color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('Acesse Perfil → Gerenciar Usuários\ne vincule usuários a esta obra.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            textAlign: TextAlign.center),
        ])));
    }

    // Agrupar por role
    final roles = <String>[];
    final por = <String, List<Map<String, dynamic>>>{};
    for (final m in _equipe) {
      final u = m['usuarios'] as Map<String, dynamic>? ?? {};
      final r = u['role'] as String? ?? 'outro';
      if (!roles.contains(r)) roles.add(r);
      por.putIfAbsent(r, () => []).add(m);
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      // Contador
      GDCard(child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _CountChip('Total', _equipe.length, AppTheme.gold),
        _CountChip('Engenheiros', (por['engenheiro']?.length ?? 0), AppTheme.info),
        _CountChip('Mestres', (por['outro']?.length ?? 0), AppTheme.warning),
        _CountChip('Clientes', (por['cliente']?.length ?? 0), AppTheme.success),
      ])).animate().fadeIn(),
      const SizedBox(height: 16),

      ...roles.map((role) {
        final lista = por[role] ?? [];
        final cor = _roleCor(role);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(width: 3, height: 16, color: cor, margin: const EdgeInsets.only(right: 8)),
              Text(_roleLabel(role), style: TextStyle(
                color: cor, fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(width: 6),
              Text('${lista.length}', style: TextStyle(color: cor.withOpacity(0.6), fontSize: 12)),
            ])),
          ...lista.asMap().entries.map((e) {
            final i = e.key;
            final u = e.value['usuarios'] as Map<String, dynamic>? ?? {};
            final nome = u['nome'] as String? ?? 'Usuário';
            final ini = nome.isNotEmpty ? nome.substring(0, 1).toUpperCase() : 'U';
            return Padding(padding: const EdgeInsets.only(bottom: 10),
              child: GDCard(child: Row(children: [
                Container(width: 46, height: 46,
                  decoration: BoxDecoration(gradient: AppTheme.goldGradient, shape: BoxShape.circle),
                  child: Center(child: Text(ini, style: const TextStyle(
                    color: AppTheme.background, fontWeight: FontWeight.w800, fontSize: 18)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(nome, style: const TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(u['email'] ?? '', style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 11)),
                  if (u['telefone'] != null)
                    Text(u['telefone'], style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(_roleLabel(role), style: TextStyle(
                    color: cor, fontSize: 11, fontWeight: FontWeight.w700))),
              ])).animate(delay: Duration(milliseconds: i * 50)).fadeIn());
          }),
          const SizedBox(height: 8),
        ]);
      }),
    ]);
  }

  String _roleLabel(String r) {
    const m = {'admin':'Admin','engenheiro':'Engenheiro','cliente':'Cliente','outro':'Mestre/Pedreiro'};
    return m[r] ?? r;
  }

  Color _roleCor(String r) {
    switch (r) {
      case 'admin': return AppTheme.gold;
      case 'engenheiro': return AppTheme.info;
      case 'cliente': return AppTheme.success;
      default: return AppTheme.warning;
    }
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _CountChip(this.label, this.count, this.color);
  @override Widget build(BuildContext context) => Column(children: [
    Text('$count', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
    Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
  ]);
}
