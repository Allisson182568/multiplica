import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'app_theme.dart';
import 'gd_card.dart';

class ObraDetailScreen extends StatefulWidget {
  final String obraId;
  const ObraDetailScreen({super.key, required this.obraId});

  @override
  State<ObraDetailScreen> createState() => _ObraDetailScreenState();
}

class _ObraDetailScreenState extends State<ObraDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  final List<_Tab> _tabs = [
    _Tab('Visão Geral', Icons.dashboard_rounded),
    _Tab('Etapas', Icons.format_list_numbered_rounded),
    _Tab('Financeiro', Icons.account_balance_wallet_rounded),
    _Tab('Diário', Icons.menu_book_rounded),
    _Tab('Materiais', Icons.inventory_2_rounded),
    _Tab('Documentos', Icons.folder_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildHeroAppBar(context),
          _buildTabBar(),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _ObraOverviewTab(obraId: widget.obraId),
            _EtapasTab(obraId: widget.obraId),
            _FinanceiroTab(obraId: widget.obraId),
            _DiarioTab(obraId: widget.obraId),
            _MateriaisTab(obraId: widget.obraId),
            _DocumentosTab(obraId: widget.obraId),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(context),
    );
  }

  SliverAppBar _buildHeroAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: AppTheme.background,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: const Icon(Icons.arrow_back_rounded, size: 18),
        ),
        onPressed: () => context.pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: () {},
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Placeholder imagem da obra
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A1408), Color(0xFF0D0D0D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Icon(Icons.construction_rounded,
                  size: 80, color: AppTheme.cardBorder,
                ),
              ),
            ),
            // Overlay gradiente
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, AppTheme.background],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.4, 1.0],
                ),
              ),
            ),
            // Info da obra
            Positioned(
              bottom: 20, left: 20, right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StatusBadge('Em Andamento', AppTheme.gold),
                      const SizedBox(width: 8),
                      _StatusBadge('Residencial', AppTheme.info),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Residência Jardim das Flores',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                        size: 14, color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text('Piracicaba, SP',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverPersistentHeader _buildTabBar() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabBarDelegate(
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppTheme.gold,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.gold,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 2,
          dividerColor: AppTheme.cardBorder,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 13,
          ),
          tabs: _tabs.map((t) => Tab(
            height: 44,
            child: Row(
              children: [
                Icon(t.icon, size: 16),
                const SizedBox(width: 6),
                Text(t.label),
              ],
            ),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {},
      backgroundColor: AppTheme.gold,
      foregroundColor: AppTheme.background,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Atualizar', style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

// ── Aba: Visão Geral ────────────────────────────────────────

class _ObraOverviewTab extends StatelessWidget {
  final String obraId;
  const _ObraOverviewTab({required this.obraId});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Progresso geral
        GDCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Progresso Geral',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              Center(
                child: CircularPercentIndicator(
                  radius: 80,
                  lineWidth: 10,
                  percent: 0.62,
                  center: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('62%', style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w800,
                        color: AppTheme.gold,
                      )),
                      const Text('concluído',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                  progressColor: AppTheme.gold,
                  backgroundColor: AppTheme.cardBorder,
                  circularStrokeCap: CircularStrokeCap.round,
                  animation: true,
                  animationDuration: 1200,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _InfoTile('Início', '10 Jan 2025')),
                  Expanded(child: _InfoTile('Previsão', 'Dez 2025')),
                  Expanded(child: _InfoTile('Área', '180 m²')),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(),
        const SizedBox(height: 16),

        // Resumo financeiro
        GDCard(
          gradient: AppTheme.cardGradient,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                    color: AppTheme.gold, size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text('Resumo Financeiro',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _FinanceiroRow('Orçamento Total', 'R\$ 420.000', AppTheme.textPrimary),
              const SizedBox(height: 12),
              _FinanceiroRow('Realizado', 'R\$ 260.400', AppTheme.gold),
              const SizedBox(height: 12),
              _FinanceiroRow('Saldo', 'R\$ 159.600', AppTheme.success),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: const LinearProgressIndicator(
                  value: 0.62,
                  backgroundColor: AppTheme.cardBorder,
                  valueColor: AlwaysStoppedAnimation(AppTheme.gold),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ).animate(delay: 100.ms).fadeIn(),
        const SizedBox(height: 16),

        // Equipe
        GDCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Equipe', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              _EquipeItem('Eng. Carlos Silva', 'Engenheiro Responsável', Icons.engineering_rounded),
              const SizedBox(height: 12),
              _EquipeItem('João Almeida', 'Cliente', Icons.person_rounded),
            ],
          ),
        ).animate(delay: 200.ms).fadeIn(),
      ],
    );
  }
}

// ── Aba: Etapas ──────────────────────────────────────────────

class _EtapasTab extends StatelessWidget {
  final String obraId;
  const _EtapasTab({required this.obraId});

  @override
  Widget build(BuildContext context) {
    final etapas = [
      ('Documentação e Aprovações', 'concluida', 1.0),
      ('Serviços Preliminares', 'concluida', 1.0),
      ('Fundação', 'concluida', 1.0),
      ('Estrutura', 'em_andamento', 0.75),
      ('Alvenaria', 'em_andamento', 0.30),
      ('Cobertura', 'nao_iniciada', 0.0),
      ('Instalações Brutas', 'nao_iniciada', 0.0),
      ('Reboco e Revestimento', 'nao_iniciada', 0.0),
      ('Acabamentos e Louças', 'nao_iniciada', 0.0),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: etapas.length,
      itemBuilder: (context, i) {
        final (nome, status, progresso) = etapas[i];
        final isLast = i == etapas.length - 1;
        return _EtapaTimelineItem(
          nome: nome,
          status: status,
          progresso: progresso,
          isLast: isLast,
          index: i + 1,
        ).animate(delay: (i * 60).ms).fadeIn().slideX(begin: -0.1);
      },
    );
  }
}

class _EtapaTimelineItem extends StatelessWidget {
  final String nome;
  final String status;
  final double progresso;
  final bool isLast;
  final int index;

  const _EtapaTimelineItem({
    required this.nome, required this.status,
    required this.progresso, required this.isLast, required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(status);
    final isDone = status == 'concluida';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline
        Column(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? color.withOpacity(0.2) : AppTheme.surface,
                border: Border.all(color: color, width: 2),
              ),
              child: Center(
                child: isDone
                  ? Icon(Icons.check_rounded, color: color, size: 18)
                  : Text('$index', style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w700,
                    )),
              ),
            ),
            if (!isLast)
              Container(
                width: 2, height: 40,
                color: isDone ? color.withOpacity(0.4) : AppTheme.cardBorder,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GDCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(nome,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(AppTheme.statusLabel(status),
                          style: TextStyle(
                            color: color, fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (progresso > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progresso,
                              backgroundColor: AppTheme.cardBorder,
                              valueColor: AlwaysStoppedAnimation(color),
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('${(progresso * 100).toInt()}%',
                          style: TextStyle(
                            color: color, fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Aba: Financeiro ──────────────────────────────────────────

class _FinanceiroTab extends StatelessWidget {
  final String obraId;
  const _FinanceiroTab({required this.obraId});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Cards resumo
        Row(
          children: [
            Expanded(child: _FinCard('Orçamento', 'R\$ 420.000', AppTheme.gold)),
            const SizedBox(width: 12),
            Expanded(child: _FinCard('Realizado', 'R\$ 260.400', AppTheme.success)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _FinCard('Saldo', 'R\$ 159.600', AppTheme.info)),
            const SizedBox(width: 12),
            Expanded(child: _FinCard('Variação', '+4.2%', AppTheme.warning)),
          ],
        ),
        const SizedBox(height: 20),
        // Últimas transações
        Text('Últimas Transações',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ...[
          ('Compra de cimento', 'Materiais', -8400.0, '03/06/2025'),
          ('Pagamento mão de obra', 'Serviços', -12000.0, '01/06/2025'),
          ('Medição cliente', 'Receita', 50000.0, '28/05/2025'),
          ('Aquisição de ferragens', 'Materiais', -3200.0, '25/05/2025'),
        ].asMap().entries.map((entry) {
          final i = entry.key;
          final (desc, cat, valor, data) = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TransacaoCard(
              descricao: desc, categoria: cat, valor: valor, data: data,
            ).animate(delay: (i * 60).ms).fadeIn(),
          );
        }),
      ],
    );
  }
}

class _FinCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _FinCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(
            color: AppTheme.textSecondary, fontSize: 12,
          )),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(
            color: color, fontSize: 18, fontWeight: FontWeight.w700,
          )),
        ],
      ),
    );
  }
}

class _TransacaoCard extends StatelessWidget {
  final String descricao;
  final String categoria;
  final double valor;
  final String data;
  const _TransacaoCard({
    required this.descricao, required this.categoria,
    required this.valor, required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = valor > 0;
    return GDCard(
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: (isPositive ? AppTheme.success : AppTheme.error).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPositive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isPositive ? AppTheme.success : AppTheme.error,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(descricao, style: Theme.of(context).textTheme.titleMedium),
                Text('$categoria · $data',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '${isPositive ? '+' : ''}R\$ ${valor.abs().toStringAsFixed(0).replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.'
            )}',
            style: TextStyle(
              color: isPositive ? AppTheme.success : AppTheme.error,
              fontWeight: FontWeight.w700, fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Aba: Diário ──────────────────────────────────────────────

class _DiarioTab extends StatelessWidget {
  final String obraId;
  const _DiarioTab({required this.obraId});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 5,
      itemBuilder: (context, i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GDCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('03/06/2025', style: Theme.of(context).textTheme.titleMedium),
                    Row(
                      children: [
                        const Icon(Icons.wb_sunny_outlined, size: 16, color: AppTheme.warning),
                        const SizedBox(width: 4),
                        Text('Ensolarado', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Etapa: Estrutura',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.gold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Concluída a concretagem dos pilares P1 ao P8. Equipe de 6 operários presentes. '
                  'Aguardando cura do concreto por 28 dias conforme norma.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.group_rounded, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text('6 operários', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(width: 16),
                    const Icon(Icons.person_outline_rounded, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text('Eng. Carlos', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ).animate(delay: (i * 60).ms).fadeIn(),
        );
      },
    );
  }
}

// ── Aba: Materiais ───────────────────────────────────────────

class _MateriaisTab extends StatelessWidget {
  final String obraId;
  const _MateriaisTab({required this.obraId});

  @override
  Widget build(BuildContext context) {
    final materiais = [
      ('Cimento CP-II', 'sc', 200, 'entregue'),
      ('Vergalhão 10mm', 'kg', 500, 'entregue'),
      ('Bloco cerâmico 9x14x19', 'un', 3000, 'solicitado'),
      ('Telha ondulada 6mm', 'm²', 180, 'pendente'),
      ('Piso porcelanato 60x60', 'm²', 120, 'pendente'),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: materiais.length,
      itemBuilder: (context, i) {
        final (nome, unidade, qtd, status) = materiais[i];
        final color = _materialStatusColor(status);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GDCard(
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.inventory_2_rounded, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nome, style: Theme.of(context).textTheme.titleMedium),
                      Text('$qtd $unidade',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_materialStatusLabel(status),
                    style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ).animate(delay: (i * 60).ms).fadeIn(),
        );
      },
    );
  }

  Color _materialStatusColor(String s) {
    switch (s) {
      case 'entregue': return AppTheme.success;
      case 'solicitado': return AppTheme.warning;
      case 'cancelado': return AppTheme.error;
      default: return AppTheme.textMuted;
    }
  }

  String _materialStatusLabel(String s) {
    switch (s) {
      case 'entregue': return 'Entregue';
      case 'solicitado': return 'Solicitado';
      case 'cancelado': return 'Cancelado';
      default: return 'Pendente';
    }
  }
}

// ── Aba: Documentos ──────────────────────────────────────────

class _DocumentosTab extends StatelessWidget {
  final String obraId;
  const _DocumentosTab({required this.obraId});

  @override
  Widget build(BuildContext context) {
    final docs = [
      ('Planta Baixa', 'planta', '2.4 MB', 'PDF'),
      ('Alvará de Construção', 'alvara', '1.1 MB', 'PDF'),
      ('ART Engenheiro', 'art', '0.8 MB', 'PDF'),
      ('Contrato de Obra', 'contrato', '3.2 MB', 'PDF'),
      ('Projeto Elétrico', 'planta', '4.7 MB', 'DWG'),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final (nome, tipo, tamanho, ext) = docs[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GDCard(
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.gold.withOpacity(0.2)),
                  ),
                  child: Center(
                    child: Text(ext, style: const TextStyle(
                      color: AppTheme.gold, fontSize: 11,
                      fontWeight: FontWeight.w800,
                    )),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nome, style: Theme.of(context).textTheme.titleMedium),
                      Text(tamanho, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.download_rounded,
                    color: AppTheme.textSecondary, size: 20,
                  ),
                  onPressed: () {},
                ),
              ],
            ),
          ).animate(delay: (i * 60).ms).fadeIn(),
        );
      },
    );
  }
}

// ── Widgets auxiliares ───────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(
        color: color, fontSize: 11, fontWeight: FontWeight.w600,
      )),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(
          color: AppTheme.textMuted, fontSize: 11,
        )),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(
          color: AppTheme.textPrimary, fontSize: 13,
          fontWeight: FontWeight.w600,
        )),
      ],
    );
  }
}

class _FinanceiroRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _FinanceiroRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(value, style: TextStyle(
          color: color, fontWeight: FontWeight.w700, fontSize: 15,
        )),
      ],
    );
  }
}

class _EquipeItem extends StatelessWidget {
  final String nome;
  final String cargo;
  final IconData icon;
  const _EquipeItem(this.nome, this.cargo, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: AppTheme.goldGradient,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.background, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nome, style: Theme.of(context).textTheme.titleMedium),
            Text(cargo, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height + 1;
  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.background,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}

class _Tab {
  final String label;
  final IconData icon;
  const _Tab(this.label, this.icon);
}
