import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'custom_app_bar.dart';
import 'translations.dart';
import 'language_state.dart';
import 'services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _emailSent = false;

  void _sendResetLink() async {
    if (_emailController.text.isEmpty) return;
    setState(() {
      _isLoading = true;
    });

    final result = await _authService.forgotPassword(_emailController.text.trim());

    setState(() {
      _isLoading = false;
    });

    final translations =
    globalIsPolish.value ? Translations.pl : Translations.en;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            translations['resetLinkSent'] ??
                'Link wysłany! Sprawdź email i skopiuj token.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _emailSent = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] ??
                (translations['userNotFound'] ?? 'Nie znaleziono użytkownika.'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resetPassword() async {
    if (_tokenController.text.isEmpty || _passwordController.text.isEmpty) return;
    setState(() {
      _isLoading = true;
    });

    final result = await _authService.resetPassword(
      _tokenController.text.trim(),
      _passwordController.text,
    );

    setState(() {
      _isLoading = false;
    });

    final translations =
    globalIsPolish.value ? Translations.pl : Translations.en;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            translations['passwordResetSuccess'] ??
                'Hasło zresetowane! Zaloguj się.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] ??
                (translations['invalidToken'] ?? 'Token niepoprawny lub wygasł.'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _buildEmailForm(
      Map<String, String> translations, ButtonStyle buttonStyle) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          translations['resetPasswordPrompt'] ??
              'Wpisz swój email, aby otrzymać link do resetu hasła.',
          style: const TextStyle(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _emailController,
          style: const TextStyle(color: Color(0xFFffc300)),
          cursorColor: const Color(0xFFffc300),
          decoration: InputDecoration(
            labelText: translations['email']!,
            labelStyle: const TextStyle(color: Color(0xFFffc300)),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFffc300)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFffda66), width: 2),
            ),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        _isLoading
            ? const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFffc300)),
        )
            : ElevatedButton(
          style: buttonStyle,
          onPressed: _sendResetLink,
          child: Text(translations['sendResetLink'] ?? 'Wyślij link'),
        ),
      ],
    );
  }

  Widget _buildResetForm(
      Map<String, String> translations, ButtonStyle buttonStyle) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextField(
          controller: _tokenController,
          style: const TextStyle(color: Color(0xFFffc300)),
          cursorColor: const Color(0xFFffc300),
          decoration: InputDecoration(
            labelText: translations['token'] ?? 'Token',
            labelStyle: const TextStyle(color: Color(0xFFffc300)),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFffc300)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFffda66), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: true,
          style: const TextStyle(color: Color(0xFFffc300)),
          cursorColor: const Color(0xFFffc300),
          decoration: InputDecoration(
            labelText: translations['newPassword'] ?? 'Nowe hasło',
            labelStyle: const TextStyle(color: Color(0xFFffc300)),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFffc300)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFffda66), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _isLoading
            ? const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFffc300)),
        )
            : ElevatedButton(
          style: buttonStyle,
          onPressed: _resetPassword,
          child: Text(translations['resetPassword'] ?? 'Resetuj hasło'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: globalIsPolish,
      builder: (context, isPolish, child) {
        final translations = isPolish ? Translations.pl : Translations.en;

        ButtonStyle customButtonStyle = ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.pressed)) {
              return const Color(0xFFffda66);
            }
            return const Color(0xFFffc300);
          }),
          foregroundColor: WidgetStateProperty.all(const Color(0xFF242424)),
          padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0)),
          textStyle: WidgetStateProperty.all(
            GoogleFonts.bebasNeue(fontSize: 24.0, fontWeight: FontWeight.w600),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          ),
        );

        return Scaffold(
          appBar: CustomAppBar(),
          backgroundColor: const Color(0xFF1a1a1a),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  translations['resetPassword'] ?? 'Resetuj hasło',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 36,
                    color: const Color(0xFFffc300),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _emailSent
                      ? _buildResetForm(translations, customButtonStyle)
                      : _buildEmailForm(translations, customButtonStyle),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}