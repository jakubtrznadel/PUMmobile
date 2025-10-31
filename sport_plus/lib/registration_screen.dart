import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'custom_app_bar.dart';
import 'translations.dart';
import 'language_state.dart';
import 'services/auth_service.dart';
import 'login_screen.dart';

class RegistrationScreen extends StatefulWidget {
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  void _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            globalIsPolish.value ? 'Hasła się nie zgadzają' : 'Passwords do not match',
            style: GoogleFonts.bebasNeue(fontSize: 18, color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await _authService.register(email, password);

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] ?? (globalIsPolish.value ? 'Rejestracja udana!' : 'Registration successful!'),
            style: GoogleFonts.bebasNeue(fontSize: 18, color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] ?? (globalIsPolish.value ? 'Błąd rejestracji' : 'Registration error'),
            style: GoogleFonts.bebasNeue(fontSize: 18, color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0)),
          textStyle: WidgetStateProperty.all(
            GoogleFonts.bebasNeue(fontSize: 24.0, fontWeight: FontWeight.w600),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          ),
          elevation: WidgetStateProperty.resolveWith<double>((states) {
            if (states.contains(WidgetState.pressed)) {
              return 4.0;
            }
            return 8.0;
          }),
          shadowColor: WidgetStateProperty.all(Colors.black26),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          animationDuration: const Duration(milliseconds: 150),
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
                  translations['register']!,
                  style: GoogleFonts.bebasNeue(
                    fontSize: 36,
                    color: const Color(0xFFffc300),
                  ),
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
                    hintStyle: const TextStyle(color: Color(0xFFffc300)),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Color(0xFFffc300)),
                  cursorColor: const Color(0xFFffc300),
                  decoration: InputDecoration(
                    labelText: translations['password']!,
                    labelStyle: const TextStyle(color: Color(0xFFffc300)),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFffc300)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFffda66), width: 2),
                    ),
                    hintStyle: const TextStyle(color: Color(0xFFffc300)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Color(0xFFffc300)),
                  cursorColor: const Color(0xFFffc300),
                  decoration: InputDecoration(
                    labelText: translations['confirmPassword']!,
                    labelStyle: const TextStyle(color: Color(0xFFffc300)),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFffc300)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFffda66), width: 2),
                    ),
                    hintStyle: const TextStyle(color: Color(0xFFffc300)),
                  ),
                ),
                const SizedBox(height: 20),
                _isLoading
                    ? const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFffc300)),
                )
                    : ElevatedButton(
                  style: customButtonStyle,
                  onPressed: _register,
                  child: Text(translations['registerButton']!),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}