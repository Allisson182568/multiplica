import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'gd_card.dart';
import 'obra_context.dart';

class RhImpostosScreen extends StatefulWidget {
  const RhImpostosScreen({super.key});
  @override
  State<RhImpostosScreen> createState() => _RhImpostosScreenState();
}

class _RhImpostosScreenState extends State<RhImpostosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _supa = Supabase.instance.client;
  final _ctx = ObraContext();

  @override
  void initState() { super.initState(); _tabs = TabController(length: 4, vsync: this); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (b) => AppTheme.goldGradient.createShader(b),
          child: const Text('RH & Impostos',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
        bottom: TabBar(controller: _tabs, isScrollable: true, tabAlignment: TabAlignment.start,
          labelColor: AppTheme.gold, unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.gold, dividerColor: AppTheme.cardBorder,
          tabs: const [
            Tab(text: 'Histórico Despesas'),
            Tab(text: 'Cálculo CNPJ'),
            Tab(text: 'Encargos CLT'),
            Tab(text: 'Retenções'),
          ]),
      ),
      body: TabBarView(controller: _tabs, children: [
        _HistoricoDespesasTab(supa: _supa, ctx: _ctx),
        _CalculoCNPJTab(),
        _EncargosTab(),
        _RetencesesTab(),
      ]),
    );
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }
}

// ─────────────────────────────────────────────────────────────
// ABA: HISTÓRICO DE DESPESAS (para contador)
// ─────────────────────────────────────────────────────────────

class _HistoricoDespesasTab extends StatefulWidget {
  final SupabaseClient supa;
  final ObraContext ctx;
  const _HistoricoDespesasTab({required this.supa, required this.ctx});
  @override
  State<_HistoricoDespesasTab> createState() => _HistoricoDespesasTabState();
}

class _HistoricoDespesasTabState extends State<_HistoricoDespesasTab> {
  List<Map<String, dynamic>> _nfs = [];
  List<Map<String, dynamic>> _materiais = [];
  List<Map<String, dynamic>> _pagamentos = [];
  bool _loading = true;
  String _filtro = 'tudo';

  @override
  void initState() { super.initState(); _carregar(); }

  Future<void> _carregar() async {
    if (widget.ctx.obraId == null) { setState(() => _loading = false); return; }

    // Notas fiscais
    final nfs = await widget.supa.schema('grupo_dantas').from('notas_fiscais')
        .select().eq('obra_id', widget.ctx.obraId!).order('data_emissao', ascending: false);
    // Materiais
    final mats = await widget.supa.schema('grupo_dantas').from('solicitacoes_material')
        .select().eq('obra_id', widget.ctx.obraId!).eq('status', 'entregue')
        .order('data_entrega_real', ascending: false);
    // Transações (pagamentos)
    final trans = await widget.supa.schema('grupo_dantas').from('transacoes')
        .select().eq('obra_id', widget.ctx.obraId!).order('data', ascending: false);

    setState(() {
      _nfs = List<Map<String, dynamic>>.from(nfs);
      _materiais = List<Map<String, dynamic>>.from(mats);
      _pagamentos = List<Map<String, dynamic>>.from(trans);
      _loading = false;
    });
  }

  Future<void> _addNF() async {
    final dataCtrl = TextEditingController();
    final cnpjCtrl = TextEditingController();
    final nfCtrl = TextEditingController();
    final descricaoCtrl = TextEditingController();
    final valorCtrl = TextEditingController();
    String tipo = 'servico';

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

            TextField(controller: dataCtrl, readOnly: true,
              onTap: () async {
                final d = await showDatePicker(context: ctx, initialDate: DateTime.now(),
                  firstDate: DateTime(2024), lastDate: DateTime.now());
                if (d != null) dataCtrl.text = d.toString().substring(0, 10);
              },
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Data emissão', prefixIcon: Icon(Icons.calendar_today_rounded))),
            const SizedBox(height: 10),

            TextField(controller: nfCtrl, keyboardType: TextInputType.number,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'NF-e / Número')),
            const SizedBox(height: 10),

            TextField(controller: cnpjCtrl, keyboardType: TextInputType.number,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'CNPJ do fornecedor')),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(value: tipo, dropdownColor: AppTheme.surface,
              decoration: const InputDecoration(labelText: 'Tipo'),
              style: const TextStyle(color: AppTheme.textPrimary),
              items: const [
                DropdownMenuItem(value: 'servico', child: Text('Serviço de Construção')),
                DropdownMenuItem(value: 'material', child: Text('Material de Construção')),
                DropdownMenuItem(value: 'equipamento', child: Text('Aluguel Equipamento')),
                DropdownMenuItem(value: 'outro', child: Text('Outro')),
              ],
              onChanged: (v) => setS(() => tipo = v!)),
            const SizedBox(height: 10),

            TextField(controller: descricaoCtrl, maxLines: 2,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Descrição do serviço/item')),
            const SizedBox(height: 10),

            TextField(controller: valorCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Valor (R\$)')),
            const SizedBox(height: 20),

            SizedBox(width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  await widget.supa.schema('grupo_dantas').from('notas_fiscais').insert({
                    'obra_id': widget.ctx.obraId,
                    'numero_nf': nfCtrl.text.trim(),
                    'cnpj_fornecedor': cnpjCtrl.text.replaceAll(RegExp(r'\D'), ''),
                    'data_emissao': dataCtrl.text,
                    'tipo': tipo,
                    'descricao': descricaoCtrl.text.trim(),
                    'valor_total': double.tryParse(valorCtrl.text.replaceAll(',', '.')) ?? 0,
                    'status': 'recebido',
                  });
                  Navigator.pop(ctx);
                  _carregar();
                },
                child: const Text('Registrar NF', style: TextStyle(fontWeight: FontWeight.w700)))),
          ]))));
  }

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    if (widget.ctx.obraId == null) {
      return const Center(child: Padding(padding: EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.monetization_on_rounded, color: AppTheme.textMuted, size: 56),
          SizedBox(height: 16),
          Text('Selecione uma obra', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('Use o seletor na barra lateral.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ])));
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNF, backgroundColor: AppTheme.gold, foregroundColor: AppTheme.background,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova NF', style: TextStyle(fontWeight: FontWeight.w700))),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2))
        : CustomScrollView(slivers: [
            SliverPadding(padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Cards resumo
                Row(children: [
                  Expanded(child: _StatCard(
                    label: 'Notas Fiscais',
                    valor: '${_nfs.length}',
                    total: _fmt(_nfs.fold(0.0, (s, n) => s + ((n['valor_total'] as num?)?.toDouble() ?? 0))),
                    icone: Icons.receipt_long_rounded, cor: AppTheme.gold)),
                  const SizedBox(width: 10),
                  Expanded(child: _StatCard(
                    label: 'Materiais',
                    valor: '${_materiais.length}',
                    total: _fmt(_materiais.fold(0.0, (s, m) => s + ((m['quantidade'] as num? ?? 0) * (m['valor_unitario'] as num? ?? 0).toDouble()))),
                    icone: Icons.inventory_rounded, cor: AppTheme.info)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _StatCard(
                    label: 'Total Despesas',
                    valor: '',
                    total: _fmt(_nfs.fold(0.0, (s, n) => s + ((n['valor_total'] as num?)?.toDouble() ?? 0)) +
                      _materiais.fold(0.0, (s, m) => s + ((m['quantidade'] as num? ?? 0) * (m['valor_unitario'] as num? ?? 0).toDouble()))),
                    icone: Icons.trending_down_rounded, cor: AppTheme.error)),
                  const SizedBox(width: 10),
                  Expanded(child: _StatCard(
                    label: 'Pagamentos',
                    valor: '${_pagamentos.length}',
                    total: _fmt(_pagamentos.fold(0.0, (s, p) => s + ((p['valor'] as num?)?.toDouble() ?? 0))),
                    icone: Icons.payment_rounded, cor: AppTheme.success)),
                ]),
                const SizedBox(height: 16),
              ])),
            ),
            if (_nfs.isEmpty)
              SliverFillRemaining(
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.receipt_long_rounded, color: AppTheme.textMuted, size: 56),
                  const SizedBox(height: 16),
                  const Text('Nenhuma nota fiscal', style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  const Text('Registre as despesas da obra aqui', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(onPressed: _addNF,
                    icon: const Icon(Icons.add_rounded), label: const Text('Primeira NF')),
                ])))
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverList(delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final nf = _nfs[i];
                    final data = nf['data_emissao'] as String?;
                    final valor = (nf['valor_total'] as num?)?.toDouble() ?? 0;
                    return Padding(padding: const EdgeInsets.only(bottom: 8),
                      child: GDCard(child: Row(children: [
                        Container(width: 44, height: 44,
                          decoration: BoxDecoration(color: AppTheme.gold.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.receipt_rounded, color: AppTheme.gold, size: 22)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(nf['descricao'] ?? nf['numero_nf'] ?? 'NF', style: const TextStyle(
                            color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('${(nf['tipo'] as String? ?? '').replaceAll('_', ' ')} · ${data ?? ''}',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                        ])),
                        Text(_fmt(valor), style: const TextStyle(
                          color: AppTheme.gold, fontWeight: FontWeight.w700, fontSize: 14)),
                      ])).animate(delay: Duration(milliseconds: i * 40)).fadeIn());
                  }, childCount: _nfs.length,
                )),
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
          ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, valor, total;
  final IconData icone;
  final Color cor;
  const _StatCard({required this.label, required this.valor, required this.total, required this.icone, required this.cor});

  @override
  Widget build(BuildContext context) {
    return GDCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
        Container(width: 28, height: 28, decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icone, color: cor, size: 14)),
      ]),
      const SizedBox(height: 8),
      if (valor.isNotEmpty) Text(valor, style: TextStyle(color: cor, fontWeight: FontWeight.w800, fontSize: 20)),
      Text(total, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
    ]));
  }
}

// ─────────────────────────────────────────────────────────────
// ABA: CÁLCULO CNPJ
// ─────────────────────────────────────────────────────────────

class _CalculoCNPJTab extends StatefulWidget {
  @override
  State<_CalculoCNPJTab> createState() => _CalculoCNPJTabState();
}

class _CalculoCNPJTabState extends State<_CalculoCNPJTab> {
  final _cnpjCtrl = TextEditingController();
  final _faturamentoCtrl = TextEditingController(text: '1000000');
  final _custosCtrl = TextEditingController(text: '600000');
  final _impostosMunicipaisCtrl = TextEditingController(text: '60000');

  double _issDevido = 0, _ir = 0, _csll = 0, _pis = 0, _cofins = 0, _totalImpostos = 0;
  bool _calculado = false;

  void _calcular() {
    final faturamento = double.tryParse(_faturamentoCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
    final custos = double.tryParse(_custosCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
    final impostosMun = double.tryParse(_impostosMunicipaisCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;

    final lucro = faturamento - custos - impostosMun;
    _issDevido = impostosMun;
    _ir = (lucro * 0.25).clamp(0, double.infinity);
    _csll = (lucro * 0.09).clamp(0, double.infinity);
    _pis = faturamento * 0.0165;
    _cofins = faturamento * 0.076;
    _totalImpostos = _issDevido + _ir + _csll + _pis + _cofins;

    setState(() => _calculado = true);
  }

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Cálculo de Impostos para Empresa Construtora',
        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
      const SizedBox(height: 4),
      const Text('Base: Lucro Real + Estimativa de Retenções',
        style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      const SizedBox(height: 16),

      TextField(controller: _cnpjCtrl, keyboardType: TextInputType.number,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: const InputDecoration(labelText: 'CNPJ da construtora', prefixIcon: Icon(Icons.business_rounded))),
      const SizedBox(height: 14),

      TextField(controller: _faturamentoCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: const InputDecoration(labelText: 'Faturamento anual (R\$)')),
      const SizedBox(height: 10),

      TextField(controller: _custosCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: const InputDecoration(labelText: 'Custos dedutiveis (R\$)')),
      const SizedBox(height: 10),

      TextField(controller: _impostosMunicipaisCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: const InputDecoration(labelText: 'ISS municipal (R\$)')),
      const SizedBox(height: 20),

      SizedBox(width: double.infinity, height: 48,
        child: ElevatedButton.icon(onPressed: _calcular,
          icon: const Icon(Icons.calculate_rounded),
          label: const Text('CALCULAR IMPOSTOS', style: TextStyle(fontWeight: FontWeight.w700)))),

      if (_calculado) ...[
        const SizedBox(height: 24),
        GDCard(gradient: AppTheme.cardGradient,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Resumo de Impostos', style: TextStyle(
              color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 12),
            _impRow('ISS Municipal', _issDevido),
            _impRow('Imposto de Renda (25%)', _ir),
            _impRow('CSLL (9%)', _csll),
            _impRow('PIS (1,65%)', _pis),
            _impRow('COFINS (7,6%)', _cofins),
            const Divider(color: AppTheme.cardBorder),
            _impRow('TOTAL IMPOSTOS', _totalImpostos, bold: true),
          ])),
      ],
    ]);
  }

  Widget _impRow(String l, double v, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: TextStyle(color: AppTheme.textSecondary, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      Text(_fmt(v), style: TextStyle(color: bold ? AppTheme.error : AppTheme.textPrimary, fontWeight: FontWeight.w700)),
    ]));
}

// ─────────────────────────────────────────────────────────────
// ABA: ENCARGOS CLT
// ─────────────────────────────────────────────────────────────

class _EncargosTab extends StatefulWidget {
  @override
  State<_EncargosTab> createState() => _EncargosTabState();
}

class _EncargosTabState extends State<_EncargosTab> {
  final _folhaCtrl = TextEditingController(text: '50000');
  String _regime = 'clt';
  double _totalEncargos = 0;
  bool _calculado = false;

  void _calcular() {
    final folha = double.tryParse(_folhaCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
    if (_regime == 'clt') {
      _totalEncargos = folha * 0.50; // ~50% de encargos
    } else if (_regime == 'mei') {
      _totalEncargos = folha * 0.11; // ~11% para MEI
    } else {
      _totalEncargos = 0;
    }
    setState(() => _calculado = true);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Cálculo de Encargos Sociais',
        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
      const SizedBox(height: 16),

      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'clt', label: Text('CLT')),
          ButtonSegment(value: 'mei', label: Text('MEI')),
          ButtonSegment(value: 'pj', label: Text('PJ (sem encargos)')),
        ],
        selected: {_regime},
        onSelectionChanged: (s) => setState(() => _regime = s.first),
      ),
      const SizedBox(height: 16),

      TextField(controller: _folhaCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: const InputDecoration(labelText: 'Folha mensal (R\$)')),
      const SizedBox(height: 20),

      SizedBox(width: double.infinity, height: 48,
        child: ElevatedButton.icon(onPressed: _calcular,
          icon: const Icon(Icons.calculate_rounded),
          label: const Text('CALCULAR ENCARGOS', style: TextStyle(fontWeight: FontWeight.w700)))),

      if (_calculado) ...[
        const SizedBox(height: 24),
        GDCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Encargos ${_regime.toUpperCase()}',
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 16),
          _encRow('Folha Mensal', double.tryParse(_folhaCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0),
          const Divider(color: AppTheme.cardBorder),
          if (_regime == 'clt') ...[
            _encRow('INSS Patronal (20%)', (double.tryParse(_folhaCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0) * 0.20),
            _encRow('RAT (3%)', (double.tryParse(_folhaCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0) * 0.03),
            _encRow('FGTS (8%)', (double.tryParse(_folhaCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0) * 0.08),
            _encRow('Férias / 13º / Encargos (~19%)', (double.tryParse(_folhaCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0) * 0.19),
          ] else if (_regime == 'mei')
            _encRow('Contribuição Mensal (~11%)', _totalEncargos),
          const Divider(color: AppTheme.gold),
          _encRow('TOTAL ENCARGOS', _totalEncargos, bold: true),
        ])),
      ],
    ]);
  }

  Widget _encRow(String l, double v, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: TextStyle(color: AppTheme.textSecondary, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      Text('R\$ ${v.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
        style: TextStyle(color: bold ? AppTheme.error : AppTheme.textPrimary, fontWeight: FontWeight.w700)),
    ]));
}

// ─────────────────────────────────────────────────────────────
// ABA: RETENÇÕES (PJ / Serviços)
// ─────────────────────────────────────────────────────────────

class _RetencesesTab extends StatefulWidget {
  @override
  State<_RetencesesTab> createState() => _RetencesesTabState();
}

class _RetencesesTabState extends State<_RetencesesTab> {
  final _servicoCtrl = TextEditingController(text: '10000');
  String _tipo = 'pj_construcao';
  double _issRetido = 0, _inssRetido = 0, _irRetido = 0, _totalRetido = 0;
  bool _calculado = false;

  void _calcular() {
    final valor = double.tryParse(_servicoCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
    if (_tipo == 'pj_construcao') {
      _issRetido = valor * 0.05;
      _inssRetido = valor * 0.11;
      _irRetido = valor * 0.015;
    } else if (_tipo == 'empreiteiro') {
      _issRetido = valor * 0.05;
      _inssRetido = valor * 0.11;
      _irRetido = 0;
    } else if (_tipo == 'profissional_autonomo') {
      _issRetido = valor * 0.05;
      _inssRetido = valor * 0.11;
      _irRetido = valor * 0.015;
    }
    _totalRetido = _issRetido + _inssRetido + _irRetido;
    setState(() => _calculado = true);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Retenções na Fonte (PJ / Autônomos)',
        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
      const SizedBox(height: 16),

      DropdownButtonFormField<String>(value: _tipo, dropdownColor: AppTheme.surface,
        decoration: const InputDecoration(labelText: 'Tipo de contratação'),
        style: const TextStyle(color: AppTheme.textPrimary),
        items: const [
          DropdownMenuItem(value: 'pj_construcao', child: Text('PJ Construção')),
          DropdownMenuItem(value: 'empreiteiro', child: Text('Empreiteiro')),
          DropdownMenuItem(value: 'profissional_autonomo', child: Text('Profissional Autônomo')),
        ],
        onChanged: (v) => setState(() => _tipo = v!)),
      const SizedBox(height: 14),

      TextField(controller: _servicoCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: const InputDecoration(labelText: 'Valor do serviço (R\$)')),
      const SizedBox(height: 20),

      SizedBox(width: double.infinity, height: 48,
        child: ElevatedButton.icon(onPressed: _calcular,
          icon: const Icon(Icons.calculate_rounded),
          label: const Text('CALCULAR RETENÇÕES', style: TextStyle(fontWeight: FontWeight.w700)))),

      if (_calculado) ...[
        const SizedBox(height: 24),
        GDCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Retenções da Fonte', style: TextStyle(
            color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 12),
          _retRow('ISS (5%)', _issRetido),
          _retRow('INSS (11%)', _inssRetido),
          if (_irRetido > 0) _retRow('IR (1,5%)', _irRetido),
          const Divider(color: AppTheme.gold),
          _retRow('TOTAL RETIDO', _totalRetido, bold: true),
          const SizedBox(height: 12),
          _retRow('LÍQUIDO A PAGAR', (double.tryParse(_servicoCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0) - _totalRetido, bold: true),
        ])),
      ],
    ]);
  }

  Widget _retRow(String l, double v, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: TextStyle(color: AppTheme.textSecondary, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      Text('R\$ ${v.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
        style: TextStyle(color: bold ? AppTheme.error : AppTheme.textPrimary, fontWeight: FontWeight.w700)),
    ]));
}
