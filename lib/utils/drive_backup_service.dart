import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'backup_excel_service.dart';

class DriveBackupService {
  static final DriveBackupService instance = DriveBackupService._();

  static const String backupFileName = 'finance_backup.xlsx';
  static const String lastBackupTimeKey = 'last_backup_time';
  static const int backupIntervalHours = 24;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
  );

  DriveBackupService._();

  drive.DriveApi? _driveApi;
  GoogleSignInAccount? _currentUser;

  GoogleSignInAccount? get currentUser => _currentUser;

  Future<GoogleSignInAccount?> signIn({bool silently = false}) async {
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

  Future<void> signOut() async {
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
      if (_currentUser == null) {
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
      if (_currentUser == null) {
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
