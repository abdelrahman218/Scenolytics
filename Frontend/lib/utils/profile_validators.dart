import '../constants/profile_field_options.dart';

String? validateDisplayNameField(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) {
    return 'Display name is required';
  }
  if (v.length < 2) {
    return 'Display name is too short';
  }
  if (v.length > 120) {
    return 'Display name is too long';
  }
  return null;
}

String? validatePhoneField(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) {
    return 'Phone is required';
  }
  final digits = v.replaceAll(RegExp(r'[\s\-\(\)\.\+]'), '');
  if (digits.length < 7 || digits.length > 20) {
    return 'Enter a valid phone number';
  }
  if (!RegExp(r'^\+?[0-9]+$').hasMatch(digits)) {
    return 'Phone may only contain digits and +';
  }
  return null;
}

String? validateHeightCmField(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) {
    return 'Height is required';
  }
  final n = int.tryParse(v);
  if (n == null) {
    return 'Enter height in centimeters';
  }
  if (n < 50 || n > 300) {
    return 'Enter a height between 50 and 300 cm';
  }
  return null;
}

String? validateActorGenderField(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) {
    return 'Gender is required';
  }
  if (!ActorProfileOptions.genderOptions.contains(v)) {
    return 'Select Male or Female';
  }
  return null;
}

String? validateBodyTypeField(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) {
    return 'Body type is required';
  }
  if (!ActorProfileOptions.bodyTypeOptions.contains(v)) {
    return 'Select a valid body type';
  }
  return null;
}

String? validateEthnicityField(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) {
    return 'Ethnicity is required';
  }
  if (!ActorProfileOptions.ethnicityOptions.contains(v)) {
    return 'Select a valid ethnicity';
  }
  return null;
}

String? validateRequiredDropdown(String? value, {required String label}) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) {
    return '$label is required';
  }
  return null;
}
