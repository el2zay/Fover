import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';


import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';


class CopypartyService {
  static String baseUrl = "";
  static String credentials = "";
  static Box box = Hive.box('settings');
  static final _client = _buildClient();
  static final ValueNotifier<double?> uploadProgress = ValueNotifier(null);
  static final _dio = Dio();
  static CancelToken? _uploadCancelToken;
  static bool _cancelRequested = false;


  static http.Client _buildClient() {
    final ioClient = HttpClient()
      ..badCertificateCallback = (cert, host, port) => true;
    return IOClient(ioClient);
  }

  static void init() {
    baseUrl = box.get('copypartyUrl') ?? '';
    final user = box.get('copypartyUser') ?? '';
    final pass = box.get('copypartyPass') ?? '';
    credentials = base64Encode(utf8.encode('$user:$pass'));
  }

  static String _normalizeUrl(String url) {
    url = url.trim();

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      final isIp = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}').hasMatch(url);
      url = isIp ? 'http://$url' : 'https://$url';
    }

    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static Future<void> connect({required String url, required String username, required String password}) async {
      url = _normalizeUrl(url);
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme || !uri.host.isNotEmpty) {
        throw Exception('Invalid URL');
      }

    final newCredentials = base64Encode(utf8.encode('$username:$password'));

    final response = await _client.get(
      uri.replace(path: '/', queryParameters: {'ls': ''}),
      headers: {'Authorization': 'Basic $newCredentials'},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 401) throw Exception("Invalid credentials");
    if (response.statusCode != 200){ 
      log("Copyparty connection error: ${response.statusCode} ${response.reasonPhrase}");
      throw Exception("Serveur error : ${response.statusCode}:${response.reasonPhrase}\nMake sure you've specified the port correctly?");
    }

    final body = jsonDecode(response.body);
    if (body['acct'] == '*') throw Exception('Invalid credentials');
    if (body['acct'] != username) throw Exception('Invalid credentials');

    await box.put('copypartyUrl', url);
    await box.put("copypartyUser", username);
    await box.put('copypartyPass', password);

    baseUrl = url;
    credentials = newCredentials;
  }

  static Map<String, String> get _headers => {
    'Authorization': 'Basic $credentials',
  };

  static Future<bool> isUp() async {
    if (baseUrl.isEmpty) return false;

    try {
      final response = await _client.get(
        Uri.parse("$baseUrl/photo?ls"),
        headers: _headers,
      );
      print(response.statusCode == 200 ? "Copyparty is up!" : "Copyparty check failed: ${response.statusCode}");
      return response.statusCode == 200;
    } catch(e) {
      log("Connection check failed: $e");
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> listFiles() async {
    final uri = Uri.parse('$baseUrl/photos?ls');
    final response = await _client.get(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('List failed: ${response.statusCode}');
    }

    final json = jsonDecode(response.body);
    final List<dynamic> entries = json['files'] ?? [];

    return entries
        .where((e) {
          final mime = lookupMimeType(e['href'] ?? '') ?? '';
          return mime.startsWith('image/') || mime.startsWith('video/');
        })
        .map<Map<String, dynamic>>((e) {
          final name = e['href'] as String;
          final mime = lookupMimeType(name) ?? 'application/octet-stream';
          return {
            'name': name,
            'path': name,
            'mimetype': mime,
            'size': e['sz'],
            'modification': e['ts'],
          };
        })
        .toList();
  }

  static Future<List<int>> fetchFile(String encodedPath) async {
    final response = await _client.get(Uri.parse('$baseUrl/photos/$encodedPath'), headers: _headers);
    if (response.statusCode != 200) throw Exception('Failed to fetch file');
    return response.bodyBytes;
  }

  static Future<Uint8List?> fetchFileRange(String fileName) async {
    final response = await _client.get(
      Uri.parse("$baseUrl/photos/$fileName"),
      headers: {
        ..._headers,
        'Range': 'bytes=0-65536'
      }
    );
    if (response.statusCode != 200 && response.statusCode != 206) return null;
    return response.bodyBytes;
  } 

  static Future<Uint8List?> getThumbnail(String path, {bool webp = true}) async {
    final uri = Uri.parse('$baseUrl/photos/$path')
        .replace(queryParameters: {'th': webp ? 'w' : 'j'});

    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode != 200) return null;

    if (response.headers['content-type'] == "image/svg+xml") {
      return null;
    }
    return response.bodyBytes;
  }



  static Future<void> deleteFile(String filename) async {
    final uri = Uri.parse('$baseUrl/photos/$filename');
    
    final response = await _client.delete(
      uri,
      headers: _headers,
    );

    log('Delete response: ${response.statusCode} ${response.body}');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete: ${response.statusCode} ${response.body}');
    }
  }

  static Future<Set<String>> listAllFiles({String path = ''}) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/photos?ls'),
      headers: _headers,
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final files = (body['files'] as List<dynamic>?) ?? [];
    return files.map((f) => f['href'] as String).toSet();
  }

  static String _mimetypeFromFilename(String filename) { 
    return lookupMimeType(filename) ?? 'application/octet-stream'; 
  }


  static void cancelUpload() {
    _cancelRequested = true; 
    _uploadCancelToken?.cancel('User cancelled');
  }

  // AI Generated
  static Future<void> uploadLocalFiles({
    required List<File> files,
    List<String>? filenames,
  }) async {
    _uploadCancelToken = CancelToken();
    _cancelRequested = false; 

    final allFilenames = List.generate(
      files.length,
      (i) => filenames?[i] ?? files[i].path.split('/').last,
    );

    final totalBytes = (await Future.wait(
      files.map((f) async => await f.length()),
    )).fold<int>(0, (sum, size) => sum + size);

    int bytesUploadedSoFar = 0;
    bool needsCleanup = false;

    try {
      for (int i = 0; i < files.length; i++) {
        if (_cancelRequested) {
          needsCleanup = true;
          break;
        }

        final filename = allFilenames[i];
        final fileSize = await files[i].length();

        final formData = FormData.fromMap({
          'act': 'bput',
          'f': await MultipartFile.fromFile(
            files[i].path,
            filename: filename,
            contentType: DioMediaType.parse(_mimetypeFromFilename(filename)),
          ),
        });

        await _dio.post(
          '$baseUrl/photos?bup',
          data: formData,
          options: Options(headers: _headers),
          cancelToken: _uploadCancelToken,
          onSendProgress: (sent, total) {
            uploadProgress.value = (bytesUploadedSoFar + sent) / totalBytes;
          },
        );

        if (_cancelRequested) {
          needsCleanup = true;
          break;
        }

        bytesUploadedSoFar += fileSize;
        log('Uploaded $filename');
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        needsCleanup = true;
      }
    } finally {
      if (needsCleanup) {
        log("Cleaning up ${allFilenames.length} files...");
        await Future.wait(
          allFilenames.map((filename) async {
            try {
              await deleteFile(filename);
              log('🗑️ Deleted $filename');
            } catch (_) {
              log('$filename not found — skipping');
            }
          }),
        );
      }

      uploadProgress.value = null;
      _uploadCancelToken = null;
      _cancelRequested = false;
    }
  }

  static Future<String?> uploadBytes({
    required Uint8List bytes,
    required String filename,
    String? folderEncodedPath,
  }) async {
    final mimetype = _mimetypeFromFilename(filename);

    final uri = Uri.parse('$baseUrl/photos?bup');

    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers);
    request.fields['act'] = 'bput';
    request.files.add(http.MultipartFile.fromBytes(
      'f',
      bytes,
      filename: filename,
      contentType: MediaType.parse(mimetype),
    ));

    final streamedResponse = await _client.send(request);
    await streamedResponse.stream.drain();

    if (streamedResponse.statusCode != 200 &&
        streamedResponse.statusCode != 201) {
      throw Exception('Upload failed: ${streamedResponse.statusCode}');
    }

    log('✅ Uploaded $filename');
    return filename;
  }
  //

  static Future<Map<String, dynamic>?> getDiskUsage() async {
      final response = await _client.get(
        Uri.parse("$baseUrl/photos?ls"),
        headers: _headers
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final srvinf = data['srvinf'];

        // AI Notice : Thank you Claude for the regex
        final match = RegExp(r'([\d.]+)\s*(\w+)\s*free of\s*([\d.]+)\s*(\w+)').firstMatch(srvinf);
        if (match != null ) {
          final freeVal = double.parse(match.group(1) ?? "");
          final freeUnit = match.group(2) ?? "";
          final totalVal = double.parse(match.group(3) ?? "");
          final totalUnit = match.group(4) ?? "";

          return {
            "free" : _toBytes(freeVal, freeUnit),
            "total": _toBytes(totalVal, totalUnit)
          };
        }
        return data;
      } else {
        log("Failed to get disk usage: ${response.statusCode} ${response.body}");
        return null;
      }
  }

    static int _toBytes(double value, String unit) {
      const units = {'KiB': 1024, 'MiB': 1048576, 'GiB': 1073741824, 'TiB': 1099511627776};
      return (value * (units[unit] ?? 1)).round();
    }


  bool get isConnected => baseUrl.isNotEmpty;

  static void disconnect() {
    box.delete('copypartyUrl');
    box.delete('copypartyUser');
    box.delete('copypartyPass');
    baseUrl = "";
    credentials = "";
  }
}