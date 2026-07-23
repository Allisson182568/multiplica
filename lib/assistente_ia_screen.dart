import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_theme.dart';
import 'gd_card.dart';
import '../../../main.dart'; // para groqApiKey

class AssistenteIAScreen extends StatefulWidget {
  final String? obraContexto;
  const AssistenteIAScreen({super.key, this.obraContexto});
  @override
  State<AssistenteIAScreen> createState() => _AssistenteIAScreenState();
}

class _AssistenteIAScreenState extends State<AssistenteIAScreen> {
  final _ctrl     = TextEditingController();
  final _scroll   = ScrollController();
  final List<_Msg> _msgs = [];
  bool _loading = false;

  static const _sugestoes = [
    'Quais documentos preciso antes de iniciar a fundação?',
    'Como calcular o BDI de uma obra?',
    'O que é SPE e quando preciso abrir uma?',
    'Quais garantias legais devo dar ao cliente?',
    'Como funciona o financiamento bancário para incorporação?',
    'Qual a diferença entre empreitada e administração?',
    'O que é CUB e como usar para orçar?',
    'Quais impostos incidem sobre a venda de imóveis?',
  ];

  Future<void> _enviar([String? texto]) async {
    final msg = (texto ?? _ctrl.text).trim();
    if (msg.isEmpty) return;
    _ctrl.clear();
    setState(() {
      _msgs.add(_Msg(msg, true));
      _loading = true;
    });
    _rolarBaixo();

    try {
      final system = '''Você é um incorporador imobiliário sênior brasileiro com 25 anos de experiência 
em construção civil, incorporação imobiliária, direito imobiliário e gestão de obras. 
Responda sempre em português brasileiro, de forma clara, prática e didática.
Quando relevante, cite leis brasileiras, normas ABNT, tabelas SINDUSCON/CUB, 
e sempre dê conselhos práticos baseados em experiência real de obra.
${widget.obraContexto != null ? 'Contexto da obra atual: ${widget.obraContexto}' : ''}
Seja direto e objetivo. Use emojis com moderação para organizar a resposta.''';

      final res = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {'role': 'system', 'content': system},
            ..._msgs.map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.texto,
            }),
          ],
          'max_tokens': 1024,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final resposta = data['choices'][0]['message']['content'] as String;
        setState(() {
          _msgs.add(_Msg(resposta, false));
          _loading = false;
        });
      } else {
        throw Exception('Erro ${res.statusCode}');
      }
    } catch (e) {
      setState(() {
        _msgs.add(_Msg('Erro ao conectar com o assistente. Verifique sua conexão.', false, isErro: true));
        _loading = false;
      });
    }
    _rolarBaixo();
  }

  void _rolarBaixo() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              gradient: AppTheme.goldGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: Text('IA',
              style: TextStyle(color: AppTheme.background,
                fontWeight: FontWeight.w800, fontSize: 11),
            )),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ShaderMask(
              shaderCallback: (b) => AppTheme.goldGradient.createShader(b),
              child: const Text('Assistente Sênior',
                style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            const Text('Powered by Groq · LLaMA 3.3 70B',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
            ),
          ]),
        ]),
        actions: [
          if (_msgs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              onPressed: () => setState(() => _msgs.clear()),
              tooltip: 'Limpar conversa',
            ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _msgs.isEmpty ? _buildBemVindo(context) : _buildChat(),
        ),
        _buildInput(context),
      ]),
    );
  }

  Widget _buildBemVindo(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      const SizedBox(height: 20),
      Center(
        child: Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: AppTheme.goldGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
              color: AppTheme.gold.withOpacity(0.3), blurRadius: 30,
            )],
          ),
          child: const Center(child: Icon(Icons.psychology_rounded,
            color: AppTheme.background, size: 36,
          )),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
      ),
      const SizedBox(height: 16),
      Center(
        child: Text('Seu Sócio Sênior Digital',
          style: Theme.of(context).textTheme.headlineMedium,
        ).animate(delay: 200.ms).fadeIn(),
      ),
      const SizedBox(height: 8),
      const Center(
        child: Text(
          '25 anos de experiência em incorporação,\nconstrução civil e direito imobiliário.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ).animate(delay: 300.ms).fadeIn(),
      const SizedBox(height: 32),
      Text('Perguntas frequentes', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      ..._sugestoes.asMap().entries.map((entry) {
        final i = entry.key;
        final s = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => _enviar(s),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(children: [
                const Icon(Icons.chat_bubble_outline_rounded,
                  size: 14, color: AppTheme.gold,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(s, style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13,
                ))),
                const Icon(Icons.arrow_forward_ios_rounded,
                  size: 12, color: AppTheme.textMuted,
                ),
              ]),
            ),
          ).animate(delay: (300 + i * 50).ms).fadeIn().slideX(begin: 0.1),
        );
      }),
    ]);
  }

  Widget _buildChat() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _msgs.length + (_loading ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _msgs.length) return _buildTyping();
        final msg = _msgs[i];
        return _BubbleMsg(msg: msg)
          .animate(delay: 50.ms).fadeIn().slideY(begin: 0.1);
      },
    );
  }

  Widget _buildTyping() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            gradient: AppTheme.goldGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(child: Text('IA',
            style: TextStyle(color: AppTheme.background,
              fontWeight: FontWeight.w800, fontSize: 10),
          )),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Row(children: [
            _dot(0), const SizedBox(width: 4),
            _dot(200), const SizedBox(width: 4),
            _dot(400),
          ]),
        ),
      ]),
    );
  }

  Widget _dot(int delay) => Container(
    width: 6, height: 6,
    decoration: const BoxDecoration(
      color: AppTheme.gold, shape: BoxShape.circle,
    ),
  ).animate(onPlay: (c) => c.repeat())
   .fadeIn(delay: delay.ms, duration: 400.ms)
   .fadeOut(delay: (delay + 400).ms, duration: 400.ms);

  Widget _buildInput(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 12, 16, 12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Pergunte qualquer coisa sobre sua obra...',
                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppTheme.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10,
                ),
              ),
              onSubmitted: (_) => _loading ? null : _enviar(),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Material(
              color: _loading ? AppTheme.textMuted : AppTheme.gold,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: _loading ? null : () => _enviar(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 44, height: 44,
                  alignment: Alignment.center,
                  child: _loading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.background,
                        ))
                    : const Icon(Icons.send_rounded,
                        color: AppTheme.background, size: 18),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _BubbleMsg extends StatelessWidget {
  final _Msg msg;
  const _BubbleMsg({required this.msg});

  @override
  Widget build(BuildContext context) {
    if (msg.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 48),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Text(msg.texto, style: const TextStyle(
                color: AppTheme.background, fontSize: 14, height: 1.4,
              )),
            ),
          ),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 48),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            gradient: msg.isErro
              ? const LinearGradient(colors: [AppTheme.error, AppTheme.error])
              : AppTheme.goldGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(msg.isErro ? '!' : 'IA',
            style: const TextStyle(color: AppTheme.background,
              fontWeight: FontWeight.w800, fontSize: 10),
          )),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: msg.isErro
                ? AppTheme.error.withOpacity(0.1)
                : AppTheme.surface,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: msg.isErro
                ? AppTheme.error.withOpacity(0.3) : AppTheme.cardBorder),
            ),
            child: Text(msg.texto, style: TextStyle(
              color: msg.isErro ? AppTheme.error : AppTheme.textPrimary,
              fontSize: 14, height: 1.5,
            )),
          ),
        ),
      ]),
    );
  }
}

class _Msg {
  final String texto;
  final bool isUser;
  final bool isErro;
  const _Msg(this.texto, this.isUser, {this.isErro = false});
}
