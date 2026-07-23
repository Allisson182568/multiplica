import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_theme.dart';
import 'gd_card.dart';
import 'obra_context.dart';
import 'main.dart'; // groqApiKey

class ViabilidadeScreen extends StatefulWidget {
  const ViabilidadeScreen({super.key});
  @override
  State<ViabilidadeScreen> createState() => _ViabilidadeScreenState();
}

class _ViabilidadeScreenState extends State<ViabilidadeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _supa = Supabase.instance.client;
  final _ctx = ObraContext();

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: ShaderMask(
            shaderCallback: (b) => AppTheme.goldGradient.createShader(b),
            child: const Text('Estudo de Viabilidade',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
        bottom: TabBar(controller: _tabs, labelColor: AppTheme.gold,
            unselectedLabelColor: AppTheme.textMuted, indicatorColor: AppTheme.gold,
            dividerColor: AppTheme.cardBorder,
            tabs: const [Tab(text: 'Novo Estudo'), Tab(text: 'Histórico')]),
      ),
      body: TabBarView(controller: _tabs, children: [
        _NovoEstudoTab(supa: _supa, ctx: _ctx, onSalvo: () => setState(() => _tabs.animateTo(1))),
        _HistoricoTab(supa: _supa, ctx: _ctx),
      ]),
    );
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }
}

// ─────────────────────────────────────────────────────────────
// NÍVEIS DE ACABAMENTO — o que entra e o que falta no custo/m²
// ─────────────────────────────────────────────────────────────

class _NivelInfo {
  final String label;
  final double pctCub; // % do CUB completo (SINDUSCON) que esse nível representa
  final List<String> incluido;
  final List<String> naoIncluido;
  const _NivelInfo({
    required this.label,
    required this.pctCub,
    required this.incluido,
    required this.naoIncluido,
  });
}

const Map<String, _NivelInfo> _niveisAcabamento = {
  'alvenaria_cinza': _NivelInfo(
    label: 'Alvenaria Cinza',
    pctCub: 0.55,
    incluido: [
      'Fundação e estrutura',
      'Alvenaria de vedação',
      'Cobertura / telhado',
      'Contrapiso',
    ],
    naoIncluido: [
      'Reboco fino e pintura',
      'Instalações elétricas/hidráulicas finais',
      'Revestimentos (piso, azulejo)',
      'Esquadrias (portas/janelas)',
      'Louças e metais',
      'Calhas e rufos',
    ],
  ),
  'sem_pintura_calha': _NivelInfo(
    label: 'Sem Pintura/Calha',
    pctCub: 0.85,
    incluido: [
      'Estrutura completa',
      'Instalações elétricas/hidráulicas',
      'Revestimentos e esquadrias',
      'Louças e metais',
    ],
    naoIncluido: [
      'Pintura (interna/externa)',
      'Calhas e rufos',
    ],
  ),
  'completo': _NivelInfo(
    label: 'Completo (padrão CUB)',
    pctCub: 1.0,
    incluido: ['Tudo conforme padrão SINDUSCON — pronto para morar'],
    naoIncluido: [],
  ),
};

// ─────────────────────────────────────────────────────────────
// ABA: NOVO ESTUDO
// ─────────────────────────────────────────────────────────────

class _NovoEstudoTab extends StatefulWidget {
  final SupabaseClient supa;
  final ObraContext ctx;
  final VoidCallback onSalvo;
  const _NovoEstudoTab({required this.supa, required this.ctx, required this.onSalvo});
  @override
  State<_NovoEstudoTab> createState() => _NovoEstudoTabState();
}

class _NovoEstudoTabState extends State<_NovoEstudoTab> {
  final _nomeCtrl = TextEditingController();
  final _areaTerrCtrl = TextEditingController();
  final _valorTerrCtrl = TextEditingController();
  final _areaConstruidaCtrl = TextEditingController();
  final _unidadesCtrl = TextEditingController(text: '1');
  final _precoVendaCtrl = TextEditingController();
  final _permutaPctCtrl = TextEditingController(text: '0');
  final _infraCtrl = TextEditingController(text: '0');
  final _prazoCtrl = TextEditingController(text: '18');
  final _entradaPctCtrl = TextEditingController(text: '30');
  final _parcEntradaCtrl = TextEditingController(text: '12');
  final _custoM2ManualCtrl = TextEditingController();

  String _modelo = 'casa_terrea';
  String _aquisicao = 'compra';
  String _estado = 'SP';
  String _tipo = 'residencial';
  double _bdi = 25;
  bool _calculado = false;
  bool _salvando = false;
  String? _analiseIA;
  bool _loadingIA = false;

  // Financiado via Crédito Associativo (CEF): perito avalia a valor de mercado,
  // então o R$/m² manual é permitido. Sem isso (T+C/à vista), usa sempre o CUB comprimido.
  bool _financiado = true;
  String _nivelAcabamento = 'completo';

  // Proporção padrão de mercado do custo de construção (ajustável conforme seu histórico)
  static const double _pctMaoObra = 0.35;
  static const double _pctMaterial = 0.65;

  // Resultados
  double _vgv = 0, _custoConst = 0, _custoTerr = 0, _custoImp = 0;
  double _custoCort = 0, _custoTotal = 0, _lucro = 0, _margem = 0;
  double _custoInfra = 0, _custoMaoObra = 0, _custoMaterial = 0;
  int _qtdLotes = 0;
  String _parecer = '';

  static const _cubPorEstado = {
    'SP': 2820.0, 'RJ': 2650.0, 'MG': 2400.0, 'PR': 2500.0,
    'SC': 2600.0, 'RS': 2550.0, 'BA': 2300.0, 'GO': 2350.0,
    'DF': 2900.0, 'CE': 2200.0, 'PE': 2250.0, 'PA': 2150.0,
  };

  bool get _temManual =>
      double.tryParse(_custoM2ManualCtrl.text.replaceAll('.', '').replaceAll(',', '.')) != null &&
          (double.tryParse(_custoM2ManualCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0) > 0;

  /// CUB completo (padrão SINDUSCON), sempre usado como referência informativa.
  double get _cubCompleto => (_cubPorEstado[_estado] ?? 2500) * (1 + _bdi / 100);

  /// Custo/m² efetivamente usado no cálculo:
  /// - Financiado + manual preenchido → usa o valor manual (perito avalia a mercado).
  /// - Caso contrário → usa o CUB base ajustado pelo nível de acabamento escolhido.
  double get _custoM2Efetivo {
    if (_financiado && _temManual) {
      return double.tryParse(_custoM2ManualCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? _cubCompleto;
    }
    final pct = _niveisAcabamento[_nivelAcabamento]?.pctCub ?? 1.0;
    return _cubCompleto * pct;
  }

  void _calcular() {
    final areaTerr = double.tryParse(_areaTerrCtrl.text.replaceAll(',', '.')) ?? 0;
    final valorTerr = double.tryParse(_valorTerrCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
    final areaConst = double.tryParse(_areaConstruidaCtrl.text.replaceAll(',', '.')) ?? 0;
    final unidades = int.tryParse(_unidadesCtrl.text) ?? 1;
    final precoVenda = double.tryParse(_precoVendaCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
    final permutaPct = double.tryParse(_permutaPctCtrl.text) ?? 0;
    final infra = double.tryParse(_infraCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;

    // Cálculo de lotes para condomínio
    if (_modelo == 'condominio_lotes' || _modelo == 'loteamento') {
      final areaUtil = areaTerr * 0.60; // 60% útil (20% verde + 20% ruas)
      final loteMedio = 200.0; // m² por lote
      _qtdLotes = (areaUtil / loteMedio).floor();
      _vgv = _qtdLotes * precoVenda;
      _custoConst = 0; // loteamento não tem construção
      _custoInfra = infra > 0 ? infra : (_qtdLotes * 15000); // R$ 15k/lote estimado
      _custoMaoObra = 0;
      _custoMaterial = 0;
    } else {
      _qtdLotes = 0;
      _vgv = unidades * precoVenda;
      _custoConst = areaConst * _custoM2Efetivo;
      _custoInfra = infra;
      _custoMaoObra = _custoConst * _pctMaoObra;
      _custoMaterial = _custoConst * _pctMaterial;
    }

    // Terreno: permuta desconta
    if (_aquisicao == 'permuta') {
      _custoTerr = 0; // terreno entra como permuta
    } else if (_aquisicao == 'mista') {
      _custoTerr = valorTerr * (1 - permutaPct / 100);
    } else {
      _custoTerr = valorTerr;
    }

    _custoImp = _vgv * 0.08;
    _custoCort = _vgv * 0.06;
    _custoTotal = _custoConst + _custoTerr + _custoImp + _custoCort + _custoInfra;
    _lucro = _vgv - _custoTotal;
    _margem = _vgv > 0 ? (_lucro / _vgv * 100) : 0;

    if (_margem >= 20) _parecer = 'viavel';
    else if (_margem >= 10) _parecer = 'margem_apertada';
    else _parecer = 'inviavel';

    setState(() => _calculado = true);
  }

  Future<void> _gerarAnaliseIA() async {
    setState(() => _loadingIA = true);
    final nivel = _niveisAcabamento[_nivelAcabamento]?.label ?? '';
    final basePreco = _financiado && _temManual
        ? 'R\$/m² informado manualmente (financiamento Crédito Associativo)'
        : 'CUB SINDUSCON ajustado ao nível "$nivel"';
    final prompt = '''
Você é um incorporador imobiliário sênior com 25 anos de experiência no mercado brasileiro.
Analise este estudo de viabilidade e dê um parecer completo:

Modelo: $_modelo | Aquisição: $_aquisicao | Estado: $_estado
Financiado (Crédito Associativo): ${_financiado ? 'Sim' : 'Não (T+C)'}
Base do custo/m²: $basePreco | Custo/m² efetivo: R\$ ${_custoM2Efetivo.toStringAsFixed(0)}
Nível de acabamento: $nivel
VGV: R\$ ${_vgv.toStringAsFixed(0)} | Custo construção: R\$ ${_custoConst.toStringAsFixed(0)}
  - Mão de obra (~${(_pctMaoObra * 100).toInt()}%): R\$ ${_custoMaoObra.toStringAsFixed(0)}
  - Material (~${(_pctMaterial * 100).toInt()}%): R\$ ${_custoMaterial.toStringAsFixed(0)}
Custo terreno: R\$ ${_custoTerr.toStringAsFixed(0)} | Infraestrutura: R\$ ${_custoInfra.toStringAsFixed(0)}
Impostos: R\$ ${_custoImp.toStringAsFixed(0)} | Corretagem: R\$ ${_custoCort.toStringAsFixed(0)}
Custo total: R\$ ${_custoTotal.toStringAsFixed(0)} | Lucro: R\$ ${_lucro.toStringAsFixed(0)}
Margem: ${_margem.toStringAsFixed(1)}% | Parecer: $_parecer
${_qtdLotes > 0 ? 'Qtd lotes: $_qtdLotes' : ''}
Prazo de obra: ${_prazoCtrl.text} meses

Responda em português com:
1. PARECER GERAL (2-3 linhas)
2. PONTOS FORTES
3. RISCOS (considere o nível de acabamento e o que falta cobrir, se houver)
4. RECOMENDAÇÕES DE CONTRATAÇÃO (quem contratar para cada fase)
5. CRONOGRAMA SUGERIDO (macro fases e duração)
6. SUGESTÃO DE FLUXO DE CAIXA (como distribuir os custos ao longo da obra, separando mão de obra e material)
''';

    try {
      // Tentar Groq
      final res = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {'Authorization': 'Bearer $groqApiKey', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [{'role': 'user', 'content': prompt}],
          'max_tokens': 2000, 'temperature': 0.3,
        }),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _analiseIA = data['choices'][0]['message']['content'];
          _loadingIA = false;
        });
        return;
      }
    } catch (_) {}
    setState(() { _analiseIA = 'Não foi possível gerar análise IA. Verifique sua conexão.'; _loadingIA = false; });
  }

  Future<void> _salvarEstudo() async {
    if (!_calculado) return;
    setState(() => _salvando = true);
    try {
      final uid = widget.supa.auth.currentUser?.id;
      final u = await widget.supa.schema('grupo_dantas').from('usuarios')
          .select('id').eq('auth_id', uid!).maybeSingle();

      await widget.supa.schema('grupo_dantas').from('estudos_viabilidade').insert({
        'obra_id': widget.ctx.obraId,
        'criado_por': u?['id'],
        'nome_projeto': _nomeCtrl.text.trim().isEmpty ? 'Estudo ${DateTime.now().toString().substring(0,10)}' : _nomeCtrl.text.trim(),
        'modelo': _modelo,
        'tipo_construcao': _tipo,
        'estado': _estado,
        'forma_aquisicao': _aquisicao,
        'area_terreno_m2': double.tryParse(_areaTerrCtrl.text.replaceAll(',', '.')) ?? 0,
        'valor_terreno': double.tryParse(_valorTerrCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0,
        'area_construida_m2': double.tryParse(_areaConstruidaCtrl.text.replaceAll(',', '.')) ?? 0,
        'numero_unidades': int.tryParse(_unidadesCtrl.text) ?? 1,
        'preco_venda_unidade': double.tryParse(_precoVendaCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0,
        'cub_m2': _cubCompleto,
        'bdi_percentual': _bdi,
        'permuta_percentual': double.tryParse(_permutaPctCtrl.text) ?? 0,
        'custo_infraestrutura': _custoInfra,
        'qtd_lotes_calculada': _qtdLotes > 0 ? _qtdLotes : null,
        'entrada_pct': double.tryParse(_entradaPctCtrl.text) ?? 30,
        'parcelas_entrada': int.tryParse(_parcEntradaCtrl.text) ?? 12,
        'prazo_obra_meses': int.tryParse(_prazoCtrl.text) ?? 18,
        'vgv': _vgv, 'custo_construcao': _custoConst, 'custo_terreno': _custoTerr,
        'custo_impostos': _custoImp, 'custo_corretagem': _custoCort, 'custo_total': _custoTotal,
        'lucro_estimado': _lucro, 'margem_percentual': _margem, 'parecer': _parecer,
        'analise_ia': _analiseIA, 'modelo_ia': _analiseIA != null ? 'groq' : null,
        'status': 'calculado',
        // Campos novos — exigem as colunas adicionadas via ALTER TABLE (ver instruções)
        'financiado': _financiado,
        'custo_m2_manual': _temManual
            ? double.tryParse(_custoM2ManualCtrl.text.replaceAll('.', '').replaceAll(',', '.'))
            : null,
        'nivel_acabamento': _nivelAcabamento,
        'custo_mao_obra': _custoMaoObra,
        'custo_material': _custoMaterial,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Estudo salvo com sucesso!'), backgroundColor: AppTheme.success));
        widget.onSalvo();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao salvar: $e'), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    final temConstrucao = _modelo != 'condominio_lotes' && _modelo != 'loteamento';

    return ListView(padding: const EdgeInsets.all(20), children: [
      // Obra vinculada
      if (widget.ctx.obraNome != null)
        Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: AppTheme.gold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.gold.withOpacity(0.25))),
            child: Row(children: [
              const Icon(Icons.construction_rounded, color: AppTheme.gold, size: 16),
              const SizedBox(width: 8),
              Text('Obra: ${widget.ctx.obraNome}', style: const TextStyle(color: AppTheme.gold, fontSize: 12, fontWeight: FontWeight.w600)),
            ])),

      // Nome do estudo
      TextField(controller: _nomeCtrl, style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(labelText: 'Nome do estudo', prefixIcon: Icon(Icons.edit_rounded, color: AppTheme.textMuted, size: 18))),
      const SizedBox(height: 14),

      // Modelo do projeto
      const Text('Modelo do Projeto', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final m in [
          ('casa_terrea', 'Casa Térrea', Icons.home_rounded),
          ('sobrado', 'Sobrado', Icons.home_work_rounded),
          ('condominio_lotes', 'Cond. Lotes', Icons.grid_view_rounded),
          ('condominio_vertical', 'Cond. Vertical', Icons.apartment_rounded),
          ('galpao', 'Galpão', Icons.warehouse_rounded),
          ('incorporacao_permuta', 'Incorporação', Icons.handshake_rounded),
          ('loteamento', 'Loteamento', Icons.map_rounded),
        ]) GestureDetector(
            onTap: () => setState(() => _modelo = m.$1),
            child: AnimatedContainer(duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                    color: _modelo == m.$1 ? AppTheme.gold.withOpacity(0.15) : AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _modelo == m.$1 ? AppTheme.gold : AppTheme.cardBorder)),
                child: Column(children: [
                  Icon(m.$3, size: 22, color: _modelo == m.$1 ? AppTheme.gold : AppTheme.textMuted),
                  const SizedBox(height: 4),
                  Text(m.$2, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                      color: _modelo == m.$1 ? AppTheme.gold : AppTheme.textSecondary)),
                ]))),
      ]),
      const SizedBox(height: 14),

      // Forma de aquisição
      const Text('Aquisição do Terreno', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        for (final a in [('compra','Compra'), ('permuta','Permuta'), ('mista','Mista'), ('proprio','Próprio')])
          ChoiceChip(label: Text(a.$2, style: const TextStyle(fontSize: 11)),
              selected: _aquisicao == a.$1,
              selectedColor: AppTheme.gold.withOpacity(0.2), backgroundColor: AppTheme.surfaceAlt,
              side: BorderSide(color: _aquisicao == a.$1 ? AppTheme.gold : AppTheme.cardBorder),
              labelStyle: TextStyle(color: _aquisicao == a.$1 ? AppTheme.gold : AppTheme.textSecondary),
              onSelected: (_) => setState(() => _aquisicao = a.$1)),
      ]),
      const SizedBox(height: 14),

      // Terreno
      Row(children: [
        Expanded(child: TextField(controller: _areaTerrCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(labelText: 'Área terreno (m²)'))),
        const SizedBox(width: 12),
        Expanded(child: TextField(controller: _valorTerrCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(labelText: 'Valor terreno (R\$)'))),
      ]),

      if (_aquisicao == 'permuta' || _aquisicao == 'mista') ...[
        const SizedBox(height: 10),
        TextField(controller: _permutaPctCtrl, keyboardType: TextInputType.number,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(labelText: '% permuta (unidades para o dono do terreno)', suffixText: '%')),
      ],
      const SizedBox(height: 14),

      // Tipo + Estado
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(value: _tipo,
            decoration: const InputDecoration(labelText: 'Tipo'), dropdownColor: AppTheme.surface,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            items: const [
              DropdownMenuItem(value: 'residencial', child: Text('Residencial')),
              DropdownMenuItem(value: 'comercial', child: Text('Comercial')),
            ], onChanged: (v) => setState(() => _tipo = v!))),
        const SizedBox(width: 12),
        Expanded(child: DropdownButtonFormField<String>(value: _estado,
            decoration: const InputDecoration(labelText: 'Estado'), dropdownColor: AppTheme.surface,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            items: _cubPorEstado.keys.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _estado = v!))),
      ]),
      const SizedBox(height: 10),

      // Área construída + unidades + preço
      if (temConstrucao) ...[
        TextField(controller: _areaConstruidaCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(labelText: 'Área construída (m²)')),
        const SizedBox(height: 10),
      ],

      Row(children: [
        Expanded(child: TextField(controller: _unidadesCtrl, keyboardType: TextInputType.number,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
                labelText: (_modelo == 'condominio_lotes' || _modelo == 'loteamento') ? 'Nº de lotes' : 'Nº de unidades'))),
        const SizedBox(width: 12),
        Expanded(child: TextField(controller: _precoVendaCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
                labelText: (_modelo == 'condominio_lotes' || _modelo == 'loteamento') ? 'Preço por lote (R\$)' : 'Preço de venda/un (R\$)'))),
      ]),

      if (_modelo == 'condominio_lotes' || _modelo == 'loteamento') ...[
        const SizedBox(height: 10),
        TextField(controller: _infraCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(labelText: 'Custo infraestrutura (R\$)',
                helperText: 'Terraplanagem, guias, ruas, portaria, drenagem')),
      ],

      // ── Financiamento + Nível de Acabamento + Custo/m² manual ──
      if (temConstrucao) ...[
        const SizedBox(height: 20),
        _buildFinanciamentoENivel(),
      ],
      const SizedBox(height: 8),

      // Prazo e entrada
      Row(children: [
        Expanded(child: TextField(controller: _prazoCtrl, keyboardType: TextInputType.number,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(labelText: 'Prazo obra (meses)'))),
        const SizedBox(width: 12),
        Expanded(child: TextField(controller: _entradaPctCtrl, keyboardType: TextInputType.number,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(labelText: 'Entrada (%)', suffixText: '%'))),
        const SizedBox(width: 12),
        Expanded(child: TextField(controller: _parcEntradaCtrl, keyboardType: TextInputType.number,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(labelText: 'Parcelas entrada'))),
      ]),
      const SizedBox(height: 20),

      // Botão calcular
      SizedBox(width: double.infinity, height: 52,
          child: ElevatedButton.icon(onPressed: _calcular,
              icon: const Icon(Icons.calculate_rounded, size: 18),
              label: const Text('CALCULAR VIABILIDADE', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)))),

      // Resultados
      if (_calculado) ...[
        const SizedBox(height: 24),
        _buildResultados(),
        const SizedBox(height: 16),

        // Botão IA
        SizedBox(width: double.infinity, height: 48,
            child: OutlinedButton.icon(
                onPressed: _loadingIA ? null : _gerarAnaliseIA,
                icon: _loadingIA
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold))
                    : const Icon(Icons.psychology_rounded),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.gold, side: const BorderSide(color: AppTheme.gold)),
                label: Text(_loadingIA ? 'Gerando análise...' : 'Gerar Parecer com IA',
                    style: const TextStyle(fontWeight: FontWeight.w700)))),

        if (_analiseIA != null) ...[
          const SizedBox(height: 16),
          GDCard(gradient: AppTheme.cardGradient,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.psychology_rounded, color: AppTheme.gold, size: 18),
                  SizedBox(width: 8),
                  Text('Parecer do Incorporador IA', style: TextStyle(
                      color: AppTheme.gold, fontWeight: FontWeight.w700, fontSize: 14)),
                ]),
                const SizedBox(height: 12),
                Text(_analiseIA!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.6)),
              ])).animate().fadeIn(),
        ],
        const SizedBox(height: 16),

        // Botão salvar
        SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton.icon(
                onPressed: _salvando ? null : _salvarEstudo,
                icon: _salvando
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.background))
                    : const Icon(Icons.save_rounded),
                label: Text(_salvando ? 'Salvando...' : 'SALVAR ESTUDO NA OBRA',
                    style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)))),
        const SizedBox(height: 40),
      ],
    ]);
  }

  Widget _buildFinanciamentoENivel() {
    final nivelInfo = _niveisAcabamento[_nivelAcabamento]!;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Toggle financiamento
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: AppTheme.surfaceAlt, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.cardBorder)),
        child: Row(children: [
          Icon(Icons.account_balance_rounded, size: 18,
              color: _financiado ? AppTheme.gold : AppTheme.textMuted),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Financiado (Crédito Associativo)', style: TextStyle(
                color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            Text(
              _financiado
                  ? 'Perito avalia a valor de mercado — pode usar R\$/m² manual'
                  : 'T+C/à vista — usa sempre o CUB comprimido (SINDUSCON)',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ])),
          Switch(
              value: _financiado,
              activeColor: AppTheme.gold,
              onChanged: (v) => setState(() => _financiado = v)),
        ]),
      ),
      const SizedBox(height: 14),

      // Nível de acabamento
      const Text('Nível de Acabamento', style: TextStyle(
          color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final entry in _niveisAcabamento.entries)
          ChoiceChip(
              label: Text(entry.value.label, style: const TextStyle(fontSize: 11)),
              selected: _nivelAcabamento == entry.key,
              selectedColor: AppTheme.gold.withOpacity(0.2),
              backgroundColor: AppTheme.surfaceAlt,
              side: BorderSide(color: _nivelAcabamento == entry.key ? AppTheme.gold : AppTheme.cardBorder),
              labelStyle: TextStyle(color: _nivelAcabamento == entry.key ? AppTheme.gold : AppTheme.textSecondary),
              onSelected: (_) => setState(() => _nivelAcabamento = entry.key)),
      ]),
      const SizedBox(height: 10),

      // Custo m² manual (só habilitado se financiado)
      TextField(
        controller: _custoM2ManualCtrl,
        enabled: _financiado,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: _financiado ? AppTheme.textPrimary : AppTheme.textMuted),
        decoration: InputDecoration(
          labelText: 'Custo m² manual (R\$) — opcional',
          helperText: _financiado
              ? 'Deixe vazio para usar a base CUB ajustada ao nível acima'
              : 'Disponível apenas quando financiado (Crédito Associativo)',
          prefixIcon: const Icon(Icons.edit_rounded, color: AppTheme.textMuted, size: 18),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 10),

      // O que entra / o que falta nesse nível
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppTheme.surfaceAlt, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.cardBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (nivelInfo.incluido.isNotEmpty) ...[
            const Text('Inclui', style: TextStyle(
                color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            ...nivelInfo.incluido.map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.check_rounded, size: 13, color: AppTheme.success),
                  const SizedBox(width: 4),
                  Expanded(child: Text(i, style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11))),
                ]))),
          ],
          if (nivelInfo.naoIncluido.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Não inclui — orçar à parte', style: TextStyle(
                color: AppTheme.warning, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            ...nivelInfo.naoIncluido.map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.close_rounded, size: 13, color: AppTheme.warning),
                  const SizedBox(width: 4),
                  Expanded(child: Text(i, style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11))),
                ]))),
          ],
        ]),
      ),
      const SizedBox(height: 10),

      // Info do custo/m² efetivo
      Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppTheme.gold.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.gold.withOpacity(0.2))),
          child: Row(children: [
            const Icon(Icons.info_outlined, color: AppTheme.gold, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(
              _financiado && _temManual
                  ? 'Custo/m² usado: R\$ ${_custoM2Efetivo.toStringAsFixed(0)} (informado manualmente)'
                  : 'Custo/m² usado: R\$ ${_custoM2Efetivo.toStringAsFixed(0)} '
                  '(CUB $_tipo/$_estado completo R\$ ${_cubCompleto.toStringAsFixed(0)} × ${nivelInfo.label})',
              style: const TextStyle(color: AppTheme.gold, fontSize: 11),
            )),
          ])),
    ]);
  }

  Widget _buildResultados() {
    final cor = _parecer == 'viavel' ? AppTheme.success
        : _parecer == 'margem_apertada' ? AppTheme.warning : AppTheme.error;
    final label = _parecer == 'viavel' ? 'VIÁVEL — Margem saudável'
        : _parecer == 'margem_apertada' ? 'MARGEM APERTADA — Atenção' : 'INVIÁVEL — Rever custos';

    return Column(children: [
      // Veredito
      Container(width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: cor.withOpacity(0.08), borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cor.withOpacity(0.4), width: 2)),
          child: Column(children: [
            Icon(_parecer == 'viavel' ? Icons.check_circle_rounded : Icons.warning_rounded, color: cor, size: 44),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: cor, fontWeight: FontWeight.w800, fontSize: 16)),
            Text('Margem mínima recomendada: 15% sobre o VGV',
                style: TextStyle(color: cor.withOpacity(0.7), fontSize: 12)),
          ])).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
      const SizedBox(height: 16),

      // Detalhes
      GDCard(child: Column(children: [
        if (_qtdLotes > 0) _row('Lotes calculados', '$_qtdLotes lotes', AppTheme.info),
        _row('VGV (Receita Total)', _fmt(_vgv), AppTheme.gold),
        const Divider(color: AppTheme.cardBorder),
        if (_custoConst > 0) _row('Custo de Construção (${_niveisAcabamento[_nivelAcabamento]?.label ?? ''})', _fmt(_custoConst), AppTheme.textSecondary),
        if (_custoInfra > 0) _row('Infraestrutura', _fmt(_custoInfra), AppTheme.textSecondary),
        _row('Terreno', _fmt(_custoTerr), AppTheme.textSecondary),
        _row('Impostos (~8% VGV)', _fmt(_custoImp), AppTheme.textSecondary),
        _row('Corretagem (~6% VGV)', _fmt(_custoCort), AppTheme.textSecondary),
        const Divider(color: AppTheme.cardBorder),
        _row('Custo Total', _fmt(_custoTotal), AppTheme.error),
        const Divider(color: AppTheme.gold),
        _row('Lucro Estimado', _fmt(_lucro), _lucro >= 0 ? AppTheme.success : AppTheme.error),
        _row('Margem de Lucro', '${_margem.toStringAsFixed(1)}%', cor),
      ])).animate().fadeIn(),

      // Mão de obra x Material
      if (_custoConst > 0) ...[
        const SizedBox(height: 12),
        GDCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.pie_chart_rounded, color: AppTheme.info, size: 16),
            SizedBox(width: 8),
            Text('Composição do Custo de Construção', style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
          const SizedBox(height: 10),
          _row('Mão de obra (~${(_pctMaoObra * 100).toInt()}%)', _fmt(_custoMaoObra), AppTheme.warning),
          _row('Material (~${(_pctMaterial * 100).toInt()}%)', _fmt(_custoMaterial), AppTheme.info),
          const SizedBox(height: 4),
          const Text('Proporção estimada de mercado — ajuste conforme seu histórico de obras.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ])).animate(delay: 100.ms).fadeIn(),
      ],
    ]);
  }

  Widget _row(String l, String v, Color cor) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(l, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
        Text(v, style: TextStyle(color: cor, fontWeight: FontWeight.w700, fontSize: 14)),
      ]));
}

// ─────────────────────────────────────────────────────────────
// ABA: HISTÓRICO DE ESTUDOS
// ─────────────────────────────────────────────────────────────

class _HistoricoTab extends StatefulWidget {
  final SupabaseClient supa;
  final ObraContext ctx;
  const _HistoricoTab({required this.supa, required this.ctx});
  @override
  State<_HistoricoTab> createState() => _HistoricoTabState();
}

class _HistoricoTabState extends State<_HistoricoTab> {
  List<Map<String, dynamic>> _estudos = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _carregar(); }

  Future<void> _carregar() async {
    if (widget.ctx.obraId == null) {
      setState(() { _estudos = []; _loading = false; });
      return;
    }

    final data = await widget.supa.schema('grupo_dantas').from('estudos_viabilidade')
        .select()
        .eq('obra_id', widget.ctx.obraId!)
        .order('criado_em', ascending: false)
        .limit(20);
    setState(() { _estudos = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2));

    if (_estudos.isEmpty) return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.analytics_rounded, color: AppTheme.textMuted, size: 56),
      SizedBox(height: 16),
      Text('Nenhum estudo salvo', style: TextStyle(color: AppTheme.textSecondary)),
      SizedBox(height: 4),
      Text('Crie um estudo na aba "Novo Estudo"', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
    ]));

    return RefreshIndicator(onRefresh: _carregar, color: AppTheme.gold,
        child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _estudos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final e = _estudos[i];
              final margem = (e['margem_percentual'] as num?)?.toDouble() ?? 0;
              final parecer = e['parecer'] as String? ?? '';
              final cor = parecer == 'viavel' ? AppTheme.success
                  : parecer == 'margem_apertada' ? AppTheme.warning : AppTheme.error;

              return GDCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 44, height: 44,
                      decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(parecer == 'viavel' ? Icons.check_circle_rounded : Icons.warning_rounded,
                          color: cor, size: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e['nome_projeto'] ?? 'Sem nome', style: const TextStyle(
                        color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('${(e['modelo'] ?? '').toString().replaceAll('_', ' ')} · ${e['estado'] ?? ''}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${margem.toStringAsFixed(1)}%', style: TextStyle(
                        color: cor, fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('margem', style: TextStyle(color: cor.withOpacity(0.6), fontSize: 10)),
                  ]),
                ]),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('VGV: ${_fmt((e['vgv'] as num?)?.toDouble() ?? 0)}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  Text('Lucro: ${_fmt((e['lucro_estimado'] as num?)?.toDouble() ?? 0)}',
                      style: TextStyle(color: cor, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
                if (e['nivel_acabamento'] != null) ...[
                  const SizedBox(height: 4),
                  Text('Acabamento: ${_niveisAcabamento[e['nivel_acabamento']]?.label ?? e['nivel_acabamento']}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                ],
                if (e['analise_ia'] != null) ...[
                  const SizedBox(height: 6),
                  const Row(children: [
                    Icon(Icons.psychology_rounded, size: 12, color: AppTheme.gold),
                    SizedBox(width: 4),
                    Text('Parecer IA disponível', style: TextStyle(color: AppTheme.gold, fontSize: 10)),
                  ]),
                ],
              ])).animate(delay: Duration(milliseconds: i * 50)).fadeIn();
            }));
  }
}