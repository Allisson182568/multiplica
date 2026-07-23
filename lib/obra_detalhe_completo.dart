import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'gd_card.dart';
import 'obra_abas.dart';

// ─────────────────────────────────────────────────────────────
// TELA PRINCIPAL DE DETALHE DA OBRA
// ─────────────────────────────────────────────────────────────

class ObraDetalheCompleto extends StatefulWidget {
  final String obraId;
  const ObraDetalheCompleto({super.key, required this.obraId});
  @override
  State<ObraDetalheCompleto> createState() => _ObraDetalheCompletoState();
}

class _ObraDetalheCompletoState extends State<ObraDetalheCompleto>
    with TickerProviderStateMixin {
  late TabController _tabs;
  final _supa = Supabase.instance.client;

  Map<String, dynamic>? _obra;
  Map<String, dynamic>? _usuario;
  bool _loading = true;

  List<_TabDef> get _tabsDef {
    final role = _usuario?['role'] as String? ?? 'cliente';
    if (role == 'cliente') {
      return [
        const _TabDef('Andamento', Icons.timeline_rounded),
        const _TabDef('Documentos', Icons.folder_rounded),
      ];
    }
    if (role == 'outro') {
      return [
        const _TabDef('Etapas',    Icons.format_list_numbered_rounded),
        const _TabDef('Diário',    Icons.menu_book_rounded),
        const _TabDef('Materiais', Icons.inventory_2_rounded),
      ];
    }
    return [
      const _TabDef('Visão Geral', Icons.dashboard_rounded),
      const _TabDef('Etapas',      Icons.format_list_numbered_rounded),
      const _TabDef('Documentos',  Icons.gavel_rounded),
      const _TabDef('Diário',      Icons.menu_book_rounded),
      const _TabDef('Materiais',   Icons.inventory_2_rounded),
      const _TabDef('Financeiro',  Icons.account_balance_wallet_rounded),
      const _TabDef('NFs',         Icons.receipt_long_rounded),
      const _TabDef('Alertas',     Icons.warning_rounded),
      const _TabDef('Equipe',      Icons.people_rounded),
    ];
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 1, vsync: this);
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final uid = _supa.auth.currentUser?.id;
      final u = await _supa.schema('grupo_dantas').from('usuarios')
          .select().eq('auth_id', uid!).maybeSingle();
      final o = await _supa.schema('grupo_dantas').from('obras')
          .select().eq('id', widget.obraId).single();
      setState(() {
        _usuario = u;
        _obra = o;
        _loading = false;
        _tabs = TabController(length: _tabsDef.length, vsync: this);
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          backgroundColor: AppTheme.background,
          body: Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2)));
    }
    if (_obra == null) {
      return const Scaffold(
          backgroundColor: AppTheme.background,
          body: Center(child: Text('Obra não encontrada',
              style: TextStyle(color: AppTheme.textSecondary))));
    }

    final obra = _obra!;
    final role = _usuario?['role'] as String? ?? 'cliente';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          _buildAppBar(obra),
          _buildTabBar(),
        ],
        body: TabBarView(
          controller: _tabs,
          children: _tabsDef.map((t) => _buildTab(t.label, obra, role)).toList(),
        ),
      ),
    );
  }

  Widget _buildTab(String label, Map obra, String role) {
    switch (label) {
      case 'Visão Geral':  return TabVisaoGeral(obra: obra, supa: _supa);
      case 'Andamento':    return TabAndamentoCliente(obra: obra, supa: _supa);
      case 'Etapas':       return TabEtapasImpl(obraId: widget.obraId, supa: _supa, role: role);
      case 'Documentos':   return TabDocumentosImpl(obraId: widget.obraId, supa: _supa, role: role);
      case 'Diário':       return TabDiarioImpl(obraId: widget.obraId, supa: _supa, role: role);
      case 'Materiais':    return TabMateriaisImpl(obraId: widget.obraId, supa: _supa, role: role);
      case 'Financeiro':   return TabFinanceiroImpl(obraId: widget.obraId, supa: _supa);
      case 'NFs':          return TabNotasFiscaisImpl(obraId: widget.obraId, supa: _supa);
      case 'Alertas':      return TabAlertasImpl(obraId: widget.obraId, supa: _supa);
      case 'Equipe':       return TabEquipeImpl(obraId: widget.obraId, supa: _supa);
      default:             return const SizedBox.shrink();
    }
  }

  SliverAppBar _buildAppBar(Map obra) {
    final status = obra['status'] as String? ?? 'planejamento';
    final prog   = (obra['progresso_percentual'] as num?)?.toDouble() ?? 0;
    final color  = AppTheme.statusColor(status);

    return SliverAppBar(
        expandedHeight: 220,
        pinned: true,
        backgroundColor: AppTheme.background,
        leading: IconButton(
            icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.cardBorder)),
                child: const Icon(Icons.arrow_back_rounded, size: 18)),
            onPressed: () => context.pop()),
        flexibleSpace: FlexibleSpaceBar(
            background: Stack(fit: StackFit.expand, children: [
              Container(decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF1A1408), Color(0xFF0D0D0D)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight))),
              const DecoratedBox(decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Colors.transparent, AppTheme.background],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      stops: [0.3, 1.0]))),
              Positioned(bottom: 20, left: 20, right: 20,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 6, children: [
                      _badge(AppTheme.statusLabel(status), color),
                      _badge(_tipoLabel(obra['tipo'] ?? ''), AppTheme.info),
                    ]),
                    const SizedBox(height: 8),
                    Text(obra['nome'] ?? '', style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
                    if (obra['endereco'] != null) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(obra['endereco'], style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                      ]),
                    ],
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                              value: prog / 100,
                              backgroundColor: AppTheme.cardBorder,
                              valueColor: AlwaysStoppedAnimation(color),
                              minHeight: 6))),
                      const SizedBox(width: 10),
                      Text('${prog.toInt()}%', style: TextStyle(
                          color: color, fontWeight: FontWeight.w700)),
                    ]),
                  ])),
            ])));
  }

  SliverPersistentHeader _buildTabBar() {
    return SliverPersistentHeader(
        pinned: true,
        delegate: _TabDelegate(TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppTheme.gold,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.gold,
            indicatorWeight: 2,
            dividerColor: AppTheme.cardBorder,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            tabs: _tabsDef.map((t) => Tab(
                height: 44,
                child: Row(children: [
                  Icon(t.icon, size: 15),
                  const SizedBox(width: 5),
                  Text(t.label, style: const TextStyle(fontSize: 12)),
                ]))).toList()), height: 50));
  }

  Widget _badge(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4))),
      child: Text(label, style: TextStyle(
          color: color, fontSize: 11, fontWeight: FontWeight.w600)));

  String _tipoLabel(String t) {
    const m = {'residencial':'Residencial','galpao':'Galpão',
      'condominio':'Condomínio','comercial':'Comercial'};
    return m[t] ?? t;
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }
}

// ─────────────────────────────────────────────────────────────
// ABA: VISÃO GERAL
// ─────────────────────────────────────────────────────────────

class TabVisaoGeral extends StatelessWidget {
  final Map obra;
  final SupabaseClient supa;
  const TabVisaoGeral({super.key, required this.obra, required this.supa});

  @override
  Widget build(BuildContext context) {
    final prog      = (obra['progresso_percentual'] as num?)?.toDouble() ?? 0;
    final orcamento = (obra['orcamento_total'] as num?)?.toDouble() ?? 0;
    final realizado = (obra['custo_realizado'] as num?)?.toDouble() ?? 0;
    final saldo     = orcamento - realizado;
    final varPct    = orcamento > 0 ? ((realizado / orcamento) * 100) : 0.0;

    return ListView(padding: const EdgeInsets.all(16), children: [
      // Progresso
      GDCard(child: Row(children: [
        SizedBox(width: 80, height: 80, child: Stack(fit: StackFit.expand, children: [
          CircularProgressIndicator(
              value: prog / 100,
              backgroundColor: AppTheme.cardBorder,
              valueColor: const AlwaysStoppedAnimation(AppTheme.gold),
              strokeWidth: 8),
          Center(child: Text('${prog.toInt()}%', style: const TextStyle(
              color: AppTheme.gold, fontWeight: FontWeight.w800, fontSize: 16))),
        ])),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(obra['nome'] ?? '', style: const TextStyle(
              color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          _infoRow('Início:',   _fmtData(obra['data_inicio'])),
          _infoRow('Previsão:', _fmtData(obra['data_previsao_fim'])),
          _diasRestantes(obra['data_previsao_fim']),
        ])),
      ])).animate().fadeIn(),
      const SizedBox(height: 12),

      // Financeiro
      GDCard(gradient: AppTheme.cardGradient,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.account_balance_wallet_rounded, color: AppTheme.gold, size: 18),
              SizedBox(width: 8),
              Text('Financeiro', style: TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
            const SizedBox(height: 12),
            _finRow('Orçamento total', _fmt(orcamento), AppTheme.textPrimary),
            _finRow('Realizado',       _fmt(realizado), AppTheme.gold),
            _finRow('Saldo disponível', _fmt(saldo),
                saldo >= 0 ? AppTheme.success : AppTheme.error),
            const SizedBox(height: 10),
            ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                    value: (varPct / 100).clamp(0.0, 1.0),
                    backgroundColor: AppTheme.cardBorder,
                    valueColor: AlwaysStoppedAnimation(
                        varPct > 90 ? AppTheme.error
                            : varPct > 70 ? AppTheme.warning : AppTheme.success),
                    minHeight: 6)),
            const SizedBox(height: 4),
            Text('${varPct.toStringAsFixed(1)}% do orçamento utilizado',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ])).animate(delay: 100.ms).fadeIn(),
      const SizedBox(height: 12),

      // Alertas resumo
      AlertasResumo(obraId: obra['id'], supa: supa),
    ]);
  }

  Widget _infoRow(String l, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        Text(l, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        const SizedBox(width: 4),
        Text(v, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11,
            fontWeight: FontWeight.w600)),
      ]));

  Widget _diasRestantes(dynamic dataStr) {
    if (dataStr == null) return const SizedBox.shrink();
    try {
      final data = DateTime.parse(dataStr.toString());
      final dias = data.difference(DateTime.now()).inDays;
      final cor = dias < 0 ? AppTheme.error : dias < 30 ? AppTheme.warning : AppTheme.success;
      final txt = dias < 0 ? '${dias.abs()} dias atrasada!' : '$dias dias restantes';
      return Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
          child: Text(txt, style: TextStyle(color: cor, fontSize: 11, fontWeight: FontWeight.w700)));
    } catch (_) { return const SizedBox.shrink(); }
  }

  Widget _finRow(String l, String v, Color cor) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        Text(v, style: TextStyle(color: cor, fontWeight: FontWeight.w700, fontSize: 13)),
      ]));

  static String _fmtData(dynamic d) {
    if (d == null) return '—';
    try {
      final dt = DateTime.parse(d.toString());
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    } catch (_) { return d.toString(); }
  }

  static String _fmt(double v) {
    final s = v.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return 'R\$ $s';
  }
}

// ─────────────────────────────────────────────────────────────
// ABA: ANDAMENTO CLIENTE
// ─────────────────────────────────────────────────────────────

class TabAndamentoCliente extends StatefulWidget {
  final Map obra;
  final SupabaseClient supa;
  const TabAndamentoCliente({super.key, required this.obra, required this.supa});
  @override State<TabAndamentoCliente> createState() => _TabAndamentoClienteState();
}

class _TabAndamentoClienteState extends State<TabAndamentoCliente> {
  List<Map<String, dynamic>> _etapas = [];

  @override
  void initState() { super.initState(); _carregar(); }

  Future<void> _carregar() async {
    final data = await widget.supa.schema('grupo_dantas').from('etapas')
        .select().eq('obra_id', widget.obra['id']).order('ordem');
    setState(() => _etapas = List<Map<String, dynamic>>.from(data));
  }

  @override
  Widget build(BuildContext context) {
    final prog    = (widget.obra['progresso_percentual'] as num?)?.toDouble() ?? 0;
    final dataFim = widget.obra['data_previsao_fim'] as String?;
    String prazoMsg = '';
    Color prazoColor = AppTheme.success;
    if (dataFim != null) {
      try {
        final dt = DateTime.parse(dataFim);
        final dias = dt.difference(DateTime.now()).inDays;
        if (dias < 0)     { prazoMsg = 'Atrasada ${dias.abs()} dias'; prazoColor = AppTheme.error; }
        else if (dias == 0) { prazoMsg = 'Entrega prevista hoje!';     prazoColor = AppTheme.warning; }
        else              { prazoMsg = 'Previsão: $dias dias';         prazoColor = AppTheme.success; }
      } catch (_) {}
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              gradient: AppTheme.cardGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.gold.withOpacity(0.2))),
          child: Column(children: [
            const Text('Sua obra está', style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            Text('${prog.toInt()}% concluída', style: const TextStyle(
                color: AppTheme.gold, fontSize: 32, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                    value: prog / 100,
                    backgroundColor: AppTheme.cardBorder,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.gold),
                    minHeight: 10)),
            if (prazoMsg.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(prazoMsg, style: TextStyle(
                  color: prazoColor, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ])).animate().fadeIn(),
      const SizedBox(height: 20),

      const Text('Etapas', style: TextStyle(
          color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
      const SizedBox(height: 12),

      ..._etapas.asMap().entries.map((e) {
        final i = e.key;
        final et = e.value;
        final status = et['status'] as String? ?? 'nao_iniciada';
        final p = (et['progresso_percentual'] as num?)?.toDouble() ?? 0;
        final cor = AppTheme.statusColor(status);

        return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: status == 'em_andamento'
                        ? AppTheme.gold.withOpacity(0.4) : AppTheme.cardBorder)),
                child: Row(children: [
                  Container(width: 32, height: 32,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          color: cor.withOpacity(0.15), border: Border.all(color: cor, width: 2)),
                      child: Center(child: status == 'concluida'
                          ? Icon(Icons.check_rounded, color: cor, size: 16)
                          : Text('${i+1}', style: TextStyle(color: cor, fontSize: 11,
                          fontWeight: FontWeight.w700)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(et['nome'] ?? '', style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                    if (p > 0) ...[
                      const SizedBox(height: 6),
                      ClipRRect(borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                              value: p / 100,
                              backgroundColor: AppTheme.cardBorder,
                              valueColor: AlwaysStoppedAnimation(cor),
                              minHeight: 4)),
                    ],
                  ])),
                  const SizedBox(width: 8),
                  Text('${p.toInt()}%', style: TextStyle(
                      color: cor, fontSize: 11, fontWeight: FontWeight.w700)),
                ])).animate(delay: Duration(milliseconds: i * 50)).fadeIn());
      }),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// WIDGET: ALERTAS RESUMO
// ─────────────────────────────────────────────────────────────

class AlertasResumo extends StatefulWidget {
  final String obraId;
  final SupabaseClient supa;
  const AlertasResumo({super.key, required this.obraId, required this.supa});
  @override State<AlertasResumo> createState() => _AlertasResumoState();
}

class _AlertasResumoState extends State<AlertasResumo> {
  List<Map<String, dynamic>> _alertas = [];

  @override
  void initState() { super.initState(); _carregar(); }

  Future<void> _carregar() async {
    try {
      final data = await widget.supa.schema('grupo_dantas').from('alertas')
          .select().eq('obra_id', widget.obraId).eq('resolvido', false)
          .order('severidade').limit(5);
      setState(() => _alertas = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_alertas.isEmpty) {
      return GDCard(child: const Row(children: [
        Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 20),
        SizedBox(width: 10),
        Text('Nenhum alerta ativo', style: TextStyle(
            color: AppTheme.success, fontWeight: FontWeight.w600, fontSize: 13)),
      ])).animate().fadeIn();
    }
    return GDCard(gradient: AppTheme.cardGradient,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.warning_rounded, color: AppTheme.warning, size: 18),
            const SizedBox(width: 8),
            Text('${_alertas.length} alerta${_alertas.length > 1 ? 's' : ''} ativo${_alertas.length > 1 ? 's' : ''}',
                style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
          const SizedBox(height: 10),
          ..._alertas.map((a) {
            final sev = a['severidade'] as String? ?? 'warning';
            final cor = sev == 'critical' ? AppTheme.error : AppTheme.warning;
            return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(sev == 'critical' ? Icons.error_rounded : Icons.warning_amber_rounded,
                      color: cor, size: 14),
                  const SizedBox(width: 6),
                  Expanded(child: Text(a['titulo'] ?? '', style: TextStyle(color: cor, fontSize: 12))),
                ]));
          }),
        ])).animate(delay: 200.ms).fadeIn();
  }
}

// ─────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────

class _TabDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final double height;
  const _TabDelegate(this.tabBar, {this.height = 50});
  @override double get minExtent => height;
  @override double get maxExtent => height;
  @override Widget build(_, __, ___) => Container(
      color: AppTheme.background, height: height, child: tabBar);
  @override bool shouldRebuild(_TabDelegate old) => false;
}

class _TabDef {
  final String label;
  final IconData icon;
  const _TabDef(this.label, this.icon);
}


// ─────────────────────────────────────────────────────────────
// VERSÃO 2 DO DETALHE — usa as implementações reais do obra_abas.dart
// Substituir os stubs acima pelos imports abaixo após integrar obra_abas.dart
// ─────────────────────────────────────────────────────────────
//
// No buildTab(), trocar cada stub pela implementação real:
//
//   'Etapas'     → TabEtapasImpl(obraId: obraId, supa: supa, role: role)
//   'Documentos' → TabDocumentosImpl(obraId: obraId, supa: supa, role: role)
//   'Diário'     → TabDiarioImpl(obraId: obraId, supa: supa, role: role)
//   'Materiais'  → TabMateriaisImpl(obraId: obraId, supa: supa, role: role)
//   'Financeiro' → TabFinanceiroImpl(obraId: obraId, supa: supa)
//   'NFs'        → TabNotasFiscaisImpl(obraId: obraId, supa: supa)
//   'Alertas'    → TabAlertasImpl(obraId: obraId, supa: supa)
//   'Equipe'     → TabEquipeImpl(obraId: obraId, supa: supa)