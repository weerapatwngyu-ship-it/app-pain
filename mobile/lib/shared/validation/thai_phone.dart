/// Validates a Thai phone number for a form field.
///
/// Returns null when it is acceptable, or the message to show when it is not,
/// matching the shape `TextFormField.validator` expects.
///
/// Shared rather than written per screen: the profile form and the profile
/// editor write to the same column, and a rule that drifted between them would
/// let a number be entered in one place and then rejected as invalid in the
/// other.
///
/// Spaces and dashes are accepted because people type them — refusing a
/// correct number over its punctuation reads as a bug, not as strictness.
/// Ten digits from a leading zero is the mobile format; nine covers the
/// landline numbers still in use.
String? validateThaiPhone(String? value) {
  final digits = (value ?? '').replaceAll(RegExp(r'[\s-]'), '');
  if (digits.isEmpty) return 'กรอกเบอร์โทรศัพท์';
  if (!RegExp(r'^0\d{8,9}$').hasMatch(digits)) {
    return 'กรอกเบอร์โทรให้ถูกต้อง เช่น 0812345678';
  }
  return null;
}
