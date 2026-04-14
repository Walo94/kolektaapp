import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/kolekta_colors.dart';
import '../../../shared/widgets/kolekta_button.dart';
import '../../../shared/widgets/kolekta_text_field.dart';
import '../../../shared/widgets/kolekta_logo_widget.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.requestPasswordReset(_emailCtrl.text.trim());

    if (!mounted) return;

    if (success) {
      setState(() => _emailSent = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Error al enviar el correo'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final isLoading = context.watch<AuthProvider>().loading;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.textPrimary),
          onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              const KolektaLogoWidget(height: 120, width: 120),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: c.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _emailSent ? _SuccessState(c: c, onBack: widget.onBack) : _FormState(
                  formKey: _formKey,
                  emailCtrl: _emailCtrl,
                  isLoading: isLoading,
                  onSubmit: _handleSubmit,
                  c: c,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Estado: formulario ────────────────────────────────────
class _FormState extends StatelessWidget {
  const _FormState({
    required this.formKey,
    required this.emailCtrl,
    required this.isLoading,
    required this.onSubmit,
    required this.c,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final bool isLoading;
  final VoidCallback onSubmit;
  final KolektaColors c;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF1E64DC).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_reset_rounded,
                color: Color(0xFF1E64DC),
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Recuperar contraseña',
              style: AppTextStyles.headingLarge.copyWith(color: c.textPrimary),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: c.textSecondary),
            ),
          ),
          const SizedBox(height: 24),
          KolektaTextField(
            controller: emailCtrl,
            hint: 'Correo electrónico',
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa tu correo';
              final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
              if (!emailRegex.hasMatch(v)) return 'Correo inválido';
              return null;
            },
          ),
          const SizedBox(height: 24),
          KolektaButton(
            label: 'Enviar enlace',
            onPressed: isLoading ? null : onSubmit,
            isLoading: isLoading,
          ),
        ],
      ),
    );
  }
}

// ── Estado: éxito ─────────────────────────────────────────
class _SuccessState extends StatelessWidget {
  const _SuccessState({required this.c, this.onBack});

  final KolektaColors c;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            color: Colors.green,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '¡Correo enviado!',
          style: AppTextStyles.headingLarge.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'Revisa tu bandeja de entrada y sigue las instrucciones para restablecer tu contraseña. El enlace expira en 1 hora.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: 24),
        KolektaButton(
          label: 'Volver al inicio de sesión',
          onPressed: onBack ?? () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}