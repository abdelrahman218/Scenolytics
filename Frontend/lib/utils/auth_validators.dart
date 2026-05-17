/// Client-side rules aligned with good passwords; the backend only requires non-empty fields.
String? validateEmailField(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) {
    return 'Email is required';
  }
  // Practical RFC 5322–style check without going overboard.
  final email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  if (!email.hasMatch(v)) {
    return 'Enter a valid email address';
  }
  if (v.length > 254) {
    return 'Email is too long';
  }
  return null;
}

String? validatePasswordField(String? value) {
  final v = value ?? '';
  if (v.isEmpty) {
    return 'Password is required';
  }
  if (v.length < 8) {
    return 'Use at least 8 characters';
  }
  if (v.length > 128) {
    return 'Password is too long';
  }
  final hasLetter = RegExp(r'[A-Za-z]').hasMatch(v);
  final hasDigit = RegExp(r'[0-9]').hasMatch(v);
  if (!hasLetter || !hasDigit) {
    return 'Include at least one letter and one number';
  }
  return null;
}

String? validateConfirmPassword(String? password, String? confirm) {
  if (password == null || password.isEmpty) {
    return 'Confirm your password';
  }
  if (password != (confirm ?? '')) {
    return 'Passwords do not match';
  }
  return null;
}

String? validateFirstNameField(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) {
    return 'First name is required';
  }
  if (v.length > 60) {
    return 'First name is too long';
  }
  return null;
}

String? validateLastNameField(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) {
    return 'Last name is required';
  }
  if (v.length > 60) {
    return 'Last name is too long';
  }
  return null;
}

/// Single full-name field used at sign-up (replaces split first/last).
String? validateNameField(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) {
    return 'Name is required';
  }
  if (v.length < 2) {
    return 'Name is too short';
  }
  if (v.length > 120) {
    return 'Name is too long';
  }
  return null;
}

String? validateGenderField(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) {
    return 'Gender is required';
  }
  return null;
}

String? validateAgeField(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) {
    return 'Age is required';
  }
  final n = int.tryParse(v);
  if (n == null) {
    return 'Enter a valid whole number';
  }
  if (n < 1 || n > 120) {
    return 'Enter an age between 1 and 120';
  }
  return null;
}
