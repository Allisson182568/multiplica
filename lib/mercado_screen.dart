import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_theme.dart';
import 'gd_card.dart';
import 'main.dart'; // groqApiKey

// ─────────────────────────────────────────────────────────────
// MODELO
// ─────────────────────────────────────────────────────────────

enum TipoImovel    { casa, terreno, apartamento }
enum SegmentoMercado { mcmv, intermediario, altopadrao }
enum FonteAnuncio  { vivareal, zapimoveis, olx, direto, outro }

class AnuncioMercado {
  final String id;
  final TipoImovel tipo;
  final SegmentoMercado segmento;
  final String bairro;
  final double preco;
  final double area;
  final int quartos;
  final FonteAnuncio fonte;
  final String obs;
  final DateTime cadastradoEm;

  AnuncioMercado({
    required this.id,
    required this.tipo,
    required this.segmento,
    required this.bairro,
    required this.preco,
    required this.area,
    required this.quartos,
    required this.fonte,
    required this.obs,
    required this.cadastradoEm,
  });

  double? get precoM2 => area > 0 ? preco / area : null;

  String get tipoLabel => switch (tipo) {
    TipoImovel.casa        => 'Casa',
    TipoImovel.terreno     => 'Terreno',
    TipoImovel.apartamento => 'Apartamento',
  };
  String get segLabel => switch (segmento) {
    SegmentoMercado.mcmv          => 'MCMV',
    SegmentoMercado.intermediario => 'Intermediário',
    SegmentoMercado.altopadrao    => 'Alto padrão',
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'tipo': tipo.name,
    'segmento': segmento.name,
    'bairro': bairro,
    'preco': preco,
    'area': area,
    'quartos': quartos,
    'fonte': fonte.name,
    'obs': obs,
    // cadastrado_em omitido — banco usa default now()
  };

  factory AnuncioMercado.fromJson(Map<String, dynamic> j) => AnuncioMercado(
    id: j['id'],
    tipo: TipoImovel.values.firstWhere((e) => e.name == j['tipo'],
        orElse: () => TipoImovel.casa),
    segmento: SegmentoMercado.values.firstWhere((e) => e.name == j['segmento'],
        orElse: () => SegmentoMercado.mcmv),
    bairro: j['bairro'] ?? '',
    preco: (j['preco'] as num).toDouble(),
    area: (j['area'] as num).toDouble(),
    quartos: (j['quartos'] as num).toInt(),
    fonte: FonteAnuncio.values.firstWhere((e) => e.name == j['fonte'],
        orElse: () => FonteAnuncio.outro),
    obs: j['obs'] ?? '',
    cadastradoEm: j['cadastrado_em'] != null
        ? DateTime.tryParse(j['cadastrado_em'].toString()) ?? DateTime.now()
        : DateTime.now(),
  );
}

// ─────────────────────────────────────────────────────────────
// PARSER — Viva Real / Zap (ctrl+A, ctrl+C, colar)
// ─────────────────────────────────────────────────────────────

class _Parser {
  // Título: aceita "m²" (desktop) ou "m..." (mobile truncado)
  static final _reTitulo = RegExp(
    r'^(Casa|Sobrado|Apartamento|Apto|Terreno|Lote|Flat|Studio|Cobertura)'
    r'.+?(\d+)\s*(?:m²|m\.{2,})',
    caseSensitive: false,
  );
  // Bairro desktop: "Nome do Bairro, Piracicaba"
  static final _reBairroCidade   = RegExp(r'^(.+?),\s*Piracicaba', caseSensitive: false);
  // Bairro mobile truncado: "Nome do Bairro, Pir..."
  static final _reBairroTruncado = RegExp(r'^(.+?),\s*Pir\.{2,}', caseSensitive: false);
  // Preço: linha com apenas "R$ NNN.NNN"
  static final _rePreco          = RegExp(r'^R\$\s*([\d.]+)\s*$');
  // Quartos no texto: "3 quartos" ou "Quantidade de quartos 3"
  static final _reQuartosTexto   = RegExp(r'(\d+)\s*quartos?|quartos?\s*(\d+)', caseSensitive: false);
  // Quartos no título desktop: "3 quartos"
  static final _reQuartosTitulo  = RegExp(r'(\d+)\s*quarto', caseSensitive: false);
  // Linha de área isolada: "90 m²"
  static final _reAreaLinha      = RegExp(r'^\d+\s*m²$');
  // Número simples (1-2 dígitos) = quartos/banheiros/vagas no mobile
  static final _reNumSimples     = RegExp(r'^\d{1,2}$');

  static List<AnuncioMercado> parse(String texto, FonteAnuncio fonte) {
    final linhas = texto.split('\n').map((l) => l.trim()).toList();
    final resultado = <AnuncioMercado>[];

    for (int i = 0; i < linhas.length; i++) {
      final linha = linhas[i];
      final mTitulo = _reTitulo.firstMatch(linha);
      if (mTitulo == null) continue;

      final tipoRaw = mTitulo.group(1)!.toLowerCase();
      final area    = double.tryParse(mTitulo.group(2)!) ?? 0;

      String bairro = '';
      double preco  = 0;
      int    quartos = 0;

      // Quartos no próprio título (desktop: "Casa... 3 quartos...")
      final mQTitulo = _reQuartosTitulo.firstMatch(linha);
      if (mQTitulo != null) quartos = int.parse(mQTitulo.group(1)!);

      final fim = (i + 18).clamp(0, linhas.length);
      for (int j = i + 1; j < fim; j++) {
        final l2 = linhas[j];
        if (l2.isEmpty) continue;

        // ── Bairro ──────────────────────────────────────────
        if (bairro.isEmpty) {
          final mb = _reBairroCidade.firstMatch(l2);
          if (mb != null) { bairro = mb.group(1)!.trim(); }

          final mb2 = _reBairroTruncado.firstMatch(l2);
          if (mb2 != null) { bairro = mb2.group(1)!.trim(); }
        }

        // ── Preço ────────────────────────────────────────────
        final mPreco = _rePreco.firstMatch(l2);
        if (mPreco != null && preco == 0) {
          preco = double.tryParse(mPreco.group(1)!.replaceAll('.', '')) ?? 0;
        }

        // ── Quartos ──────────────────────────────────────────
        if (quartos == 0) {
          // Desktop: "Quantidade de quartos 3" ou "3 quartos"
          final mq = _reQuartosTexto.firstMatch(l2);
          if (mq != null) {
            quartos = int.parse(mq.group(1) ?? mq.group(2)!);
          }
          // Mobile: linha "NNN m²" seguida de números simples (quartos, banheiros, vagas)
          if (_reAreaLinha.hasMatch(l2)) {
            final nums = <int>[];
            for (int k = j + 1; k < (j + 5).clamp(0, linhas.length); k++) {
              if (_reNumSimples.hasMatch(linhas[k])) {
                nums.add(int.parse(linhas[k]));
              } else {
                break;
              }
            }
            if (nums.isNotEmpty) quartos = nums[0]; // primeiro = quartos
          }
        }
      }

      if (bairro.isEmpty || preco <= 0) continue;

      final tipo = switch (tipoRaw) {
        'sobrado'     => TipoImovel.casa,
        'casa'        => TipoImovel.casa,
        'terreno'     => TipoImovel.terreno,
        'lote'        => TipoImovel.terreno,
        'apartamento' => TipoImovel.apartamento,
        'apto'        => TipoImovel.apartamento,
        'flat'        => TipoImovel.apartamento,
        'studio'      => TipoImovel.apartamento,
        'cobertura'   => TipoImovel.apartamento,
        _             => TipoImovel.casa,
      };

      // Segmento pelo preço total para todos (imóveis e terrenos)
      // Terrenos: até R$200k = MCMV, até R$400k = Intermediário, acima = Alto padrão
      final segmento = tipo == TipoImovel.terreno
          ? (preco <= 200000
          ? SegmentoMercado.mcmv
          : preco <= 400000
          ? SegmentoMercado.intermediario
          : SegmentoMercado.altopadrao)
          : (preco <= 350000
          ? SegmentoMercado.mcmv
          : preco <= 600000
          ? SegmentoMercado.intermediario
          : SegmentoMercado.altopadrao);

      resultado.add(AnuncioMercado(
        id: '${DateTime.now().microsecondsSinceEpoch}_$i',
        tipo: tipo,
        segmento: segmento,
        bairro: bairro,
        preco: preco,
        area: area,
        quartos: tipo == TipoImovel.terreno ? 0 : quartos,
        fonte: fonte,
        obs: '',
        cadastradoEm: DateTime.now(),
      ));
    }

    return resultado;
  }
}

// ─────────────────────────────────────────────────────────────
// SCREEN PRINCIPAL
// ─────────────────────────────────────────────────────────────

class MercadoScreen extends StatefulWidget {
  const MercadoScreen({super.key});
  @override
  State<MercadoScreen> createState() => _MercadoScreenState();
}

class _MercadoScreenState extends State<MercadoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _supa = Supabase.instance.client;
  List<AnuncioMercado> _anuncios = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _carregar();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _carregar() async {
    try {
      final rows = await _supa
          .schema('grupo_dantas')
          .from('anuncios_mercado')
          .select()
          .order('cadastrado_em', ascending: false)
          .limit(500);
      debugPrint('Mercado: carregados ${(rows as List).length} anúncios do banco');
      if (mounted) {
        setState(() {
          _anuncios = (rows as List)
              .map((r) => AnuncioMercado.fromJson(r as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Mercado _carregar ERRO: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao carregar do banco: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
        ));
      }
    }
  }

  // Salva em lote — um único insert para qualquer quantidade de anúncios
  Future<void> _salvarLote(List<AnuncioMercado> lista) async {
    if (lista.isEmpty) return;
    try {
      const chunkSize = 100;
      int salvos = 0;
      for (int i = 0; i < lista.length; i += chunkSize) {
        final chunk = lista.sublist(i, (i + chunkSize).clamp(0, lista.length));
        await _supa
            .schema('grupo_dantas')
            .from('anuncios_mercado')
            .insert(chunk.map((a) => a.toJson()).toList());
        salvos += chunk.length;
        debugPrint('Mercado: salvos $salvos/${lista.length} anúncios');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${lista.length} anúncios salvos no banco com sucesso!'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      debugPrint('Mercado _salvarLote ERRO: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao salvar no banco: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
        ));
      }
    }
  }

  Future<void> _deletar(String id) async {
    try { await _supa.schema('grupo_dantas').from('anuncios_mercado').delete().eq('id', id); } catch (_) {}
  }

  void _addAnuncios(List<AnuncioMercado> lista) {
    setState(() => _anuncios.insertAll(0, lista));
    _salvarLote(lista); // lote único, não loop
  }

  void _remover(String id) {
    setState(() => _anuncios.removeWhere((a) => a.id == id));
    _deletar(id);
  }

  void _limparTudo() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Limpar tudo?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Remove os ${_anuncios.length} anúncios cadastrados.',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              final ids = _anuncios.map((a) => a.id).toList();
              setState(() => _anuncios.clear());
              for (final id in ids) { _deletar(id); }
            },
            child: const Text('Limpar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (b) => AppTheme.goldGradient.createShader(b),
          child: const Text('Mercado Piracicaba',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        ),
        actions: [
          if (_anuncios.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: AppTheme.textMuted),
              tooltip: 'Limpar todos',
              onPressed: _limparTudo,
            ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.gold,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.gold,
          dividerColor: AppTheme.cardBorder,
          tabs: [
            Tab(icon: const Icon(Icons.content_paste_rounded, size: 15),
                text: 'Colar (${_anuncios.length})'),
            const Tab(icon: Icon(Icons.bar_chart_rounded, size: 15), text: 'Painel'),
            const Tab(icon: Icon(Icons.psychology_rounded, size: 15),  text: 'Análise IA'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _TabColar(onAdd: _addAnuncios, onRemove: _remover, anuncios: _anuncios),
          _TabPainel(anuncios: _anuncios),
          _TabAnaliseIA(anuncios: _anuncios),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ABA 1 — COLAR TEXTO
// ─────────────────────────────────────────────────────────────

class _TabColar extends StatefulWidget {
  final List<AnuncioMercado> anuncios;
  final ValueChanged<List<AnuncioMercado>> onAdd;
  final ValueChanged<String> onRemove;
  const _TabColar({required this.anuncios, required this.onAdd, required this.onRemove});
  @override
  State<_TabColar> createState() => _TabColarState();
}

class _TabColarState extends State<_TabColar> {
  final _ctrl = TextEditingController();
  FonteAnuncio _fonte = FonteAnuncio.vivareal;
  List<AnuncioMercado> _preview = [];
  bool _mostrandoPreview = false;
  bool _confirmando = false;

  String _fmtPreco(double v) =>
      'R\$ ${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  void _parsear() {
    final texto = _ctrl.text.trim();
    if (texto.isEmpty) return;
    final lista = _Parser.parse(texto, _fonte);
    setState(() { _preview = lista; _mostrandoPreview = true; });
    if (lista.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nenhum anúncio reconhecido. Verifique o texto colado.'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _confirmar() {
    if (_preview.isEmpty || _confirmando) return;
    _confirmando = true;
    final lista = List<AnuncioMercado>.from(_preview);
    widget.onAdd(lista);
    final qtd = lista.length;
    setState(() { _preview = []; _mostrandoPreview = false; _ctrl.clear(); _confirmando = false; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$qtd anúncios enviados para salvar!'),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  void _cancelarPreview() =>
      setState(() { _preview = []; _mostrandoPreview = false; });

  Color _segColor(SegmentoMercado s) => switch (s) {
    SegmentoMercado.mcmv          => AppTheme.success,
    SegmentoMercado.intermediario => Colors.blue,
    SegmentoMercado.altopadrao    => AppTheme.gold,
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Instrução ────────────────────────────────────────
        GDCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.tips_and_updates_rounded,
                  color: AppTheme.gold, size: 18),
              const SizedBox(width: 8),
              const Text('Como usar',
                  style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
            const SizedBox(height: 10),
            const Text(
              '1. Abra o Viva Real ou Zap Imóveis no navegador\n'
                  '2. Filtre por Piracicaba e o tipo desejado\n'
                  '3. Selecione tudo (Ctrl+A) e copie (Ctrl+C)\n'
                  '4. Cole abaixo e clique em Extrair anúncios',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.7),
            ),
          ]),
        ).animate().fadeIn(),
        const SizedBox(height: 14),

        // ── Fonte + Área de colar ────────────────────────────
        if (!_mostrandoPreview) ...[
          GDCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Selector de fonte
              Row(children: [
                const Text('Fonte:',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(width: 10),
                ...FonteAnuncio.values.where((f) =>
                f == FonteAnuncio.vivareal ||
                    f == FonteAnuncio.zapimoveis ||
                    f == FonteAnuncio.olx).map((f) {
                  final sel = _fonte == f;
                  final label = switch (f) {
                    FonteAnuncio.vivareal   => 'Viva Real',
                    FonteAnuncio.zapimoveis => 'Zap Imóveis',
                    FonteAnuncio.olx        => 'OLX',
                    _                       => '',
                  };
                  return GestureDetector(
                    onTap: () => setState(() => _fonte = f),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: sel ? AppTheme.gold.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? AppTheme.gold : AppTheme.cardBorder),
                      ),
                      child: Text(label,
                          style: TextStyle(
                              color: sel ? AppTheme.gold : AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                    ),
                  );
                }),
              ]),
              const SizedBox(height: 12),
              // Textarea
              TextField(
                controller: _ctrl,
                maxLines: 10,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, height: 1.5),
                decoration: InputDecoration(
                  hintText: 'Cole aqui o texto copiado do site (Ctrl+A → Ctrl+C → Ctrl+V)...',
                  hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.cardBorder),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _parsear,
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                      label: const Text('Extrair anúncios',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.gold,
                        foregroundColor: AppTheme.background,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        _ctrl.text = data!.text!;
                      }
                    },
                    icon: const Icon(Icons.content_paste_rounded, size: 16),
                    label: const Text('Colar área', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.cardBorder),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),
            ]),
          ).animate().fadeIn(),
        ],

        // ── Preview dos extraídos ────────────────────────────
        if (_mostrandoPreview && _preview.isNotEmpty) ...[
          GDCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_preview.length} anúncios reconhecidos',
                      style: const TextStyle(
                          color: AppTheme.gold, fontWeight: FontWeight.w700, fontSize: 13)),
                  TextButton(
                    onPressed: _cancelarPreview,
                    child: const Text('Voltar',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Revise abaixo antes de confirmar.',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),

              // Mini tabela
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.cardBorder),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(children: [
                  // Cabeçalho
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    ),
                    child: const Row(children: [
                      Expanded(flex: 3, child: Text('Bairro',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 11,
                              fontWeight: FontWeight.w600))),
                      Expanded(flex: 2, child: Text('Preço',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 11,
                              fontWeight: FontWeight.w600))),
                      Expanded(flex: 1, child: Text('Área',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 11,
                              fontWeight: FontWeight.w600))),
                      Expanded(flex: 2, child: Text('R\u0024/m²',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 11,
                              fontWeight: FontWeight.w600))),
                      SizedBox(width: 50, child: Text('Seg.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 11,
                              fontWeight: FontWeight.w600))),
                    ]),
                  ),
                  const Divider(height: 1, color: AppTheme.cardBorder),
                  // Linhas
                  ...(_preview.asMap().entries.map((e) {
                    final a = e.value;
                    final isLast = e.key == _preview.length - 1;
                    final cor = _segColor(a.segmento);
                    return Column(children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        child: Row(children: [
                          Expanded(flex: 3, child: Text(a.bairro,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary, fontSize: 11))),
                          Expanded(flex: 2, child: Text(_fmtPreco(a.preco),
                              style: const TextStyle(
                                  color: AppTheme.textPrimary, fontSize: 11))),
                          Expanded(flex: 1, child: Text('${a.area.toStringAsFixed(0)}m²',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 11))),
                          Expanded(flex: 2, child: Text(
                              a.precoM2 != null
                                  ? 'R\$ ${a.precoM2!.toStringAsFixed(0)}'
                                  : '—',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 11))),
                          SizedBox(
                            width: 50,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: cor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(a.segLabel,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: cor, fontSize: 9,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ]),
                      ),
                      if (!isLast) const Divider(height: 1, color: AppTheme.cardBorder),
                    ]);
                  })),
                ]),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _confirmar,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text('Confirmar ${_preview.length} anúncios',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
          ).animate().fadeIn(),
        ],

        const SizedBox(height: 20),

        // ── Lista salva ───────────────────────────────────────
        if (widget.anuncios.isNotEmpty && !_mostrandoPreview) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${widget.anuncios.length} anúncios salvos',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
              TextButton.icon(
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) {
                    _ctrl.text = data!.text!;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Texto colado! Clique em Extrair anúncios.'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ));
                  }
                },
                icon: const Icon(Icons.add_rounded, size: 14),
                label: const Text('Adicionar mais', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: AppTheme.gold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...widget.anuncios.take(50).map((a) => _AnuncioTile(
            a: a,
            onRemove: () => widget.onRemove(a.id),
          ).animate().fadeIn(delay: 20.ms)),
          if (widget.anuncios.length > 50)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ ${widget.anuncios.length - 50} anúncios não exibidos (use o Painel)',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
        ],

        if (widget.anuncios.isEmpty && !_mostrandoPreview)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.storefront_outlined, color: AppTheme.textMuted, size: 48),
                SizedBox(height: 12),
                Text('Nenhum anúncio ainda.',
                    style: TextStyle(color: AppTheme.textSecondary)),
                SizedBox(height: 4),
                Text('Cole o texto do Viva Real ou Zap acima.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _AnuncioTile extends StatelessWidget {
  final AnuncioMercado a;
  final VoidCallback onRemove;
  const _AnuncioTile({required this.a, required this.onRemove});

  String _fmt(double v) =>
      'R\$ ${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  Color get _cor => switch (a.segmento) {
    SegmentoMercado.mcmv          => AppTheme.success,
    SegmentoMercado.intermediario => Colors.blue,
    SegmentoMercado.altopadrao    => AppTheme.gold,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: _cor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            switch (a.tipo) {
              TipoImovel.casa        => Icons.home_rounded,
              TipoImovel.terreno     => Icons.landscape_rounded,
              TipoImovel.apartamento => Icons.apartment_rounded,
            },
            color: _cor, size: 16,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(a.bairro,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12, fontWeight: FontWeight.w600))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _cor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(a.segLabel,
                  style: TextStyle(color: _cor, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ]),
          Text(
            '${_fmt(a.preco)}  ·  ${a.area.toStringAsFixed(0)}m²'
                '${a.precoM2 != null ? '  ·  R\$ ${a.precoM2!.toStringAsFixed(0)}/m²' : ''}'
                '${a.tipo != TipoImovel.terreno && a.quartos > 0 ? '  ·  ${a.quartos}q' : ''}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
          ),
        ])),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              color: AppTheme.textMuted, size: 16),
          onPressed: onRemove,
          visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ABA 2 — PAINEL DE MERCADO
// ─────────────────────────────────────────────────────────────

class _TabPainel extends StatefulWidget {
  final List<AnuncioMercado> anuncios;
  const _TabPainel({required this.anuncios});
  @override
  State<_TabPainel> createState() => _TabPainelState();
}

class _TabPainelState extends State<_TabPainel> {
  SegmentoMercado? _filtroSeg;
  TipoImovel?      _filtroTipo;

  List<AnuncioMercado> get _dados {
    var lista = widget.anuncios;
    if (_filtroSeg  != null) lista = lista.where((a) => a.segmento == _filtroSeg).toList();
    if (_filtroTipo != null) lista = lista.where((a) => a.tipo == _filtroTipo).toList();
    return lista;
  }

  String _fmt(double v) =>
      'R\$ ${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  double _avg(List<double> l) =>
      l.isEmpty ? 0 : l.reduce((a, b) => a + b) / l.length;

  double _median(List<double> l) {
    if (l.isEmpty) return 0;
    final s = [...l]..sort();
    return s[s.length ~/ 2];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.anuncios.length < 3) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.bar_chart_rounded, color: AppTheme.textMuted, size: 56),
        SizedBox(height: 12),
        Text('Adicione pelo menos 3 anúncios',
            style: TextStyle(color: AppTheme.textSecondary)),
        SizedBox(height: 4),
        Text('Cole texto do Viva Real na aba anterior.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      ]));
    }

    final dados    = _dados;
    final precos   = dados.map((a) => a.preco).toList();
    final pm2s     = dados.where((a) => a.area > 0)
        .map((a) => a.preco / a.area).toList();
    final terrenos = dados.where((a) => a.tipo == TipoImovel.terreno).toList();

    // Agrupar R$/m² por bairro
    final bairroMap = <String, List<double>>{};
    for (final a in dados) {
      if (a.tipo != TipoImovel.terreno && a.area > 0) {
        bairroMap.putIfAbsent(a.bairro, () => []).add(a.preco / a.area);
      }
    }
    final bairros = bairroMap.entries
        .map((e) => MapEntry(e.key, _avg(e.value)))
        .toList()..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Filtros de tipo
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _tipoBtn(null, 'Todos os tipos', Icons.apps_rounded),
            _tipoBtn(TipoImovel.casa, 'Casas', Icons.home_rounded),
            _tipoBtn(TipoImovel.terreno, 'Terrenos', Icons.landscape_rounded),
            _tipoBtn(TipoImovel.apartamento, 'Apartamentos', Icons.apartment_rounded),
          ]),
        ),
        const SizedBox(height: 6),
        // Filtros de segmento
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _segBtn(null, 'Todos os segmentos'),
            _segBtn(SegmentoMercado.mcmv, 'MCMV'),
            _segBtn(SegmentoMercado.intermediario, 'Intermediário'),
            _segBtn(SegmentoMercado.altopadrao, 'Alto padrão'),
          ]),
        ),
        const SizedBox(height: 14),

        // Métricas
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.0,
          children: [
            _metricCard('Total', '${dados.length} anúncios',
                sub: '${terrenos.length} terrenos, ${dados.length - terrenos.length} imóveis'),
            _metricCard('Ticket médio', _fmt(_avg(precos)),
                sub: 'mediana ${_fmt(_median(precos))}'),
            _metricCard('R\u0024/m² médio',
                pm2s.isEmpty ? '—' : 'R\$ ${_avg(pm2s).toStringAsFixed(0)}',
                sub: 'imóveis construídos'),
            _metricCard('Faixa de preço',
                precos.isEmpty ? '—' : _fmt(precos.reduce((a, b) => a < b ? a : b)),
                sub: precos.isEmpty ? '' : 'até ${_fmt(precos.reduce((a, b) => a > b ? a : b))}'),
          ],
        ),
        const SizedBox(height: 16),

        // R$/m² por bairro
        if (bairros.isNotEmpty)
          GDCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('R\u0024/m² médio por bairro',
                  style: TextStyle(color: AppTheme.gold, fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              ...bairros.take(20).map((e) {
                final pct = bairros.first.value > 0 ? e.value / bairros.first.value : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Text(e.key, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12))),
                      Text('R\$ ${e.value.toStringAsFixed(0)}/m²',
                          style: const TextStyle(color: AppTheme.gold,
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 4),
                    LayoutBuilder(builder: (ctx, box) => Stack(children: [
                      Container(height: 5, width: box.maxWidth,
                          decoration: BoxDecoration(color: AppTheme.cardBorder,
                              borderRadius: BorderRadius.circular(3))),
                      Container(height: 5, width: box.maxWidth * pct,
                          decoration: BoxDecoration(color: AppTheme.gold,
                              borderRadius: BorderRadius.circular(3))),
                    ])),
                  ]),
                );
              }),
            ]),
          ).animate().fadeIn(),

        const SizedBox(height: 12),

        // Distribuição por segmento
        GDCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Distribuição por segmento',
                style: TextStyle(color: AppTheme.gold, fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...SegmentoMercado.values.map((seg) {
              final count = dados.where((a) => a.segmento == seg).length;
              final pct   = dados.isNotEmpty ? count / dados.length : 0.0;
              final pm2Seg = dados.where((a) => a.segmento == seg &&
                  a.area > 0)
                  .map((a) => a.preco / a.area).toList();
              final cor = switch (seg) {
                SegmentoMercado.mcmv          => AppTheme.success,
                SegmentoMercado.intermediario => Colors.blue,
                SegmentoMercado.altopadrao    => AppTheme.gold,
              };
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [
                      Container(width: 10, height: 10,
                          decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(switch (seg) {
                        SegmentoMercado.mcmv          => 'MCMV (até R\$350k)',
                        SegmentoMercado.intermediario => 'Intermediário (R\$350k–R\$600k)',
                        SegmentoMercado.altopadrao    => 'Alto padrão (acima R\$600k)',
                      }, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                    ]),
                    Text('$count  (${(pct * 100).toStringAsFixed(0)}%)',
                        style: TextStyle(color: cor, fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ]),
                  if (pm2Seg.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 18, top: 2),
                      child: Text('R\u0024/m² médio: R\$ ${_avg(pm2Seg).toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 11)),
                    ),
                ]),
              );
            }),
          ]),
        ).animate().fadeIn(delay: 80.ms),

        const SizedBox(height: 12),

        // Terrenos por bairro
        if (terrenos.isNotEmpty) ...[
          GDCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Terrenos — R\u0024/m² por bairro',
                      style: TextStyle(color: AppTheme.gold, fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  Text('${terrenos.length} terrenos',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 2),
              Text('Ordenado do mais barato — menor R\u0024/m² = maior oportunidade de incorporação',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              const SizedBox(height: 12),
              ...() {
                final map = <String, List<double>>{};
                for (final t in terrenos) {
                  if (t.area > 0) map.putIfAbsent(t.bairro, () => []).add(t.preco / t.area);
                }
                final lista = map.entries
                    .map((e) => MapEntry(e.key, _avg(e.value)))
                    .toList()..sort((a, b) => a.value.compareTo(b.value));
                return lista.take(30).map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(e.key, style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 12)),
                    Text('R\$ ${e.value.toStringAsFixed(0)}/m²',
                        style: const TextStyle(color: AppTheme.success,
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ));
              }(),
            ]),
          ).animate().fadeIn(delay: 160.ms),
        ],
      ]),
    );
  }

  Widget _tipoBtn(TipoImovel? tipo, String label, IconData icon) {
    final sel = _filtroTipo == tipo;
    return GestureDetector(
      onTap: () => setState(() => _filtroTipo = tipo),
      child: Container(
        margin: const EdgeInsets.only(right: 8, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? AppTheme.gold.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? AppTheme.gold : AppTheme.cardBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: sel ? AppTheme.gold : AppTheme.textSecondary),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
              color: sel ? AppTheme.gold : AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
        ]),
      ),
    );
  }

  Widget _segBtn(SegmentoMercado? seg, String label) {
    final sel = _filtroSeg == seg;
    return GestureDetector(
      onTap: () => setState(() => _filtroSeg = seg),
      child: Container(
        margin: const EdgeInsets.only(right: 8, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? AppTheme.gold.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? AppTheme.gold : AppTheme.cardBorder),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? AppTheme.gold : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
      ),
    );
  }

  Widget _metricCard(String label, String value, {String? sub}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.cardBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(
          color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
      if (sub != null && sub.isNotEmpty)
        Text(sub, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────
// ABA 3 — ANÁLISE IA
// ─────────────────────────────────────────────────────────────

class _TabAnaliseIA extends StatefulWidget {
  final List<AnuncioMercado> anuncios;
  const _TabAnaliseIA({required this.anuncios});
  @override
  State<_TabAnaliseIA> createState() => _TabAnaliseIAState();
}

class _TabAnaliseIAState extends State<_TabAnaliseIA> {
  String _analise = '';
  bool   _loading = false;

  // Agrega estatísticas — resolve o estouro de tokens com muitos anúncios
  String _buildPrompt() {
    final an = widget.anuncios;
    final total = an.length;

    // ── helpers ──────────────────────────────────────────────
    double avg(List<double> l) => l.isEmpty ? 0 : l.reduce((a,b)=>a+b)/l.length;
    double med(List<double> l) { if(l.isEmpty)return 0; final s=[...l]..sort(); return s[s.length~/2]; }
    String fv(double v) => 'R\$ ${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),(m)=>'${m[1]}.')}';

    // ── 1. Visão geral ────────────────────────────────────────
    final todos     = an.where((a) => a.tipo != TipoImovel.terreno).toList();
    final terrenos  = an.where((a) => a.tipo == TipoImovel.terreno).toList();
    final precosTodos = todos.map((a)=>a.preco).toList();
    final pm2Todos    = todos.where((a)=>a.area>0).map((a)=>a.preco/a.area).toList();

    final geral = '''VISÃO GERAL ($total anúncios — ${todos.length} imóveis + ${terrenos.length} terrenos)
Ticket médio: ${fv(avg(precosTodos))} | Mediana: ${fv(med(precosTodos))}
R\u0024/m² médio: R\$ ${avg(pm2Todos).toStringAsFixed(0)} | Mediana R\u0024/m²: R\$ ${med(pm2Todos).toStringAsFixed(0)}
Faixa: ${fv(precosTodos.isEmpty?0:precosTodos.reduce((a,b)=>a<b?a:b))} até ${fv(precosTodos.isEmpty?0:precosTodos.reduce((a,b)=>a>b?a:b))}''';

    // ── 2. Por segmento ───────────────────────────────────────
    final segLines = SegmentoMercado.values.map((s) {
      final d  = todos.where((a)=>a.segmento==s).toList();
      if (d.isEmpty) return null;
      final pm2 = d.where((a)=>a.area>0).map((a)=>a.preco/a.area).toList();
      final sl  = switch(s){ SegmentoMercado.mcmv=>'MCMV (até R\$350k)', SegmentoMercado.intermediario=>'Intermediário (R\$350k–R\$600k)', SegmentoMercado.altopadrao=>'Alto padrão (>R\$600k)' };
      return '$sl: ${d.length} anúncios | ticket médio ${fv(avg(d.map((a)=>a.preco).toList()))} | R\u0024/m² médio R\$ ${avg(pm2).toStringAsFixed(0)} | mediana R\u0024/m² R\$ ${med(pm2).toStringAsFixed(0)}';
    }).whereType<String>().join('\n');

    // ── 3. Por tipologia (tipo + quartos) ─────────────────────
    final tipoMap = <String,List<double>>{};
    for (final a in todos) {
      final k = '${a.tipoLabel} ${a.quartos>0 ? "${a.quartos}q" : ""}'.trim();
      tipoMap.putIfAbsent(k,()=>[]).add(a.preco);
    }
    final tipoLines = (tipoMap.entries.toList()
      ..sort((a,b)=>b.value.length.compareTo(a.value.length)))
        .take(10)
        .map((e)=>'${e.key}: ${e.value.length} anúncios | ticket médio ${fv(avg(e.value))} | mediana ${fv(med(e.value))}')
        .join('\n');

    // ── 4. Top bairros por R$/m² (imóveis) ───────────────────
    final bairroMap = <String,List<double>>{};
    for (final a in todos) {
      if (a.area>0) bairroMap.putIfAbsent(a.bairro,()=>[]).add(a.preco/a.area);
    }
    final bairroLines = (bairroMap.entries.toList()
      ..sort((a,b)=>b.value.length.compareTo(a.value.length)))
        .take(20)
        .map((e)=>'${e.key}: ${e.value.length} imóveis | R\u0024/m² médio R\$ ${avg(e.value).toStringAsFixed(0)} | mediana R\$ ${med(e.value).toStringAsFixed(0)}')
        .join('\n');

    // ── 5. Terrenos por bairro ────────────────────────────────
    String terrenoSection = '';
    if (terrenos.isNotEmpty) {
      final tMap = <String,List<double>>{};
      for (final t in terrenos) {
        if (t.area>0) tMap.putIfAbsent(t.bairro,()=>[]).add(t.preco/t.area);
      }
      final tLines = (tMap.entries.toList()
        ..sort((a,b)=>a.value.length.compareTo(b.value.length)))
          .map((e)=>'${e.key}: ${e.value.length} terrenos | R\u0024/m² médio R\$ ${avg(e.value).toStringAsFixed(0)}')
          .join('\n');
      terrenoSection = '\nTERRENOS POR BAIRRO:\n$tLines';
    }

    // ── 6. Distribuição de quartos ────────────────────────────
    final quartosMap = <int,int>{};
    for (final a in todos) { if (a.quartos>0) quartosMap[a.quartos]=(quartosMap[a.quartos]??0)+1; }
    final quartosLine = (quartosMap.entries.toList()..sort((a,b)=>a.key.compareTo(b.key)))
        .map((e)=>'${e.key} quartos: ${e.value} anúncios (${(e.value/total*100).toStringAsFixed(0)}%)')
        .join(' | ');

    return '''Você é um analista de mercado imobiliário sênior especialista em Piracicaba, SP, com foco em incorporação residencial.

DADOS ESTATÍSTICOS DO MERCADO (coletados de portais imobiliários):

$geral

POR SEGMENTO:
$segLines

POR TIPOLOGIA E QUARTOS:
$tipoLines

DISTRIBUIÇÃO POR QUARTOS: $quartosLine

TOP BAIRROS — R\u0024/m² (imóveis construídos):
$bairroLines
$terrenoSection

Com base nesses dados reais do mercado de Piracicaba, responda de forma objetiva e estratégica:

📊 PADRÃO DE MERCADO
- Qual o padrão dominante de imóvel em Piracicaba? (tipologia, metragem, quartos mais comuns)
- Qual a faixa de R\u0024/m² considerada normal, barata e cara para cada segmento?
- Quais bairros estão precificados acima ou abaixo da média? Por quê isso é relevante?

🏠 TIPOLOGIA E QUARTOS
- Qual tipologia tem melhor relação oferta × demanda?
- Casas de 2q vs 3q vs 4q: qual entrega mais valor por m² ao comprador?
- Existe alguma tipologia subofertada que a Multiplika poderia explorar?

🌍 OPORTUNIDADE DE TERRENOS
- Com base no R\u0024/m² dos imóveis prontos, qual o teto máximo a pagar por terreno em cada bairro para viabilizar um projeto com margem de 20%?
- (considere: custo construção ≈ R\$ 2.800/m², margem 20% sobre VGV)
- Quais bairros apresentam melhor arbitragem terreno→produto acabado?

💡 POSICIONAMENTO MULTIPLIKA
- Qual segmento e tipologia priorizar primeiro: MCMV 3q ou Intermediário 3q?
- Como precificar um produto novo para ser competitivo mas proteger a margem?
- Qual bairro/região atacar primeiro com base nos dados?

Seja direto. Use os números dos dados acima. Responda em português brasileiro.''';
  }

  Future<void> _gerarAnalise() async {
    if (widget.anuncios.length < 3) return;
    setState(() { _loading = true; _analise = ''; });

    try {
      final res = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [{'role': 'user', 'content': _buildPrompt()}],
          'max_tokens': 2500,
          'temperature': 0.25,
        }),
      ).timeout(const Duration(seconds: 60));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _analise = data['choices'][0]['message']['content'] ?? '';
          _loading = false;
        });
        return;
      }
      // Log do erro para debug
      setState(() {
        _analise = 'Erro ${res.statusCode}: ${res.body.substring(0, res.body.length.clamp(0,200))}';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _analise = 'Erro de conexão: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.anuncios.length < 3) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.psychology_outlined, color: AppTheme.textMuted, size: 56),
        SizedBox(height: 12),
        Text('Adicione pelo menos 3 anúncios',
            style: TextStyle(color: AppTheme.textSecondary)),
        SizedBox(height: 4),
        Text('Cole o texto do Viva Real na aba "Colar".',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      ]));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GDCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Análise inteligente de mercado',
                style: TextStyle(color: AppTheme.gold,
                    fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 4),
            Text('${widget.anuncios.length} anúncios carregados. '
                'A IA analisa precificação, oportunidades e posicionamento.',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _gerarAnalise,
                icon: _loading
                    ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        color: AppTheme.background, strokeWidth: 2))
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(_loading ? 'Gerando análise...' : 'Gerar análise de mercado',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.background,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ),

        if (_analise.isNotEmpty) ...[
          const SizedBox(height: 16),
          GDCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Resultado',
                      style: TextStyle(color: AppTheme.gold,
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded,
                        size: 16, color: AppTheme.textMuted),
                    tooltip: 'Copiar análise',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _analise));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Copiado!'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(_analise,
                  style: const TextStyle(color: AppTheme.textSecondary,
                      fontSize: 13, height: 1.65)),
            ]),
          ).animate().fadeIn(),
        ],
      ]),
    );
  }
}