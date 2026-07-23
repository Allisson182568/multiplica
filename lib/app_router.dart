import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';
import 'splash_screen.dart';
import 'register_screen.dart';
import 'aguardando_screen.dart';
import 'dashboard_screen.dart';
import 'obras_list_screen.dart';
import 'obra_form_screen.dart';
import 'obra_detalhe_completo.dart';
import 'viabilidade_screen.dart';
import 'juridico_screen.dart';
import 'rh_impostos_screen.dart';
import 'checklist_obra_screen.dart';
import 'financiamento_screen.dart';
import 'triagem_leads_screen.dart';
import 'pci_caixa_screen.dart';
import 'mercado_screen.dart';           // ← NOVO
import 'assistente_ia_screen.dart';
import 'aprovacao_usuarios_screen.dart';
import 'remaining_screens.dart';
import 'app_shell.dart';
import 'obra_context.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) async {
      final session = Supabase.instance.client.auth.currentSession;
      const pub = ['/splash', '/login', '/cadastro', '/aguardando-aprovacao'];
      if (session == null) {
        return pub.contains(state.matchedLocation) ? null : '/login';
      }
      if (!pub.contains(state.matchedLocation)) {
        try {
          final row = await Supabase.instance.client
              .schema('grupo_dantas').from('usuarios')
              .select('status_aprovacao').eq('auth_id', session.user.id).maybeSingle();
          if (row == null) return null;
          final s = row['status_aprovacao'] as String? ?? 'pendente';
          if (s == 'pendente') return '/aguardando-aprovacao';
          if (s == 'rejeitado') return '/login';
        } catch (_) {}
      }
      return null;
    },
    routes: [
      // ── Rotas públicas / tela cheia (sem AppShell) ────────────────
      GoRoute(path: '/splash',               builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login',                builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/cadastro',             builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/aguardando-aprovacao', builder: (_, __) => const AguardandoAprovacaoScreen()),

      // Triagem: tela cheia sem nav (fluxo de captação externo)
      GoRoute(path: '/triagem', builder: (_, __) => const TriagemLeadsScreen()),

      // PCI Caixa: tela cheia sem nav (documento formal)
      GoRoute(
        path: '/pci',
        builder: (_, state) => PciCaixaScreen(
          obraId:        state.uri.queryParameters['obraId'],
          obraDescricao: state.uri.queryParameters['descricao'],
        ),
      ),

      // ── Rotas com AppShell (sidebar + bottom nav) ─────────────────
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard',    builder: (_, __) => const DashboardScreen()),
          GoRoute(
            path: '/obras',
            builder: (_, __) => const ObrasListScreen(),
            routes: [
              GoRoute(path: 'nova', builder: (_, __) => const ObraFormScreen()),
              GoRoute(
                path: ':id',
                builder: (_, s) => ObraDetalheCompleto(obraId: s.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(path: '/viabilidade',   builder: (_, __) => const ViabilidadeScreen()),
          GoRoute(path: '/juridico',      builder: (_, __) => const JuridicoScreen()),
          GoRoute(path: '/rh',            builder: (_, __) => const RhImpostosScreen()),
          GoRoute(
            path: '/checklist',
            builder: (_, s) => ChecklistObraScreen(
              obraId: s.uri.queryParameters['obraId'] ?? ObraContext().obraId ?? '',
            ),
          ),
          GoRoute(path: '/financiamento', builder: (_, __) => const FinanciamentoScreen()),
          GoRoute(path: '/mercado',       builder: (_, __) => const MercadoScreen()),  // ← NOVO
          GoRoute(
            path: '/assistente',
            builder: (_, s) => AssistenteIAScreen(
              obraContexto: s.uri.queryParameters['contexto'],
            ),
          ),
          GoRoute(path: '/usuarios',     builder: (_, __) => const AprovacaoUsuariosScreen()),
          GoRoute(path: '/notificacoes', builder: (_, __) => const NotificacoesScreen()),
          GoRoute(path: '/perfil',       builder: (_, __) => const PerfilScreen()),
        ],
      ),
    ],
  );
});