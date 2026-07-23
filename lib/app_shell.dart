import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'app_theme.dart';
import 'obra_context.dart';
import 'multiplika_logo.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  final _ctx = ObraContext();

  // ── índices ────────────────────────────────────────────────
  // 0  Dashboard
  // 1  Obras
  // ── FERRAMENTAS ───────────────────────────────────────────
  // 2  Viabilidade
  // 3  Jurídico
  // 4  RH & Impostos
  // 5  Checklist
  // 6  Financiamento
  // 7  Triagem de Leads
  // 8  PCI Caixa
  // 9  Mercado            ← NOVO
  // ── SUPORTE ──────────────────────────────────────────────
  // 10 Assistente IA
  // 11 Avisos
  // 12 Perfil
  // ─────────────────────────────────────────────────────────

  final List<_NavItem> _items = [
    _NavItem(Icons.dashboard_rounded,              'Dashboard',        '/dashboard'),
    _NavItem(Icons.construction_rounded,           'Obras',            '/obras'),
    _NavItem(Icons.show_chart_rounded,             'Viabilidade',      '/viabilidade'),
    _NavItem(Icons.gavel_rounded,                  'Jurídico',         '/juridico'),
    _NavItem(Icons.people_rounded,                 'RH & Impostos',    '/rh'),
    _NavItem(Icons.checklist_rounded,              'Checklist',        '/checklist'),
    _NavItem(Icons.account_balance_rounded,        'Financiamento',    '/financiamento'),
    _NavItem(Icons.person_search_rounded,          'Triagem de Leads', '/triagem'),
    _NavItem(Icons.description_outlined,           'PCI Caixa',        '/pci'),
    _NavItem(Icons.store_mall_directory_rounded,   'Mercado',          '/mercado'),  // ← NOVO
    _NavItem(Icons.psychology_rounded,             'Assistente IA',    '/assistente'),
    _NavItem(Icons.notifications_rounded,          'Avisos',           '/notificacoes'),
    _NavItem(Icons.person_rounded,                 'Perfil',           '/perfil'),
  ];

  // Mobile bottom nav: Dashboard, Obras, RH, Assistente IA, Perfil
  final List<int> _mobileIndexes = [0, 1, 4, 10, 12];

  bool get _isWide => MediaQuery.sizeOf(context).width >= 900;

  @override
  void initState() {
    super.initState();
    _ctx.carregarObras();
    _ctx.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  Widget build(BuildContext context) {
    if (_isWide) return _buildWideLayout();
    return _buildMobileLayout();
  }

  Widget _buildWideLayout() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(children: [
        _SideNav(
          items: _items,
          selectedIndex: _selectedIndex,
          onItemTap: (i) {
            setState(() => _selectedIndex = i);
            context.go(_items[i].path);
          },
          obraContext: _ctx,
        ),
        Expanded(child: widget.child),
      ]),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: widget.child,
      drawer: _buildDrawer(),
      bottomNavigationBar: _BottomNav(
        items: _mobileIndexes.map((i) => _items[i]).toList(),
        selectedIndex: _mobileIndexes.contains(_selectedIndex)
            ? _mobileIndexes.indexOf(_selectedIndex)
            : 0,
        onItemTap: (i) {
          final realIdx = _mobileIndexes[i];
          setState(() => _selectedIndex = realIdx);
          context.go(_items[realIdx].path);
        },
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppTheme.surface,
      child: SafeArea(child: Column(children: [
        const SizedBox(height: 20),
        _logoWidget(),
        const SizedBox(height: 12),
        _ObraSelectorCompact(ctx: _ctx),
        const Divider(color: AppTheme.cardBorder),
        Expanded(child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          children: _items.asMap().entries.map((e) => _SideNavItem(
            item: e.value,
            selected: e.key == _selectedIndex,
            onTap: () {
              setState(() => _selectedIndex = e.key);
              context.go(e.value.path);
              Navigator.pop(context);
            },
          )).toList(),
        )),
      ])),
    );
  }

  Widget _logoWidget() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(children: [
      MultiplicaLogo(size: 36),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ShaderMask(
          shaderCallback: (b) => AppTheme.goldGradient.createShader(b),
          child: const Text('MULTIPLIKA', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
        ),
        const Text('INCORPORADORA', style: TextStyle(
            color: AppTheme.textMuted, fontSize: 8, letterSpacing: 2)),
      ]),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────
// SELETOR DE OBRA COMPACTO
// ─────────────────────────────────────────────────────────────

class _ObraSelectorCompact extends StatelessWidget {
  final ObraContext ctx;
  const _ObraSelectorCompact({required this.ctx});

  @override
  Widget build(BuildContext context) {
    if (ctx.obras.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
            color: AppTheme.gold.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.gold.withOpacity(0.25))),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: ctx.obraId,
            isExpanded: true,
            dropdownColor: AppTheme.surface,
            icon: const Icon(Icons.unfold_more_rounded, size: 16, color: AppTheme.gold),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
            hint: const Text('Selecionar obra',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            items: ctx.obras.map((o) => DropdownMenuItem(
              value: o['id'] as String,
              child: Row(children: [
                Icon(Icons.construction_rounded, size: 13,
                    color: AppTheme.statusColor(o['status'] ?? 'planejamento')),
                const SizedBox(width: 6),
                Expanded(child: Text(o['nome'] ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12))),
              ]),
            )).toList(),
            onChanged: (id) {
              if (id == null) return;
              final obra = ctx.obras.firstWhere((o) => o['id'] == id);
              ctx.selecionarObra(obra);
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SIDEBAR
// ─────────────────────────────────────────────────────────────

class _SideNav extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemTap;
  final ObraContext obraContext;
  const _SideNav({
    required this.items,
    required this.selectedIndex,
    required this.onItemTap,
    required this.obraContext,
  });

  @override
  Widget build(BuildContext context) {
    final grupos = [
      _Grupo('Principal',   [0, 1]),
      _Grupo('Ferramentas', [2, 3, 4, 5, 6, 7, 8, 9]),  // 9 = Mercado
      _Grupo('Suporte',     [10, 11, 12]),
    ];

    return Container(
      width: 240,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Column(children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            MultiplicaLogo(size: 36),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ShaderMask(
                shaderCallback: (b) => AppTheme.goldGradient.createShader(b),
                child: const Text('MULTIPLIKA', style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
              ),
              const Text('INCORPORADORA', style: TextStyle(
                  color: AppTheme.textMuted, fontSize: 8, letterSpacing: 2)),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        _ObraSelectorCompact(ctx: obraContext),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: grupos.map((g) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
                  child: Text(g.nome.toUpperCase(), style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 9,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  )),
                ),
                ...g.indices.map((i) => _SideNavItem(
                  item: items[i],
                  selected: i == selectedIndex,
                  onTap: () => onItemTap(i),
                ).animate(delay: (i * 30).ms).fadeIn()),
              ],
            )).toList(),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('v2.0.0 — Multiplika',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ),
      ]),
    );
  }
}

class _SideNavItem extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _SideNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppTheme.gold.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? AppTheme.gold.withOpacity(0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(children: [
              Icon(item.icon, size: 18,
                  color: selected ? AppTheme.gold : AppTheme.textSecondary),
              const SizedBox(width: 10),
              Expanded(child: Text(item.label, style: TextStyle(
                color: selected ? AppTheme.gold : AppTheme.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ))),
              if (selected)
                Container(width: 5, height: 5,
                    decoration: const BoxDecoration(
                        color: AppTheme.gold, shape: BoxShape.circle)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOTTOM NAV (mobile)
// ─────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemTap;
  const _BottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: items.asMap().entries.map((e) {
              final sel = e.key == selectedIndex;
              return Expanded(
                child: InkWell(
                  onTap: () => onItemTap(e.key),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppTheme.gold.withOpacity(0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(e.value.icon, size: 22,
                            color: sel ? AppTheme.gold : AppTheme.textMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(e.value.label, style: TextStyle(
                        fontSize: 9,
                        color: sel ? AppTheme.gold : AppTheme.textMuted,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                      )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DATA CLASSES
// ─────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label, path;
  const _NavItem(this.icon, this.label, this.path);
}

class _Grupo {
  final String nome;
  final List<int> indices;
  const _Grupo(this.nome, this.indices);
}