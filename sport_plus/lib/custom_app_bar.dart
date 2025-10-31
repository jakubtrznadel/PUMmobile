import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import 'language_state.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'services/auth_service.dart';

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  _CustomAppBarState createState() => _CustomAppBarState();
}

class _CustomAppBarState extends State<CustomAppBar> {
  final _authService = AuthService();

  void toggleLanguage() {
    globalIsPolish.value = !globalIsPolish.value;
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF1a1a1a),
      elevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      leadingWidth: 0,
      title: GestureDetector(
        onTap: () {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => MainScreen(),
              transitionDuration: Duration.zero,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.only(left: 15.0),
          child: Text(
            'Sport+',
            style: GoogleFonts.bebasNeue(
              fontSize: 24,
              color: const Color(0xFFffc300),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      actions: [
        ValueListenableBuilder<bool>(
          valueListenable: globalIsPolish,
          builder: (context, value, child) {
            return IconButton(
              icon: Text(
                value ? 'PL' : 'EN',
                style: const TextStyle(
                  fontSize: 18,
                  color: Color(0xFFffc300),
                ),
              ),
              onPressed: toggleLanguage,
            );
          },
        ),
        FutureBuilder<String?>(
          future: _authService.getToken(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
              return IconButton(
                icon: const Icon(Icons.person, color: Color(0xFFffc300)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfileScreen()),
                  );
                },
              );
            }
            return IconButton(
              icon: const Icon(Icons.login, color: Color(0xFFffc300)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              },
            );
          },
        ),
      ],
    );
  }
}