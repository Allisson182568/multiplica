import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'gd_card.dart';
class ObraFormScreen extends StatefulWidget {
  const ObraFormScreen({super.key});
  @override
  State<ObraFormScreen> createState() => _ObraFormScreenState();
}

class _ObraFormScreenState extends State<ObraFormScreen> {
  final _nomeCtrl      = TextEditingController();
  final _enderecoCtrl  = TextEditingController();
  final _orcamentoCtrl = TextEditingController();
  final _areaCtrl      = TextEditingController();
  final _descCtrl      = TextEditingController();
  String _tipo         = 'residencial';
  DateTime? _dataInicio;
  DateTime? _dataFim;
  bool _loading        = false;

  final _supabase = Supabase.instance.client;

  Future<void> _salvar() async {
    if (_nomeCtrl.text.trim().isEmpty) {
      _snack('Informe o nome da obra', AppTheme.error);
      return;
    }

    setState(() => _loading = true);

    try {
      final userId = _supabase.auth.currentUser?.id;

      // Busca o id do usuário na tabela usuarios
      final userRow = await _supabase
          .schema('grupo_dantas')
          .from('usuarios')
          .select('id')
          .eq('auth_id', userId!)
          .maybeSingle();

      final adminId = userRow?['id'];

      await _supabase.schema('grupo_dantas').from('obras').insert({
        'nome': _nomeCtrl.text.trim(),
        'endereco': _enderecoCtrl.text.trim().isEmpty ? null : _enderecoCtrl.text.trim(),
        'tipo': _tipo,
        'status': 'planejamento',
        'orcamento_total': double.tryParse(
          _orcamentoCtrl.text.replaceAll('.', '').replaceAll(',', '.'),
        ) ?? 0,
        'area_total': double.tryParse(_areaCtrl.text.replaceAll(',', '.')) ?? null,
        'descricao': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'data_inicio': _dataInicio?.toIso8601String().substring(0, 10),
        'data_previsao_fim': _dataFim?.toIso8601String().substring(0, 10),
        'admin_id': adminId,
        'progresso_percentual': 0,
      });

      if (mounted) {
        _snack('Obra cadastrada com sucesso!', AppTheme.success);
        await Future.delayed(const Duration(milliseconds: 800));
        context.go('/obras');
      }
    } on PostgrestException catch (e) {
      _snack('Erro ao salvar: ${e.message}', AppTheme.error);
    } catch (e) {
      _snack('Erro inesperado: $e', AppTheme.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: cor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _pickData(bool isInicio) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.gold,
            onPrimary: AppTheme.background,
            surface: AppTheme.surface,
            onSurface: AppTheme.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isInicio) _dataInicio = picked;
        else _dataFim = picked;
      });
    }
  }

  String _fmtData(DateTime? d) =>
      d == null ? '' : '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Nova Obra'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Nome
          _field(_nomeCtrl, 'Nome da Obra *', Icons.business_rounded)
            .animate().fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 14),

          // Endereço
          _field(_enderecoCtrl, 'Endereço', Icons.location_on_outlined)
            .animate(delay: 50.ms).fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 14),

          // Tipo
          DropdownButtonFormField<String>(
            value: _tipo,
            decoration: const InputDecoration(labelText: 'Tipo de Obra'),
            dropdownColor: AppTheme.surface,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            items: const [
              DropdownMenuItem(value: 'residencial', child: Text('Residencial')),
              DropdownMenuItem(value: 'comercial',   child: Text('Comercial')),
              DropdownMenuItem(value: 'galpao',      child: Text('Galpão')),
              DropdownMenuItem(value: 'condominio',  child: Text('Condomínio')),
              DropdownMenuItem(value: 'outro',       child: Text('Outro')),
            ],
            onChanged: (v) => setState(() => _tipo = v!),
          ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 14),

          // Orçamento
          _field(_orcamentoCtrl, 'Orçamento Total (R\$)', Icons.attach_money_rounded,
            type: const TextInputType.numberWithOptions(decimal: true))
            .animate(delay: 150.ms).fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 14),

          // Área
          _field(_areaCtrl, 'Área total construída (m²)', Icons.square_foot_rounded,
            type: const TextInputType.numberWithOptions(decimal: true))
            .animate(delay: 180.ms).fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 14),

          // Datas
          Row(children: [
            Expanded(child: _dataPicker('Data Início', _dataInicio, () => _pickData(true))),
            const SizedBox(width: 12),
            Expanded(child: _dataPicker('Previsão Fim', _dataFim, () => _pickData(false))),
          ]).animate(delay: 200.ms).fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 14),

          // Descrição
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
          ).animate(delay: 220.ms).fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 32),

          // Botão
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _salvar,
              child: _loading
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: AppTheme.background))
                : const Text('CADASTRAR OBRA',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            ),
          ).animate(delay: 250.ms).fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: c,
      keyboardType: type,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 18),
      ),
    );
  }

  Widget _dataPicker(String label, DateTime? value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: value != null ? AppTheme.gold.withOpacity(0.5) : AppTheme.cardBorder),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_rounded,
            size: 16,
            color: value != null ? AppTheme.gold : AppTheme.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(
            value != null ? _fmtData(value) : label,
            style: TextStyle(
              color: value != null ? AppTheme.textPrimary : AppTheme.textMuted,
              fontSize: 13,
            ),
          )),
        ]),
      ),
    );
  }
}
