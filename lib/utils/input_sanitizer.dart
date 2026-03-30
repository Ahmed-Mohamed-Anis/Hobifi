/// Strips HTML tags and trims whitespace from user input.
/// Used at service boundaries before sending data to the database.
class InputSanitizer {
  static final _htmlTagRegex = RegExp(r'<[^>]*>');

  /// Remove HTML tags and trim whitespace.
  static String stripHtml(String input) {
    return input.replaceAll(_htmlTagRegex, '').trim();
  }

  /// Strip HTML and enforce max length.
  static String sanitize(String input, {int? maxLength}) {
    var cleaned = stripHtml(input);
    if (maxLength != null && cleaned.length > maxLength) {
      cleaned = cleaned.substring(0, maxLength);
    }
    return cleaned;
  }
}
