import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../core/constants/app_constants.dart';

/// Optional Google Drive backup. Sign-in is explicit and scoped to
/// `drive.file` — the app can only see files it created itself.
class DriveService {
  DriveService._();
  static final DriveService instance = DriveService._();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
  bool get isSignedIn => currentUser != null;

  Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _googleSignIn.signIn();
    } catch (_) {
      return null;
    }
  }

  Future<GoogleSignInAccount?> signInSilently() =>
      _googleSignIn.signInSilently();

  Future<void> signOut() => _googleSignIn.signOut();

  Future<drive.DriveApi?> _api() async {
    final client = await _googleSignIn.authenticatedClient();
    return client == null ? null : drive.DriveApi(client);
  }

  /// Finds or creates the app folder ("Focus OBD2 Scanner") in the
  /// user's Drive and returns its id.
  Future<String?> _ensureFolder(drive.DriveApi api) async {
    final result = await api.files.list(
      q: "name = '${AppConstants.driveFolderName}' and "
          "mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    if (result.files?.isNotEmpty == true) return result.files!.first.id;

    final folder = await api.files.create(drive.File()
      ..name = AppConstants.driveFolderName
      ..mimeType = 'application/vnd.google-apps.folder');
    return folder.id;
  }

  /// Uploads [file] into the app folder. Returns true on success.
  Future<bool> uploadFile(File file, {String? mimeType}) async {
    final api = await _api();
    if (api == null) return false;
    try {
      final folderId = await _ensureFolder(api);
      if (folderId == null) return false;

      final meta = drive.File()
        ..name = file.uri.pathSegments.last
        ..parents = [folderId];
      await api.files.create(
        meta,
        uploadMedia: drive.Media(
          file.openRead(),
          await file.length(),
          contentType: mimeType ?? 'application/octet-stream',
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
