final class AppConfig {
  const AppConfig({
    required this.apiBaseUri,
    required this.oidcIssuer,
    required this.oidcClientId,
    required this.redirectUri,
    required this.postLogoutRedirectUri,
    required this.isProduction,
    this.localDevelopmentToolsEnabled = false,
  });

  final Uri apiBaseUri;
  final Uri oidcIssuer;
  final String oidcClientId;
  final String redirectUri;
  final String postLogoutRedirectUri;
  final bool isProduction;
  final bool localDevelopmentToolsEnabled;

  static AppConfigResult fromEnvironment() {
    const apiValue = String.fromEnvironment('KELIMIO_API_BASE_URL');
    const issuerValue = String.fromEnvironment('KELIMIO_OIDC_ISSUER');
    const clientId = String.fromEnvironment('KELIMIO_OIDC_CLIENT_ID');
    const redirect = String.fromEnvironment(
      'KELIMIO_OIDC_REDIRECT_URI',
      defaultValue: 'com.kelimio.app:/oauthredirect',
    );
    const logoutRedirect = String.fromEnvironment(
      'KELIMIO_OIDC_POST_LOGOUT_REDIRECT_URI',
      defaultValue: 'com.kelimio.app:/logout',
    );
    const isProduction = bool.fromEnvironment('dart.vm.product');
    const localDevelopmentToolsEnabled = bool.fromEnvironment(
      'KELIMIO_LOCAL_DEVELOPMENT_TOOLS',
    );

    final issues = <ConfigurationIssue>[];
    final apiUri = Uri.tryParse(apiValue);
    final issuerUri = Uri.tryParse(issuerValue);

    if (apiValue.isEmpty ||
        apiUri == null ||
        !apiUri.hasScheme ||
        apiUri.host.isEmpty) {
      issues.add(const ConfigurationIssue('KELIMIO_API_BASE_URL'));
    }
    if (issuerValue.isEmpty ||
        issuerUri == null ||
        !issuerUri.hasScheme ||
        issuerUri.host.isEmpty) {
      issues.add(const ConfigurationIssue('KELIMIO_OIDC_ISSUER'));
    }
    if (clientId.trim().isEmpty) {
      issues.add(const ConfigurationIssue('KELIMIO_OIDC_CLIENT_ID'));
    }
    if (isProduction && apiUri?.scheme != 'https') {
      issues.add(
        const ConfigurationIssue('KELIMIO_API_BASE_URL', requiresHttps: true),
      );
    }
    if (isProduction && issuerUri?.scheme != 'https') {
      issues.add(
        const ConfigurationIssue('KELIMIO_OIDC_ISSUER', requiresHttps: true),
      );
    }
    if (isProduction && localDevelopmentToolsEnabled) {
      issues.add(const ConfigurationIssue('KELIMIO_LOCAL_DEVELOPMENT_TOOLS'));
    }

    if (issues.isNotEmpty || apiUri == null || issuerUri == null) {
      return AppConfigInvalid(List.unmodifiable(issues));
    }

    final normalizedApi = apiUri.replace(
      path: apiUri.path.endsWith('/')
          ? apiUri.path.substring(0, apiUri.path.length - 1)
          : apiUri.path,
    );
    return AppConfigValid(
      AppConfig(
        apiBaseUri: normalizedApi,
        oidcIssuer: issuerUri,
        oidcClientId: clientId.trim(),
        redirectUri: redirect,
        postLogoutRedirectUri: logoutRedirect,
        isProduction: isProduction,
        localDevelopmentToolsEnabled: localDevelopmentToolsEnabled,
      ),
    );
  }
}

sealed class AppConfigResult {
  const AppConfigResult();
}

final class AppConfigValid extends AppConfigResult {
  const AppConfigValid(this.config);

  final AppConfig config;
}

final class AppConfigInvalid extends AppConfigResult {
  const AppConfigInvalid(this.issues);

  final List<ConfigurationIssue> issues;
}

final class ConfigurationIssue {
  const ConfigurationIssue(this.defineName, {this.requiresHttps = false});

  final String defineName;
  final bool requiresHttps;
}
