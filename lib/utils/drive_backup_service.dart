import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'backup_excel_service.dart';

class DriveBackupService {
  static final DriveBackupService instance = DriveBackupService._();

  static const String backupFileName = 'finance_backup.xlsx';
  static const String lastBackupTimeKey = 'last_backup_time';
  static const int backupIntervalHours = 24;
  static const String _desktopAccessTokenKey = 'desktop_access_token';
  static const String _desktopRefreshTokenKey = 'desktop_refresh_token';
  static const String _desktopTokenExpiryKey = 'desktop_token_expiry';
  static const String _desktopEmailKey = 'desktop_email';
  static const String _desktopClientSecretAsset =
      'client_secret_764916282635-9ih2dea53apls6ai1vcp0na6diosh0bu.apps.googleusercontent.com.json';
  static const String _desktopRedirectUri = 'http://localhost:8080';

  final GoogleSignIn _googleSignIn;

  DriveBackupService._() : _googleSignIn = _initializeGoogleSignIn();

  static GoogleSignIn _initializeGoogleSignIn() {
    // GoogleSignIn automatically handles platform-specific implementations
    return GoogleSignIn(scopes: [drive.DriveApi.driveAppdataScope]);
  }

  drive.DriveApi? _driveApi;
  GoogleSignInAccount? _currentUser;
  String? _desktopAccessToken;
  String? _desktopEmail;
  _OAuthConfig? _oauthConfig;

  GoogleSignInAccount? get currentUser => _currentUser;

  Future<GoogleSignInAccount?> signIn({bool silently = false}) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      debugPrint('Google Sign-In is not supported on desktop.');
      return null;
    }

    final account = silently
        ? await _googleSignIn.signInSilently()
        : await _googleSignIn.signIn();

    if (account == null) {
      return null;
    }

    _currentUser = account;
    await _signInFirebase(account);
    await _initDriveApi(account);
    return account;
  }

  Future<String?> signInEmail({bool silently = false}) async {
    if (_isDesktop) {
      return _desktopSignIn(silently: silently);
    }
    final account = await signIn(silently: silently);
    return account?.email;
  }

  Future<void> signOut() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_desktopAccessTokenKey);
      await prefs.remove(_desktopRefreshTokenKey);
      await prefs.remove(_desktopTokenExpiryKey);
      await prefs.remove(_desktopEmailKey);
      _desktopAccessToken = null;
      _desktopEmail = null;
      _driveApi = null;
      return;
    }

    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
    _currentUser = null;
    _driveApi = null;
  }

  Future<bool> backupToDrive() async {
    final api = await _ensureDriveApi();
    if (api == null) return false;

    final bytes = await BackupExcelService.instance.generateBackupExcelBytes();

    final existingFile = await _findBackupFile(api);
    final media = drive.Media(
      Stream.fromIterable([bytes]),
      bytes.length,
      contentType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );

    if (existingFile != null) {
      await api.files.update(
        drive.File()..name = backupFileName,
        existingFile.id!,
        uploadMedia: media,
      );
    } else {
      final file = drive.File()
        ..name = backupFileName
        ..parents = ['appDataFolder'];

      await api.files.create(file, uploadMedia: media);
    }

    return true;
  }

  Future<bool> restoreFromDrive() async {
    final api = await _ensureDriveApi();
    if (api == null) return false;

    final backupFile = await _findBackupFile(api);
    if (backupFile == null || backupFile.id == null) {
      return false;
    }

    final media =
        await api.files.get(
              backupFile.id!,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    final bytes = await _readMediaBytes(media);
    await BackupExcelService.instance.restoreFromBackupBytes(bytes);
    return true;
  }

  Future<void> _signInFirebase(GoogleSignInAccount account) async {
    if (_isDesktop) return;
    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<void> _initDriveApi(GoogleSignInAccount account) async {
    final headers = await account.authHeaders;
    final client = _GoogleAuthClient(headers);
    _driveApi = drive.DriveApi(client);
  }

  Future<drive.DriveApi?> _ensureDriveApi() async {
    if (_driveApi != null) return _driveApi;
    if (_isDesktop) {
      return _ensureDesktopDriveApi();
    }
    if (_currentUser == null) {
      return null;
    }
    await _initDriveApi(_currentUser!);
    return _driveApi;
  }

  Future<drive.File?> _findBackupFile(drive.DriveApi api) async {
    final result = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$backupFileName' and trashed = false",
      $fields: 'files(id, name)',
      pageSize: 1,
    );
    if (result.files == null || result.files!.isEmpty) {
      return null;
    }
    return result.files!.first;
  }

  Future<List<int>> _readMediaBytes(drive.Media media) async {
    final completer = Completer<List<int>>();
    final bytes = <int>[];
    media.stream.listen(
      bytes.addAll,
      onDone: () => completer.complete(bytes),
      onError: completer.completeError,
      cancelOnError: true,
    );
    return completer.future;
  }

  Future<Map<String, dynamic>?> getBackupInfo() async {
    final api = await _ensureDriveApi();
    if (api == null) return null;

    try {
      final result = await api.files.list(
        spaces: 'appDataFolder',
        q: "name = '$backupFileName' and trashed = false",
        $fields: 'files(id, name, size, modifiedTime, createdTime)',
        pageSize: 1,
      );

      if (result.files == null || result.files!.isEmpty) {
        return null;
      }

      final file = result.files!.first;
      return {
        'exists': true,
        'name': file.name ?? backupFileName,
        'size': file.size != null ? int.parse(file.size!) : 0,
        'modifiedTime': file.modifiedTime,
        'createdTime': file.createdTime,
      };
    } catch (e) {
      debugPrint('Error getting backup info: $e');
      return null;
    }
  }

  // Auto-backup methods
  Future<bool> autoBackupIfNeeded() async {
    try {
      // Only backup if user is signed in
      if (!_isSignedIn) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastBackupTimeStr = prefs.getString(lastBackupTimeKey);

      if (lastBackupTimeStr == null) {
        // No previous backup, do it now
        return await _performAutoBackup(prefs);
      }

      final lastBackupTime = DateTime.parse(lastBackupTimeStr);
      final now = DateTime.now();
      final hoursSinceBackup = now.difference(lastBackupTime).inHours;

      if (hoursSinceBackup >= backupIntervalHours) {
        // Time for scheduled backup
        return await _performAutoBackup(prefs);
      }

      return false;
    } catch (e) {
      debugPrint('Auto-backup check failed: $e');
      return false;
    }
  }

  Future<bool> autoBackupNow() async {
    try {
      if (!_isSignedIn) {
        return false;
      }

      final success = await backupToDrive();
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          lastBackupTimeKey,
          DateTime.now().toIso8601String(),
        );
      }
      return success;
    } catch (e) {
      debugPrint('Auto-backup failed: $e');
      return false;
    }
  }

  Future<bool> _performAutoBackup(SharedPreferences prefs) async {
    try {
      final success = await backupToDrive();
      if (success) {
        await prefs.setString(
          lastBackupTimeKey,
          DateTime.now().toIso8601String(),
        );
        debugPrint('Auto-backup completed successfully');
      }
      return success;
    } catch (e) {
      debugPrint('Auto-backup error: $e');
      return false;
    }
  }

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  bool get _isSignedIn => _isDesktop
      ? (_desktopAccessToken != null || _desktopEmail != null)
      : _currentUser != null;

  Future<String?> _desktopSignIn({bool silently = false}) async {
    if (silently) {
      final token = await _ensureDesktopAccessToken(allowRefresh: true);
      if (token == null) return null;
      _desktopAccessToken = token;
      _driveApi = drive.DriveApi(_GoogleAuthClient(_authHeaders(token)));
      return _desktopEmail ??= await _fetchDesktopEmail(token);
    }

    final authCode = await _runDesktopAuthFlow();
    if (authCode == null) return null;

    final token = await _exchangeCodeForToken(authCode);
    if (token == null) return null;

    _desktopAccessToken = token;
    _driveApi = drive.DriveApi(_GoogleAuthClient(_authHeaders(token)));
    final email = await _fetchDesktopEmail(token);
    if (email != null) {
      _desktopEmail = email;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_desktopEmailKey, email);
    }
    return email;
  }

  Future<_OAuthConfig> _loadOAuthConfig() async {
    if (_oauthConfig != null) return _oauthConfig!;
    final jsonStr = await rootBundle.loadString(_desktopClientSecretAsset);
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final installed = data['installed'] as Map<String, dynamic>;
    _oauthConfig = _OAuthConfig.fromMap(installed);
    return _oauthConfig!;
  }

  Future<String?> _runDesktopAuthFlow() async {
    final config = await _loadOAuthConfig();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);

    final authUrl = Uri.parse(config.authUri).replace(
      queryParameters: {
        'client_id': config.clientId,
        'redirect_uri': _desktopRedirectUri,
        'response_type': 'code',
        'scope': [
          drive.DriveApi.driveAppdataScope,
          'email',
          'profile',
        ].join(' '),
        'access_type': 'offline',
        'prompt': 'consent',
      },
    );

    if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
      await server.close();
      return null;
    }

    final request = await server.first;
    final params = request.uri.queryParameters;
    final code = params['code'];
    final error = params['error'];

    request.response.statusCode = 200;
    request.response.headers.contentType = ContentType.html;
    request.response.write(
      '<html><body><h3>Authentication complete.</h3>'
      '<p>You can close this window and return to the app.</p></body></html>',
    );
    await request.response.close();
    await server.close();

    if (error != null || code == null) {
      return null;
    }
    return code;
  }

  Future<String?> _exchangeCodeForToken(String code) async {
    final config = await _loadOAuthConfig();
    final response = await http.post(
      Uri.parse(config.tokenUri),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': config.clientId,
        'client_secret': config.clientSecret,
        'code': code,
        'grant_type': 'authorization_code',
        'redirect_uri': _desktopRedirectUri,
      },
    );

    if (response.statusCode != 200) {
      debugPrint('Token exchange failed: ${response.body}');
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;
    final expiresIn = data['expires_in'] as int? ?? 3600;

    if (accessToken == null) return null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_desktopAccessTokenKey, accessToken);
    if (refreshToken != null) {
      await prefs.setString(_desktopRefreshTokenKey, refreshToken);
    }
    final expiry = DateTime.now()
        .add(Duration(seconds: expiresIn - 60))
        .toIso8601String();
    await prefs.setString(_desktopTokenExpiryKey, expiry);

    return accessToken;
  }

  Future<String?> _ensureDesktopAccessToken({
    required bool allowRefresh,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_desktopAccessTokenKey);
    final expiryStr = prefs.getString(_desktopTokenExpiryKey);
    _desktopEmail ??= prefs.getString(_desktopEmailKey);

    if (token != null && expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null && DateTime.now().isBefore(expiry)) {
        return token;
      }
    }

    if (!allowRefresh) return null;

    final refreshToken = prefs.getString(_desktopRefreshTokenKey);
    if (refreshToken == null) return null;

    final config = await _loadOAuthConfig();
    final response = await http.post(
      Uri.parse(config.tokenUri),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': config.clientId,
        'client_secret': config.clientSecret,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      },
    );

    if (response.statusCode != 200) {
      debugPrint('Token refresh failed: ${response.body}');
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = data['access_token'] as String?;
    final expiresIn = data['expires_in'] as int? ?? 3600;
    if (accessToken == null) return null;

    await prefs.setString(_desktopAccessTokenKey, accessToken);
    final expiry = DateTime.now()
        .add(Duration(seconds: expiresIn - 60))
        .toIso8601String();
    await prefs.setString(_desktopTokenExpiryKey, expiry);
    return accessToken;
  }

  Future<drive.DriveApi?> _ensureDesktopDriveApi() async {
    final token = await _ensureDesktopAccessToken(allowRefresh: true);
    if (token == null) return null;
    _desktopAccessToken = token;
    _driveApi = drive.DriveApi(_GoogleAuthClient(_authHeaders(token)));
    return _driveApi;
  }

  Map<String, String> _authHeaders(String accessToken) => {
    'Authorization': 'Bearer $accessToken',
  };

  Future<String?> _fetchDesktopEmail(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
        headers: _authHeaders(accessToken),
      );
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['email'] as String?;
    } catch (_) {
      return null;
    }
  }
}

class _OAuthConfig {
  final String clientId;
  final String clientSecret;
  final String authUri;
  final String tokenUri;

  _OAuthConfig({
    required this.clientId,
    required this.clientSecret,
    required this.authUri,
    required this.tokenUri,
  });

  factory _OAuthConfig.fromMap(Map<String, dynamic> map) {
    return _OAuthConfig(
      clientId: map['client_id'] as String,
      clientSecret: map['client_secret'] as String,
      authUri: map['auth_uri'] as String,
      tokenUri: map['token_uri'] as String,
    );
  }
}

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}
