// ============================================================
// MULTIPLIKA INCORPORADORA — Triagem de Leads v3
// lib/triagem_leads_screen.dart
// Formulário enxuto → Motor inteligente → Plano completo
// + Compartilhamento do relatório
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'gd_card.dart';
import 'obra_context.dart';

// ─────────────────────────────────────────────
// CONSTANTES DO MOTOR
// ─────────────────────────────────────────────

const double kCubSP          = 2850.0;
const double kTaxaMCMV1      = 0.040;  // renda ≤ 2k (cotista)
const double kTaxaMCMV2      = 0.045;  // renda ≤ 4k
const double kTaxaMCMV3      = 0.060;  // renda ≤ 8k
const double kTaxaMCMV4      = 0.065;  // renda ≤ 12k
const double kTaxaSBPE       = 0.095;  // SBPE SAC
const int    kPrazoMCMV      = 420;
const int    kPrazoSBPE      = 360;
const double kEntradaMCMV    = 0.20;
const double kEntradaSBPE    = 0.20;
const double kComprometMax   = 0.30;
const double kTetoMCMVSP     = 350000.0; // teto MCMV interior SP

// Subsídios MCMV por faixa de renda (valores aproximados 2024)
double subsidioMCMV(double renda, int dependentes) {
  if (renda <= 2000) return dependentes >= 1 ? 55000 : 47000;
  if (renda <= 3000) return dependentes >= 1 ? 45000 : 37000;
  if (renda <= 4000) return dependentes >= 1 ? 35000 : 27000;
  if (renda <= 6000) return dependentes >= 1 ? 20000 : 12000;
  if (renda <= 8000) return dependentes >= 1 ? 8000  : 4000;
  return 0;
}

// ─────────────────────────────────────────────
// MODELOS
// ─────────────────────────────────────────────

enum FaixaMercado { mcmv, sbpeInt, sbpeHigh }
enum SistemaAmort { sac, price }
enum EstadoCivil  { solteiro, casado, uniaoEstavel, divorciado }

class ModeloProduto {
  final String id, nome, descricao;
  final FaixaMercado faixa;
  final double areaMin, areaMax, cubMultiplier, margemAlvo, vgvMax;

  const ModeloProduto({
    required this.id, required this.nome, required this.descricao,
    required this.faixa, required this.areaMin, required this.areaMax,
    required this.cubMultiplier, required this.margemAlvo, required this.vgvMax,
  });

  double get areaMedia => (areaMin + areaMax) / 2;
  double custo(double cub) => areaMedia * cub * cubMultiplier;
}

const List<ModeloProduto> kModelos = [
  ModeloProduto(id: 'M1-TERREA-MCMV', nome: 'Compacto Térreo Otimizado',
      descricao: 'Estrutura enxuta, acabamento padrão Caixa',
      faixa: FaixaMercado.mcmv, areaMin: 48, areaMax: 55,
      cubMultiplier: 1.15, margemAlvo: 0.175, vgvMax: 350000),
  ModeloProduto(id: 'M2-EVOLUTIVA-MCMV', nome: 'Planta Evolutiva Otimizada',
      descricao: 'Ampliável em 2ª fase, acabamento Caixa',
      faixa: FaixaMercado.mcmv, areaMin: 55, areaMax: 65,
      cubMultiplier: 1.15, margemAlvo: 0.175, vgvMax: 350000),
  ModeloProduto(id: 'M8-SOBRADO-INT', nome: 'Sobrado 3 Suítes Imponente',
      descricao: 'Fachada imponente, 3 suítes, varanda',
      faixa: FaixaMercado.sbpeInt, areaMin: 120, areaMax: 140,
      cubMultiplier: 1.22, margemAlvo: 0.25, vgvMax: 600000),
  ModeloProduto(id: 'M9-TERREA-INT', nome: 'Casa Térrea Conceito',
      descricao: 'Volumetria moderna, LED, revestimentos premium',
      faixa: FaixaMercado.sbpeInt, areaMin: 115, areaMax: 125,
      cubMultiplier: 1.22, margemAlvo: 0.25, vgvMax: 600000),
  ModeloProduto(id: 'M10-LAZER-INT', nome: 'Casa Lazer com Piscina/Hidro',
      descricao: 'Área gourmet, piscina, hidromassagem',
      faixa: FaixaMercado.sbpeInt, areaMin: 140, areaMax: 150,
      cubMultiplier: 1.30, margemAlvo: 0.25, vgvMax: 600000),
  ModeloProduto(id: 'M-LINEAR-LUX', nome: 'Mansão Linear High-End',
      descricao: 'Grandes vãos, esquadrias piso-teto, automação',
      faixa: FaixaMercado.sbpeHigh, areaMin: 180, areaMax: 250,
      cubMultiplier: 1.35, margemAlvo: 0.325, vgvMax: double.infinity),
  ModeloProduto(id: 'M-RESORT-LUX', nome: 'Resort Urbano Assinado',
      descricao: 'Projeto assinado, automação total, boutique',
      faixa: FaixaMercado.sbpeHigh, areaMin: 250, areaMax: 350,
      cubMultiplier: 1.35, margemAlvo: 0.325, vgvMax: double.infinity),
];

// ─────────────────────────────────────────────
// RESULTADO DO MOTOR
// ─────────────────────────────────────────────

class ResultadoMotor {
  final String      nomeCliente;
  final double      renda;
  final int         dependentes;
  final EstadoCivil estadoCivil;
  final bool        cotistaCaixa;
  final bool        temTerreno;
  final double      fgts;
  final double      entradaPropria;

  final FaixaMercado faixa;
  final ModeloProduto modelo;
  final double       vgvMaxCapacidade;  // pelo limite de renda
  final double       vgvOperavel;       // credito + entrada disponivel
  final double       subsidio;

  final double entradaExigida;
  final double entradaDisponivel;
  final double gapEntrada;

  final double valorFinanciado;
  final double taxaAnual;
  final int    prazoMeses;
  final SistemaAmort sistema;
  final double parcelaPrimeira;
  final double parcelaUltima;
  final double parcelaPrice;
  final double parcelaRef;
  final double comprometimento;

  final double custoConstrucao;
  final double margemReais;
  final double tetoTerreno;
  final bool   margemApertada;

  final String scoreGeral;
  final List<String> alertas;
  final String resumoTexto; // para compartilhar

  const ResultadoMotor({
    required this.nomeCliente, required this.renda, required this.dependentes,
    required this.estadoCivil, required this.cotistaCaixa, required this.temTerreno,
    required this.fgts, required this.entradaPropria,
    required this.faixa, required this.modelo,
    required this.vgvMaxCapacidade, required this.vgvOperavel, required this.subsidio,
    required this.entradaExigida, required this.entradaDisponivel, required this.gapEntrada,
    required this.valorFinanciado, required this.taxaAnual, required this.prazoMeses,
    required this.sistema, required this.parcelaPrimeira, required this.parcelaUltima,
    required this.parcelaPrice, required this.parcelaRef, required this.comprometimento,
    required this.custoConstrucao, required this.margemReais, required this.tetoTerreno,
    required this.margemApertada,
    required this.scoreGeral, required this.alertas, required this.resumoTexto,
  });
}

// ─────────────────────────────────────────────
// MOTOR
// ─────────────────────────────────────────────

class Motor {
  static final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static String f(double v) => _fmt.format(v);
  static String p(double v) => '${(v * 100).toStringAsFixed(1)}%';

  static double _taxaMCMV(double renda, bool cotista) {
    if (renda <= 2000) return cotista ? 0.040 : 0.045;
    if (renda <= 4000) return cotista ? 0.045 : 0.050;
    if (renda <= 8000) return cotista ? 0.055 : 0.060;
    return cotista ? 0.060 : 0.065;
  }

  static double _pow(double b, int e) {
    double r = 1; for (int i = 0; i < e; i++) r *= b; return r;
  }

  static double _parcelaPrice(double pv, int n, double ta) {
    final tm = ta / 12;
    if (tm == 0) return pv / n;
    return pv * (tm * _pow(1 + tm, n)) / (_pow(1 + tm, n) - 1);
  }

  static (double, double) _parcelaSAC(double pv, int n, double ta) {
    final tm = ta / 12;
    final a  = pv / n;
    return (a + pv * tm, a + a * tm);
  }

  // Capacidade máxima de financiamento pela renda
  static double capacidadeFinanciamento(double renda, int prazo, double taxa) {
    final tm = taxa / 12;
    // inverso do SAC: saldo = (renda*30%) / (1/n + taxa)
    final parcelaMax = renda * kComprometMax;
    if (tm == 0) return parcelaMax * prazo;
    // aproximação pela 1ª parcela SAC: parcela1 = (PV/n) + PV*tm
    // => PV = parcelaMax / (1/n + tm)
    return parcelaMax / (1 / prazo + tm);
  }

  static FaixaMercado enquadrar(double vgv) {
    if (vgv <= 350000) return FaixaMercado.mcmv;
    if (vgv <= 600000) return FaixaMercado.sbpeInt;
    return FaixaMercado.sbpeHigh;
  }

  static ModeloProduto modeloIdeal(FaixaMercado faixa, {bool piscina = false}) {
    final lista = kModelos.where((m) => m.faixa == faixa).toList();
    if (faixa == FaixaMercado.sbpeInt && piscina) {
      return lista.firstWhere((m) => m.id == 'M10-LAZER-INT', orElse: () => lista.first);
    }
    return lista.first;
  }

  static ResultadoMotor calcular({
    required String nome,
    required double renda,
    required int    dependentes,
    required EstadoCivil estadoCivil,
    required bool   cotista,
    required bool   temTerreno,
    required double fgts,
    required double entradaPropria,
    required bool   piscina,
    required int    parcelasEntrada,
    required double cub,
  }) {
    final double entradaDisp = fgts + entradaPropria;

    // 1. Determina taxa e prazo provisórios para calcular capacidade
    //    Começa tentando MCMV, ajusta se VGV ultrapassar teto
    double taxaProv  = _taxaMCMV(renda, cotista);
    int    prazoProv = kPrazoMCMV;

    double capFin = capacidadeFinanciamento(renda, prazoProv, taxaProv);
    double sub    = subsidioMCMV(renda, dependentes);

    // VGV máximo = capacidade financiamento + entrada + subsidio
    double vgvMaxCap = capFin + entradaDisp + sub;

    // 2. Enquadra faixa
    FaixaMercado faixa = enquadrar(vgvMaxCap);

    // Se SBPE, recalcula com taxa/prazo SBPE
    if (faixa != FaixaMercado.mcmv) {
      taxaProv  = kTaxaSBPE;
      prazoProv = kPrazoSBPE;
      sub       = 0;
      capFin    = capacidadeFinanciamento(renda, prazoProv, taxaProv);
      vgvMaxCap = capFin + entradaDisp;
      faixa     = enquadrar(vgvMaxCap);
    }

    // VGV operável real (não ultrapassa o teto do modelo)
    final modelo    = modeloIdeal(faixa, piscina: piscina);
    final vgvOp     = vgvMaxCap.clamp(0, modelo.vgvMax).toDouble();

    // 3. Entrada
    final double pctEnt  = kEntradaMCMV; // 20% para ambos
    final double entExig = (vgvOp - sub) * pctEnt;
    final double gap     = (entExig - entradaDisp).clamp(0.0, double.infinity);
    final double valFin  = vgvOp - entExig - sub;

    // 4. Simulação bancária
    final double taxa   = faixa == FaixaMercado.mcmv ? _taxaMCMV(renda, cotista) : kTaxaSBPE;
    final int    prazo  = faixa == FaixaMercado.mcmv ? kPrazoMCMV : kPrazoSBPE;
    final SistemaAmort sis = faixa == FaixaMercado.mcmv ? SistemaAmort.price : SistemaAmort.sac;

    final double parPrice           = _parcelaPrice(valFin, prazo, taxa);
    final (double sac1, double sacU) = _parcelaSAC(valFin, prazo, taxa);
    final double parRef              = sis == SistemaAmort.price ? parPrice : sac1;
    final double comp                = renda > 0 ? parRef / renda : 0;

    // 5. Construção + lote virtual
    final double custo  = modelo.custo(cub);
    final double margR  = vgvOp * modelo.margemAlvo;
    final double teto   = vgvOp - custo - margR;
    final bool   apert  = teto < 0;

    // 6. Alertas
    final alertas = <String>[];
    if (sub > 0)
      alertas.add('🎁 Subsídio MCMV estimado de ${f(sub)} aplicado automaticamente.');
    if (gap > 0)
      alertas.add('💰 Falta ${f(gap)} de entrada. Parcelar em ${parcelasEntrada}× de ${f(gap / parcelasEntrada)}.');
    if (comp > kComprometMax)
      alertas.add('⚠️ Comprometimento de ${p(comp)} acima do limite de 30% — banco pode reprovar.');
    if (apert)
      alertas.add('⚠️ Teto do terreno negativo com margem cheia. Motor ajustou para margem mínima viável.');
    if (!temTerreno && teto < 30000 && teto > 0)
      alertas.add('🎯 Teto do lote (${f(teto)}) muito baixo — priorize captação de terreno via permuta.');
    if (temTerreno)
      alertas.add('✅ Cliente possui terreno — sem necessidade de cálculo de lote virtual.');

    // 7. Score
    final int vermelhos = [comp > kComprometMax, gap > entradaDisp, teto < 0].where((x) => x).length;
    final int amarelos  = [gap > 0, comp > 0.25, apert].where((x) => x).length;
    final score = vermelhos >= 2 ? 'vermelho' : vermelhos == 1 || amarelos >= 2 ? 'amarelo' : 'verde';

    // 8. Resumo texto para compartilhar
    final resumo = _gerarResumo(
      nome: nome, faixa: faixa, modelo: modelo,
      vgvOp: vgvOp, sub: sub, entExig: entExig,
      entradaDisp: entradaDisp, gap: gap, valFin: valFin,
      taxa: taxa, prazo: prazo, sis: sis,
      parRef: parRef, comp: comp, custo: custo,
      margR: margR, teto: teto, score: score, alertas: alertas,
    );

    return ResultadoMotor(
      nomeCliente: nome, renda: renda, dependentes: dependentes,
      estadoCivil: estadoCivil, cotistaCaixa: cotista, temTerreno: temTerreno,
      fgts: fgts, entradaPropria: entradaPropria,
      faixa: faixa, modelo: modelo,
      vgvMaxCapacidade: vgvMaxCap, vgvOperavel: vgvOp, subsidio: sub,
      entradaExigida: entExig, entradaDisponivel: entradaDisp, gapEntrada: gap,
      valorFinanciado: valFin, taxaAnual: taxa, prazoMeses: prazo,
      sistema: sis, parcelaPrimeira: sac1, parcelaUltima: sacU,
      parcelaPrice: parPrice, parcelaRef: parRef, comprometimento: comp,
      custoConstrucao: custo, margemReais: margR, tetoTerreno: teto,
      margemApertada: apert,
      scoreGeral: score, alertas: alertas, resumoTexto: resumo,
    );
  }

  static String _gerarResumo({
    required String nome, required FaixaMercado faixa,
    required ModeloProduto modelo, required double vgvOp,
    required double sub, required double entExig,
    required double entradaDisp, required double gap,
    required double valFin, required double taxa,
    required int prazo, required SistemaAmort sis,
    required double parRef, required double comp,
    required double custo, required double margR,
    required double teto, required String score,
    required List<String> alertas,
  }) {
    final sb = StringBuffer();
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('📋 ANÁLISE DE LEAD — MULTIPLIKA INCORPORADORA');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('👤 Cliente: $nome');
    sb.writeln('📊 Faixa: ${faixa == FaixaMercado.mcmv ? "MCMV" : faixa == FaixaMercado.sbpeInt ? "SBPE Intermediário" : "SBPE High-End"}');
    sb.writeln('🏠 Modelo Ideal: [${modelo.id}] ${modelo.nome}');
    sb.writeln('');
    sb.writeln('💰 COMPOSIÇÃO FINANCEIRA');
    sb.writeln('  VGV Total: ${f(vgvOp)}');
    if (sub > 0) sb.writeln('  Subsídio MCMV: ${f(sub)}');
    sb.writeln('  Entrada Exigida (20%): ${f(entExig)}');
    sb.writeln('  Entrada Disponível: ${f(entradaDisp)}');
    if (gap > 0) sb.writeln('  ⚠️ Falta de Entrada: ${f(gap)}');
    sb.writeln('  Valor Financiado: ${f(valFin)}');
    sb.writeln('');
    sb.writeln('🏦 SIMULAÇÃO BANCÁRIA');
    sb.writeln('  Sistema: ${sis == SistemaAmort.sac ? "SAC" : "PRICE"}');
    sb.writeln('  Taxa: ${(taxa * 100).toStringAsFixed(1)}% a.a.');
    sb.writeln('  Prazo: $prazo meses (${(prazo / 12).toStringAsFixed(0)} anos)');
    sb.writeln('  Parcela Referência: ${f(parRef)}/mês');
    sb.writeln('  Comprometimento de Renda: ${p(comp)}');
    sb.writeln('');
    sb.writeln('🎯 LOTE VIRTUAL');
    sb.writeln('  Custo Construção: ${f(custo)}');
    sb.writeln('  Margem Incorporadora: ${f(margR)}');
    sb.writeln('  Teto do Terreno: ${f(teto)}');
    sb.writeln('');
    sb.writeln('📌 ALERTAS');
    for (final a in alertas) sb.writeln('  $a');
    sb.writeln('');
    final scoreLabel = score == 'verde' ? '✅ VIÁVEL' : score == 'amarelo' ? '🟡 VIÁVEL COM RESSALVAS' : '🔴 INVIÁVEL';
    sb.writeln('RESULTADO: $scoreLabel');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    sb.write('Gerado por Multiplika Incorporadora');
    return sb.toString();
  }
}

// ─────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────

class TriagemLeadsScreen extends StatefulWidget {
  const TriagemLeadsScreen({super.key});
  @override
  State<TriagemLeadsScreen> createState() => _TriagemLeadsScreenState();
}

class _TriagemLeadsScreenState extends State<TriagemLeadsScreen>
    with SingleTickerProviderStateMixin {

  final _formKey    = GlobalKey<FormState>();
  final _scrollCtrl = ScrollController();

  // Campos do formulário
  final _nomeCtrl     = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _cidadeCtrl   = TextEditingController();
  final _rendaCtrl    = TextEditingController();
  final _fgtsCtrl     = TextEditingController();
  final _entradaCtrl  = TextEditingController();

  EstadoCivil _estadoCivil  = EstadoCivil.solteiro;
  int         _dependentes  = 0;
  bool        _cotista      = false;
  bool        _restricao    = false;
  bool        _temTerreno   = false;
  bool        _piscina      = false;
  double      _cubAtual     = kCubSP;
  int         _parcelasEnt  = 12;

  ResultadoMotor? _resultado;
  bool _salvando = false, _salvo = false;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _animCtrl.dispose(); _scrollCtrl.dispose();
    for (final c in [_nomeCtrl, _telefoneCtrl, _cidadeCtrl, _rendaCtrl, _fgtsCtrl, _entradaCtrl]) c.dispose();
    super.dispose();
  }

  double _parseR$(String s) => double.tryParse(s.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
  String _fmtR$(double v)   => NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(v);
  String _fmtPct(double v)  => '${(v * 100).toStringAsFixed(1)}%';

  Color _cor(String s) {
    switch (s) {
      case 'verde':    return AppTheme.success;
      case 'amarelo':  return AppTheme.warning;
      case 'vermelho': return AppTheme.error;
      default:         return AppTheme.textMuted;
    }
  }

  IconData _icon(String s) {
    switch (s) {
      case 'verde':    return Icons.check_circle_rounded;
      case 'amarelo':  return Icons.warning_amber_rounded;
      case 'vermelho': return Icons.cancel_rounded;
      default:         return Icons.help_outline;
    }
  }

  void _snack(String msg, {bool erro = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.dmSans()),
      backgroundColor: erro ? AppTheme.error : AppTheme.gold,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Calcular ──────────────────────────────

  void _calcular() {
    if (!_formKey.currentState!.validate()) return;
    final r = Motor.calcular(
      nome:          _nomeCtrl.text.trim(),
      renda:         _parseR$(_rendaCtrl.text),
      dependentes:   _dependentes,
      estadoCivil:   _estadoCivil,
      cotista:       _cotista,
      temTerreno:    _temTerreno,
      fgts:          _parseR$(_fgtsCtrl.text),
      entradaPropria: _parseR$(_entradaCtrl.text),
      piscina:       _piscina,
      parcelasEntrada: _parcelasEnt,
      cub:           _cubAtual,
    );
    setState(() { _resultado = r; _salvo = false; });
    _animCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
      }
    });
  }

  // ── Compartilhar ──────────────────────────

  void _compartilhar() {
    if (_resultado == null) return;
    Clipboard.setData(ClipboardData(text: _resultado!.resumoTexto));
    _snack('Análise copiada! Cole no WhatsApp ou e-mail.');
  }

  // ── Salvar ────────────────────────────────

  Future<void> _salvar() async {
    if (_resultado == null) return;
    setState(() => _salvando = true);
    try {
      final r = _resultado!;
      await Supabase.instance.client.schema('grupo_dantas').from('leads_triagem').insert({
        'nome': r.nomeCliente, 'telefone': _telefoneCtrl.text.trim(),
        'cidade': _cidadeCtrl.text.trim(), 'renda_mensal': r.renda,
        'fgts': r.fgts, 'recursos_proprios': r.entradaDisponivel,
        'credito_aprovado': r.valorFinanciado,
        'preferencias': {
          'estado_civil': r.estadoCivil.name,
          'dependentes':  r.dependentes,
          'cotista':      r.cotistaCaixa,
          'restricao':    _restricao,
          'tem_terreno':  r.temTerreno,
          'piscina':      _piscina,
        },
        'vgv_total': r.vgvOperavel, 'faixa': r.faixa.name,
        'modelo_id': r.modelo.id, 'modelo_nome': r.modelo.nome,
        'custo_construcao': r.custoConstrucao, 'margem_alvo': r.margemReais,
        'valor_teto_terreno': r.tetoTerreno, 'score_viabilidade': r.scoreGeral,
        'relatorio_json': {
          'subsidio': r.subsidio, 'gap_entrada': r.gapEntrada,
          'parcela_banco': r.parcelaRef, 'prazo_meses': r.prazoMeses,
          'taxa_anual': r.taxaAnual, 'sistema_amort': r.sistema.name,
          'alertas': r.alertas,
        },
        'status': 'novo', 'obra_id': ObraContext().obraId,
        'criado_por': Supabase.instance.client.auth.currentUser?.email,
      });
      setState(() { _salvo = true; _salvando = false; });
      _snack('Lead salvo!');
    } catch (e) {
      setState(() => _salvando = false);
      _snack('Erro: $e', erro: true);
    }
  }

  void _enviarViabilidade() {
    if (_resultado == null) return;
    final r = _resultado!;
    context.push('/viabilidade', extra: {
      'origem': 'triagem_lead', 'nome_lead': r.nomeCliente,
      'vgv_estimado': r.vgvOperavel, 'valor_teto_terreno': r.tetoTerreno,
      'modelo_id': r.modelo.id, 'modelo_nome': r.modelo.nome,
      'faixa': r.faixa.name, 'parcela_banco': r.parcelaRef, 'gap_entrada': r.gapEntrada,
    });
  }

  // ─────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _appBar(),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sec('👤  DADOS DO CLIENTE'),
            _buildDadosPessoais(),
            const SizedBox(height: 24),
            _sec('💰  RECURSOS DISPONÍVEIS'),
            _buildRecursos(),
            const SizedBox(height: 24),
            _sec('🏠  PREFERÊNCIAS'),
            _buildPreferencias(),
            const SizedBox(height: 28),
            _btnCalcular(),
            if (_resultado != null) ...[
              const SizedBox(height: 28),
              FadeTransition(opacity: _fadeAnim, child: _buildResultado(_resultado!)),
            ],
          ]),
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────

  AppBar _appBar() => AppBar(
    backgroundColor: AppTheme.background, elevation: 0,
    title: Row(children: [
      Icon(Icons.person_search_rounded, color: AppTheme.gold, size: 20),
      const SizedBox(width: 10),
      Text('TRIAGEM DE LEADS', style: GoogleFonts.syne(
          color: AppTheme.textPrimary, fontWeight: FontWeight.w700,
          fontSize: 16, letterSpacing: 1.5)),
    ]),
    actions: [
      if (_resultado != null)
        IconButton(
          onPressed: _compartilhar,
          icon: const Icon(Icons.share_rounded),
          tooltip: 'Compartilhar análise',
          color: AppTheme.textSecondary,
        ),
      if (_resultado != null && !_salvo)
        TextButton.icon(
          onPressed: _salvando ? null : _salvar,
          icon: _salvando
              ? const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
              : const Icon(Icons.save_rounded, size: 17),
          label: Text(_salvando ? 'Salvando…' : 'Salvar',
              style: GoogleFonts.syne(fontSize: 13)),
          style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
        ),
      if (_salvo)
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16),
            child: Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 22)),
    ],
  );

  Widget _sec(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(t, style: GoogleFonts.syne(
        color: AppTheme.gold, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.4)),
  );

  // ── Dados pessoais ────────────────────────

  Widget _buildDadosPessoais() => GDCard(child: Column(children: [
    _field(_nomeCtrl, 'Nome completo *', Icons.person_outline,
        validator: (v) => v == null || v.trim().isEmpty ? 'Obrigatório' : null),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: _field(_telefoneCtrl, 'Telefone / WhatsApp',
          Icons.phone_outlined, keyboard: TextInputType.phone)),
      const SizedBox(width: 12),
      Expanded(child: _field(_cidadeCtrl, 'Cidade *', Icons.location_city_outlined,
          validator: (v) => v == null || v.trim().isEmpty ? 'Obrigatório' : null)),
    ]),
    const SizedBox(height: 16),

    // Estado civil
    _labelRow('Estado Civil'),
    const SizedBox(height: 8),
    SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: EstadoCivil.values.map((e) {
        final labels = ['Solteiro(a)', 'Casado(a)', 'União Estável', 'Divorciado(a)'];
        final sel = _estadoCivil == e;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _estadoCivil = e),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: sel ? AppTheme.gold.withOpacity(0.12) : AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? AppTheme.gold : AppTheme.cardBorder)),
              child: Text(labels[e.index], style: GoogleFonts.dmSans(
                  color: sel ? AppTheme.gold : AppTheme.textSecondary,
                  fontSize: 12, fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
            ),
          ),
        );
      }).toList()),
    ),
    const SizedBox(height: 16),

    // Dependentes
    Row(children: [
      Expanded(child: _labelRow('Dependentes (filhos / cônjuge)')),
      _qtdBtn(Icons.remove, () => setState(() { if (_dependentes > 0) _dependentes--; })),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('$_dependentes', style: GoogleFonts.syne(
              color: AppTheme.gold, fontWeight: FontWeight.w700, fontSize: 18))),
      _qtdBtn(Icons.add, () => setState(() { if (_dependentes < 8) _dependentes++; })),
    ]),
    const SizedBox(height: 16),

    // Switches
    _switchRow('Tem conta na Caixa Econômica? (cotista)', _cotista,
            (v) => setState(() => _cotista = v)),
    const SizedBox(height: 8),
    _switchRow('Possui restrição no CPF (SPC/Serasa)?', _restricao,
            (v) => setState(() => _restricao = v),
        cor: _restricao ? AppTheme.error : null),
  ]));

  // ── Recursos ─────────────────────────────

  Widget _buildRecursos() => GDCard(child: Column(children: [
    _fieldR$(_rendaCtrl, 'Renda Familiar Bruta *', Icons.attach_money,
        validator: (v) {
          if (v == null || v.isEmpty) return 'Obrigatório';
          if (_parseR$(v) <= 0) return 'Valor inválido';
          return null;
        }),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: _fieldR$(_fgtsCtrl, 'Saldo FGTS', Icons.savings_outlined)),
      const SizedBox(width: 12),
      Expanded(child: _fieldR$(_entradaCtrl, 'Entrada própria', Icons.wallet_outlined)),
    ]),
    const SizedBox(height: 12),

    // Preview em tempo real
    ListenableBuilder(
      listenable: Listenable.merge([_rendaCtrl, _fgtsCtrl, _entradaCtrl]),
      builder: (_, __) {
        final renda  = _parseR$(_rendaCtrl.text);
        final fgts   = _parseR$(_fgtsCtrl.text);
        final ent    = _parseR$(_entradaCtrl.text);
        if (renda == 0) return const SizedBox.shrink();

        final taxa   = renda <= 8000
            ? Motor._taxaMCMV(renda, _cotista)
            : kTaxaSBPE;
        final prazo  = renda <= 8000 ? kPrazoMCMV : kPrazoSBPE;
        final cap    = Motor.capacidadeFinanciamento(renda, prazo, taxa);
        final sub    = subsidioMCMV(renda, _dependentes);
        final vgv    = cap + fgts + ent + sub;
        final faixa  = Motor.enquadrar(vgv);

        final faixaLabel = faixa == FaixaMercado.mcmv
            ? '🟢 MCMV' : faixa == FaixaMercado.sbpeInt
            ? '🟡 SBPE Intermediário' : '🔴 SBPE High-End';
        final corFaixa = faixa == FaixaMercado.mcmv
            ? AppTheme.success : faixa == FaixaMercado.sbpeInt
            ? AppTheme.warning : AppTheme.error;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
              color: corFaixa.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: corFaixa.withOpacity(0.35))),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Capacidade estimada', style: GoogleFonts.dmSans(
                  color: AppTheme.textSecondary, fontSize: 12)),
              Text(_fmtR$(vgv), style: GoogleFonts.syne(
                  color: corFaixa, fontWeight: FontWeight.w700, fontSize: 16)),
            ]),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Financiamento banco: ${_fmtR$(cap)}',
                  style: GoogleFonts.dmSans(color: AppTheme.textMuted, fontSize: 11)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: corFaixa.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(faixaLabel, style: GoogleFonts.syne(
                    color: corFaixa, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ]),
            if (sub > 0) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.card_giftcard_rounded, color: AppTheme.success, size: 13),
                const SizedBox(width: 4),
                Text('Subsídio MCMV estimado: ${_fmtR$(sub)}',
                    style: GoogleFonts.dmSans(color: AppTheme.success, fontSize: 11)),
              ]),
            ],
          ]),
        );
      },
    ),
  ]));

  // ── Preferências ─────────────────────────

  Widget _buildPreferencias() => GDCard(child: Column(children: [
    _switchRow('Já possui terreno?', _temTerreno,
            (v) => setState(() => _temTerreno = v)),
    const SizedBox(height: 8),
    _switchRow('Deseja piscina/área de lazer?', _piscina,
            (v) => setState(() => _piscina = v)),
    const SizedBox(height: 14),
    Row(children: [
      Expanded(child: Text('CUB Regional (R\$/m²)',
          style: GoogleFonts.dmSans(color: AppTheme.textSecondary, fontSize: 13))),
      SizedBox(width: 110, child: TextFormField(
        initialValue: kCubSP.toStringAsFixed(0),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (v) => setState(() => _cubAtual = double.tryParse(v) ?? kCubSP),
        style: GoogleFonts.syne(color: AppTheme.gold, fontSize: 14, fontWeight: FontWeight.w700),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          suffixText: '/m²',
          suffixStyle: GoogleFonts.dmSans(color: AppTheme.textMuted, fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      )),
    ]),
  ]));

  // ── Botão calcular ────────────────────────

  Widget _btnCalcular() => SizedBox(
    width: double.infinity, height: 52,
    child: ElevatedButton.icon(
      onPressed: _calcular,
      icon: const Icon(Icons.auto_awesome_rounded, size: 20),
      label: Text('ANALISAR CLIENTE', style: GoogleFonts.syne(
          fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: 15)),
      style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.gold, foregroundColor: AppTheme.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    ),
  );

  // ─────────────────────────────────────────
  // RESULTADO COMPLETO
  // ─────────────────────────────────────────

  Widget _buildResultado(ResultadoMotor r) {
    final corScore  = _cor(r.scoreGeral);
    final faixaLabel = r.faixa == FaixaMercado.mcmv ? '🟢 MCMV'
        : r.faixa == FaixaMercado.sbpeInt ? '🟡 SBPE Intermediário' : '🔴 SBPE High-End';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Score ────────────────────────────
      _sec('📋  RESULTADO DA ANÁLISE'),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: corScore.withOpacity(0.07), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: corScore.withOpacity(0.45))),
        child: Row(children: [
          Icon(_icon(r.scoreGeral), color: corScore, size: 36),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.scoreGeral == 'verde' ? 'VIÁVEL — Avançar'
                : r.scoreGeral == 'amarelo' ? 'VIÁVEL COM RESSALVAS' : 'INVIÁVEL — Revisar',
                style: GoogleFonts.syne(color: corScore, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 3),
            Text('$faixaLabel  ·  ${r.modelo.nome}',
                style: GoogleFonts.dmSans(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 3),
            Text('VGV: ${_fmtR$(r.vgvOperavel)}  ·  Parcela: ${_fmtR$(r.parcelaRef)}/mês',
                style: GoogleFonts.syne(color: AppTheme.textPrimary,
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ])),
        ]),
      ),
      const SizedBox(height: 12),

      // Botão compartilhar (inline também)
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _compartilhar,
          icon: const Icon(Icons.share_rounded, size: 16),
          label: Text('COMPARTILHAR ANÁLISE COMPLETA',
              style: GoogleFonts.syne(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.gold,
              side: BorderSide(color: AppTheme.gold.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
      ),

      // ── Alertas ──────────────────────────
      if (r.alertas.isNotEmpty) ...[
        const SizedBox(height: 16),
        ...r.alertas.map((a) {
          final isVerm = a.startsWith('⚠️');
          final cor = isVerm ? AppTheme.error : AppTheme.warning;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: cor.withOpacity(0.07), borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cor.withOpacity(0.35))),
            child: Text(a, style: GoogleFonts.dmSans(color: cor, fontSize: 13, height: 1.45)),
          );
        }),
      ],

      const SizedBox(height: 20),

      // ── Modelo recomendado ────────────────
      _sec('🏗️  MODELO RECOMENDADO'),
      _modeloCard(r.modelo),
      const SizedBox(height: 20),

      // ── Composição financeira ─────────────
      _sec('💵  COMPOSIÇÃO FINANCEIRA'),
      GDCard(child: Column(children: [
        _linha('Capacidade Total (VGV)', _fmtR$(r.vgvOperavel), 'verde'),
        if (r.subsidio > 0) _linha('  🎁 Subsídio MCMV incluído', _fmtR$(r.subsidio), 'verde'),
        _div(),
        _linha('Entrada Exigida (20%)', _fmtR$(r.entradaExigida), 'amarelo'),
        _linha('  Disponível (FGTS + entrada)',
            _fmtR$(r.entradaDisponivel),
            r.entradaDisponivel >= r.entradaExigida ? 'verde' : 'vermelho'),
        if (r.gapEntrada > 0)
          _linha('  ⚠️ Falta complementar', _fmtR$(r.gapEntrada), 'vermelho'),
        _div(),
        _linha('Valor Financiado', _fmtR$(r.valorFinanciado), 'verde'),
      ])),

      // ── Gap de entrada ────────────────────
      if (r.gapEntrada > 0) ...[
        const SizedBox(height: 20),
        _sec('📅  PARCELAMENTO DA ENTRADA'),
        GDCard(child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Parcelar em', style: GoogleFonts.dmSans(
                color: AppTheme.textSecondary, fontSize: 13)),
            Text('$_parcelasEnt× de ${_fmtR$(r.gapEntrada / _parcelasEnt)}',
                style: GoogleFonts.syne(color: AppTheme.gold,
                    fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
          Slider(
            value: _parcelasEnt.toDouble(), min: 1, max: 24, divisions: 23,
            activeColor: AppTheme.gold, inactiveColor: AppTheme.cardBorder,
            onChanged: (v) { setState(() => _parcelasEnt = v.round()); _calcular(); },
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('1×', style: GoogleFonts.dmSans(color: AppTheme.textMuted, fontSize: 11)),
            Text('24×', style: GoogleFonts.dmSans(color: AppTheme.textMuted, fontSize: 11)),
          ]),
        ])),
      ],

      const SizedBox(height: 20),

      // ── Simulação bancária ────────────────
      _sec('🏦  SIMULAÇÃO BANCÁRIA'),
      GDCard(child: Column(children: [
        _linha('Sistema', r.sistema == SistemaAmort.sac
            ? 'SAC — parcelas decrescentes' : 'PRICE — parcelas fixas', 'verde'),
        _linha('Taxa', '${_fmtPct(r.taxaAnual)} a.a.${r.faixa == FaixaMercado.mcmv ? "" : " + TR"}', 'verde'),
        _linha('Prazo', '${r.prazoMeses} meses (${(r.prazoMeses / 12).toStringAsFixed(0)} anos)', 'verde'),
        _div(),
        if (r.sistema == SistemaAmort.sac) ...[
          _linha('1ª Parcela (maior)', _fmtR$(r.parcelaPrimeira),
              r.comprometimento > 0.30 ? 'vermelho' : r.comprometimento > 0.25 ? 'amarelo' : 'verde'),
          _linha('Última Parcela (menor)', _fmtR$(r.parcelaUltima), 'verde'),
        ] else
          _linha('Parcela Mensal Fixa', _fmtR$(r.parcelaPrice),
              r.comprometimento > 0.30 ? 'vermelho' : r.comprometimento > 0.25 ? 'amarelo' : 'verde'),
        _div(),
        _linha('Comprometimento de Renda',
            '${_fmtPct(r.comprometimento)} de ${_fmtR$(r.renda)}/mês',
            r.comprometimento > 0.30 ? 'vermelho' : r.comprometimento > 0.25 ? 'amarelo' : 'verde'),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
              value: r.comprometimento.clamp(0, 1),
              minHeight: 7, backgroundColor: AppTheme.cardBorder,
              valueColor: AlwaysStoppedAnimation(
                  r.comprometimento > 0.30 ? AppTheme.error
                      : r.comprometimento > 0.25 ? AppTheme.warning : AppTheme.success)),
        ),
        Padding(padding: const EdgeInsets.only(top: 4), child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0%', style: GoogleFonts.dmSans(color: AppTheme.textMuted, fontSize: 10)),
            Text('▲ Limite Caixa: 30%', style: GoogleFonts.dmSans(color: AppTheme.textMuted, fontSize: 10)),
          ],
        )),
      ])),

      const SizedBox(height: 20),

      // ── Lote virtual ─────────────────────
      if (!r.temTerreno) ...[
        _sec('🎯  ALERTA DO LOTE VIRTUAL'),
        _loteCard(r),
        const SizedBox(height: 20),
      ],

      // ── Botões finais ─────────────────────
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: _salvando ? null : _salvar,
          icon: Icon(_salvo ? Icons.check_rounded : Icons.save_rounded, size: 16),
          label: Text(_salvo ? 'Salvo!' : 'Salvar',
              style: GoogleFonts.syne(fontSize: 13)),
          style: OutlinedButton.styleFrom(
              foregroundColor: _salvo ? AppTheme.success : AppTheme.textSecondary,
              side: BorderSide(color: _salvo ? AppTheme.success : AppTheme.cardBorder),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        )),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton.icon(
          onPressed: r.scoreGeral != 'vermelho' ? _enviarViabilidade : null,
          icon: const Icon(Icons.send_rounded, size: 16),
          label: Text('ENVIAR PARA\nVIABILIDADE',
              textAlign: TextAlign.center,
              style: GoogleFonts.syne(fontSize: 12, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold, foregroundColor: AppTheme.background,
              disabledBackgroundColor: AppTheme.cardBorder,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        )),
      ]),
    ]);
  }

  // ── Modelo card ───────────────────────────

  Widget _modeloCard(ModeloProduto m) {
    final Color fc = m.faixa == FaixaMercado.mcmv
        ? AppTheme.success : m.faixa == FaixaMercado.sbpeInt
        ? AppTheme.warning : AppTheme.error;
    final String emoji = m.faixa == FaixaMercado.mcmv ? '🟢'
        : m.faixa == FaixaMercado.sbpeInt ? '🟡' : '🔴';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: fc.withOpacity(0.06), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: fc.withOpacity(0.4), width: 1.5)),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('[${m.id}]', style: GoogleFonts.syne(
              color: fc.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(m.nome, style: GoogleFonts.syne(
              color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 2),
          Text('${m.descricao}  ·  ${m.areaMedia.toStringAsFixed(0)}m²  ·  CUB ×${m.cubMultiplier}',
              style: GoogleFonts.dmSans(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text('Custo estimado: ${_fmtR$(m.custo(_cubAtual))}  ·  Margem: ${_fmtPct(m.margemAlvo)}',
              style: GoogleFonts.dmSans(color: AppTheme.textMuted, fontSize: 11)),
        ])),
      ]),
    );
  }

  // ── Lote virtual ──────────────────────────

  Widget _loteCard(ResultadoMotor r) {
    final teto = r.tetoTerreno;
    final cor  = teto <= 0 ? AppTheme.error : teto < 30000 ? AppTheme.warning : AppTheme.success;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cor.withOpacity(0.06), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cor.withOpacity(0.5), width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _linhaF('VGV Total', _fmtR$(r.vgvOperavel), AppTheme.textPrimary),
        _linhaF('− Custo Construção', _fmtR$(r.custoConstrucao), AppTheme.error.withOpacity(0.8)),
        _linhaF('− Margem (${_fmtPct(r.modelo.margemAlvo)})', _fmtR$(r.margemReais), AppTheme.error.withOpacity(0.8)),
        Divider(color: AppTheme.cardBorder, height: 14),
        _linhaF('= Teto do Terreno', _fmtR$(teto), cor, bold: true),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(
              teto <= 0
                  ? 'VGV insuficiente para cobrir construção + margem. Considere produto menor ou aumento do crédito.'
                  : '🎯 Localize um lote na região com valor de compra de até ${_fmtR$(teto)} para viabilizar este cliente.',
              style: GoogleFonts.dmSans(color: cor, fontSize: 13, height: 1.5)),
        ),
      ]),
    );
  }

  // ── Layout helpers ─────────────────────────

  Widget _linha(String label, String valor, String score) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(_icon(score), color: _cor(score), size: 14),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: GoogleFonts.dmSans(
          color: AppTheme.textSecondary, fontSize: 13))),
      Text(valor, style: GoogleFonts.syne(
          color: _cor(score), fontWeight: FontWeight.w700, fontSize: 13)),
    ]),
  );

  Widget _linhaF(String label, String valor, Color cor, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Expanded(child: Text(label, style: GoogleFonts.dmSans(
          color: bold ? AppTheme.textPrimary : AppTheme.textSecondary,
          fontSize: 12, fontWeight: bold ? FontWeight.w700 : FontWeight.normal))),
      Text(valor, style: GoogleFonts.syne(color: cor, fontSize: 13,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
    ]),
  );

  Widget _div() => Divider(color: AppTheme.cardBorder, height: 16, thickness: 1);

  Widget _labelRow(String t) => Text(t, style: GoogleFonts.dmSans(
      color: AppTheme.textSecondary, fontSize: 13));

  Widget _qtdBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
            color: AppTheme.gold.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.gold.withOpacity(0.4))),
        child: Icon(icon, color: AppTheme.gold, size: 16)),
  );

  Widget _switchRow(String label, bool val, ValueChanged<bool> onChange, {Color? cor}) => Row(children: [
    Expanded(child: Text(label, style: GoogleFonts.dmSans(
        color: cor ?? AppTheme.textSecondary, fontSize: 13))),
    Switch(
      value: val, onChanged: onChange,
      activeColor: cor ?? AppTheme.gold,
      inactiveThumbColor: AppTheme.textMuted,
      inactiveTrackColor: AppTheme.cardBorder,
    ),
  ]);

  // ── Input helpers ─────────────────────────

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {String? Function(String?)? validator, TextInputType keyboard = TextInputType.text}) =>
      TextFormField(
        controller: ctrl, keyboardType: keyboard, validator: validator,
        style: GoogleFonts.dmSans(color: AppTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(labelText: label,
            prefixIcon: Icon(icon, color: AppTheme.gold.withOpacity(0.7), size: 18)),
      );

  Widget _fieldR$(TextEditingController ctrl, String label, IconData icon,
      {String? Function(String?)? validator}) =>
      TextFormField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
        validator: validator,
        style: GoogleFonts.dmSans(color: AppTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(labelText: label, prefixText: 'R\$ ',
            prefixStyle: GoogleFonts.dmSans(color: AppTheme.textSecondary, fontSize: 14),
            prefixIcon: Icon(icon, color: AppTheme.gold.withOpacity(0.7), size: 18)),
      );
}