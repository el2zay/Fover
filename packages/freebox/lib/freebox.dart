// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:web_socket_channel/io.dart';

// Créez une instance de HttpClient qui ignore les erreurs de certificat
HttpClient createHttpClient() {
  var client = HttpClient();
  client.badCertificateCallback =
      (X509Certificate cert, String host, int port) => true;
  return client;
}


// Utilisez cette instance pour créer un IOClient personnalisé
final ioClient = IOClient(createHttpClient());

class FreeboxResponse {
  final int statusCode;
  final dynamic _data;

  const FreeboxResponse({required this.statusCode, required dynamic data}) : _data = data; 
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  dynamic operator [](String key) => _data is Map ? _data[key] : null;

  dynamic get data => _data;

}

class FreeboxClient {
  bool verbose;
  String apiDomain;
  int? httpsPort;
  String appId;
  String appToken;
  String apiBaseUrl;
  HttpClient httpClient;
  String? sessionToken;

  FreeboxClient({
    this.verbose = false,
    this.apiDomain = 'mafreebox.freebox.fr',
    this.httpsPort,
    required this.appId,
    required this.appToken,
    this.apiBaseUrl = '/api/',
  }) : httpClient = HttpClient() {
    // Désactiver la vérification des certificats
    httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    if (verbose) print('Freebox client initialized!');
  }

  static Future<dynamic> registerFreebox({
    bool verbose = true,
    String appId = 'fbx.example',
    String appName = 'Exemple',
    String appVersion = '1.0.0',
    String deviceName = 'DartClient',
  }) async {
    var client = HttpClient();

    // Désactiver la vérification des certificats
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;

    // Vérifier la connexion au serveur
    var request = await client
        .getUrl(Uri.parse('https://mafreebox.freebox.fr/api/v8/api_version'));
    var response = await request.close();

    if (response.statusCode != 200) {
      if (verbose) {
        print(
            'Impossible de joindre le serveur de votre Freebox (mafreebox.freebox.fr). Êtes-vous bien connecté au même réseau que votre Freebox ?');
      }
      return 'UNREACHABLE';
    }

    var responseBody = await response.transform(utf8.decoder).join();
    var freebox = jsonDecode(responseBody);

    if (freebox['api_base_url'] == null || freebox['box_model'] == null) {
      if (verbose) {
        print(
            'Impossible de récupérer les informations de votre Freebox. ${freebox['msg'] ?? freebox}');
      }
      return 'CANNOT_GET_INFOS';
    }
    if (verbose) {
      print(
          "Un message s'affichera dans quelques instants sur l'écran de votre Freebox Server pour permettre l'autorisation.");
    }
    var authorizeRequest = await ioClient.post(
      Uri.parse('https://mafreebox.freebox.fr/api/v8/login/authorize'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'app_id': appId,
        'app_name': appName,
        'app_version': appVersion,
        'device_name': deviceName
      }),
    );
    if (authorizeRequest.statusCode != 200) {
      if (verbose) {
        print('Impossible de demander l\'autorisation à votre Freebox.');
      }
      return 'CANNOT_ASK_AUTHORIZATION';
    }

    var register = jsonDecode(authorizeRequest.body);

    if (register?['success'] != true) {
      if (verbose) {
        print(
            'Impossible de demander l\'autorisation à votre Freebox. ${register['msg']}');
      }
      return 'CANNOT_ASK_AUTHORIZATION';
    }

    // Obtenir le token
    var appToken = register['result']?['app_token'];
    if (appToken == null) {
      if (verbose) {
        print('Impossible de récupérer le token de votre Freebox.');
      }
      return 'CANNOT_GET_TOKEN';
    }
    var status = 'pending';
    while (status == 'pending') {
      await Future.delayed(const Duration(seconds: 2));
      var statusRequest = await ioClient.get(
        Uri.parse(
            'https://mafreebox.freebox.fr/api/v8/login/authorize/${register['result']?['track_id']}'),
      );

      if (statusRequest.statusCode != 200) {
        if (verbose) {
          print('Impossible de récupérer le statut de l\'autorisation.');
        }
        return 'CANNOT_GET_AUTHORIZATION_STATUS';
      }
      var statusResponse = jsonDecode(statusRequest.body);
      status = statusResponse['result']?['status'];
    }

    if (status != 'granted') {
      if (verbose) {
        print(
            "Impossible de se connecter à votre Freebox. L'accès ${status == 'timeout' ? 'a expiré' : status == 'denied' ? "a été refusé par l'utilisateur" : ''}.");
      }
      return "ACCESS_NOT_GRANTED_BY_USER";
    }

    var values = {
      'appToken': appToken,
      'appId': appId,
      'apiDomain': freebox['api_domain'],
      'httpsPort': freebox['https_port'],
    };

    if (verbose) {
      print('Vous êtes maintenant connecté à votre Freebox !');

      print(values);
    }
    return values;
  }

  Future<FreeboxResponse> fetch({
    required String url,
    String method = 'GET',
    Map<String, String>? headers,
    dynamic body,
    bool parseJson = true,
  }) async {
    if (!url.startsWith('http')) {
      if (url.startsWith("/")) url = url.substring(1);
      url =
          'https://$apiDomain${httpsPort != null ? ':$httpsPort' : ''}$apiBaseUrl$url';
    }
    if (verbose) print('Request URL: $url');

    var uri = Uri.parse(url);
    var requestHeaders = {
      'Content-Type': 'application/json',
      if (sessionToken != null) 'X-Fbx-App-Auth': sessionToken!,
      ...?headers
    };

    // Création d'un client HTTP qui ignore la vérification des certificats
    HttpClient httpClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    IOClient ioClient = IOClient(httpClient);

    // Timeout de 7 secondes
    try {
      http.BaseRequest request;
      if (method == 'GET') {
        request = http.Request(method, uri);
      } else {
        request = http.Request(method, uri)..body = jsonEncode(body);
      }
      request.headers.addAll(requestHeaders);

      var streamedResponse = await ioClient.send(request).timeout(
        const Duration(seconds: 7),
        onTimeout: () {
          if (verbose) print('Request timed out');
          throw TimeoutException('Error: Timeout');
        },
      );

      if (streamedResponse.statusCode != 200 && streamedResponse.statusCode != 206) {
        String responseBody = await streamedResponse.stream.bytesToString();
        dynamic json;
        try {
          json = jsonDecode(responseBody);
        } catch (err) {
          json = {};
        }

        // Si on essayait de s'authentifier
        if (verbose) print("Fetch error: ${json['error']}");
        if (url.endsWith("login/session")) {
         return FreeboxResponse(statusCode: streamedResponse.statusCode, data: {"success": false, "msg": json['error'] ?? streamedResponse.reasonPhrase});
        }

        // Si l'erreur n'est pas liée à l'authentification
        if (json['error_code'] == 'auth_required') {
          return const FreeboxResponse(statusCode: 401, data: {"success": false, "msg": "Authentification requise"});
        }

        // On s'authentifie
        if (verbose) print("Réhautentification...");
        var auth = await authentificate();
        if (auth.data?['success'] != true) return auth;

        // On refait la requête
        if (verbose) print("Nouvelle requête...");
        return fetch(url: url, method: method, headers: headers, body: body);
      } else {
        if (!parseJson) {
          return FreeboxResponse(statusCode: streamedResponse.statusCode, data: await streamedResponse.stream.toBytes());
        } else {
          String responseBody = await streamedResponse.stream.bytesToString();
          try {
            return FreeboxResponse(statusCode: streamedResponse.statusCode, data: jsonDecode(responseBody));
          } catch (e) {
            if (verbose) print('Error decoding JSON: $e');
            return FreeboxResponse(statusCode: streamedResponse.statusCode, data: responseBody);
          }
        }
      }
    } catch (e) {
      if (verbose) print('Error during fetch: $e');
      return FreeboxResponse(statusCode: 0, data: {"success": false, "msg": e.toString()});
    } finally {
      ioClient.close();
      httpClient.close();
    }
  }

  Future<FreeboxResponse> authentificate() async {
    dynamic freebox;
    // Obtenir le challenge
    var challenge = await fetch(url: 'v8/login/', method: 'GET');

    if (verbose) {
      print(
          "Challenge: ${challenge.data?['success']?['challenge'] ?? challenge.data?['msg'] ?? challenge}");
    }
    if (challenge.data?['success'] != true) return challenge;

    // Si on a pas de challenge
    if (challenge.data?['result']?['challenge'] == null) {
      // Si on est déjà connecté
      if (challenge.data?['result']?['logged_in'] == true) {
        // On fait une requête qui nécessite d'être connecté
        if (verbose) {
          print("Vous avez l'air d'être déjà connecté, 2e vérification...");
        }

        var freeboxSystem = await fetch(url: 'v8/system');
        if (verbose) print("Freebox system: $freeboxSystem");

        // Si ça a fonctonné, on est connecté
        if (freeboxSystem.data?['success'] == true) {
          return FreeboxResponse(statusCode: 200, data: {"success": true, "freebox": freebox});
        }

        // Sinon on dit que le challenge n'a pas fonctionné
        return FreeboxResponse(statusCode: 0, data: {"success": false,
          "msg":
            "Impossible de récupérer le challenge pour une raison inconnue ${challenge.data['msg'] ?? challenge.data['message'] ?? challenge.data?['result']?['msg'] ?? challenge.data?['result']?['message'] ?? challenge.data?['status_code']}"
        });
      }
    }

    var passwordHash = Hmac(sha1, utf8.encode(appToken))
        .convert(utf8.encode(challenge.data?['result']?['challenge']))
        .toString();

    if (verbose) print("Password hash: $passwordHash");

    // S'authentifier
    var auth = await fetch(
      url: 'v8/login/session',
      method: 'POST',
      body: {'app_id': appId, 'password': passwordHash},
    );

    if (verbose) {
      print(
          "Auth: ${auth.data?['success']} ${auth.data?['result']?['session_token'] ?? auth.data?['msg'] ?? auth}");
    }
    if (auth.data?['success'] != true) return auth;

    // On définit le token de session
    if (verbose) print("Authentification réussie !");
    sessionToken = auth.data['result']?['session_token'];

    // On récupère les infos de la Freebox
    freebox = await fetch(url: 'v8/api_version');

    if (verbose) print("Infos de la freebox obtenus: $freebox");
    return FreeboxResponse(statusCode: 200, data: {"success": true, "freebox": freebox});
  }
}

class FreeboxUploader {
  final String apiDomain;
  final int? httpsPort;
  final String sessionToken;

  static const int chunkSize = 512 * 1024;

  FreeboxUploader({
    required this.apiDomain,
    required this.sessionToken,
    this.httpsPort,
  });

  Future<bool> uploadFile({
    required Uint8List fileBytes,
    required String filename,
    required String dirname,
    required void Function(int uploaded, int total) onProgress,
    String force = 'overwrite',
    int requestId = 1,
  }) async {
    final port = httpsPort != null ? ':$httpsPort' : '';
    final wsUrl = 'wss://$apiDomain$port/api/v8/ws/upload';

    final channel = IOWebSocketChannel.connect(
      Uri.parse(wsUrl),
      headers: {'X-Fbx-App-Auth': sessionToken},
      customClient: HttpClient()
        ..badCertificateCallback = (cert, host, port) => true,
    );

    final completer = Completer<bool>();

    channel.stream.listen(
      (message) {
        print('[WS RECEIVED] $message');
        final json = jsonDecode(message as String);
        final action = json['action'];

        if (action == 'upload_start') {
          if (json['success'] == true) {
            print('[WS] Upload start OK, envoi des chunks...');
            _sendChunks(channel, fileBytes, onProgress);
            channel.sink.add(jsonEncode({
              'action': 'upload_finalize',
              'request_id': requestId,
            }));
          } else {
            print('[WS] Upload start FAILED: ${json['msg']} (${json['error_code']})');
            completer.complete(false);
            channel.sink.close();
          }
        } else if (action == 'upload_data') {
          final totalLen = json['result']?['total_len'] ?? 0;
          onProgress(totalLen, fileBytes.lengthInBytes);
        } else if (action == 'upload_finalize') {
          print('[WS] Finalize: $json');
          completer.complete(json['success'] == true);
          channel.sink.close();
        }
      },
      onError: (e) {
        print('[WS ERROR] $e');
        completer.completeError(e);
      },
      onDone: () {
        print('[WS] Connexion fermée');
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    print('[WS] Envoi upload_start pour $filename (${fileBytes.lengthInBytes} bytes)');
    channel.sink.add(jsonEncode({
      'action': 'upload_start',
      'request_id': requestId,
      'size': fileBytes.lengthInBytes,
      'dirname': dirname,
      'filename': filename,
      'force': force,
    }));

    return completer.future;
  }

  void _sendChunks(
    IOWebSocketChannel channel,
    Uint8List bytes,
    void Function(int, int) onProgress,
  ) {
    int offset = 0;
    while (offset < bytes.lengthInBytes) {
      final end = (offset + chunkSize).clamp(0, bytes.lengthInBytes);
      channel.sink.add(bytes.sublist(offset, end));
      offset = end;
    }
    print('[WS] Tous les chunks envoyés (${bytes.lengthInBytes} bytes)');
  }

}
