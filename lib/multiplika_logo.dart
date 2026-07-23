import 'package:flutter/material.dart';

/// Logo da Multiplika — usa assets/images/logo.png
/// Mantém a mesma API pública para não quebrar nada

class MultiplicaLogo extends StatelessWidget {
  final double size;
  const MultiplicaLogo({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

/// Versão completa: logo + nome + slogan
class MultiplicaLogoCompleto extends StatelessWidget {
  final double logoSize;
  final bool showSlogan;
  final bool horizontal;

  const MultiplicaLogoCompleto({
    super.key,
    this.logoSize = 80,
    this.showSlogan = true,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final nomes = Column(
      crossAxisAlignment: horizontal ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFB87333), Color(0xFFD4954F)],
          ).createShader(bounds),
          child: Text(
            'MULTIPLIKA',
            style: TextStyle(
              color: Colors.white,
              fontSize: logoSize * 0.35,
              fontWeight: FontWeight.w800,
              letterSpacing: logoSize * 0.02,
              height: 1.1,
            ),
          ),
        ),
        Text(
          'INCORPORADORA',
          style: TextStyle(
            color: const Color(0xFF8A8580),
            fontSize: logoSize * 0.18,
            fontWeight: FontWeight.w400,
            letterSpacing: logoSize * 0.04,
          ),
        ),
        if (showSlogan) ...[
          const SizedBox(height: 2),
          Text(
            'SOLIDEZ EM CADA PILAR',
            style: TextStyle(
              color: const Color(0xFF4A4540),
              fontSize: logoSize * 0.12,
              letterSpacing: logoSize * 0.03,
            ),
          ),
        ],
      ],
    );

    if (horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MultiplicaLogo(size: logoSize),
          SizedBox(width: logoSize * 0.2),
          nomes,
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MultiplicaLogo(size: logoSize),
        SizedBox(height: logoSize * 0.15),
        nomes,
      ],
    );
  }
}
