import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:io';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey webViewKey = GlobalKey();
  InAppWebViewController? webViewController;

  // Setting WebView
  InAppWebViewSettings settings = InAppWebViewSettings(
    isInspectable: true,
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
  );

  PullToRefreshController? pullToRefreshController;

  String url = "";
  double progress = 0;
  final urlController = TextEditingController();

  // Logic Loading
  bool isInitialLoading = true;
  URLRequest? initialRequest;

  // URL Target Utama
  final String liveUrl = "https://inappwebview.dev/";

  @override
  void initState() {
    super.initState();

    // Setup Pull to Refresh (Tarik layar)
    pullToRefreshController = PullToRefreshController(
      onRefresh: () async {
        await checkAndLoadContent();
        pullToRefreshController?.endRefreshing();
      },
    );

    // Cek Koneksi Awal
    initFirstLoad();
  }

  Future<void> initFirstLoad() async {
    bool isConnected = await _checkInternetConnection();

    setState(() {
      if (isConnected) {
        initialRequest = URLRequest(url: WebUri(liveUrl));
      } else {
        initialRequest = URLRequest(
          url: WebUri.uri(Uri.dataFromString(
            getDummyNewsHtml(),
            mimeType: 'text/html',
            encoding: Encoding.getByName('utf-8'),
          )),
        );
      }
      isInitialLoading = false;
    });
  }

  // LOGIKA UTAMA: Switch antara Online vs Offline
  Future<void> checkAndLoadContent() async {
    bool isConnected = await _checkInternetConnection();

    if (isConnected) {
      // Jika Online: Load URL Website
      webViewController?.loadUrl(
          urlRequest: URLRequest(url: WebUri(liveUrl))
      );
    } else {
      // Jika Offline: Load Dummy HTML
      webViewController?.loadUrl(
          urlRequest: URLRequest(
            url: WebUri.uri(Uri.dataFromString(
              getDummyNewsHtml(),
              mimeType: 'text/html',
              encoding: Encoding.getByName('utf-8'),
            )),
          )
      );
    }
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  String getDummyNewsHtml() {
    return """
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body { font-family: sans-serif; padding: 20px; text-align: center; background-color: #fff3e0; }
          .box { border: 1px solid #ffcc80; padding: 20px; background: white; border-radius: 8px; }
          h1 { color: #e65100; }
        </style>
      </head>
      <body>
        <div class="box">
          <h1>Mode Offline</h1>
          <p>Anda sedang tidak terhubung ke internet.</p>
          <p>Konten ini dimuat dari <strong>Lokal</strong>.</p>
          <hr>
          <p>Silakan aktifkan internet dan tekan tombol <strong>Refresh</strong> di bawah.</p>
        </div>
      </body>
      </html>
    """;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Smart WebView")),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Kolom Pencarian URL (Opsional, saya biarkan sesuai kode asli)
            TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search)),
              controller: urlController,
              keyboardType: TextInputType.url,
              onSubmitted: (value) {
                var webUri = WebUri(value);
                if (webUri.scheme.isEmpty) {
                  webUri = WebUri("https://www.google.com/search?q=$value");
                }
                webViewController?.loadUrl(urlRequest: URLRequest(url: webUri));
              },
            ),

            // Area WebView
            Expanded(
              child: Stack(
                children: [
                  if (isInitialLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    InAppWebView(
                      key: webViewKey,
                      initialUrlRequest: initialRequest,
                      initialSettings: settings,
                      pullToRefreshController: pullToRefreshController,
                      onWebViewCreated: (controller) {
                        webViewController = controller;
                      },
                      onLoadStart: (controller, url) {
                        setState(() {
                          this.url = url.toString();
                          urlController.text = this.url;
                        });
                      },
                      onLoadStop: (controller, url) {
                        pullToRefreshController?.endRefreshing();
                        setState(() {
                          this.url = url.toString();
                          urlController.text = this.url;
                        });
                      },
                      onProgressChanged: (controller, progress) {
                        if (progress == 100) {
                          pullToRefreshController?.endRefreshing();
                        }
                        setState(() {
                          this.progress = progress / 100;
                        });
                      },
                    ),

                  if (progress < 1.0)
                    LinearProgressIndicator(value: progress),
                ],
              ),
            ),

            // --- TOMBOL NAVIGASI DI SINI (SESUAI REQUEST) ---
            OverflowBar(
              alignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                  child: const Icon(Icons.arrow_back),
                  onPressed: () {
                    webViewController?.goBack();
                  },
                ),
                ElevatedButton(
                  child: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    webViewController?.goForward();
                  },
                ),
                ElevatedButton(
                  child: const Icon(Icons.refresh),
                  onPressed: () {
                    // Di sini saya ubah sedikit:
                    // Alih-alih cuma reload(), kita panggil fungsi pintar kita.
                    // Supaya kalau user nyalakan internet lalu klik refresh, dia pindah ke URL Live.
                    checkAndLoadContent();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}