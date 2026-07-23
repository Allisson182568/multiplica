// ============================================================
// MULTIPLIKA — Módulo PCI Caixa v2.0
// lib/pci_caixa_screen.dart
//
// Layout: a grade de dados (aba Auxiliar e aba PCI Oficial) é
// renderizada como uma PLANILHA DE VERDADE — fundo branco,
// linhas/colunas quadriculadas, cabeçalho cinza — emoldurada
// dentro do frame escuro do app. Isso permite copiar/colar
// direto de uma planilha Excel real sem perder a referência
// visual de onde cada valor vai.
// ============================================================

import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';

// ─────────────────────────────────────────────
// PALETA "PLANILHA" (fixa, não usa AppTheme — precisa parecer Excel)
// ─────────────────────────────────────────────

class _Sheet {
  static const Color bg          = Color(0xFFFFFFFF);
  static const Color gridLine    = Color(0xFFD4D4D4);
  static const Color gridLineHd  = Color(0xFFB0B0B0);
  static const Color headerBg    = Color(0xFFF1F3F4);
  static const Color headerBgAlt = Color(0xFFE8EAED);
  static const Color rowAlt      = Color(0xFFF8F9FA);
  static const Color colHeaderBg = Color(0xFF1C2733); // navy escuro tipo MAKAI
  static const Color colHeaderTx = Color(0xFFFFFFFF);
  static const Color textDark    = Color(0xFF1A1A1A);
  static const Color textGray    = Color(0xFF5F6368);
  static const Color cellFocus   = Color(0xFFE8F0FE);
  static const Color cellFocusBd = Color(0xFF1A73E8);
  static const Color okGreen     = Color(0xFF1E8E3E);
  static const Color okGreenBg   = Color(0xFFE6F4EA);
  static const Color warnAmber   = Color(0xFFB06000);
  static const Color warnAmberBg = Color(0xFFFEF7E0);
  static const Color errRed      = Color(0xFFC5221F);
  static const Color errRedBg    = Color(0xFFFCE8E6);
  static const Color totalBg     = Color(0xFF202124);
  static const Color totalTx     = Color(0xFFFFFFFF);
}

// ─────────────────────────────────────────────
// MODELO DE ITEM PCI
// ─────────────────────────────────────────────

class PciItem {
  final int numero;
  final String descricao;
  final double incidenciaMin;
  final double incidenciaMax;
  double valorProposto;

  PciItem({
    required this.numero,
    required this.descricao,
    required this.incidenciaMin,
    required this.incidenciaMax,
    this.valorProposto = 0,
  });
}

List<PciItem> _buildItensPCI() => [
  PciItem(numero: 1,  descricao: 'Barracão+lig. provisórias(água/luz)+projetos/aprovs.', incidenciaMin: 1.13,  incidenciaMax: 3.97),
  PciItem(numero: 2,  descricao: 'Infraestrutura (estacas, brocas, baldrames, sapatas)',  incidenciaMin: 3.07,  incidenciaMax: 7.43),
  PciItem(numero: 3,  descricao: 'Supraestrutura (Vigas, pilares, cintas, escadas)',      incidenciaMin: 12.17, incidenciaMax: 17.67),
  PciItem(numero: 4,  descricao: 'Paredes e Painéis',                                     incidenciaMin: 4.80,  incidenciaMax: 10.67),
  PciItem(numero: 5,  descricao: 'Esquadrias',                                            incidenciaMin: 4.16,  incidenciaMax: 13.27),
  PciItem(numero: 6,  descricao: 'Vidros e Plásticos',                                    incidenciaMin: 0.00,  incidenciaMax: 2.45),
  PciItem(numero: 7,  descricao: 'Coberturas (estrutura e telhas)',                       incidenciaMin: 0.00,  incidenciaMax: 12.94),
  PciItem(numero: 8,  descricao: 'Impermeabilizações',                                    incidenciaMin: 0.00,  incidenciaMax: 10.10),
  PciItem(numero: 9,  descricao: 'Revestimentos Internos',                                incidenciaMin: 6.81,  incidenciaMax: 9.32),
  PciItem(numero: 10, descricao: 'Forros',                                                incidenciaMin: 0.00,  incidenciaMax: 2.18),
  PciItem(numero: 11, descricao: 'Revestimentos Externos',                                incidenciaMin: 3.87,  incidenciaMax: 5.30),
  PciItem(numero: 12, descricao: 'Pinturas',                                              incidenciaMin: 3.63,  incidenciaMax: 6.47),
  PciItem(numero: 13, descricao: 'Pisos',                                                 incidenciaMin: 8.41,  incidenciaMax: 11.51),
  PciItem(numero: 14, descricao: 'Acabamentos (soleiras, rodapés, peitoril etc.)',        incidenciaMin: 1.01,  incidenciaMax: 1.38),
  PciItem(numero: 15, descricao: 'Instalações Elétricas e Telefônicas',                  incidenciaMin: 3.75,  incidenciaMax: 4.85),
  PciItem(numero: 16, descricao: 'Instalações Hidráulicas',                               incidenciaMin: 3.63,  incidenciaMax: 4.27),
  PciItem(numero: 17, descricao: 'Instalações: Esgoto e Águas Pluviais',                 incidenciaMin: 3.65,  incidenciaMax: 4.30),
  PciItem(numero: 18, descricao: 'Louças e Metais',                                       incidenciaMin: 4.14,  incidenciaMax: 4.87),
  PciItem(numero: 19, descricao: 'Complementos (limpeza final e calafete)',               incidenciaMin: 0.24,  incidenciaMax: 2.29),
  PciItem(numero: 20, descricao: 'Outros (discriminar em Serviços Adicionais)',           incidenciaMin: 0.00,  incidenciaMax: 10.00),
];

// ─────────────────────────────────────────────
// SCREEN PRINCIPAL
// ─────────────────────────────────────────────

class PciCaixaScreen extends StatefulWidget {
  final String? obraId;
  final String? obraDescricao;
  const PciCaixaScreen({super.key, this.obraId, this.obraDescricao});

  @override
  State<PciCaixaScreen> createState() => _PciCaixaScreenState();
}

class _PciCaixaScreenState extends State<PciCaixaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // Identificação
  final _proponenteCtrl = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _cpfCtrl        = TextEditingController();
  final _telefoneCtrl   = TextEditingController();
  final _enderecoCtrl   = TextEditingController();
  final _bairroCtrl     = TextEditingController();
  final _cepCtrl        = TextEditingController();
  final _municipioCtrl  = TextEditingController();
  final _matriculaCtrl  = TextEditingController();
  String _uf = 'SP';

  // RT
  final _rtpNomeCtrl    = TextEditingController();
  final _rtpCreaCauCtrl = TextEditingController();
  final _rtpCpfCtrl     = TextEditingController();

  // Áreas e valores
  final _areaCobertaCtrl  = TextEditingController();
  final _areaPermeaCtrl   = TextEditingController();
  final _areaTotalCtrl    = TextEditingController();
  final _areaTerrenoCtrl  = TextEditingController();
  final _valorTerrenoCtrl = TextEditingController();
  final _valorImovelCtrl  = TextEditingController();

  // Base de cálculo (cabeçalho estilo MAKAI)
  final _cubCtrl  = TextEditingController(text: '2850,00');
  final _m2Ctrl   = TextEditingController();
  final _bdiCtrl  = TextEditingController(text: '25,00');
  final _anoMesCtrl   = TextEditingController(text: 'MAI/25');
  final _estadoCtrl   = TextEditingController(text: 'SP');
  final _padraoCtrl   = TextEditingController(text: 'Normal');

  final List<PciItem> _itens = _buildItensPCI();
  final List<TextEditingController> _itemCtrl = [];
  final List<FocusNode> _itemFocus = [];

  final List<_ServicoAdicional> _adicionais =
  List.generate(6, (_) => _ServicoAdicional());

  bool _exportando = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    for (var _ in _itens) {
      _itemCtrl.add(TextEditingController());
      _itemFocus.add(FocusNode());
    }
    if (widget.obraDescricao != null) {
      _enderecoCtrl.text = widget.obraDescricao!;
    }
    for (final c in [..._itemCtrl, _cubCtrl, _m2Ctrl, _bdiCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    for (var c in _itemCtrl) c.dispose();
    for (var f in _itemFocus) f.dispose();
    super.dispose();
  }

  final _fmtR$  = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 2);
  final _fmtPct = NumberFormat('0.00', 'pt_BR');

  double _parseNum(String v) {
    if (v.trim().isEmpty) return 0;
    final clean = v.replaceAll(RegExp(r'[R\$\s]'), '')
        .replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(clean) ?? 0;
  }

  String _fR$(double v) => _fmtR$.format(v);
  String _fP(double v) => '${_fmtPct.format(v)}%';

  double get _custoObra {
    final cub = _parseNum(_cubCtrl.text);
    final m2  = _parseNum(_m2Ctrl.text);
    return cub * m2;
  }

  double get _totalServicos {
    double total = 0;
    for (final c in _itemCtrl) {
      total += _parseNum(c.text);
    }
    for (final a in _adicionais) {
      total += _parseNum(a.valorCtrl.text);
    }
    return total;
  }

  double get _bdiPct => _parseNum(_bdiCtrl.text);
  double get _bdiValor => _totalServicos * (_bdiPct / 100);
  double get _totalComBdi => _totalServicos + _bdiValor;
  double get _diferenca => _custoObra - _totalComBdi;

  double _incidenciaItem(PciItem item) {
    final total = _totalServicos;
    if (total == 0) return 0;
    return (item.valorProposto / total) * 100;
  }

  void _preencherPorCUB() {
    final custo = _custoObra;
    if (custo <= 0) return;
    final bdiFrac = _bdiPct / 100;
    final base = custo / (1 + bdiFrac);
    setState(() {
      for (var i = 0; i < _itens.length; i++) {
        final item = _itens[i];
        final pct = item.incidenciaMin == 0
            ? item.incidenciaMax * 0.5
            : (item.incidenciaMin + item.incidenciaMax) / 2;
        final val = base * (pct / 100);
        _itemCtrl[i].text = val.toStringAsFixed(2).replaceAll('.', ',');
        item.valorProposto = val;
      }
    });
  }

  Color _corStatus(PciItem item) {
    if (_totalServicos == 0) return _Sheet.textGray;
    final inc = _incidenciaItem(item);
    if (item.incidenciaMin > 0 && inc < item.incidenciaMin) return _Sheet.errRed;
    if (inc > item.incidenciaMax) return _Sheet.errRed;
    return _Sheet.okGreen;
  }

  Color _bgStatus(PciItem item) {
    if (_totalServicos == 0) return Colors.transparent;
    final inc = _incidenciaItem(item);
    if (item.incidenciaMin > 0 && inc < item.incidenciaMin) return _Sheet.errRedBg;
    if (inc > item.incidenciaMax) return _Sheet.errRedBg;
    return _Sheet.okGreenBg;
  }

  // ─────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.gold),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PCI Caixa', style: GoogleFonts.syne(
              color: AppTheme.gold, fontWeight: FontWeight.w700, fontSize: 18)),
          if (widget.obraDescricao != null)
            Text(widget.obraDescricao!, style: GoogleFonts.dmSans(
                color: AppTheme.textMuted, fontSize: 11)),
        ]),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppTheme.gold,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.gold,
          labelStyle: GoogleFonts.syne(fontWeight: FontWeight.w600, fontSize: 12),
          tabs: const [
            Tab(text: 'PLANILHA AUXILIAR'),
            Tab(text: 'PCI OFICIAL'),
            Tab(text: 'RESULTADO'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _exportando ? null : _exportarXlsx,
              icon: _exportando
                  ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold))
                  : const Icon(Icons.download_rounded, size: 16, color: AppTheme.gold),
              label: Text('Exportar .xlsx',
                  style: GoogleFonts.syne(color: AppTheme.gold, fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildAbaAuxiliar(),
          _buildAbaPciOficial(),
          _buildAbaResultado(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // FRAME "PLANILHA DENTRO DO APP"
  // borda preta do app + miolo branco quadriculado
  // ═══════════════════════════════════════════

  Widget _sheetFrame({required String titulo, required Widget child, IconData icon = Icons.grid_on_rounded}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // barra de título estilo "nome do arquivo .xlsx"
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceAlt,
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            Icon(icon, size: 14, color: AppTheme.gold),
            const SizedBox(width: 8),
            Text(titulo, style: GoogleFonts.dmSans(
                color: AppTheme.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w600)),
            const Spacer(),
            ...List.generate(3, (i) => Container(
              margin: const EdgeInsets.only(left: 5),
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: [AppTheme.error, AppTheme.warning, AppTheme.success][i].withOpacity(0.6),
                shape: BoxShape.circle,
              ),
            )),
          ]),
        ),
        Theme(
          data: ThemeData(
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: _Sheet.bg,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: _Sheet.cellFocusBd, width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              isDense: true,
            ),
            textTheme: TextTheme(
              bodyMedium: TextStyle(color: _Sheet.textDark),
            ),
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: _Sheet.bg,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ),
      ]),
    );
  }

  Widget _colLetterRow(List<String> letters, List<double> widths) {
    return Container(
      decoration: const BoxDecoration(
        color: _Sheet.headerBgAlt,
        border: Border(bottom: BorderSide(color: _Sheet.gridLineHd, width: 1)),
      ),
      child: Row(children: [
        Container(
          width: 28, height: 22,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: _Sheet.gridLineHd)),
          ),
        ),
        ...List.generate(letters.length, (i) => Container(
          width: widths[i], height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: _Sheet.gridLineHd)),
          ),
          child: Text(letters[i], style: GoogleFonts.dmSans(
              color: _Sheet.textGray, fontSize: 10, fontWeight: FontWeight.w600)),
        )),
      ]),
    );
  }

  // ─────────────────────────────────────────
  // ABA 1 — PLANILHA AUXILIAR (grade tipo MAKAI)
  // ─────────────────────────────────────────

  Widget _buildAbaAuxiliar() {
    final total  = _totalServicos;
    final custo  = _custoObra;

    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [

      _sheetFrame(
        titulo: 'BASE_CALCULO.xlsx',
        icon: Icons.calculate_outlined,
        child: Column(children: [
          _gridRowHeader2(['CUB', 'M²', 'BDI', 'Ano/Mês', 'Estado']),
          _gridRowInputs5(
            [_cubCtrl, _m2Ctrl, _bdiCtrl, _anoMesCtrl, _estadoCtrl],
            isNumeric: [true, true, true, false, false],
          ),
          Container(
            width: double.infinity,
            color: _Sheet.totalBg,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              const Icon(Icons.functions_rounded, size: 14, color: AppTheme.gold),
              const SizedBox(width: 8),
              Text('CUSTO OBRA (CUB × M²):', style: GoogleFonts.dmSans(
                  color: Colors.white70, fontSize: 11.5)),
              const Spacer(),
              Text(_fR$(custo), style: GoogleFonts.syne(
                  color: AppTheme.gold, fontSize: 13.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ),

      const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Align(alignment: Alignment.centerLeft, child: Text(
          'Cole os valores diretamente da sua planilha — a coluna "Custo R\$" aceita colar (Ctrl+V) em sequência.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
        )),
      ),

      const SizedBox(height: 4),

      _sheetFrame(
        titulo: 'AUTOMACAO_PCI.xlsx — Planilha1',
        icon: Icons.table_chart_outlined,
        child: Column(children: [
          _colLetterRow(['A', 'B', 'C', 'D', 'E'], [28, 230, 100, 70, 90]),
          Container(
            decoration: const BoxDecoration(
              color: _Sheet.colHeaderBg,
              border: Border(bottom: BorderSide(color: _Sheet.gridLineHd)),
            ),
            child: Row(children: [
              _hdCell('Nº', 28),
              _hdCell('SERVIÇO', 230, alignLeft: true),
              _hdCell('CUSTO R\$', 100),
              _hdCell('INC.%', 70),
              _hdCell('FAIXA CAIXA', 90),
            ]),
          ),
          ...List.generate(_itens.length, (i) => _gridItemRow(i)),
          Container(
            color: _Sheet.totalBg,
            child: Row(children: [
              _totCell('', 28),
              _totCell('CUSTO TOTAL DOS SERVIÇOS', 230, alignLeft: true),
              _totCell(_fR$(total), 100, color: AppTheme.gold),
              _totCell('100%', 70),
              _totCell('', 90),
            ]),
          ),
        ]),
      ),

      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _preencherPorCUB,
            icon: const Icon(Icons.auto_fix_high_rounded, size: 15),
            label: Text('Preencher itens por incidência média (a partir do CUB)',
                style: GoogleFonts.syne(fontSize: 12, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.gold,
              side: const BorderSide(color: AppTheme.gold),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ),

      const SizedBox(height: 16),

      _sheetFrame(
        titulo: 'SERVICOS_ADICIONAIS.xlsx',
        icon: Icons.add_box_outlined,
        child: Column(children: [
          _colLetterRow(['A', 'B', 'C'], [28, 290, 110]),
          Container(
            decoration: const BoxDecoration(
              color: _Sheet.colHeaderBg,
              border: Border(bottom: BorderSide(color: _Sheet.gridLineHd)),
            ),
            child: Row(children: [
              _hdCell('Item', 28),
              _hdCell('Serviços Adicionais', 290, alignLeft: true),
              _hdCell('Valor R\$', 110),
            ]),
          ),
          ...List.generate(_adicionais.length, (i) => _gridAdicionalRow(i)),
        ]),
      ),

      const SizedBox(height: 16),

      _sheetFrame(
        titulo: 'TOTAIS',
        icon: Icons.summarize_outlined,
        child: Column(children: [
          _linhaTotalGrid('Custo Total dos Serviços', total),
          _linhaTotalGrid('BDI (${_bdiCtrl.text}%)', _bdiValor),
          _linhaTotalGrid('Custo Total com BDI', _totalComBdi, destaque: true),
          Container(
            width: double.infinity,
            color: _diferenca.abs() < 500 ? _Sheet.okGreenBg : _Sheet.warnAmberBg,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Text('DIFERENÇA (CUB − Total c/ BDI)', style: GoogleFonts.dmSans(
                  color: _Sheet.textDark, fontSize: 12, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(_fR$(_diferenca), style: GoogleFonts.syne(
                  color: _diferenca.abs() < 500 ? _Sheet.okGreen : _Sheet.warnAmber,
                  fontSize: 13.5, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
      ),
    ]);
  }

  Widget _hdCell(String txt, double w, {bool alignLeft = false}) => Container(
    width: w, height: 30,
    alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
    padding: alignLeft ? const EdgeInsets.only(left: 8) : EdgeInsets.zero,
    decoration: const BoxDecoration(
      border: Border(right: BorderSide(color: Color(0xFF2C3A4A))),
    ),
    child: Text(txt, style: GoogleFonts.dmSans(
        color: _Sheet.colHeaderTx, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
  );

  Widget _totCell(String txt, double w, {bool alignLeft = false, Color? color}) => Container(
    width: w, height: 34,
    alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
    padding: alignLeft ? const EdgeInsets.only(left: 8) : EdgeInsets.zero,
    decoration: const BoxDecoration(
      border: Border(right: BorderSide(color: Color(0xFF333333))),
    ),
    child: Text(txt, style: GoogleFonts.syne(
        color: color ?? Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
  );

  Widget _gridItemRow(int i) {
    final item = _itens[i];
    final isAlt = i % 2 == 1;
    final val = _parseNum(_itemCtrl[i].text);
    item.valorProposto = val;
    final inc = _incidenciaItem(item);
    final cor = _corStatus(item);
    final tot = _totalServicos;
    final bg  = tot == 0 ? (isAlt ? _Sheet.rowAlt : _Sheet.bg) : _bgStatus(item);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: const Border(bottom: BorderSide(color: _Sheet.gridLine)),
      ),
      child: Row(children: [
        Container(
          width: 28, height: 36, alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: _Sheet.gridLine)),
          ),
          child: Text('${item.numero}', style: GoogleFonts.dmSans(
              color: _Sheet.textGray, fontSize: 10.5)),
        ),
        Container(
          width: 230, height: 36,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: _Sheet.gridLine)),
          ),
          child: Text(item.descricao, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(color: _Sheet.textDark, fontSize: 10.5)),
        ),
        Container(
          width: 100, height: 36,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: _Sheet.gridLine)),
          ),
          child: TextField(
            controller: _itemCtrl[i],
            focusNode: _itemFocus[i],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            style: GoogleFonts.dmSans(color: _Sheet.textDark, fontSize: 11),
            decoration: InputDecoration(
              isDense: true,
              hintText: '0,00',
              hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 10.5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              filled: true,
              fillColor: _Sheet.bg,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: _Sheet.cellFocusBd, width: 2),
              ),
            ),
          ),
        ),
        Container(
          width: 70, height: 36, alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: _Sheet.gridLine)),
          ),
          child: Text(tot > 0 ? _fP(inc) : '—', style: GoogleFonts.dmSans(
              color: cor, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ),
        Container(
          width: 90, height: 36, alignment: Alignment.center,
          child: Text(
            '${_fmtPct.format(item.incidenciaMin)}–${_fmtPct.format(item.incidenciaMax)}%',
            style: GoogleFonts.dmSans(color: _Sheet.textGray, fontSize: 9.5),
          ),
        ),
      ]),
    );
  }

  Widget _gridAdicionalRow(int i) {
    final isAlt = i % 2 == 1;
    return Container(
      decoration: BoxDecoration(
        color: isAlt ? _Sheet.rowAlt : _Sheet.bg,
        border: const Border(bottom: BorderSide(color: _Sheet.gridLine)),
      ),
      child: Row(children: [
        Container(
          width: 28, height: 34, alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: _Sheet.gridLine)),
          ),
          child: Text('${i + 1}', style: GoogleFonts.dmSans(color: _Sheet.textGray, fontSize: 10.5)),
        ),
        Container(
          width: 290, height: 34,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: _Sheet.gridLine)),
          ),
          child: TextField(
            controller: _adicionais[i].descCtrl,
            style: GoogleFonts.dmSans(color: _Sheet.textDark, fontSize: 11),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Descrição do serviço',
              hintStyle: TextStyle(color: Color(0xFFBBBBBB), fontSize: 10.5),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: InputBorder.none,
            ),
          ),
        ),
        SizedBox(
          width: 110, height: 34,
          child: TextField(
            controller: _adicionais[i].valorCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            style: GoogleFonts.dmSans(color: _Sheet.textDark, fontSize: 11),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              isDense: true,
              hintText: '0,00',
              hintStyle: TextStyle(color: Color(0xFFBBBBBB), fontSize: 10.5),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: InputBorder.none,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _gridRowHeader2(List<String> labels) => Container(
    decoration: const BoxDecoration(
      color: _Sheet.colHeaderBg,
      border: Border(bottom: BorderSide(color: _Sheet.gridLineHd)),
    ),
    child: Row(children: labels.map((l) => Expanded(
      child: Container(
        height: 28, alignment: Alignment.center,
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: Color(0xFF2C3A4A))),
        ),
        child: Text(l, style: GoogleFonts.dmSans(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
      ),
    )).toList()),
  );

  Widget _gridRowInputs5(List<TextEditingController> ctrls, {required List<bool> isNumeric}) => Container(
    decoration: const BoxDecoration(
      color: _Sheet.bg,
      border: Border(bottom: BorderSide(color: _Sheet.gridLineHd)),
    ),
    child: Row(children: List.generate(ctrls.length, (i) => Expanded(
      child: Container(
        height: 38,
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: _Sheet.gridLine)),
        ),
        child: TextField(
          controller: ctrls[i],
          textAlign: TextAlign.center,
          keyboardType: isNumeric[i]
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: GoogleFonts.dmSans(color: _Sheet.textDark, fontSize: 11.5, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
            isDense: true,
            filled: true,
            fillColor: _Sheet.bg,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
          ),
        ),
      ),
    )).toList()),
  );

  Widget _linhaTotalGrid(String label, double valor, {bool destaque = false}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: destaque ? _Sheet.totalBg : _Sheet.bg,
      border: const Border(bottom: BorderSide(color: _Sheet.gridLine)),
    ),
    child: Row(children: [
      Text(label, style: GoogleFonts.dmSans(
          color: destaque ? Colors.white : _Sheet.textDark,
          fontSize: 12, fontWeight: destaque ? FontWeight.w700 : FontWeight.w500)),
      const Spacer(),
      Text(_fR$(valor), style: GoogleFonts.syne(
          color: destaque ? AppTheme.gold : _Sheet.textDark,
          fontSize: destaque ? 13.5 : 12, fontWeight: FontWeight.w700)),
    ]),
  );

  // ─────────────────────────────────────────
  // ABA 2 — PCI OFICIAL (mesma lógica de grade)
  // ─────────────────────────────────────────

  Widget _buildAbaPciOficial() {
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [

      Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF003366),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('CAIXA ECONÔMICA FEDERAL', style: GoogleFonts.syne(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
          Text('Planilha de Custo de Incorporação (PCI)', style: GoogleFonts.dmSans(
              color: Colors.white70, fontSize: 11)),
        ]),
      ),

      _sheetFrame(
        titulo: 'IDENTIFICACAO.xlsx',
        icon: Icons.badge_outlined,
        child: Column(children: [
          _formGridRow('Proponente', _proponenteCtrl, full: true),
          _formGridRow2('E-mail', _emailCtrl, 'CPF/CNPJ', _cpfCtrl),
          _formGridRow('Telefone', _telefoneCtrl),
        ]),
      ),

      _sheetFrame(
        titulo: 'RESPONSAVEL_TECNICO.xlsx',
        icon: Icons.engineering_outlined,
        child: Column(children: [
          _formGridRow('Nome do RT', _rtpNomeCtrl, full: true),
          _formGridRow2('Nº CREA/CAU', _rtpCreaCauCtrl, 'CPF do RT', _rtpCpfCtrl),
        ]),
      ),

      _sheetFrame(
        titulo: 'IMOVEL.xlsx',
        icon: Icons.location_on_outlined,
        child: Column(children: [
          _formGridRow('Endereço', _enderecoCtrl, full: true),
          _formGridRow2('Bairro', _bairroCtrl, 'CEP', _cepCtrl),
          _formGridRow2('Município', _municipioCtrl, 'UF', TextEditingController(text: _uf)),
          _formGridRow('Matrícula', _matriculaCtrl),
        ]),
      ),

      _sheetFrame(
        titulo: 'AREAS_VALORES.xlsx',
        icon: Icons.straighten_rounded,
        child: Column(children: [
          _formGridRow2('Área Coberta (m²)', _areaCobertaCtrl, 'Área Permeável (m²)', _areaPermeaCtrl, numeric: true),
          _formGridRow2('Área Construída Total (m²)', _areaTotalCtrl, 'Área Terreno (m²)', _areaTerrenoCtrl, numeric: true),
          _formGridRow2("Valor Terreno (R\$)", _valorTerrenoCtrl, "Valor Imóvel (R\$)", _valorImovelCtrl, numeric: true),
        ]),
      ),

      _sheetFrame(
        titulo: 'CUSTOS_COMPONENTES.xlsx',
        icon: Icons.table_chart_outlined,
        child: Column(children: [
          _colLetterRow(['A', 'B', 'C', 'D'], [28, 250, 100, 70]),
          Container(
            decoration: const BoxDecoration(
              color: _Sheet.colHeaderBg,
              border: Border(bottom: BorderSide(color: _Sheet.gridLineHd)),
            ),
            child: Row(children: [
              _hdCell('Nº', 28),
              _hdCell('SERVIÇO', 250, alignLeft: true),
              _hdCell('CUSTO R\$', 100),
              _hdCell('%', 70),
            ]),
          ),
          ...List.generate(_itens.length, (i) {
            final item = _itens[i];
            final val  = item.valorProposto;
            final inc  = _incidenciaItem(item);
            final cor  = _corStatus(item);
            final isAlt = i % 2 == 1;
            return Container(
              decoration: BoxDecoration(
                color: isAlt ? _Sheet.rowAlt : _Sheet.bg,
                border: const Border(bottom: BorderSide(color: _Sheet.gridLine)),
              ),
              child: Row(children: [
                Container(width: 28, height: 32, alignment: Alignment.center,
                  decoration: const BoxDecoration(border: Border(right: BorderSide(color: _Sheet.gridLine))),
                  child: Text('${item.numero}', style: GoogleFonts.dmSans(color: _Sheet.textGray, fontSize: 10)),
                ),
                Container(width: 250, height: 32, alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 8),
                  decoration: const BoxDecoration(border: Border(right: BorderSide(color: _Sheet.gridLine))),
                  child: Text(item.descricao, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(color: _Sheet.textDark, fontSize: 10.5)),
                ),
                Container(width: 100, height: 32, alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(border: Border(right: BorderSide(color: _Sheet.gridLine))),
                  child: Text(_fR$(val), style: GoogleFonts.dmSans(color: _Sheet.textDark, fontSize: 10.5)),
                ),
                Container(width: 70, height: 32, alignment: Alignment.center,
                  child: Text(_fP(inc), style: GoogleFonts.dmSans(color: cor, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ]),
            );
          }),
          _linhaTotalGrid('Custo Total de Serviços', _totalServicos),
          _linhaTotalGrid('BDI (${_bdiCtrl.text}%)', _bdiValor),
          _linhaTotalGrid('Custo Total com BDI', _totalComBdi, destaque: true),
        ]),
      ),
    ]);
  }

  Widget _formGridRow(String label, TextEditingController ctrl, {bool full = false}) => Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: _Sheet.gridLine)),
    ),
    child: Row(children: [
      Container(
        width: 130, height: 38, alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 10),
        decoration: const BoxDecoration(
          color: _Sheet.headerBg,
          border: Border(right: BorderSide(color: _Sheet.gridLine)),
        ),
        child: Text(label, style: GoogleFonts.dmSans(
            color: _Sheet.textGray, fontSize: 10.5, fontWeight: FontWeight.w600)),
      ),
      Expanded(
        child: SizedBox(
          height: 38,
          child: TextField(
            controller: ctrl,
            style: GoogleFonts.dmSans(color: _Sheet.textDark, fontSize: 11.5),
            decoration: const InputDecoration(
              isDense: true,
              filled: true,
              fillColor: _Sheet.bg,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
            ),
          ),
        ),
      ),
    ]),
  );

  Widget _formGridRow2(String label1, TextEditingController ctrl1,
      String label2, TextEditingController ctrl2, {bool numeric = false}) => Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: _Sheet.gridLine)),
    ),
    child: Row(children: [
      Container(
        width: 130, height: 38, alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 10),
        decoration: const BoxDecoration(
          color: _Sheet.headerBg,
          border: Border(right: BorderSide(color: _Sheet.gridLine)),
        ),
        child: Text(label1, style: GoogleFonts.dmSans(
            color: _Sheet.textGray, fontSize: 10.5, fontWeight: FontWeight.w600)),
      ),
      Expanded(
        child: SizedBox(
          height: 38,
          child: TextField(
            controller: ctrl1,
            keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            style: GoogleFonts.dmSans(color: _Sheet.textDark, fontSize: 11.5),
            decoration: const InputDecoration(
              isDense: true,
              filled: true,
              fillColor: _Sheet.bg,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
            ),
          ),
        ),
      ),
      Container(
        width: 110, height: 38, alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 10),
        decoration: const BoxDecoration(
          color: _Sheet.headerBg,
          border: Border(left: BorderSide(color: _Sheet.gridLine), right: BorderSide(color: _Sheet.gridLine)),
        ),
        child: Text(label2, style: GoogleFonts.dmSans(
            color: _Sheet.textGray, fontSize: 10.5, fontWeight: FontWeight.w600)),
      ),
      Expanded(
        child: SizedBox(
          height: 38,
          child: TextField(
            controller: ctrl2,
            keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            style: GoogleFonts.dmSans(color: _Sheet.textDark, fontSize: 11.5),
            decoration: const InputDecoration(
              isDense: true,
              filled: true,
              fillColor: _Sheet.bg,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
            ),
          ),
        ),
      ),
    ]),
  );

  // ─────────────────────────────────────────
  // ABA 3 — RESULTADO
  // ─────────────────────────────────────────

  Widget _buildAbaResultado() {
    final totalS  = _totalServicos;
    final comBdi  = _totalComBdi;
    final custo   = _custoObra;
    final dif     = _diferenca;
    final ok      = dif.abs() < 500;
    final itensFora = _itens.where((item) {
      if (totalS == 0) return false;
      final inc = item.valorProposto / totalS * 100;
      return (item.incidenciaMin > 0 && inc < item.incidenciaMin) || inc > item.incidenciaMax;
    }).toList();

    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ok && itensFora.isEmpty ? AppTheme.success.withOpacity(0.1) : AppTheme.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ok && itensFora.isEmpty ? AppTheme.success : AppTheme.error),
        ),
        child: Row(children: [
          Icon(ok && itensFora.isEmpty ? Icons.check_circle_rounded : Icons.warning_rounded,
              color: ok && itensFora.isEmpty ? AppTheme.success : AppTheme.error, size: 32),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ok && itensFora.isEmpty ? 'PCI dentro dos parâmetros Caixa' : 'Ajustes necessários antes de enviar',
                style: GoogleFonts.syne(
                    color: ok && itensFora.isEmpty ? AppTheme.success : AppTheme.error,
                    fontWeight: FontWeight.w700, fontSize: 15)),
            if (itensFora.isNotEmpty)
              Text('${itensFora.length} item(ns) fora da faixa de incidência aceitável.',
                  style: GoogleFonts.dmSans(color: AppTheme.textSecondary, fontSize: 12)),
          ])),
        ]),
      ),

      const SizedBox(height: 16),
      if (itensFora.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ITENS FORA DA FAIXA', style: GoogleFonts.syne(
                color: AppTheme.gold, fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 10),
            ...itensFora.map((item) {
              final inc = totalS > 0 ? (item.valorProposto / totalS) * 100 : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  const Icon(Icons.cancel_rounded, color: AppTheme.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Item ${item.numero} — ${item.descricao}', style: GoogleFonts.dmSans(
                        color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('Proposto: ${_fP(inc)}  |  Faixa: ${_fmtPct.format(item.incidenciaMin)}–${_fmtPct.format(item.incidenciaMax)}%',
                        style: GoogleFonts.dmSans(color: AppTheme.error, fontSize: 11)),
                  ])),
                ]),
              );
            }),
          ]),
        ),

      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(children: [
          _linhaRes('Custo Referencial (CUB × m²)', _fR$(custo)),
          _linhaRes('Total de Serviços (PCI)', _fR$(totalS)),
          _linhaRes('BDI (${_bdiCtrl.text}%)', _fR$(_bdiValor)),
          _linhaRes('Total com BDI', _fR$(comBdi), bold: true),
          const Divider(color: AppTheme.cardBorder),
          _linhaRes('DIFERENÇA (CUB − Total c/ BDI)', _fR$(dif),
              cor: dif.abs() < 500 ? AppTheme.success : AppTheme.warning),
        ]),
      ),
    ]);
  }

  Widget _linhaRes(String label, String valor, {bool bold = false, Color? cor}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Expanded(child: Text(label, style: GoogleFonts.dmSans(
          color: AppTheme.textSecondary, fontSize: 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal))),
      Text(valor, style: GoogleFonts.syne(
          color: cor ?? (bold ? AppTheme.gold : AppTheme.textPrimary),
          fontSize: bold ? 14 : 12, fontWeight: FontWeight.w600)),
    ]),
  );

  // ─────────────────────────────────────────
  // EXPORTAR .XLSX
  // ─────────────────────────────────────────

  Future<void> _exportarXlsx() async {
    setState(() => _exportando = true);
    try {
      final excel = xls.Excel.createExcel();

      // ── Aba 1: PCI Auxiliar ──────────────────────────────────
      final xls.Sheet shAux = excel['PCI_AUXILIAR'];

      // Cabeçalho base de cálculo
      _xlsxRow(shAux, 0, ["CUB (R\$/m²)", 'M² Construído', 'BDI (%)', 'Ano/Mês', 'Estado'],
          bold: true, bgHex: '1C2733', fgHex: 'FFFFFF');
      _xlsxRow(shAux, 1, [
        _cubCtrl.text, _m2Ctrl.text, _bdiCtrl.text,
        _anoMesCtrl.text, _estadoCtrl.text,
      ]);
      _xlsxRow(shAux, 2, ['CUSTO OBRA (CUB × M²)', '', '', '', _fR$(_custoObra)],
          bold: true, bgHex: '202124', fgHex: 'D4A017');

      shAux.appendRow([xls.TextCellValue('')]);

      // Cabeçalho dos 20 itens
      _xlsxRow(shAux, 4, ['Nº', 'Serviço', "Custo R\$", 'Incidência %', 'Faixa Mín %', 'Faixa Máx %'],
          bold: true, bgHex: '1C2733', fgHex: 'FFFFFF');

      // 20 itens
      for (var i = 0; i < _itens.length; i++) {
        final item = _itens[i];
        final val  = _parseNum(_itemCtrl[i].text);
        final inc  = _totalServicos > 0 ? (val / _totalServicos * 100) : 0.0;
        _xlsxRow(shAux, 5 + i, [
          '${item.numero}',
          item.descricao,
          _fR$(val),
          _fP(inc),
          '${_fmtPct.format(item.incidenciaMin)}%',
          '${_fmtPct.format(item.incidenciaMax)}%',
        ], bgHex: i % 2 == 0 ? 'FFFFFF' : 'F8F9FA');
      }

      // Totais
      _xlsxRow(shAux, 25, ['', 'CUSTO TOTAL DOS SERVIÇOS', _fR$(_totalServicos), '100%', '', ''],
          bold: true, bgHex: '202124', fgHex: 'D4A017');
      _xlsxRow(shAux, 26, ['', 'BDI (${_bdiCtrl.text}%)', _fR$(_bdiValor), '', '', ''],
          bold: true, bgHex: '202124', fgHex: 'FFFFFF');
      _xlsxRow(shAux, 27, ['', 'CUSTO TOTAL COM BDI', _fR$(_totalComBdi), '', '', ''],
          bold: true, bgHex: '202124', fgHex: 'D4A017');
      _xlsxRow(shAux, 28, ['', 'DIFERENÇA (CUB − Total c/ BDI)', _fR$(_diferenca), '', '', ''],
          bold: true,
          bgHex: _diferenca.abs() < 500 ? 'E6F4EA' : 'FEF7E0',
          fgHex: _diferenca.abs() < 500 ? '1E8E3E' : 'B06000');

      // Serviços adicionais
      shAux.appendRow([xls.TextCellValue('')]);
      _xlsxRow(shAux, 30, ['Item', 'Serviços Adicionais', 'Valor R\$'],
          bold: true, bgHex: '1C2733', fgHex: 'FFFFFF');
      for (var i = 0; i < _adicionais.length; i++) {
        final desc = _adicionais[i].descCtrl.text;
        final val  = _adicionais[i].valorCtrl.text;
        if (desc.isNotEmpty || val.isNotEmpty) {
          _xlsxRow(shAux, 31 + i, ['${i + 1}', desc, val]);
        }
      }

      // ── Aba 2: PCI Oficial ───────────────────────────────────
      final xls.Sheet shPci = excel['PCI_OFICIAL'];

      _xlsxRow(shPci, 0, ['CAIXA ECONÔMICA FEDERAL — Planilha de Custo de Incorporação (PCI)'],
          bold: true, bgHex: '003366', fgHex: 'FFFFFF');

      shPci.appendRow([xls.TextCellValue('')]);
      _xlsxRow(shPci, 2, ['IDENTIFICAÇÃO'], bold: true, bgHex: 'F1F3F4', fgHex: '1A1A1A');
      _xlsxRow(shPci, 3,  ['Proponente',  _proponenteCtrl.text]);
      _xlsxRow(shPci, 4,  ['E-mail',      _emailCtrl.text]);
      _xlsxRow(shPci, 5,  ['CPF/CNPJ',   _cpfCtrl.text]);
      _xlsxRow(shPci, 6,  ['Telefone',   _telefoneCtrl.text]);

      shPci.appendRow([xls.TextCellValue('')]);
      _xlsxRow(shPci, 8, ['RESPONSÁVEL TÉCNICO'], bold: true, bgHex: 'F1F3F4', fgHex: '1A1A1A');
      _xlsxRow(shPci, 9,  ['Nome do RT',   _rtpNomeCtrl.text]);
      _xlsxRow(shPci, 10, ['Nº CREA/CAU', _rtpCreaCauCtrl.text]);
      _xlsxRow(shPci, 11, ['CPF do RT',   _rtpCpfCtrl.text]);

      shPci.appendRow([xls.TextCellValue('')]);
      _xlsxRow(shPci, 13, ['IMÓVEL'], bold: true, bgHex: 'F1F3F4', fgHex: '1A1A1A');
      _xlsxRow(shPci, 14, ['Endereço',   _enderecoCtrl.text]);
      _xlsxRow(shPci, 15, ['Bairro',     _bairroCtrl.text]);
      _xlsxRow(shPci, 16, ['CEP',        _cepCtrl.text]);
      _xlsxRow(shPci, 17, ['Município',  _municipioCtrl.text]);
      _xlsxRow(shPci, 18, ['UF',         _uf]);
      _xlsxRow(shPci, 19, ['Matrícula',  _matriculaCtrl.text]);

      shPci.appendRow([xls.TextCellValue('')]);
      _xlsxRow(shPci, 21, ['ÁREAS E VALORES'], bold: true, bgHex: 'F1F3F4', fgHex: '1A1A1A');
      _xlsxRow(shPci, 22, ['Área Coberta (m²)',         _areaCobertaCtrl.text]);
      _xlsxRow(shPci, 23, ['Área Permeável (m²)',        _areaPermeaCtrl.text]);
      _xlsxRow(shPci, 24, ['Área Construída Total (m²)', _areaTotalCtrl.text]);
      _xlsxRow(shPci, 25, ['Área Terreno (m²)',          _areaTerrenoCtrl.text]);
      _xlsxRow(shPci, 26, ["Valor Terreno (R\$)",        _valorTerrenoCtrl.text]);
      _xlsxRow(shPci, 27, ["Valor Imóvel (R\$)",         _valorImovelCtrl.text]);

      shPci.appendRow([xls.TextCellValue('')]);
      _xlsxRow(shPci, 29, ['Nº', 'SERVIÇO', 'CUSTO R\$', 'INCIDÊNCIA %'],
          bold: true, bgHex: '1C2733', fgHex: 'FFFFFF');
      for (var i = 0; i < _itens.length; i++) {
        final item = _itens[i];
        final val  = item.valorProposto;
        final inc  = _totalServicos > 0 ? (val / _totalServicos * 100) : 0.0;
        _xlsxRow(shPci, 30 + i, [
          '${item.numero}', item.descricao, _fR$(val), _fP(inc),
        ], bgHex: i % 2 == 0 ? 'FFFFFF' : 'F8F9FA');
      }
      _xlsxRow(shPci, 50, ['', 'Custo Total de Serviços', _fR$(_totalServicos), ''],
          bold: true, bgHex: '202124', fgHex: 'D4A017');
      _xlsxRow(shPci, 51, ['', 'BDI', _fR$(_bdiValor), ''],
          bold: true, bgHex: '202124', fgHex: 'FFFFFF');
      _xlsxRow(shPci, 52, ['', 'CUSTO TOTAL COM BDI', _fR$(_totalComBdi), ''],
          bold: true, bgHex: '202124', fgHex: 'D4A017');

      // Remove aba padrão vazia
      excel.delete('Sheet1');

      // Larguras de coluna
      shAux.setColumnWidth(1, 45);
      shPci.setColumnWidth(1, 45);

      // Gera bytes e faz download (web) ou salva (mobile)
      final bytes = excel.save();
      if (bytes == null) throw Exception('Falha ao gerar bytes do arquivo');

      final nome = 'PCI_Multiplika_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      // Web: download via anchor
      // ignore: avoid_web_libraries_in_flutter
      final blob = html.Blob([Uint8List.fromList(bytes)],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url  = html.Url.createObjectUrlFromBlob(blob);
      final a    = html.AnchorElement(href: url)
        ..setAttribute('download', nome)
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppTheme.success,
          content: Text('✅ $nome exportado com sucesso!',
              style: GoogleFonts.dmSans(color: Colors.white)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppTheme.error,
          content: Text('Erro ao exportar: $e',
              style: GoogleFonts.dmSans(color: Colors.white)),
        ));
      }
    } finally {
      setState(() => _exportando = false);
    }
  }

  // Helper: escreve uma linha no xlsx com estilo opcional
  void _xlsxRow(xls.Sheet sheet, int rowIdx, List<String> values,
      {bool bold = false, String? bgHex, String? fgHex}) {
    for (var c = 0; c < values.length; c++) {
      final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx));
      cell.value = xls.TextCellValue(values[c]);
      cell.cellStyle = xls.CellStyle(
        bold: bold,
        backgroundColorHex: xls.ExcelColor.fromHexString('#${bgHex ?? "FFFFFF"}'),
        fontColorHex: xls.ExcelColor.fromHexString('#${fgHex ?? "1A1A1A"}'),
      );
    }
  }
}

// ─────────────────────────────────────────────
class _ServicoAdicional {
  final descCtrl  = TextEditingController();
  final valorCtrl = TextEditingController();
}