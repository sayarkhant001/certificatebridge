import 'dart:async';
import 'dart:io';

class LoopbackAuthServer {
  final int port;
  HttpServer? _server;

  LoopbackAuthServer({this.port = 54321});

  /// Starts the loopback HTTP server and waits for the OAuth callback
  Future<Map<String, String>> waitForCallback({
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final completer = Completer<Map<String, String>>();

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    } catch (e) {
      throw Exception('Failed to bind to loopback port $port: $e');
    }

    Timer? timeoutTimer;
    timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        stop();
        completer.completeError(
          TimeoutException('OAuth callback timed out after ${timeout.inMinutes} minutes.'),
        );
      }
    });

    _server!.listen((HttpRequest request) async {
      final uri = request.uri;

      if (uri.path == '/callback' || uri.path == '/oauth/callback') {
        final queryParams = uri.queryParameters;

        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.html;
        request.response.write('''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>CertiBridge - Authentication Complete</title>
  <style>
    body {
      background: #0f172a;
      color: #f8fafc;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      display: flex;
      align-items: center;
      justify-content: center;
      height: 100vh;
      margin: 0;
    }
    .card {
      background: #1e293b;
      padding: 40px;
      border-radius: 16px;
      box-shadow: 0 10px 25px -5px rgba(0,0,0,0.5);
      text-align: center;
      max-width: 440px;
      border: 1px solid #334155;
    }
    .icon {
      font-size: 54px;
      color: #10b981;
      margin-bottom: 16px;
    }
    h1 { margin: 0 0 12px; font-size: 22px; color: #f1f5f9; }
    p { margin: 0; color: #94a3b8; font-size: 15px; line-height: 1.5; }
    .badge {
      display: inline-block;
      margin-top: 20px;
      background: #0369a1;
      color: #fff;
      padding: 6px 16px;
      border-radius: 20px;
      font-size: 13px;
      font-weight: 500;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">✓</div>
    <h1>Authentication Successful!</h1>
    <p>Your account has been connected to CertiBridge.<br>You may safely close this browser tab and return to the application.</p>
    <div class="badge">CertiBridge BYOA Secure Loopback</div>
  </div>
</body>
</html>
''');
        await request.response.close();

        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(queryParams);
        }

        // Close server immediately after receiving token payload
        await stop();
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Not Found');
        await request.response.close();
      }
    });

    return completer.future;
  }

  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
  }
}
