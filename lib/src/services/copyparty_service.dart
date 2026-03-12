import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';


class CopypartyService {
  static late String _baseUrl;
  static late String _credentials;
  static Box box = Hive.box('settings');
  static final _client = _buildClient();

  static http.Client _buildClient() {
    final ioClient = HttpClient()
      ..badCertificateCallback = (cert, host, port) => true;
    return IOClient(ioClient);
  }

  static void init() {
    _baseUrl = box.get('copypartyUrl') ?? '';
    final user = box.get('copypartyUser') ?? '';
    final pass = box.get('copypartyPass') ?? '';
    _credentials = base64Encode(utf8.encode('$user:$pass'));
  }

  static String _normalizeUrl(String url) {
    if (!url.startsWith('http://') || !url.startsWith('https://')) {
      url = 'https://$url';
    }
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static Future<void> connect({required String url, required String username, required String password}) async {
      url = _normalizeUrl(url);
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme || !uri.host.isNotEmpty) {
        throw Exception('Invalid URL');
      }

    final credentials = base64Encode(utf8.encode('$username:$password'));

    final response = await _client.get(
      uri.replace(path: '/', queryParameters: {'ls': ''}),
      headers: {'Authorization': 'Basic $credentials'},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 401) throw Exception("Invalid credentials");
    if (response.statusCode != 200){ 
      log("Copyparty connection error: ${response.statusCode} ${response.reasonPhrase}");
      throw Exception("Serveur error : ${response.statusCode}:${response.reasonPhrase}");
    }

    final body = jsonDecode(response.body);
    if (body['acct'] == '*') throw Exception('Invalid credentials');
    if (body['acct'] != username) throw Exception('Invalid credentials');

    await box.put('copypartyUrl', url);
    await box.put("copypartyUser", username);
    await box.put('copypartyPass', password);

    _baseUrl = url;
    _credentials = credentials;
  }

  static final Map<String, String> _headers = {
    'Authorization': 'Basic $_credentials'
  };

  static Future<dynamic> listFiles(String path) async {
    final response = await _client.get(Uri.parse('$_baseUrl/?ls&vpath=$path&format=json'), headers: _headers);
    if (response.statusCode != 200) throw Exception("Failed to list files");
    return jsonDecode(response.body);
  }

  static Future<List<int>> fetchFile(String encodedPath) async {
    final response = await _client.get(Uri.parse('$_baseUrl/$encodedPath'), headers: _headers);
    if (response.statusCode != 200) throw Exception('Failed to fetch file');
    return response.bodyBytes;
  }

  bool get isConnected => _baseUrl.isNotEmpty;

  static void disconnect() {
    box.delete('copypartyUrl');
    box.delete('copypartyUser');
    box.delete('copypartyPass');
    _baseUrl = "";
    _credentials = "";
  }
}