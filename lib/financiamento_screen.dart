import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'gd_card.dart';
import 'obra_context.dart';

class FinanciamentoScreen extends StatefulWidget {
  const FinanciamentoScreen({super.key});
  @override
  State<FinanciamentoScreen> createState() => _FinanciamentoScreenState();
}

class _FinanciamentoScreenState extends State<FinanciamentoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _supa = Supabase.instance.client;
  final _ctx = ObraContext();

  @override
  void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (b) => AppTheme.goldGradient.createShader(b),
          child: const Text('Financiamento',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
        bottom: TabBar(controller: _tabs, labelColor: AppTheme.gold,
          unselectedLabelColor: AppTheme.textMuted, indicatorColor: AppTheme.gold,
          dividerColor: AppTheme.cardBorder,
          tabs: const [
            Tab(text: 'Modelo Financeiro'),
            Tab(text: 'Parcelas'),
            Tab(text: 'Visão Cliente'),
          ]),
      ),
      body: TabBarView(controller: _tabs, children: [
        _ModeloTab(supa: _supa, ctx: _ctx),
        _ParcelasTab(supa: _supa, ctx: _ctx),
        _VisaoClienteTab(supa: _supa, ctx: _ctx),
      ]),
    );
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }
}

// ─────────────────────────────────────────────────────────────
// ABA: MODELO FINANCEIRO (configuração do financiamento)
// ─────────────────────────────────────────────────────────────

class _ModeloTab extends StatefulWidget {
  final SupabaseClient supa;
  final ObraContext ctx;
  const _ModeloTab({required this.supa, required this.ctx});
  @override
  State<_ModeloTab> createState() => _ModeloTabState();
}

class _ModeloTabState extends State<_ModeloTab> {
  Map<String, dynamic>? _financiamento;
  bool _loading = true;
  bool _editando = false;
  late TextEditingController _bancoCtrl, _linhaCtrl, _taxaCtrl, _prazoCtrl;
  late TextEditingController _entrada1Ctrl, _entrada2Ctrl, _construcaoCtrl;
  String _modelo = 'tradicional';

  @override
  void initState() {
    super.initState();
    _bancoCtrl = TextEditingController();
    _linhaCtrl = TextEditingController();
    _taxaCtrl = TextEditingController();
    _prazoCtrl = TextEditingController(text: '120');
    _entrada1Ctrl = TextEditingController(text: '30');
    _entrada2Ctrl = TextEditingController(text: '20');
    _construcaoCtrl = TextEditingController(text: '50');
    _carregar();
  }

  Future<void> _carregar() async {
    if (widget.ctx.obraId == null) { setState(() => _loading = false); return; }
    try {
      final data = await widget.supa.schema('grupo_dantas').from('financiamentos')
          .select().eq('obra_id', widget.ctx.obraId!).maybeSingle();
      if (data != null) {
        _financiamento = data;
        _bancoCtrl.text = data['banco'] ?? '';
        _linhaCtrl.text = data['linha_credito'] ?? '';
        _taxaCtrl.text = (data['taxa_juros'] as num?)?.toString() ?? '';
        _prazoCtrl.text = (data['prazo_meses'] as num?)?.toString() ?? '120';
        _entrada1Ctrl.text = (data['entrada_pct'] as num?)?.toString() ?? '30';
        _entrada2Ctrl.text = (data['entrada_obra_pct'] as num?)?.toString() ?? '20';
        _construcaoCtrl.text = (data['construcao_pct'] as num?)?.toString() ?? '50';
        _modelo = data['modelo'] ?? 'tradicional';
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _salvar() async {
    if (widget.ctx.obraId == null) return;
    final taxa = double.tryParse(_taxaCtrl.text) ?? 0;
    final prazo = int.tryParse(_prazoCtrl.text) ?? 120;
    final entrada1 = double.tryParse(_entrada1Ctrl.text) ?? 30;
    final entrada2 = double.tryParse(_entrada2Ctrl.text) ?? 20;
    final construcao = double.tryParse(_construcaoCtrl.text) ?? 50;

    if (_financiamento == null) {
      await widget.supa.schema('grupo_dantas').from('financiamentos').insert({
        'obra_id': widget.ctx.obraId,
        'modelo': _modelo,
        'banco': _bancoCtrl.text.trim(),
        'linha_credito': _linhaCtrl.text.trim(),
        'taxa_juros': taxa,
        'prazo_meses': prazo,
        'entrada_pct': entrada1,
        'entrada_obra_pct': entrada2,
        'construcao_pct': construcao,
        'status': 'ativo',
      });
    } else {
      await widget.supa.schema('grupo_dantas').from('financiamentos')
          .update({
            'modelo': _modelo,
            'banco': _bancoCtrl.text.trim(),
            'linha_credito': _linhaCtrl.text.trim(),
            'taxa_juros': taxa,
            'prazo_meses': prazo,
            'entrada_pct': entrada1,
            'entrada_obra_pct': entrada2,
            'construcao_pct': construcao,
          }).eq('id', _financiamento!['id']);
    }
    _carregar();
    setState(() => _editando = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Modelo salvo com sucesso!'), backgroundColor: AppTheme.success));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ctx.obraId == null) {
      return const Center(child: Padding(padding: EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.account_balance_rounded, color: AppTheme.textMuted, size: 56),
          SizedBox(height: 16),
          Text('Selecione uma obra', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('Use o seletor na barra lateral.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ])));
    }

    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2));

    return ListView(padding: const EdgeInsets.all(20), children: [
      if (widget.ctx.obraNome != null)
        Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(color: AppTheme.gold.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.gold.withOpacity(0.25))),
          child: Row(children: [
            const Icon(Icons.construction_rounded, color: AppTheme.gold, size: 16),
            const SizedBox(width: 8),
            Text('Obra: ${widget.ctx.obraNome}', style: const TextStyle(color: AppTheme.gold, fontSize: 12, fontWeight: FontWeight.w600)),
          ])),

      if (!_editando && _financiamento != null) ...[
        GDCard(gradient: AppTheme.cardGradient, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Modelo: Tradicional', style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w700, fontSize: 14)),
              Text(_bancoCtrl.text.isEmpty ? 'Sem banco vinculado' : _bancoCtrl.text,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ]),
            IconButton(icon: const Icon(Icons.edit_rounded, color: AppTheme.gold), onPressed: () => setState(() => _editando = true)),
          ]),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.cardBorder),
          const SizedBox(height: 8),
          _infoRow('Entrada', '${_entrada1Ctrl.text}%'),
          _infoRow('Entrada obra (início construção)', '${_entrada2Ctrl.text}%'),
          _infoRow('Financiamento', '${_construcaoCtrl.text}%'),
          if (_taxaCtrl.text.isNotEmpty) _infoRow('Taxa', '${_taxaCtrl.text}% a.a.'),
          _infoRow('Prazo', '${_prazoCtrl.text} meses'),
        ])),
      ],

      if (_editando || _financiamento == null) ...[
        const Text('Modelo do Financiamento',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final m in [
            ('tradicional', 'Tradicional', Icons.home_rounded),
            ('permuta', 'Permuta', Icons.handshake_rounded),
            ('mista', 'Mista', Icons.merge_rounded),
            ('direto_dev', 'Direto do Dev', Icons.home_work_rounded),
          ]) ChoiceChip(label: Text(m.$2, style: const TextStyle(fontSize: 11)),
            selected: _modelo == m.$1,
            selectedColor: AppTheme.gold.withOpacity(0.2), backgroundColor: AppTheme.surfaceAlt,
            side: BorderSide(color: _modelo == m.$1 ? AppTheme.gold : AppTheme.cardBorder),
            labelStyle: TextStyle(color: _modelo == m.$1 ? AppTheme.gold : AppTheme.textSecondary),
            onSelected: (_) => setState(() => _modelo = m.$1)),
        ]),
        const SizedBox(height: 14),

        TextField(controller: _bancoCtrl, style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(labelText: 'Banco/Instituição')),
        const SizedBox(height: 10),

        TextField(controller: _linhaCtrl, style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(labelText: 'Linha de crédito')),
        const SizedBox(height: 10),

        Row(children: [
          Expanded(child: TextField(controller: _taxaCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(labelText: 'Taxa (% a.a.)', suffixText: '%'))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _prazoCtrl, keyboardType: TextInputType.number,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(labelText: 'Prazo (meses)'))),
        ]),
        const SizedBox(height: 14),

        const Text('Fluxo de Pagamento (%)',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 8),

        TextField(controller: _entrada1Ctrl, keyboardType: TextInputType.number,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(labelText: 'Entrada antes de iniciar', suffixText: '%')),
        const SizedBox(height: 10),

        TextField(controller: _entrada2Ctrl, keyboardType: TextInputType.number,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(labelText: 'Entrada ao iniciar obra', suffixText: '%')),
        const SizedBox(height: 10),

        TextField(controller: _construcaoCtrl, keyboardType: TextInputType.number,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(labelText: 'Financiamento na construção', suffixText: '%')),
        const SizedBox(height: 20),

        SizedBox(width: double.infinity, height: 48,
          child: ElevatedButton.icon(
            onPressed: _salvar,
            icon: const Icon(Icons.save_rounded),
            label: const Text('SALVAR MODELO', style: TextStyle(fontWeight: FontWeight.w700)))),

        if (_editando)
          Padding(padding: const EdgeInsets.only(top: 10),
            child: SizedBox(width: double.infinity, height: 40,
              child: OutlinedButton(
                onPressed: () => setState(() => _editando = false),
                child: const Text('CANCELAR')))),
      ],
    ]);
  }

  Widget _infoRow(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      Text(v, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
    ]));
}

// ─────────────────────────────────────────────────────────────
// ABA: PARCELAS (controle de pagamentos)
// ─────────────────────────────────────────────────────────────

class _ParcelasTab extends StatefulWidget {
  final SupabaseClient supa;
  final ObraContext ctx;
  const _ParcelasTab({required this.supa, required this.ctx});
  @override
  State<_ParcelasTab> createState() => _ParcelasTabState();
}

class _ParcelasTabState extends State<_ParcelasTab> {
  List<Map<String, dynamic>> _parcelas = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _carregar(); }

  Future<void> _carregar() async {
    if (widget.ctx.obraId == null) { setState(() => _loading = false); return; }
    final data = await widget.supa.schema('grupo_dantas').from('financiamento_parcelas')
        .select().eq('obra_id', widget.ctx.obraId!)
        .order('data_vencimento', ascending: true);
    setState(() { _parcelas = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  Future<void> _marcarPago(Map<String, dynamic> parc, bool pago) async {
    await widget.supa.schema('grupo_dantas').from('financiamento_parcelas')
        .update({'status': pago ? 'pago' : 'pendente'}).eq('id', parc['id']);
    _carregar();
  }

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    if (widget.ctx.obraId == null) {
      return const Center(child: Padding(padding: EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.event_note_rounded, color: AppTheme.textMuted, size: 56),
          SizedBox(height: 16),
          Text('Selecione uma obra', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('Use o seletor na barra lateral.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ])));
    }

    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2));

    if (_parcelas.isEmpty) return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.event_note_rounded, color: AppTheme.textMuted, size: 56),
      SizedBox(height: 16),
      Text('Nenhuma parcela cadastrada', style: TextStyle(color: AppTheme.textSecondary)),
      SizedBox(height: 4),
      Text('Configure o modelo na aba anterior', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
    ]));

    final pendentes = _parcelas.where((p) => p['status'] == 'pendente').length;
    final pagas = _parcelas.where((p) => p['status'] == 'pago').length;
    final atrasadas = _parcelas.where((p) => p['status'] == 'pendente' &&
      DateTime.parse(p['data_vencimento'] as String).isBefore(DateTime.now())).length;

    return RefreshIndicator(onRefresh: _carregar, color: AppTheme.gold,
      child: CustomScrollView(slivers: [
        SliverPadding(padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(child: Row(children: [
            Expanded(child: _ParcelaStat('Pendentes', '$pendentes', AppTheme.warning)),
            const SizedBox(width: 10),
            Expanded(child: _ParcelaStat('Pagas', '$pagas', AppTheme.success)),
            const SizedBox(width: 10),
            Expanded(child: _ParcelaStat('Atrasadas', '$atrasadas', AppTheme.error)),
          ]))),
        SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverList(delegate: SliverChildBuilderDelegate(
            (_, i) {
              final p = _parcelas[i];
              final venc = DateTime.tryParse(p['data_vencimento'] as String? ?? '');
              final agora = DateTime.now();
              final atrasada = p['status'] == 'pendente' && venc != null && venc.isBefore(agora);
              final cor = p['status'] == 'pago' ? AppTheme.success
                : atrasada ? AppTheme.error : AppTheme.textSecondary;

              return Padding(padding: const EdgeInsets.only(bottom: 8),
                child: GDCard(onTap: () => _marcarPago(p, p['status'] != 'pago'),
                  child: Row(children: [
                    Container(width: 44, height: 44,
                      decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(
                        p['status'] == 'pago' ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                        color: cor, size: 22)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Parcela ${i + 1}', style: const TextStyle(
                        color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                      Row(children: [
                        Text('Venc: ${venc?.toString().substring(0, 10) ?? ''}',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                        const SizedBox(width: 8),
                        if (atrasada)
                          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                            child: const Text('ATRASADA', style: TextStyle(color: AppTheme.error, fontSize: 8, fontWeight: FontWeight.w700))),
                      ]),
                    ])),
                    Text(_fmt((p['valor'] as num?)?.toDouble() ?? 0),
                      style: TextStyle(color: cor, fontWeight: FontWeight.w700, fontSize: 13)),
                  ])).animate(delay: Duration(milliseconds: i * 40)).fadeIn());
            }, childCount: _parcelas.length,
          ))),
        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ]),
    );
  }
}

class _ParcelaStat extends StatelessWidget {
  final String label, valor;
  final Color cor;
  const _ParcelaStat(this.label, this.valor, this.cor);

  @override
  Widget build(BuildContext context) {
    return GDCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(valor, style: TextStyle(color: cor, fontWeight: FontWeight.w800, fontSize: 22)),
    ]));
  }
}

// ─────────────────────────────────────────────────────────────
// ABA: VISÃO CLIENTE (o que o cliente vê/controla)
// ─────────────────────────────────────────────────────────────

class _VisaoClienteTab extends StatefulWidget {
  final SupabaseClient supa;
  final ObraContext ctx;
  const _VisaoClienteTab({required this.supa, required this.ctx});
  @override
  State<_VisaoClienteTab> createState() => _VisaoClienteTabState();
}

class _VisaoClienteTabState extends State<_VisaoClienteTab> {
  Map<String, dynamic>? _financiamento;
  List<Map<String, dynamic>> _parcelas = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _carregar(); }

  Future<void> _carregar() async {
    if (widget.ctx.obraId == null) { setState(() => _loading = false); return; }
    try {
      final fin = await widget.supa.schema('grupo_dantas').from('financiamentos')
          .select().eq('obra_id', widget.ctx.obraId!).maybeSingle();
      final parc = await widget.supa.schema('grupo_dantas').from('financiamento_parcelas')
          .select().eq('obra_id', widget.ctx.obraId!).order('data_vencimento', ascending: true);
      setState(() {
        _financiamento = fin;
        _parcelas = List<Map<String, dynamic>>.from(parc);
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2));

    if (_financiamento == null || _parcelas.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.visibility_off_rounded, color: AppTheme.textMuted, size: 56),
        SizedBox(height: 16),
        Text('Sem informações de financiamento', style: TextStyle(color: AppTheme.textSecondary)),
        SizedBox(height: 4),
        Text('Configure na aba "Modelo Financeiro"', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      ]));
    }

    final totalVGV = _parcelas.fold(0.0, (s, p) => s + ((p['valor'] as num?)?.toDouble() ?? 0));
    final pago = _parcelas
        .where((p) => p['status'] == 'pago')
        .fold(0.0, (s, p) => s + ((p['valor'] as num?)?.toDouble() ?? 0));
    final pct = totalVGV > 0 ? (pago / totalVGV * 100) : 0;

    return ListView(padding: const EdgeInsets.all(20), children: [
      GDCard(gradient: AppTheme.cardGradient,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Seu Investimento', style: TextStyle(
            color: AppTheme.gold, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 12),
          _clientRow('Banco', _financiamento!['banco'] ?? '—'),
          _clientRow('Modelo', (_financiamento!['modelo'] as String? ?? '').replaceAll('_', ' ').toUpperCase()),
          if (_financiamento!['taxa_juros'] != null)
            _clientRow('Taxa', '${_financiamento!['taxa_juros']}% a.a.'),
          _clientRow('Total investido', _fmt(totalVGV)),
          _clientRow('Já pago', _fmt(pago)),
          const Divider(color: AppTheme.cardBorder),
          _clientRow('Faltam', _fmt(totalVGV - pago), bold: true),
        ])),
      const SizedBox(height: 16),

      Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppTheme.gold.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.gold.withOpacity(0.2))),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Progresso de Pagamento', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: pct / 100,
              backgroundColor: AppTheme.cardBorder,
              valueColor: const AlwaysStoppedAnimation(AppTheme.gold), minHeight: 8)),
        ])),
      const SizedBox(height: 20),

      const Text('Cronograma de Pagamentos', style: TextStyle(
        color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
      const SizedBox(height: 12),

      ..._parcelas.asMap().entries.map((e) {
        final i = e.key;
        final p = e.value;
        final venc = DateTime.tryParse(p['data_vencimento'] as String? ?? '');
        final pago = p['status'] == 'pago';
        return Padding(padding: const EdgeInsets.only(bottom: 8),
          child: GDCard(child: Row(children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(
                color: pago ? AppTheme.success.withOpacity(0.1) : AppTheme.gold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(pago ? Icons.check_rounded : Icons.pending_actions_rounded,
                color: pago ? AppTheme.success : AppTheme.gold, size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Parcela ${i + 1} ${pago ? '✓' : ''}',
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600,
                  decoration: pago ? TextDecoration.lineThrough : null)),
              Text('${venc?.toString().substring(0, 10) ?? ''}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ])),
            Text(_fmt((p['valor'] as num?)?.toDouble() ?? 0),
              style: TextStyle(color: pago ? AppTheme.success : AppTheme.gold, fontWeight: FontWeight.w700)),
          ])).animate(delay: Duration(milliseconds: i * 40)).fadeIn());
      }),
      const SizedBox(height: 40),
    ]);
  }

  Widget _clientRow(String l, String v, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      Text(v, style: TextStyle(color: AppTheme.textPrimary, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, fontSize: 13)),
    ]));
}
