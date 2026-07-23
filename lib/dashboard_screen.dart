import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'gd_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _supa = Supabase.instance.client;
  int _total = 0, _emAndamento = 0, _concluidas = 0, _pausadas = 0;
  List<Map<String, dynamic>> _obras = [];
  List<Map<String, dynamic>> _etapasAtivas = [];
  String _nomeUsuario = 'Multiplika';
  bool _loading = true;

  @override
  void initState() { super.initState(); _carregar(); }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      // Nome do usuário
      final uid = _supa.auth.currentUser?.id;
      if (uid != null) {
        final u = await _supa.schema('grupo_dantas').from('usuarios')
            .select('nome').eq('auth_id', uid).maybeSingle();
        if (u != null && u['nome'] != null) _nomeUsuario = u['nome'];
      }

      final obras = await _supa.schema('grupo_dantas').from('obras')
          .select('id, nome, tipo, status, progresso_percentual, orcamento_total, custo_realizado, cidade, estado')
          .order('atualizado_em', ascending: false);
      final lista = List<Map<String, dynamic>>.from(obras);

      final etapas = await _supa.schema('grupo_dantas').from('etapas')
          .select('id, nome, status, progresso_percentual, obra_id, obras!inner(nome)')
          .eq('status', 'em_andamento')
          .order('atualizado_em', ascending: false).limit(5);

      setState(() {
        _obras       = lista;
        _total       = lista.length;
        _emAndamento = lista.where((o) => o['status'] == 'em_andamento').length;
        _concluidas  = lista.where((o) => o['status'] == 'concluida').length;
        _pausadas    = lista.where((o) => o['status'] == 'pausada').length;
        _etapasAtivas = List<Map<String, dynamic>>.from(etapas);
        _loading     = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: _carregar, color: AppTheme.gold, backgroundColor: AppTheme.surface,
        child: CustomScrollView(slivers: [
          _buildAppBar(),
          SliverPadding(padding: const EdgeInsets.all(20),
            sliver: SliverList(delegate: SliverChildListDelegate([
              _buildKPIRow(),
              const SizedBox(height: 24),
              _buildObrasRecentes(),
              if (_etapasAtivas.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildEtapasAtivas(),
              ],
              const SizedBox(height: 40),
            ]))),
        ]),
      ),
    );
  }

  SliverAppBar _buildAppBar() {
    final hora = DateTime.now().hour;
    final saudacao = hora < 12 ? 'Bom dia,' : hora < 18 ? 'Boa tarde,' : 'Boa noite,';
    return SliverAppBar(
      expandedHeight: 110, floating: true, pinned: true,
      backgroundColor: AppTheme.background,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
        title: Column(mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(saudacao, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ShaderMask(
            shaderCallback: (b) => AppTheme.goldGradient.createShader(b),
            child: Text(_nomeUsuario, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
          ),
        ]),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _carregar),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildKPIRow() {
    final kpis = [
      _KPI('Total de Obras',   '$_total',       Icons.construction_rounded,     AppTheme.gold),
      _KPI('Em Andamento',     '$_emAndamento', Icons.play_circle_rounded,       AppTheme.success),
      _KPI('Concluídas',       '$_concluidas',  Icons.check_circle_rounded,      AppTheme.info),
      _KPI('Pausadas',         '$_pausadas',    Icons.pause_circle_rounded,      AppTheme.warning),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final crossCount = constraints.maxWidth > 600 ? 4 : 2;
      return GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossCount, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6),
        itemCount: kpis.length,
        itemBuilder: (_, i) {
          final k = kpis[i];
          return GDCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(width: 34, height: 34,
              decoration: BoxDecoration(color: k.color.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
              child: Icon(k.icon, color: k.color, size: 17)),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _loading
                ? Container(width: 32, height: 24, decoration: BoxDecoration(
                    color: AppTheme.cardBorder, borderRadius: BorderRadius.circular(4)))
                : Text(k.value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: k.color)),
              Text(k.label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ]),
          ])).animate(delay: (i * 80).ms).fadeIn().slideY(begin: 0.2);
        },
      );
    });
  }

  Widget _buildObrasRecentes() {
    final recentes = _obras.take(4).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Obras Recentes', style: Theme.of(context).textTheme.titleLarge),
        TextButton(onPressed: () => context.go('/obras'),
          child: const Text('Ver todas', style: TextStyle(color: AppTheme.gold, fontSize: 13))),
      ]),
      const SizedBox(height: 12),
      if (_loading)
        const Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2))
      else if (recentes.isEmpty)
        GDCard(child: Column(children: [
          const Icon(Icons.construction_rounded, color: AppTheme.textMuted, size: 40),
          const SizedBox(height: 8),
          const Text('Nenhuma obra cadastrada ainda', style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => context.go('/obras/nova'),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Cadastrar primeira obra')),
        ]))
      else SizedBox(height: 190, child: ListView.separated(
        scrollDirection: Axis.horizontal, itemCount: recentes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(width: 220,
          child: _ObraMiniCard(obra: recentes[i])
            .animate(delay: (i * 80).ms).fadeIn().slideX(begin: 0.2)),
      )),
    ]);
  }

  Widget _buildEtapasAtivas() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Etapas em Progresso', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      ..._etapasAtivas.asMap().entries.map((entry) {
        final i = entry.key;
        final e = entry.value;
        final prog = (e['progresso_percentual'] as num?)?.toDouble() ?? 0;
        final nomeObra = (e['obras'] as Map?)?['nome'] ?? '';
        return Padding(padding: const EdgeInsets.only(bottom: 10),
          child: GDCard(child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nomeObra, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(e['nome'] ?? '', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 10),
              ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: prog / 100,
                  backgroundColor: AppTheme.cardBorder,
                  valueColor: AlwaysStoppedAnimation(prog > 70 ? AppTheme.success : AppTheme.gold),
                  minHeight: 6)),
            ])),
            const SizedBox(width: 16),
            Text('${prog.toInt()}%', style: TextStyle(
              color: prog > 70 ? AppTheme.success : AppTheme.gold,
              fontWeight: FontWeight.w700, fontSize: 18)),
          ])).animate(delay: (i * 80).ms).fadeIn());
      }),
    ]);
  }
}

class _ObraMiniCard extends StatelessWidget {
  final Map<String, dynamic> obra;
  const _ObraMiniCard({required this.obra});

  @override
  Widget build(BuildContext context) {
    final status = obra['status'] as String? ?? 'planejamento';
    final tipo   = obra['tipo'] as String? ?? 'outro';
    final prog   = (obra['progresso_percentual'] as num?)?.toDouble() ?? 0.0;
    final color  = AppTheme.statusColor(status);

    return GDCard(gradient: AppTheme.cardGradient, padding: EdgeInsets.zero,
      onTap: () => context.push('/obras/${obra['id']}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 70,
          decoration: BoxDecoration(color: AppTheme.surfaceAlt,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
          child: Center(child: Icon(_tipoIcon(tipo), size: 32, color: AppTheme.cardBorder))),
        Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(obra['nome'] ?? '', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(AppTheme.statusLabel(status),
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: prog / 100,
                backgroundColor: AppTheme.cardBorder,
                valueColor: AlwaysStoppedAnimation(color), minHeight: 4))),
            const SizedBox(width: 8),
            Text('${prog.toInt()}%', style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ])),
      ]),
    );
  }

  IconData _tipoIcon(String t) {
    switch (t) {
      case 'galpao':     return Icons.warehouse_rounded;
      case 'condominio': return Icons.apartment_rounded;
      case 'comercial':  return Icons.store_rounded;
      default:           return Icons.home_rounded;
    }
  }
}

class _KPI {
  final String label, value;
  final IconData icon;
  final Color color;
  const _KPI(this.label, this.value, this.icon, this.color);
}
