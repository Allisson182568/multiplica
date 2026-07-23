import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'gd_card.dart';

class ObrasListScreen extends StatefulWidget {
  const ObrasListScreen({super.key});
  @override
  State<ObrasListScreen> createState() => _ObrasListScreenState();
}

class _ObrasListScreenState extends State<ObrasListScreen> {
  String _filtro = 'todas';
  List<Map<String, dynamic>> _obras = [];
  bool _loading = true;
  String? _erro;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() { _loading = true; _erro = null; });
    try {
      var query = _supabase
          .schema('grupo_dantas')
          .from('obras')
          .select('id, nome, tipo, status, progresso_percentual, orcamento_total, cidade, estado')
          .order('criado_em', ascending: false);

      final data = await query;
      setState(() { _obras = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (e) {
      setState(() { _erro = e.toString(); _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _obrasFiltradas {
    if (_filtro == 'todas') return _obras;
    return _obras.where((o) => o['status'] == _filtro).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (b) => AppTheme.goldGradient.createShader(b),
          child: const Text('Obras', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _carregar),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/obras/nova');
          _carregar(); // recarrega ao voltar
        },
        backgroundColor: AppTheme.gold,
        foregroundColor: AppTheme.background,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova Obra', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [
        // Filtros
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            children: [
              ['todas', 'Todas'],
              ['em_andamento', 'Em Andamento'],
              ['planejamento', 'Planejamento'],
              ['concluida', 'Concluídas'],
              ['pausada', 'Pausadas'],
            ].map((f) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f[1]),
                selected: _filtro == f[0],
                onSelected: (_) => setState(() => _filtro = f[0]),
                selectedColor: AppTheme.gold.withOpacity(0.2),
                backgroundColor: AppTheme.surface,
                side: BorderSide(color: _filtro == f[0] ? AppTheme.gold.withOpacity(0.5) : AppTheme.cardBorder),
                labelStyle: TextStyle(
                  color: _filtro == f[0] ? AppTheme.gold : AppTheme.textSecondary,
                  fontSize: 12, fontWeight: FontWeight.w500,
                ),
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 10),

        // Conteúdo
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(
      child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2),
    );

    if (_erro != null) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 48),
        const SizedBox(height: 12),
        Text('Erro ao carregar obras', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(_erro!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _carregar,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Tentar novamente'),
        ),
      ],
    ));

    final lista = _obrasFiltradas;

    if (lista.isEmpty) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.construction_rounded, color: AppTheme.textMuted, size: 56),
        const SizedBox(height: 16),
        Text(
          _obras.isEmpty ? 'Nenhuma obra cadastrada ainda' : 'Nenhuma obra neste filtro',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        ),
        if (_obras.isEmpty) ...[
          const SizedBox(height: 8),
          const Text('Toque em + Nova Obra para começar',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
        ],
      ],
    ));

    return RefreshIndicator(
      onRefresh: _carregar,
      color: AppTheme.gold,
      backgroundColor: AppTheme.surface,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        itemCount: lista.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _ObraCard(obra: lista[i])
          .animate(delay: (i * 50).ms).fadeIn().slideY(begin: 0.1),
      ),
    );
  }
}

class _ObraCard extends StatelessWidget {
  final Map<String, dynamic> obra;
  const _ObraCard({required this.obra});

  @override
  Widget build(BuildContext context) {
    final status    = obra['status'] as String? ?? 'planejamento';
    final tipo      = obra['tipo'] as String? ?? 'outro';
    final prog      = (obra['progresso_percentual'] as num?)?.toDouble() ?? 0.0;
    final orcamento = (obra['orcamento_total'] as num?)?.toDouble() ?? 0.0;
    final color     = AppTheme.statusColor(status);
    final cidade    = obra['cidade'] as String?;
    final estado    = obra['estado'] as String?;
    final local     = [cidade, estado].where((v) => v != null && v.isNotEmpty).join(', ');

    return GDCard(
      onTap: () => context.push('/obras/${obra['id']}'),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(_tipoIcon(tipo), color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(obra['nome'] ?? '', style: Theme.of(context).textTheme.titleMedium,
            maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Row(children: [
            Text(_tipoLabel(tipo), style: Theme.of(context).textTheme.bodySmall),
            if (orcamento > 0) ...[
              const Text(' · ', style: TextStyle(color: AppTheme.textMuted)),
              Text(_fmtOrcamento(orcamento), style: const TextStyle(
                color: AppTheme.gold, fontSize: 12, fontWeight: FontWeight.w600,
              )),
            ],
            if (local.isNotEmpty) ...[
              const Text(' · ', style: TextStyle(color: AppTheme.textMuted)),
              Flexible(child: Text(local, style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis)),
            ],
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: prog / 100,
                backgroundColor: AppTheme.cardBorder,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 4,
              ),
            )),
            const SizedBox(width: 8),
            Text('${prog.toInt()}%', style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700,
            )),
          ]),
        ])),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(AppTheme.statusLabel(status),
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  String _fmtOrcamento(double v) {
    if (v >= 1000000) return 'R\$ ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return 'R\$ ${(v / 1000).toStringAsFixed(0)}k';
    return 'R\$ ${v.toStringAsFixed(0)}';
  }

  IconData _tipoIcon(String t) {
    switch (t) {
      case 'galpao':     return Icons.warehouse_rounded;
      case 'condominio': return Icons.apartment_rounded;
      case 'comercial':  return Icons.store_rounded;
      default:           return Icons.home_rounded;
    }
  }

  String _tipoLabel(String t) {
    switch (t) {
      case 'galpao':     return 'Galpão';
      case 'condominio': return 'Condomínio';
      case 'comercial':  return 'Comercial';
      case 'residencial':return 'Residencial';
      default:           return 'Outro';
    }
  }
}
