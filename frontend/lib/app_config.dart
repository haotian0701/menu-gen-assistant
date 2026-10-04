class AppConfig {
  AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const oauthRedirectUrl = String.fromEnvironment('OAUTH_REDIRECT_URL');

  static String? get configurationError {
    final missing = <String>[];
    if (supabaseUrl.trim().isEmpty) missing.add('SUPABASE_URL');
    if (supabaseAnonKey.trim().isEmpty) missing.add('SUPABASE_ANON_KEY');

    if (missing.isEmpty) return null;
    return 'Missing app configuration: ${missing.join(', ')}. '
        'Start Flutter with --dart-define-from-file=config/dev.json.';
  }

  static Uri get generateRecipeUri {
    final baseUrl = supabaseUrl.replaceFirst(RegExp(r'/$'), '');
    return Uri.parse('$baseUrl/functions/v1/generate_recipe');
  }

  static String get authRedirectUrl {
    if (oauthRedirectUrl.trim().isNotEmpty) return oauthRedirectUrl;
    return '${Uri.base.origin}/';
  }
}
