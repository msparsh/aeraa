import 'dart:io';
import 'dart:convert';

class StorageService {
  /// Resolves the path to ~/Documents/TaskFlutter/todo.json
  Future<File> get _localFile async {
    // Determine the home directory based on the OS
    String? home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null) {
      throw Exception("Could not determine home directory. 🛑");
    }

    final separator = Platform.pathSeparator;
    final dirPath = '$home${separator}Documents${separator}TaskFlutter';
    final dir = Directory(dirPath);

    // Create the directory if it doesn't exist
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return File('$dirPath${separator}todo.json');
  }

  /// Writes data to the JSON file
  Future<void> saveData(Map<String, dynamic> data) async {
    try {
      final file = await _localFile;
      final jsonString = jsonEncode(data);
      await file.writeAsString(jsonString);
    } catch (e) {
      print("Error saving data: $e ⚠️");
    }
  }

  /// Reads and parses data from the JSON file
  Future<Map<String, dynamic>?> loadData() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        return null; // Return null if it's the first time running
      }
      final contents = await file.readAsString();
      return jsonDecode(contents) as Map<String, dynamic>;
    } catch (e) {
      print("Error loading data: $e ⚠️");
      return null;
    }
  }
}
