import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Contexto global de obra selecionada
/// Usado por Viabilidade, Jurídico, Checklist, Financeiro etc.
class ObraContext extends ChangeNotifier {
  static final ObraContext _instance = ObraContext._();
  factory ObraContext() => _instance;
  ObraContext._();

  Map<String, dynamic>? _obraAtiva;
  List<Map<String, dynamic>> _obras = [];

  Map<String, dynamic>? get obraAtiva => _obraAtiva;
  List<Map<String, dynamic>> get obras => _obras;
  String? get obraId => _obraAtiva?['id'] as String?;
  String? get obraNome => _obraAtiva?['nome'] as String?;
  String? get obraTipo => _obraAtiva?['tipo'] as String?;

  /// Retorna as obras visíveis para o usuário logado:
  /// - admin: todas as obras
  /// - qualquer outro papel (cliente, engenheiro, pedreiro): só as obras
  ///   vinculadas a ele na tabela obra_usuarios
  static Future<List<Map<String, dynamic>>> buscarObrasVisiveis({
    String select = 'id, nome, tipo, status, progresso_percentual',
    String orderBy = 'criado_em',
  }) async {
    final supa = Supabase.instance.client;
    final authId = supa.auth.currentUser?.id;
    if (authId == null) return [];

    final usuario = await supa.schema('grupo_dantas').from('usuarios')
        .select('id, role').eq('auth_id', authId).maybeSingle();
    if (usuario == null) return [];

    if (usuario['role'] == 'admin') {
      return List<Map<String, dynamic>>.from(await supa
          .schema('grupo_dantas')
          .from('obras')
          .select(select)
          .order(orderBy, ascending: false));
    }

    final obraIds = await buscarObraIdsVisiveis(usuarioId: usuario['id'] as String);
    if (obraIds.isEmpty) return [];

    return List<Map<String, dynamic>>.from(await supa
        .schema('grupo_dantas')
        .from('obras')
        .select(select)
        .inFilter('id', obraIds)
        .order(orderBy, ascending: false));
  }

  /// Retorna só os IDs das obras vinculadas a um usuário (usado também
  /// para filtrar etapas, transações etc. por obra permitida).
  static Future<List<String>> buscarObraIdsVisiveis({required String usuarioId}) async {
    final supa = Supabase.instance.client;
    final vinculos = await supa.schema('grupo_dantas').from('obra_usuarios')
        .select('obra_id').eq('usuario_id', usuarioId);
    return (vinculos as List).map((v) => v['obra_id'] as String).toList();
  }

  /// Retorna true se o usuário logado é admin (todas as obras visíveis).
  static Future<bool> usuarioEhAdmin() async {
    final supa = Supabase.instance.client;
    final authId = supa.auth.currentUser?.id;
    if (authId == null) return false;
    final usuario = await supa.schema('grupo_dantas').from('usuarios')
        .select('role').eq('auth_id', authId).maybeSingle();
    return usuario?['role'] == 'admin';
  }

  Future<void> carregarObras() async {
    _obras = await buscarObrasVisiveis();

    if (_obraAtiva == null && _obras.isNotEmpty) {
      _obraAtiva = _obras.first;
    } else if (_obraAtiva != null &&
        !_obras.any((o) => o['id'] == _obraAtiva!['id'])) {
      // A obra selecionada não está mais entre as visíveis
      // (ex: trocou de conta/cliente) — reseta a seleção.
      _obraAtiva = _obras.isNotEmpty ? _obras.first : null;
    }
    notifyListeners();
  }

  void selecionarObra(Map<String, dynamic> obra) {
    _obraAtiva = obra;
    notifyListeners();
  }

  void limpar() {
    _obraAtiva = null;
    _obras = [];
    notifyListeners();
  }
}