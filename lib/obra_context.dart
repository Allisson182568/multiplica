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

  Future<void> carregarObras() async {
    final data = await Supabase.instance.client
        .schema('grupo_dantas')
        .from('obras')
        .select('id, nome, tipo, status, progresso_percentual')
        .order('criado_em', ascending: false);
    _obras = List<Map<String, dynamic>>.from(data);
    if (_obraAtiva == null && _obras.isNotEmpty) {
      _obraAtiva = _obras.first;
    }
    notifyListeners();
  }

  void selecionarObra(Map<String, dynamic> obra) {
    _obraAtiva = obra;
    notifyListeners();
  }

  void limpar() {
    _obraAtiva = null;
    notifyListeners();
  }
}
