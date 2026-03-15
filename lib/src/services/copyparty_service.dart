import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';


class CopypartyService {
  static String baseUrl = "";
  static String credentials = "";
  static Box box = Hive.box('settings');
  static final _client = _buildClient();

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
      print(isIp);
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
    final response = await _client.get(Uri.parse('$baseUrl/$encodedPath'), headers: _headers);
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

//   static Future<void> deleteFile(String encodedPath) async {
//   final response = await _client.post(
//     Uri.parse('$baseUrl/?delete'),
//     headers: _headers,
//     body: jsonEncode({'paths': [encodedPath]}),
//   );

//   final body = jsonDecode(response.body);
//   if (body['ok'] != true) throw Exception('Failed to delete: ${body['msg']}');
// }
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


  // AI Generated
  static Future<void> upload({
    List<File>? files,
    List<XFile>? xfiles,
    void Function(int uploaded, int total)? onProgress,
  }) async {
    final List<File> toUpload = files ?? xfiles?.map((x) => File(x.path)).toList() ?? [];

    for (int i = 0; i < toUpload.length; i++) {
      final file = toUpload[i];
      final filename = files != null ? file.path.split('/').last : xfiles![i].name;

      final totalBytes = await file.length();

      final mimetype = (xfiles != null && xfiles[i].mimeType != null && xfiles[i].mimeType!.isNotEmpty)
          ? xfiles[i].mimeType!
          : _mimetypeFromFilename(filename);

      final uri = Uri.parse('$baseUrl/photos?bup');

      // On crée un stream qui permet de suivre la lecture
      final stream = file.openRead();

      int sentBytes = 0;
      final monitoredStream = stream.transform<List<int>>(
        StreamTransformer.fromHandlers(
          handleData: (chunk, sink) {
            sentBytes += chunk.length;
            final progress = (sentBytes / totalBytes * 100).toStringAsFixed(1);
            // Log console pour ce fichier
            log('Uploading $filename: $progress% ($sentBytes / $totalBytes bytes)');
            // Callback externe si besoin
            onProgress?.call(sentBytes, totalBytes);
            sink.add(chunk);
          },
        ),
      );

      final multipartFile = http.MultipartFile(
        'f',
        monitoredStream,
        totalBytes,
        filename: filename,
        contentType: MediaType.parse(mimetype),
      );

      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_headers);
      request.fields['act'] = 'bput';
      request.files.add(multipartFile);

      final streamedResponse = await _client.send(request);
      await streamedResponse.stream.drain();

      if (streamedResponse.statusCode != 200 && streamedResponse.statusCode != 201) {
        throw Exception('Upload failed: ${streamedResponse.statusCode}');
      }

      log('✅ Uploaded $filename');
    }
  }


  //



  bool get isConnected => baseUrl.isNotEmpty;

  static void disconnect() {
    box.delete('copypartyUrl');
    box.delete('copypartyUser');
    box.delete('copypartyPass');
    baseUrl = "";
    credentials = "";
  }
}