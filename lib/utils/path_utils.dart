
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Windows上でパス長の制限を回避するためのユーティリティクラス
class PathUtils {
  /// Windowsのファイルパス長の制限（通常260文字）
  static const int _windowsPathLengthLimit = 260;

  /// ロングパス接頭辞（Windows上で長いパスを有効にする）
  static const String _longPathPrefix = r'\\?\';

  /// 指定されたパスが長すぎる場合、Windows上で長いパスサポートを追加します
  /// [filePath] 処理するファイルパス
  /// [return] 長いパスをサポートするために修正されたパス、または元のパス
  static String ensureSafePath(String filePath) {
    if (!Platform.isWindows) {
      return filePath; // Windowsでない場合は修正不要
    }

    // すでにプレフィックスが付いている場合はそのまま返す
    if (filePath.startsWith(_longPathPrefix)) {
      return filePath;
    }

    // 絶対パスでない場合は絶対パスに変換
    final absolutePath = p.isAbsolute(filePath) 
        ? filePath 
        : p.absolute(filePath);

    // パスの長さがWindows制限を超える場合
    if (absolutePath.length > _windowsPathLengthLimit) {
      debugPrint('Path length exceeds Windows limit, using long path: $absolutePath');
      return '$_longPathPrefix${absolutePath.replaceAll('/', '\\')}';
    }

    return absolutePath;
  }

  /// ファイルパスが存在するか確認します。長いパスの場合はプレフィックスを追加します。
  /// [filePath] 確認するファイルパス
  /// [return] 存在する場合はtrue、存在しない場合はfalse
  static Future<bool> fileExists(String filePath) async {
    final safePath = ensureSafePath(filePath);
    return await File(safePath).exists();
  }

  /// ファイルを読み込みます。長いパスの場合はプレフィックスを追加します。
  /// [filePath] 読み込むファイルパス
  /// [return] ファイルの内容
  static Future<String> readFileAsString(String filePath) async {
    final safePath = ensureSafePath(filePath);
    return await File(safePath).readAsString();
  }

  /// ファイルに書き込みます。長いパスの場合はプレフィックスを追加します。
  /// [filePath] 書き込むファイルパス
  /// [content] 書き込む内容
  static Future<void> writeFileAsString(String filePath, String content) async {
    final safePath = ensureSafePath(filePath);
    await File(safePath).writeAsString(content);
  }

  /// クラスパスエントリの最大長
  static const int _classpathEntryMaxLength = 200;

  /// クラスパスを安全な形式に処理します。
  /// 長すぎるエントリはシンボリックリンクで置き換えるか、短縮します。
  /// 
  /// [classpath] 処理するクラスパスのリスト
  /// [workingDir] 作業ディレクトリ（シンボリックリンクの作成場所）
  /// [return] 処理されたクラスパスのリスト
  static Future<List<String>> processSafeClasspath(
    List<String> classpath,
    String workingDir,
  ) async {
    if (!Platform.isWindows) {
      return classpath; // Windowsでない場合は修正不要
    }

    final processedClasspath = <String>[];
    final symlinkDir = Directory(p.join(workingDir, 'classpath_symlinks'));
    
    // シンボリックリンク用ディレクトリが存在しない場合は作成
    if (!await symlinkDir.exists()) {
      await symlinkDir.create(recursive: true);
    }

    int symlinkIndex = 0;
    for (final path in classpath) {
      if (path.length <= _classpathEntryMaxLength) {
        // 短いパスはそのまま追加
        processedClasspath.add(path);
        continue;
      }

      try {
        // 長いパスの場合はシンボリックリンクを作成
        final fileName = p.basename(path);
        final symlinkPath = p.join(
          symlinkDir.path,
          'link_${symlinkIndex}_$fileName',
        );
        
        final linkFile = Link(symlinkPath);
        if (await linkFile.exists()) {
          await linkFile.delete();
        }
        
        await linkFile.create(
          ensureSafePath(path),
          recursive: true,
        );
        
        processedClasspath.add(symlinkPath);
        symlinkIndex++;
        
        debugPrint('Created symlink for long path: $path -> $symlinkPath');
      } catch (e) {
        debugPrint('Error creating symlink for long path: $e');
        // 失敗した場合は元のパスを使用
        processedClasspath.add(ensureSafePath(path));
      }
    }
    
    return processedClasspath;
  }
}
