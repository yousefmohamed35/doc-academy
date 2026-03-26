import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:emulator_checker/emulator_checker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isPhysical = await _isPhysicalDevice();

  if (!isPhysical) {
    runApp(const MaterialApp(home: EmulatorBlockedScreen()));
    return;
  }

  runApp(const MyApp());
}

Future<bool> _isPhysicalDevice() async {
  bool isEmulatorFlag = false;
  bool isNotPhysicalFromDeviceInfo = false;

  try {
    isEmulatorFlag = await EmulatorChecker.isEmulator();
  } catch (e) {
    debugPrint('EmulatorChecker error: $e');
  }

  try {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await deviceInfo.androidInfo;
      final model = android.model.toLowerCase();
      final product = android.product.toLowerCase();
      final brand = android.brand.toLowerCase();
      final hardware = android.hardware.toLowerCase();
      final fingerprint = android.fingerprint.toLowerCase();
      final manufacturer = android.manufacturer.toLowerCase();

      final List<bool> emulatorIndicators = [
        !android.isPhysicalDevice,
        model.contains('sdk'),
        model.contains('emulator'),
        product.contains('sdk'),
        product.contains('vbox'),
        brand.contains('generic'),
        hardware.contains('goldfish'),
        hardware.contains('ranchu'),
        fingerprint.contains('generic'),
        manufacturer.contains('genymotion'),
      ];

      isNotPhysicalFromDeviceInfo = emulatorIndicators.any((flag) => flag);
    } else if (Platform.isIOS) {
      final ios = await deviceInfo.iosInfo;
      isNotPhysicalFromDeviceInfo = !ios.isPhysicalDevice;
    }
  } catch (e) {
    debugPrint('Device info emulator detection error: $e');
  }

  return !(isEmulatorFlag || isNotPhysicalFromDeviceInfo);
}

/// Converts WhatsApp web URLs (wa.me, api.whatsapp.com, web.whatsapp.com)
/// to whatsapp:// so the native app opens on phone.
String? _tryConvertWhatsAppWebUrlToAppUrl(String url) {
  if (url.startsWith('whatsapp://')) return url;

  // https://wa.me/1234567890 or https://wa.me/1234567890?text=hello
  if (url.contains('wa.me/')) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final segments = path.split('/');
      final number = segments.isNotEmpty && segments.last.isNotEmpty
          ? segments.last
          : null;
      if (number != null && number != 'send') {
        final query = uri.query.isEmpty ? '' : '&${uri.query}';
        return 'whatsapp://send?phone=$number$query';
      }
    } catch (_) {}
    return null;
  }

  // https://api.whatsapp.com/send?phone=123&text=hello
  if (url.contains('api.whatsapp.com/send')) {
    try {
      final uri = Uri.parse(url);
      final phone = uri.queryParameters['phone'];
      if (phone != null && phone.isNotEmpty) {
        final buffer = StringBuffer('whatsapp://send?phone=$phone');
        final text = uri.queryParameters['text'];
        if (text != null && text.isNotEmpty) {
          buffer.write('&text=${Uri.encodeComponent(text)}');
        }
        return buffer.toString();
      }
    } catch (_) {}
    return null;
  }

  // https://web.whatsapp.com/send?phone=... or web.whatsapp.com/...
  if (url.contains('web.whatsapp.com')) {
    try {
      final uri = Uri.parse(url);
      final phone = uri.queryParameters['phone'];
      if (phone != null && phone.isNotEmpty) {
        final buffer = StringBuffer('whatsapp://send?phone=$phone');
        final text = uri.queryParameters['text'];
        if (text != null && text.isNotEmpty) {
          buffer.write('&text=${Uri.encodeComponent(text)}');
        }
        return buffer.toString();
      }
      // web.whatsapp.com/send/1234567890
      final path = uri.path;
      final match = RegExp(r'/send/(\d+)').firstMatch(path);
      if (match != null) {
        return 'whatsapp://send?phone=${match.group(1)}';
      }
    } catch (_) {}
    return null;
  }

  return null;
}

/// Converts YouTube web URLs to app scheme so the native app opens on phone.
String? _tryConvertYouTubeWebUrlToAppUrl(String url) {
  if (!url.contains('youtube.com') && !url.contains('youtu.be')) return null;
  try {
    final uri = Uri.parse(url);
    String? videoId;
    if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
      videoId = uri.pathSegments.first;
    } else {
      videoId = uri.queryParameters['v'];
    }
    if (videoId != null && videoId.isNotEmpty) {
      // vnd.youtube:// works on Android; use youtube:// on iOS
      if (Platform.isIOS) {
        return 'youtube://watch?v=$videoId';
      }
      return 'vnd.youtube://watch?v=$videoId';
    }
  } catch (_) {}
  return null;
}

/// Returns true if URL is a Facebook/Meta web link (to open in app).
bool _isFacebookWebUrl(String url) {
  final lower = url.toLowerCase();
  return lower.contains('facebook.com') ||
      lower.contains('fb.com') ||
      lower.contains('fb.me') ||
      lower.contains('m.facebook.com') ||
      lower.contains('www.facebook.com') ||
      lower.contains('fb.watch') ||
      lower.contains('fb.com/watch');
}

class EmulatorBlockedScreen extends StatelessWidget {
  const EmulatorBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'التطبيق متاح فقط على جهاز حقيقي.\nيُرجى تشغيله على هاتف أو جهاز لوحي فعلي.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, height: 1.4),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Doc Academy',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _webViewController;
  double _loadingProgress = 0.0;
  bool _isLoading = true;
  bool _hasLoadedSuccessfully = false;
  final String _initialUrl = 'https://docacademy.anmka.com/';

  @override
  void initState() {
    super.initState();
    _initializeWebViewController();
    _initializeScreenProtector();
  }

  void _initializeWebViewController() {
    late final PlatformWebViewControllerCreationParams params;
    if (defaultTargetPlatform == TargetPlatform.android) {
      params = AndroidWebViewControllerCreationParams();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _webViewController = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(true);

    // Platform-specific settings
    if (_webViewController.platform is AndroidWebViewController) {
      (_webViewController.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _webViewController.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) {
          debugPrint('🚀 Page started loading: $url');
          debugPrint('📋 Request headers: X-App-Source: anmka');
          if (mounted) {
            setState(() {
              _loadingProgress = 0.0;
              _isLoading = true;
            });
          }
        },
        onPageFinished: (url) {
          debugPrint('✅ Page finished loading: $url');
          // Enable media autoplay for all videos and iframes
          _webViewController.runJavaScript('''
              (function() {
                try {
                  // Enable autoplay for all video elements
                  var videos = document.querySelectorAll('video');
                  videos.forEach(function(video) {
                    video.setAttribute('playsinline', '');
                    video.setAttribute('webkit-playsinline', '');
                    video.setAttribute('x5-playsinline', '');
                    video.setAttribute('x5-video-player-type', 'h5');
                    video.setAttribute('x5-video-player-fullscreen', 'true');
                    video.setAttribute('x5-video-orientation', 'portraint');
                    video.muted = false;
                    video.controls = true;
                    // Try to play the video
                    video.play().catch(function(e) {
                      console.log('Video autoplay prevented:', e);
                    });
                  });
                  
                  // Enable autoplay for all iframes (YouTube, Vimeo, etc.)
                  var iframes = document.querySelectorAll('iframe');
                  iframes.forEach(function(iframe) {
                    var currentAllow = iframe.getAttribute('allow') || '';
                    var newAllow = 'autoplay; encrypted-media; picture-in-picture; fullscreen; accelerometer; gyroscope';
                    if (!currentAllow.includes('autoplay')) {
                      iframe.setAttribute('allow', newAllow);
                    }
                    // For YouTube iframes, ensure proper attributes
                    if (iframe.src && (iframe.src.includes('youtube.com') || iframe.src.includes('youtu.be'))) {
                      iframe.setAttribute('allowfullscreen', '');
                      iframe.setAttribute('frameborder', '0');
                    }
                  });
                  
                  // Enable autoplay for dynamically added videos
                  var observer = new MutationObserver(function(mutations) {
                    mutations.forEach(function(mutation) {
                      mutation.addedNodes.forEach(function(node) {
                        if (node.nodeType === 1) {
                          if (node.tagName === 'VIDEO') {
                            node.setAttribute('playsinline', '');
                            node.setAttribute('webkit-playsinline', '');
                            node.muted = false;
                            node.play().catch(function(e) {
                              console.log('Dynamic video autoplay prevented:', e);
                            });
                          } else if (node.tagName === 'IFRAME') {
                            var currentAllow = node.getAttribute('allow') || '';
                            if (!currentAllow.includes('autoplay')) {
                              node.setAttribute('allow', 'autoplay; encrypted-media; picture-in-picture; fullscreen');
                            }
                          }
                          // Check for videos/iframes inside added nodes
                          var videos = node.querySelectorAll && node.querySelectorAll('video');
                          if (videos) {
                            videos.forEach(function(video) {
                              video.setAttribute('playsinline', '');
                              video.setAttribute('webkit-playsinline', '');
                              video.muted = false;
                            });
                          }
                          var iframes = node.querySelectorAll && node.querySelectorAll('iframe');
                          if (iframes) {
                            iframes.forEach(function(iframe) {
                              var currentAllow = iframe.getAttribute('allow') || '';
                              if (!currentAllow.includes('autoplay')) {
                                iframe.setAttribute('allow', 'autoplay; encrypted-media; picture-in-picture; fullscreen');
                              }
                            });
                          }
                        }
                      });
                    });
                  });
                  
                  observer.observe(document.body, {
                    childList: true,
                    subtree: true
                  });
                  
                  console.log('Media autoplay enabled for', videos.length, 'videos and', iframes.length, 'iframes');
                } catch (e) {
                  console.error('Error enabling media autoplay:', e);
                }
              })();
            ''');
          if (mounted) {
            setState(() {
              _loadingProgress = 1.0;
              _isLoading = false;
              _hasLoadedSuccessfully = true;
            });
          }
        },
        onWebResourceError: (error) {
          debugPrint('❌ WebView Error: ${error.description}');
          if (!_hasLoadedSuccessfully) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          }
        },
        onNavigationRequest: (request) async {
          final url = request.url;
          debugPrint('🧭 Navigation request: $url');

          // Handle Android Intent URLs specially
          if (url.startsWith('intent://')) {
            try {
              // Parse the intent URL to extract the actual scheme and package
              // Format: intent://...#Intent;scheme=SCHEME;package=PACKAGE;end
              final intentMatch = RegExp(
                r'intent://(.+)#Intent;scheme=([^;]+);package=([^;]+);end',
              ).firstMatch(url);

              if (intentMatch != null) {
                final scheme = intentMatch.group(2);
                final packageName = intentMatch.group(3);
                final path = intentMatch.group(1);

                // Try the app-specific scheme first (e.g., fb-messenger://)
                final appUrl = '$scheme://$path';
                debugPrint('🔄 Trying app URL: $appUrl');

                try {
                  final uri = Uri.parse(appUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                    debugPrint('✅ Opened with app scheme: $appUrl');
                    return NavigationDecision.prevent;
                  }
                } catch (e) {
                  debugPrint('⚠️ App scheme failed, trying package: $e');
                }

                // If app scheme fails, try opening the package directly
                final marketUrl = 'market://details?id=$packageName';
                try {
                  final uri = Uri.parse(marketUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                    debugPrint('✅ Opened Play Store for: $packageName');
                  }
                } catch (e) {
                  debugPrint('❌ Could not open app or Play Store: $e');
                }
              }
            } catch (e) {
              debugPrint('❌ Error parsing intent URL: $e');
            }
            return NavigationDecision.prevent;
          }

          // Intercept YouTube web links and open in the YouTube app
          final youtubeAppUrl = _tryConvertYouTubeWebUrlToAppUrl(url);
          if (youtubeAppUrl != null) {
            try {
              final uri = Uri.parse(youtubeAppUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                debugPrint('✅ Opened YouTube app: $youtubeAppUrl');
              } else {
                try {
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                } catch (_) {}
              }
            } catch (e) {
              debugPrint('❌ Error launching YouTube: $e');
            }
            return NavigationDecision.prevent;
          }

          // Intercept Facebook web links and open in the Facebook app
          if (_isFacebookWebUrl(url)) {
            try {
              // Try fb:// scheme first so the app opens directly
              final fbAppUrl =
                  'fb://facewebmodal/f?href=${Uri.encodeComponent(url)}';
              final fbUri = Uri.parse(fbAppUrl);
              if (await canLaunchUrl(fbUri)) {
                await launchUrl(fbUri, mode: LaunchMode.externalApplication);
                debugPrint('✅ Opened Facebook app: $url');
              } else {
                await launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
              }
            } catch (e) {
              try {
                await launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
              } catch (_) {
                debugPrint('❌ Error launching Facebook: $e');
              }
            }
            return NavigationDecision.prevent;
          }

          // Intercept WhatsApp web links (wa.me, api.whatsapp.com, web.whatsapp.com)
          // and open in the WhatsApp app instead of in the WebView
          final whatsappAppUrl = _tryConvertWhatsAppWebUrlToAppUrl(url);
          if (whatsappAppUrl != null) {
            try {
              final uri = Uri.parse(whatsappAppUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                debugPrint('✅ Opened WhatsApp app: $whatsappAppUrl');
              } else {
                // Fallback: try opening the original web URL externally
                try {
                  final webUri = Uri.parse(url);
                  await launchUrl(webUri, mode: LaunchMode.externalApplication);
                } catch (_) {}
              }
            } catch (e) {
              debugPrint('❌ Error launching WhatsApp: $e');
            }
            return NavigationDecision.prevent;
          }

          // Check if it's an external URL scheme (WhatsApp, tel, mailto, etc.)
          if (url.startsWith('whatsapp://') ||
              url.startsWith('tel:') ||
              url.startsWith('mailto:') ||
              url.startsWith('sms:') ||
              url.startsWith('fb://') ||
              url.startsWith('fb-messenger://') ||
              url.startsWith('instagram://') ||
              url.startsWith('twitter://') ||
              url.startsWith('tg://')) {
            // Try to launch the external app
            try {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                debugPrint('✅ Opened external app: $url');
              } else {
                debugPrint('❌ Cannot launch: $url');
              }
            } catch (e) {
              debugPrint('❌ Error launching URL: $e');
            }
            return NavigationDecision.prevent;
          }

          return NavigationDecision.navigate;
        },
      ),
    );

    _webViewController.loadRequest(
      Uri.parse(_initialUrl),
      headers: {
        'X-App-Source': 'anmka', // <-- الهيدر اللي بيتأكد منه السيرفر
      },
    );

    // Print header when app opens
    debugPrint('🔧 WebView initialized');
    debugPrint('📋 Headers being sent: X-App-Source: anmka');
    debugPrint('🌐 Loading URL: $_initialUrl');
  }

  /// Initialize screen protection on Android/iOS
  Future<void> _initializeScreenProtector() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        debugPrint('🛡️ Enabling Android screen protection...');
        await ScreenProtector.protectDataLeakageOn();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        debugPrint('🛡️ Enabling iOS screenshot prevention...');
        await ScreenProtector.preventScreenshotOn();
      }
    } catch (e) {
      debugPrint('❌ ScreenProtector init error: $e');
    }
  }

  void _refreshWebView() {
    debugPrint('🔄 Refreshing WebView...');
    if (mounted) {
      setState(() {
        _loadingProgress = 0.0;
        _isLoading = true;
        _hasLoadedSuccessfully = false;
      });
    }
    _webViewController.reload();
  }

  /// Handle back: go back in WebView if there is history, otherwise exit app.
  Future<void> _onBackPressed() async {
    final canGoBack = await _webViewController.canGoBack();
    if (canGoBack && mounted) {
      _webViewController.goBack();
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  void dispose() {
    // Disable screen protection when leaving
    if (defaultTargetPlatform == TargetPlatform.android) {
      ScreenProtector.protectDataLeakageOff();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      ScreenProtector.preventScreenshotOff();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _onBackPressed();
      },
      child: Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              _refreshWebView();
            },
            child: Stack(
              children: [
                WebViewWidget(controller: _webViewController),
                if (_isLoading && _loadingProgress < 1.0)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      value: _loadingProgress,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blue[700]!,
                      ),
                      minHeight: 3,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
