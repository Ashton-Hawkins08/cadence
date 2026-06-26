import 'package:cadence/core/constants/app_constants.dart';

class NameValidator {
  NameValidator._();

  static const _blocked = [
    'penis', 'vagina', 'fuck', 'shit', 'cunt', 'cock',
    'pussy', 'whore', 'nigger', 'nigga', 'faggot', 'retard', 'bitch',
  ];

  static String sanitize(String raw) {
    return raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool _containsProfanity(String text) {
    final lower = text.toLowerCase();
    for (final word in _blocked) {
      final idx = lower.indexOf(word);
      if (idx == -1) continue;
      final before = idx == 0 || !_isLetter(lower[idx - 1]);
      final after = idx + word.length >= lower.length ||
          !_isLetter(lower[idx + word.length]);
      if (before && after) return true;
    }
    return false;
  }

  static bool _isLetter(String c) => RegExp(r'[a-zA-Z]').hasMatch(c);

  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a name — it can\'t be empty.';
    }

    final n = sanitize(value);

    if (RegExp(r'^\d+$').hasMatch(n)) {
      return 'Names can\'t be just a number. Please add letters too.';
    }

    if (n.toLowerCase() == 'cancel') {
      return '\'Cancel\' is reserved. Please pick a different name.';
    }

    if (n.length > AppConstants.maxName) {
      return 'Name is too long (${n.length} chars). Keep it under ${AppConstants.maxName}.';
    }

    if (_containsProfanity(n)) {
      return 'That name isn\'t allowed. Please choose something appropriate.';
    }

    return null;
  }

  // Lenient validator for optional fields (last name, etc.) — allows empty
  static String? validateOptional(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return validate(value);
  }

  static bool isSameNormalized(String a, String b) {
    return a.trim().toLowerCase() == b.trim().toLowerCase();
  }

  static bool existsIn(String name, Iterable<String> names) {
    return names.any((n) => isSameNormalized(n, name));
  }
}
