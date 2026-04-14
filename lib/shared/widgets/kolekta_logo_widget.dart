import 'package:flutter/material.dart';


class KolektaLogoWidget extends StatelessWidget {
  const KolektaLogoWidget({
    super.key,
    this.showSlogan = true,
    this.height = 140, // Tamaño por defecto para el icono
    this.width = 140,
  });

  final bool showSlogan;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Usamos la imagen del logo aquí
        Image.asset(
          'assets/images/logo.png',
          height: height,
          width: width,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}