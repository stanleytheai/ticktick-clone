import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/models/user_settings.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system);

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  void fromString(String theme) {
    switch (theme) {
      case 'light':
        state = ThemeMode.light;
      case 'dark':
        state = ThemeMode.dark;
      default:
        state = ThemeMode.system;
    }
  }
}

// Stream of user settings from Firestore
final userSettingsStreamProvider = StreamProvider<UserSettings>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(UserSettings.defaultSettings);
  return ref.watch(firestoreServiceProvider).watchSettings(user.uid);
});

// Current user settings (convenience accessor)
final userSettingsProvider = Provider<UserSettings>((ref) {
  return ref.watch(userSettingsStreamProvider).valueOrNull ??
      UserSettings.defaultSettings;
});
