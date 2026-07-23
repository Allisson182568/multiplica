import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_router.dart';
import 'app_theme.dart';
import 'gd_card.dart';

// ── Chaves de API — substitua antes de rodar ─────────────────
const String groqApiKey      = String.fromEnvironment('GROQ_API_KEY');
const String supabaseUrl      = 'https://wfoysxuynbcuxybkqmfz.supabase.co';
const String supabaseAnonKey  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indmb3lzeHV5bmJjdXh5YmtxbWZ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI3OTk3NDcsImV4cCI6MjA4ODM3NTc0N30.v28Tj6z6PrnyUk_kFSvvchjzwHmV7ZXcJH903hQTiZg';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: GrupoDantasApp()));
}

class GrupoDantasApp extends ConsumerWidget {
  const GrupoDantasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Grupo Dantas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
