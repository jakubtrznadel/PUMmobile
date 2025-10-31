import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

ValueNotifier<bool> globalIsPolish = ValueNotifier<bool>(true);

Future<void> saveLanguagePreference(bool isPolish) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('isPolish', isPolish);
  globalIsPolish.value = isPolish;
}

Future<void> loadLanguagePreference() async {
  final prefs = await SharedPreferences.getInstance();
  globalIsPolish.value = prefs.getBool('isPolish') ?? true;
}