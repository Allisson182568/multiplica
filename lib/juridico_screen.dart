import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'gd_card.dart';
import 'obra_context.dart';

class JuridicoScreen extends StatefulWidget {
  const JuridicoScreen({super.key});
  @override
  State<JuridicoScreen> createState() => _JuridicoScreenState();
}

class _JuridicoScreenState extends State<JuridicoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (b) => AppTheme.goldGradient.createShader(b),
          child: const Text('Jurídico & Licenças',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
        bottom: TabBar(
          controller: _tabs, isScrollable: true, tabAlignment: TabAlignment.start,
          labelColor: AppTheme.gold, unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.gold, dividerColor: AppTheme.cardBorder,
          tabs: const [
            Tab(text: 'Prestadores'),
            Tab(text: 'Pré-Obra'),
            Tab(text: 'Durante Obra'),
            Tab(text: 'Contratos'),
            Tab(text: 'Entrega'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        const _PrestadoresTab(),
        _ChecklistTab(items: _preObra),
        _ChecklistTab(items: _duranteObra),
        _ContratosTab(),
        _ChecklistTab(items: _entrega),
      ]),
    );
  }

  // ── Dados do checklist (mantidos iguais ao original) ──────
  static final List<_CheckItem> _preObra = [
    _CheckItem(titulo: 'Matrícula atualizada do terreno', descricao: 'Solicite a certidão de matrícula atualizada no Cartório de Registro de Imóveis. Verifique se há ônus, penhoras ou gravames. Validade: 30 dias.', obrigatorio: true, lei: 'Lei 6.015/73', orgao: 'Cartório de Registro de Imóveis'),
    _CheckItem(titulo: 'Certidão de ônus reais', descricao: 'Confirma que o imóvel está livre de hipotecas, penhoras e outros gravames.', obrigatorio: true, orgao: 'Cartório de Registro de Imóveis'),
    _CheckItem(titulo: 'Certidões negativas do vendedor', descricao: 'CND Federal, Estadual, Municipal, FGTS, PGFN, protestos.', obrigatorio: true, orgao: 'Receita Federal, Prefeitura, Cartórios'),
    _CheckItem(titulo: 'Consulta de viabilidade na Prefeitura', descricao: 'Zoneamento, coeficiente de aproveitamento (CA), taxa de ocupação (TO) e recuos.', obrigatorio: true, orgao: 'Prefeitura Municipal'),
    _CheckItem(titulo: 'Projeto arquitetônico aprovado', descricao: 'Projeto elaborado por arquiteto (CREA/CAU), aprovado na prefeitura.', obrigatorio: true, orgao: 'Prefeitura Municipal'),
    _CheckItem(titulo: 'ART/RRT do projeto', descricao: 'Anotação de Responsabilidade Técnica ou Registro de Responsabilidade Técnica.', obrigatorio: true, orgao: 'CREA ou CAU'),
    _CheckItem(titulo: 'Alvará de construção', descricao: 'Autorização municipal para iniciar a obra.', obrigatorio: true, orgao: 'Prefeitura Municipal'),
    _CheckItem(titulo: 'CNO (Cadastro Nacional de Obras)', descricao: 'Cadastro da obra na Receita Federal para recolhimento do INSS.', obrigatorio: true, lei: 'IN RFB 2.110/2022', orgao: 'Receita Federal'),
    _CheckItem(titulo: 'Seguro de risco de engenharia', descricao: 'Cobre danos à obra durante a construção. Custo: 0,2% a 0,5% do valor da obra.', obrigatorio: false),
  ];

  static final List<_CheckItem> _duranteObra = [
    _CheckItem(titulo: 'Diário de obra atualizado', descricao: 'Registro diário das atividades. Obrigatório por lei.', obrigatorio: true, lei: 'Resolução CONFEA 1.094/2017'),
    _CheckItem(titulo: 'ART de execução', descricao: 'ART específica para a execução da obra.', obrigatorio: true, orgao: 'CREA'),
    _CheckItem(titulo: 'PCMAT / PPRA', descricao: 'Programa de Condições e Meio Ambiente de Trabalho. Obrigatório para 20+ trabalhadores.', obrigatorio: true, lei: 'NR-18'),
    _CheckItem(titulo: 'Recolhimento mensal do CNO', descricao: 'INSS sobre folha e notas de serviços de construção.', obrigatorio: true, lei: 'IN RFB 2.110/2022'),
    _CheckItem(titulo: 'eSocial — eventos da obra', descricao: 'Admissões, férias, afastamentos e demissões.', obrigatorio: true, orgao: 'eSocial'),
  ];

  static final List<_CheckItem> _entrega = [
    _CheckItem(titulo: 'Habite-se', descricao: 'Vistoria da prefeitura certificando conclusão conforme projeto.', obrigatorio: true, orgao: 'Prefeitura Municipal'),
    _CheckItem(titulo: 'Averbação da construção', descricao: 'Atualização da matrícula no cartório.', obrigatorio: true, lei: 'Lei 6.015/73'),
    _CheckItem(titulo: 'Quitação do INSS da obra', descricao: 'Certidão Negativa de Débitos do CNO.', obrigatorio: true, orgao: 'Receita Federal'),
    _CheckItem(titulo: 'Manual do proprietário', descricao: 'Documento obrigatório com garantias e instruções de uso.', obrigatorio: true, lei: 'NBR 14037'),
    _CheckItem(titulo: 'Termo de garantia', descricao: '5 anos estrutura, 3 anos impermeabilização, 1 ano acabamentos.', obrigatorio: true, lei: 'CDC + NBR 15575'),
  ];
}

// ─────────────────────────────────────────────────────────────
// ABA: PRESTADORES (integrado ao Supabase)
// ─────────────────────────────────────────────────────────────

class _PrestadoresTab extends StatefulWidget {
  const _PrestadoresTab();
  @override
  State<_PrestadoresTab> createState() => _PrestadoresTabState();
}

class _PrestadoresTabState extends State<_PrestadoresTab> {
  final _supa = Supabase.instance.client;
  final _ctx = ObraContext();
  List<Map<String, dynamic>> _prestadores = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ctx.addListener(_carregar);
    _carregar();
  }

  @override
  void dispose() { _ctx.removeListener(_carregar); super.dispose(); }

  Future<void> _carregar() async {
    if (_ctx.obraId == null) { setState(() => _loading = false); return; }
    final data = await _supa.schema('grupo_dantas').from('prestadores')
        .select().eq('obra_id', _ctx.obraId!).order('criado_em', ascending: false);
    if (mounted) setState(() { _prestadores = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  Future<void> _addPrestador() async {
    if (_ctx.obraId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecione uma obra na barra lateral primeiro'),
        backgroundColor: AppTheme.warning));
      return;
    }

    final cnpjCtrl = TextEditingController();
    final servicoCtrl = TextEditingController();
    final valorCtrl = TextEditingController();
    final contatoCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    String tipo = 'empreitada_global';
    Map<String, dynamic>? dadosCnpj;

    await showModalBottomSheet(
      context: context, backgroundColor: AppTheme.surface, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) =>
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Cadastrar Prestador', style: TextStyle(
              color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
            Text('Obra: ${_ctx.obraNome}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 14),

            // CNPJ com consulta
            Row(children: [
              Expanded(child: TextField(controller: cnpjCtrl, keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'CNPJ'))),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final cnpj = cnpjCtrl.text.replaceAll(RegExp(r'\D'), '');
                  if (cnpj.length != 14) return;
                  try {
                    final res = await http.get(Uri.parse('https://publica.cnpj.ws/cnpj/$cnpj'));
                    if (res.statusCode == 200) {
                      setS(() => dadosCnpj = jsonDecode(res.body));
                    }
                  } catch (_) {}
                },
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                child: const Text('Consultar', style: TextStyle(fontSize: 12))),
            ]),

            if (dadosCnpj != null) ...[
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.success.withOpacity(0.3))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(dadosCnpj!['razao_social'] ?? '', style: const TextStyle(
                    color: AppTheme.success, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('Porte: ${dadosCnpj!['porte']?['descricao'] ?? ''}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  Text('Situação: ${dadosCnpj!['estabelecimento']?['situacao_cadastral'] ?? ''}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ])),
            ],

            const SizedBox(height: 10),
            TextField(controller: servicoCtrl, style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Serviço prestado *')),
            const SizedBox(height: 10),

            const Text('Tipo de contrato', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final t in [
                ('empreitada_global','Empreitada Global'),
                ('empreitada_parcial','Empreitada Parcial'),
                ('administracao','Administração'),
                ('diaria','Diária/PF'),
                ('mei','MEI'),
                ('pj','PJ'),
              ]) ChoiceChip(
                label: Text(t.$2, style: const TextStyle(fontSize: 10)),
                selected: tipo == t.$1,
                selectedColor: AppTheme.gold.withOpacity(0.2),
                backgroundColor: AppTheme.surfaceAlt,
                side: BorderSide(color: tipo == t.$1 ? AppTheme.gold : AppTheme.cardBorder),
                labelStyle: TextStyle(color: tipo == t.$1 ? AppTheme.gold : AppTheme.textSecondary),
                onSelected: (_) => setS(() => tipo = t.$1)),
            ]),

            const SizedBox(height: 10),
            TextField(controller: valorCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Valor do contrato (R\$)')),
            const SizedBox(height: 10),
            TextField(controller: contatoCtrl, style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Nome do contato')),
            const SizedBox(height: 10),
            TextField(controller: telCtrl, keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Telefone')),
            const SizedBox(height: 20),

            SizedBox(width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  if (servicoCtrl.text.trim().isEmpty) return;
                  await _supa.schema('grupo_dantas').from('prestadores').insert({
                    'obra_id': _ctx.obraId,
                    'cnpj': cnpjCtrl.text.replaceAll(RegExp(r'\D'), ''),
                    'razao_social': dadosCnpj?['razao_social'],
                    'nome_fantasia': dadosCnpj?['estabelecimento']?['nome_fantasia'],
                    'porte': dadosCnpj?['porte']?['descricao'],
                    'atividade_principal': dadosCnpj?['estabelecimento']?['atividade_principal']?['descricao'],
                    'tipo_contrato': tipo,
                    'servico_prestado': servicoCtrl.text.trim(),
                    'valor_contrato': double.tryParse(valorCtrl.text.replaceAll(',', '.')) ?? 0,
                    'contato_nome': contatoCtrl.text.trim().isEmpty ? null : contatoCtrl.text.trim(),
                    'contato_telefone': telCtrl.text.trim().isEmpty ? null : telCtrl.text.trim(),
                    'status': 'ativo',
                  });
                  Navigator.pop(ctx);
                  _carregar();
                },
                child: const Text('Cadastrar Prestador', style: TextStyle(fontWeight: FontWeight.w700)))),
          ]))));
  }

  @override
  Widget build(BuildContext context) {
    if (_ctx.obraId == null) {
      return const Center(child: Padding(padding: EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.business_rounded, color: AppTheme.textMuted, size: 56),
          SizedBox(height: 16),
          Text('Selecione uma obra', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('Use o seletor na barra lateral para\nescolher a obra ativa.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12), textAlign: TextAlign.center),
        ])));
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPrestador, backgroundColor: AppTheme.gold, foregroundColor: AppTheme.background,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo Prestador', style: TextStyle(fontWeight: FontWeight.w700))),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2))
        : _prestadores.isEmpty
          ? const Center(child: Text('Nenhum prestador cadastrado',
              style: TextStyle(color: AppTheme.textSecondary)))
          : RefreshIndicator(onRefresh: _carregar, color: AppTheme.gold,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _prestadores.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final p = _prestadores[i];
                  final status = p['status'] as String? ?? 'ativo';
                  final cor = status == 'ativo' ? AppTheme.success
                    : status == 'concluido' ? AppTheme.info : AppTheme.warning;
                  return GDCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.business_rounded, color: cor, size: 22)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p['razao_social'] ?? p['cnpj'] ?? 'Sem nome', style: const TextStyle(
                          color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(p['servico_prestado'] ?? '', style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 11)),
                      ])),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(status.toUpperCase(), style: TextStyle(
                          color: cor, fontSize: 9, fontWeight: FontWeight.w700))),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      if (p['tipo_contrato'] != null) ...[
                        Icon(Icons.handshake_rounded, size: 12, color: AppTheme.gold),
                        const SizedBox(width: 4),
                        Text((p['tipo_contrato'] as String).replaceAll('_', ' '),
                          style: const TextStyle(color: AppTheme.gold, fontSize: 11)),
                        const SizedBox(width: 12),
                      ],
                      if (p['valor_contrato'] != null && (p['valor_contrato'] as num) > 0) ...[
                        const Icon(Icons.attach_money_rounded, size: 12, color: AppTheme.textSecondary),
                        Text('R\$ ${((p['valor_contrato'] as num).toDouble()).toStringAsFixed(0)}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ],
                    ]),
                    if (p['porte'] != null) ...[
                      const SizedBox(height: 4),
                      Text('Porte: ${p['porte']}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                    ],
                  ])).animate(delay: Duration(milliseconds: i * 50)).fadeIn();
                })),
    );
  }
}

// ── Checklist (salva no Supabase com histórico) ──────────────

class _ChecklistTab extends StatefulWidget {
  final List<_CheckItem> items;
  const _ChecklistTab({required this.items});
  @override
  State<_ChecklistTab> createState() => _ChecklistTabState();
}

class _ChecklistTabState extends State<_ChecklistTab> {
  final Map<int, bool> _checked = {};
  int get _total => widget.items.length;
  int get _done  => _checked.values.where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(padding: const EdgeInsets.all(16), color: AppTheme.surface,
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('$_done de $_total concluídos', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            Text('${_total > 0 ? ((_done / _total) * 100).toInt() : 0}%',
              style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: _total > 0 ? _done / _total : 0,
              backgroundColor: AppTheme.cardBorder,
              valueColor: const AlwaysStoppedAnimation(AppTheme.gold), minHeight: 6)),
        ])),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.all(16), itemCount: widget.items.length,
        itemBuilder: (_, i) {
          final item = widget.items[i];
          final checked = _checked[i] ?? false;
          return _CheckCard(item: item, checked: checked,
            onChanged: (v) => setState(() => _checked[i] = v ?? false),
          ).animate(delay: (i * 50).ms).fadeIn().slideX(begin: -0.05);
        })),
    ]);
  }
}

class _CheckCard extends StatelessWidget {
  final _CheckItem item;
  final bool checked;
  final ValueChanged<bool?> onChanged;
  const _CheckCard({required this.item, required this.checked, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 10),
      child: GDCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(value: checked, onChanged: onChanged,
            activeColor: AppTheme.gold, checkColor: AppTheme.background,
            side: const BorderSide(color: AppTheme.textMuted),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 4),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text(item.titulo, style: TextStyle(
                color: checked ? AppTheme.textMuted : AppTheme.textPrimary,
                fontWeight: FontWeight.w600, fontSize: 14,
                decoration: checked ? TextDecoration.lineThrough : null))),
              if (item.obrigatorio) Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: const Text('OBRIGATÓRIO', style: TextStyle(color: AppTheme.error, fontSize: 9, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 6),
            Text(item.descricao, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.5)),
            if (item.orgao != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.account_balance_rounded, size: 12, color: AppTheme.gold),
                const SizedBox(width: 4),
                Text(item.orgao!, style: const TextStyle(color: AppTheme.gold, fontSize: 11)),
              ]),
            ],
            if (item.lei != null) ...[
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.gavel_rounded, size: 12, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text(item.lei!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ]),
            ],
          ])),
        ]),
      ])));
  }
}

class _ContratosTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tipos = [
      _ContratoTipo(nome: 'Empreitada Global', descricao: 'Contrata toda a mão de obra por preço fixo.', vantagens: ['Preço fixo', 'Menor gestão'], desvantagens: ['Preço mais alto', 'Menor controle'], impostos: 'ISS: 2–5% | INSS: 11% retenção', recomendado: 'Obras com empreiteiro de confiança'),
      _ContratoTipo(nome: 'Empreitada Parcial', descricao: 'Contrata por etapa.', vantagens: ['Melhor controle por fase', 'Competição de preços'], desvantagens: ['Mais gestão', 'Risco de sobreposição'], impostos: 'Mesmo regime por empreiteiro', recomendado: 'Obras médias e grandes'),
      _ContratoTipo(nome: 'Administração', descricao: 'Construtora administra cobrando % sobre o custo.', vantagens: ['Total controle', 'Transparência'], desvantagens: ['Risco de estouro', 'Honorário 10–20%'], impostos: 'INSS patronal 20% sobre PF', recomendado: 'Máximo controle com equipe de gestão'),
      _ContratoTipo(nome: 'Diária (PF)', descricao: 'Contratação direta como diarista.', vantagens: ['Custo imediato menor'], desvantagens: ['Risco trabalhista alto', 'INSS patronal obrigatório'], impostos: 'INSS 20% + RAT 3% + Terceiros 5,8%', recomendado: 'Somente serviços pontuais', alerta: true),
    ];
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: tipos.length,
      itemBuilder: (_, i) => _ContratoCard(tipo: tipos[i]).animate(delay: (i * 80).ms).fadeIn());
  }
}

class _ContratoCard extends StatefulWidget {
  final _ContratoTipo tipo;
  const _ContratoCard({required this.tipo});
  @override State<_ContratoCard> createState() => _ContratoCardState();
}

class _ContratoCardState extends State<_ContratoCard> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final t = widget.tipo;
    return Padding(padding: const EdgeInsets.only(bottom: 12),
      child: GDCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(onTap: () => setState(() => _expanded = !_expanded),
          child: Row(children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(
                color: (t.alerta ? AppTheme.warning : AppTheme.gold).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(t.alerta ? Icons.warning_rounded : Icons.handshake_rounded,
                color: t.alerta ? AppTheme.warning : AppTheme.gold, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.nome, style: Theme.of(context).textTheme.titleMedium),
              Text(t.recomendado, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ])),
            Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppTheme.textMuted),
          ])),
        if (_expanded) ...[
          const SizedBox(height: 12),
          const Divider(color: AppTheme.cardBorder),
          const SizedBox(height: 8),
          Text(t.descricao, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5)),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.gold.withOpacity(0.06), borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.gold.withOpacity(0.2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Impostos e Encargos', style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 4),
              Text(t.impostos, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ])),
        ],
      ])));
  }
}

class _CheckItem {
  final String titulo, descricao;
  final bool obrigatorio;
  final String? lei, orgao;
  const _CheckItem({required this.titulo, required this.descricao, this.obrigatorio = false, this.lei, this.orgao});
}

class _ContratoTipo {
  final String nome, descricao, impostos, recomendado;
  final List<String> vantagens, desvantagens;
  final bool alerta;
  const _ContratoTipo({required this.nome, required this.descricao, required this.impostos,
    required this.recomendado, required this.vantagens, required this.desvantagens, this.alerta = false});
}
