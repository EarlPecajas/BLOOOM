import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:exif/exif.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/env.dart';

/// Applied to network calls that previously had no timeout at all, which let
/// a flaky (not fully-offline) connection hang for a long OS-level timeout
/// before failing — making screens feel stuck rather than falling back to
/// cache quickly.
const Duration _kNetworkTimeout = Duration(seconds: 8);

/// Tracks device network reachability so screens can show an immediate
/// "Offline" banner instead of leaving the user watching a loading spinner
/// guess whether it's stuck or just slow. A single instance is shared
/// app-wide (see [connectivityController]) so every screen agrees on status.
class ConnectivityController extends ChangeNotifier {
  ConnectivityController() {
    _init();
  }

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  Future<void> _init() async {
    try {
      _apply(await Connectivity().checkConnectivity());
    } catch (_) {
      // Platform channel unavailable (e.g. unsupported host) — assume online
      // rather than showing a false "Offline" banner.
    }
    _subscription = Connectivity().onConnectivityChanged.listen(_apply);
  }

  void _apply(List<ConnectivityResult> results) {
    final bool offline =
        results.isEmpty ||
        results.every((ConnectivityResult r) => r == ConnectivityResult.none);
    if (offline != _isOffline) {
      _isOffline = offline;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// App-wide singleton — created once and shared by every screen's
/// [OfflineBanner] so they all reflect the same connectivity state.
final ConnectivityController connectivityController = ConnectivityController();

/// Slim banner pinned to the top of a screen, visible only while
/// [connectivityController] reports no network. Drop this at the top of any
/// screen that fetches live data so users get an instant explanation instead
/// of an unexplained loading state.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: connectivityController,
      builder: (BuildContext context, Widget? _) {
        if (!connectivityController.isOffline) {
          return const SizedBox.shrink();
        }
        return Container(
          width: double.infinity,
          color: const Color(0xFFB3261E),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.cloud_off_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Offline — showing saved data',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Persists the last successful fetch of a given key to disk (via
/// SharedPreferences) so screens can fall back to real data — instead of an
/// error state — when opened without network. Callers write after a
/// successful network fetch and read only when that fetch fails.
class OfflineCache {
  static const String _prefix = 'offline_cache_';
  static Future<void> save(String key, Object? data) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$key', jsonEncode(data));
  }

  static Future<dynamic> load(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
}

/// Shared by both catalog screens' loaders to read back a species list
/// previously saved via [OfflineCache.save].
Future<List<CatalogSpecies>?> _loadCachedSpecies(String key) async {
  final dynamic raw = await OfflineCache.load(key);
  if (raw is! List) return null;
  final List<CatalogSpecies> species = raw
      .whereType<Map>()
      .map((Map m) => CatalogSpecies.fromJson(Map<String, dynamic>.from(m)))
      .toList(growable: false);
  return species.isEmpty ? null : species;
}

bool _kIsDark = false;
Color get _appBackgroundColor =>
    _kIsDark ? _primaryDarkColor : _surfaceSoftColor;
Color get _surfaceColor => _kIsDark ? const Color(0xFF0F2210) : Colors.white;
Color get _textColor => _kIsDark ? const Color(0xFFD4F0CC) : _primarySoftColor;
Color get _mutedTextColor =>
    _kIsDark ? const Color(0xFF75B86C) : _mutedTextLightColor;
Color get _lineColor =>
    _kIsDark ? const Color(0xFF1B3C1C) : _surfaceOutlineColor;
// Palette aligned to web's `.researcher-theme` (frontend/styles.css ~4415,
// explicitly commented "matches mobile app") so both apps read as one system.
const Color _surfaceTintColor = Color(0xFFF0F8ED);
const Color _surfaceSoftColor = Color(0xFFF0EAD2); // web bg
const Color _surfaceSoftStrongColor = Color(0xFFE8E2CB); // web panel
const Color _surfaceOutlineColor = Color(0xFFC0D8C4); // web border
const Color _surfaceMutedColor = Color(0xFFA8D4A5);
const Color _mutedTextLightColor = Color(0xFF6A8A64); // web muted text
const Color _hintTextColor = Color(0xFF9CA3AF);
const Color _primaryColor = Color(0xFF145A1E); // web primary
const Color _primarySoftColor = Color(0xFF1A3A1A); // web text
const Color _primaryGradientColor = Color(0xFF3D8A50); // web primary-soft
const Color _primaryDeepColor = Color(0xFF072207);
const Color _primaryDarkColor = Color(0xFF0D3312); // web dark-theme bg
const Color _primaryOverlayColor = Color(0xFF041003);
const Color _accentColor = Color(0xFF3D8A50);
const Color _accentSoftColor = Color(0xFFD9F3D5);
const Color _textOnPrimaryColor = Color(0xFFE7E1B1);
// Status colors — mirror web's submission/draft status badges exactly
// (frontend/styles.css `.submission-status-badge.status-*`).
const Color _statusApprovedBg = Color(0xFFECFDF3);
const Color _statusApprovedText = Color(0xFF13683A);
const Color _statusApprovedBorder = Color(0xFFB8EBCF);
const Color _statusRejectedBg = Color(0xFFFEF2F2);
const Color _statusRejectedText = Color(0xFF9F1D1D);
const Color _statusRejectedBorder = Color(0xFFFECACA);
const Color _statusRevisionBg = Color(0xFFFFFBEB);
const Color _statusRevisionText = Color(0xFF9A6100);
const Color _statusRevisionBorder = Color(0xFFFDE68A);
const Color _statusPendingBg = Color(0xFFF1F5F9);
const Color _statusPendingText = Color(0xFF334155);
const Color _statusPendingBorder = Color(0xFFCBD5E1);

/// Maps a `review_status` value to its web-matching label/colors. Shared by
/// every submission/draft status chip so 'revision' always gets its own
/// distinct amber treatment instead of silently falling into 'pending'.
String reviewStatusLabel(String status) {
  switch (status.trim().toLowerCase()) {
    case 'approved':
      return 'Approved';
    case 'rejected':
      return 'Rejected';
    case 'revision':
      return 'Needs Revision';
    case 'draft':
      return 'Draft';
    default:
      return 'Pending';
  }
}

Color reviewStatusColor(String status) {
  switch (status.trim().toLowerCase()) {
    case 'approved':
      return _statusApprovedText;
    case 'rejected':
      return _statusRejectedText;
    case 'revision':
      return _statusRevisionText;
    default:
      return _statusPendingText;
  }
}

Color reviewStatusBg(String status) {
  switch (status.trim().toLowerCase()) {
    case 'approved':
      return _statusApprovedBg;
    case 'rejected':
      return _statusRejectedBg;
    case 'revision':
      return _statusRevisionBg;
    default:
      return _statusPendingBg;
  }
}

Color reviewStatusBorder(String status) {
  switch (status.trim().toLowerCase()) {
    case 'approved':
      return _statusApprovedBorder;
    case 'rejected':
      return _statusRejectedBorder;
    case 'revision':
      return _statusRevisionBorder;
    default:
      return _statusPendingBorder;
  }
}

// Upload form green theme
const Color _uploadPrimary = Color(0xFF145A1E);
const Color _uploadPrimaryDark = Color(0xFF0E4018);
Color get _uploadBg => _kIsDark ? _primaryDarkColor : const Color(0xFFF5FAF0);
Color get _uploadSubCardBg =>
    _kIsDark ? const Color(0xFF0F2B10) : _surfaceSoftStrongColor;
Color get _uploadBorderColor =>
    _kIsDark ? const Color(0x550D530E) : const Color(0x2E0D530E);
const bool kOfflineMode = false;

/// Converts a picture.file_path value to a Supabase Storage public URL.
/// Handles already-absolute URLs, relative "./name.ext" paths, and bare paths.
String _orchidImageUrl(String filePath) {
  final String normalized = filePath.trim();
  if (normalized.isEmpty) return '';
  if (normalized == '[object Object]') return '';
  if (normalized.startsWith('http')) return normalized;
  final String p = normalized.startsWith('./')
      ? normalized.substring(2)
      : normalized;
  return Supabase.instance.client.storage.from(kStorageBucket).getPublicUrl(p);
}

String _readNestedString(Map<String, dynamic> json, List<String> keys) {
  for (final String key in keys) {
    final dynamic value = json[key];
    if (value == null) {
      continue;
    }
    final String text = value.toString().trim();
    if (text.isEmpty || text == 'null' || text == '[object Object]') {
      continue;
    }
    return text;
  }
  return '';
}

/// Looks up terrain elevation for a coordinate via api.open-elevation.com
/// the same DEM-based lookup web uses (researcher-dashboard.html), which is
/// more consistent than raw device-GPS altitude. Returns null on any
/// failure so callers can fall back to GPS altitude.
Future<double?> fetchOpenElevationMeters(double lat, double lng) async {
  try {
    final Uri uri = Uri.https(
      'api.open-elevation.com',
      '/api/v1/lookup',
      <String, String>{'locations': '$lat,$lng'},
    );
    final http.Response response = await http
        .get(uri)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final dynamic decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final dynamic results = decoded['results'];
      if (results is List && results.isNotEmpty) {
        final dynamic first = results.first;
        if (first is Map) {
          final dynamic elevation = first['elevation'];
          if (elevation is num) return elevation.toDouble();
        }
      }
    }
  } catch (_) {}
  return null;
}

/// Extracts file_path from a biogeography→picture join result and returns a URL.
String _orchidImageUrlFromJson(Map<String, dynamic> json) {
  final dynamic bioRaw = json['biogeography'];
  // orchids.biogeography is embedded via a UNIQUE FK (biogeography.orchid_id),
  // so PostgREST returns it as a single object, not a one-element array
  // only treat it as a list when Supabase actually sends one (defensive).
  final List<dynamic> bioList;
  if (bioRaw is Map) {
    bioList = <dynamic>[bioRaw];
  } else if (bioRaw is List) {
    bioList = bioRaw;
  } else {
    return '';
  }
  if (bioList.isEmpty) return '';
  for (final dynamic bio in bioList) {
    if (bio is! Map) continue;
    final Map<String, dynamic> bioMap = Map<String, dynamic>.from(bio);
    final dynamic pictureRaw = bioMap['picture'];
    final List<Map<String, dynamic>> pictures = <Map<String, dynamic>>[];
    if (pictureRaw is Map) {
      pictures.add(Map<String, dynamic>.from(pictureRaw));
    } else if (pictureRaw is List) {
      for (final dynamic entry in pictureRaw) {
        if (entry is Map) {
          pictures.add(Map<String, dynamic>.from(entry));
        }
      }
    }
    for (final Map<String, dynamic> picture in pictures) {
      final String source = _readNestedString(picture, <String>[
        'file_path',
        'file_url',
      ]);
      if (source.isNotEmpty) {
        return _orchidImageUrl(source);
      }
    }
  }
  return '';
}

Future<Map<String, String>> _loadLatestSightingThumbs() async {
  try {
    final List<dynamic> rows = await Supabase.instance.client
        .from('species_sightings')
        .select(
          'scientific_name, created_at, review_status, '
          'sighting_media(media_category, picture(file_path))',
        )
        .eq('review_status', 'approved')
        .order('created_at', ascending: false)
        .limit(500)
        .timeout(_kNetworkTimeout);
    final Map<String, String> map = <String, String>{};
    for (final dynamic row in rows) {
      if (row is! Map) continue;
      final String sci = (row['scientific_name'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      String url = '';
      {
        final List<dynamic> media =
            (row['sighting_media'] as List?) ?? const <dynamic>[];
        for (final dynamic m in media) {
          if (m is Map && m['media_category'] == 'whole_plant') {
            final dynamic pic = m['picture'];
            if (pic is Map) {
              url = (pic['file_path'] ?? '').toString().trim();
              if (url.isNotEmpty) break;
            }
          }
        }
      }
      if (sci.isEmpty || url.isEmpty) continue;
      map.putIfAbsent(sci, () => url);
    }
    return map;
  } catch (_) {
    return <String, String>{};
  }
}

/// Builds the inner child for a profile avatar.
/// Prefers [profilePhotoUrl] (network), falls back to [profilePhotoBase64]
/// (legacy base64), then shows [initials] text on a transparent background.
Widget _buildProfileAvatarChild({
  required String profilePhotoUrl,
  required String profilePhotoBase64,
  required String initials,
  double iconSize = 28,
}) {
  if (profilePhotoUrl.trim().isNotEmpty) {
    return CachedNetworkImage(
      imageUrl: profilePhotoUrl.trim(),
      fit: BoxFit.cover,
      placeholder: (_, _) => const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      ),
      errorWidget: (_, _, _) => Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
  if (profilePhotoBase64.trim().isNotEmpty) {
    try {
      final Uint8List bytes = base64Decode(profilePhotoBase64.trim());
      return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    } catch (_) {}
  }
  return Center(
    child: Text(
      initials,
      style: TextStyle(
        fontSize: iconSize,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );
}

/// Tries to read GPS coordinates from JPEG EXIF data.
/// Returns null when no GPS tags are present or EXIF cannot be parsed.
Future<({double lat, double lng})?> _extractGpsFromExif(Uint8List bytes) async {
  try {
    final Map<String, IfdTag> data = await readExifFromBytes(bytes);
    if (data.isEmpty) return null;
    final String? latRef = data['GPS GPSLatitudeRef']?.toString();
    final String? lonRef = data['GPS GPSLongitudeRef']?.toString();
    final IfdValues? latValues = data['GPS GPSLatitude']?.values;
    final IfdValues? lonValues = data['GPS GPSLongitude']?.values;
    if (latRef == null ||
        lonRef == null ||
        latValues == null ||
        lonValues == null) {
      return null;
    }
    if (latValues is! IfdRatios || lonValues is! IfdRatios) {
      return null;
    }
    double gpsToDecimal(IfdRatios v, String ref) {
      double sum = 0;
      double unit = 1.0;
      for (final r in v.ratios) {
        sum += r.toDouble() * unit;
        unit /= 60.0;
      }
      if (ref == 'S' || ref == 'W') sum = -sum;
      return sum;
    }

    final double lat = gpsToDecimal(latValues, latRef);
    final double lng = gpsToDecimal(lonValues, lonRef);
    if (lat == 0.0 && lng == 0.0) return null;
    return (lat: lat, lng: lng);
  } catch (_) {
    return null;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Do NOT await Supabase here — it makes a network call and blocks runApp()
  // causing a native white screen for 10+ seconds. Instead, runApp immediately
  // so the branded splash renders, then initialize inside AppAuthController.
  runApp(const OrchidApp());
}

class OrchidApp extends StatefulWidget {
  const OrchidApp({super.key});
  @override
  State<OrchidApp> createState() => _OrchidAppState();
}

class _OrchidAppState extends State<OrchidApp> {
  final AppAuthController _authController = AppAuthController();
  // Cached so ThemeData is not rebuilt on every auth notification.
  ThemeData? _cachedTheme;
  bool _cachedIsDark = false;
  @override
  void initState() {
    super.initState();
    _authController.initialize();
    _authController.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() => setState(() {
    _kIsDark = _authController.isDarkMode;
  });
  @override
  void dispose() {
    _authController.removeListener(_onControllerUpdate);
    _authController.dispose();
    super.dispose();
  }

  ThemeData _buildTheme(bool isDark) {
    // Return cached theme if dark-mode hasn't changed — avoids rebuilding
    // ColorScheme.fromSeed (expensive) on every auth notification.
    if (_cachedTheme != null && _cachedIsDark == isDark) {
      return _cachedTheme!;
    }
    _cachedIsDark = isDark;
    final Brightness brightness = isDark ? Brightness.dark : Brightness.light;
    final ColorScheme colorScheme =
        ColorScheme.fromSeed(
          seedColor: _primaryColor,
          brightness: brightness,
        ).copyWith(
          primary: _primaryColor,
          secondary: _accentColor,
          surface: _surfaceColor,
          onSurface: _textColor,
          tertiary: _primarySoftColor,
        );
    final TextTheme baseTextTheme = ThemeData.light().textTheme;
    _cachedTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _appBackgroundColor,
      visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      cardTheme: CardThemeData(
        color: _surfaceColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: _lineColor, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: _textColor,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: _lineColor, space: 1, thickness: 1),
      textTheme: baseTextTheme.copyWith(
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: _textColor,
        ),
        titleLarge: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: _textColor,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _textColor,
        ),
        bodyLarge: TextStyle(fontSize: 14, color: _textColor),
        bodyMedium: TextStyle(fontSize: 13, color: _textColor),
        bodySmall: TextStyle(fontSize: 12, color: _mutedTextColor),
        labelLarge: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: _surfaceColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _lineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _primaryColor, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 1,
          backgroundColor: _primaryColor,
          foregroundColor: _textOnPrimaryColor,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryColor,
          side: const BorderSide(color: _primaryColor, width: 1.3),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: _textOnPrimaryColor,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryColor,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _textColor,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
    return _cachedTheme!;
  }

  @override
  Widget build(BuildContext context) {
    _kIsDark = _authController.isDarkMode;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BLOOM3D',
      theme: _buildTheme(_kIsDark),
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: const TextScaler.linear(0.92)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: AnimatedBuilder(
        animation: _authController,
        builder: (context, _) {
          if (_authController.isInitializing) {
            return const SplashScreen();
          }
          if (_authController.user != null) {
            return AuthenticatedShell(
              authController: _authController,
              initialTabIndex: 0,
            );
          }
          return WelcomeScreen(authController: _authController);
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _fade = Tween<double>(
      begin: 0.25,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryDarkColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _fade,
              child: Image.asset('logo.png', width: 150, fit: BoxFit.contain),
            ),
            const SizedBox(height: 16),
            FadeTransition(
              opacity: _fade,
              child: const Text(
                'BLOOM',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 6,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Orchidaceae Conservation',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 2,
                color: Colors.white.withAlpha(140),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({required this.authController, super.key});
  final AppAuthController authController;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryDarkColor,
      body: Stack(
        children: [
          // Hero background image
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl:
                  'https://images.unsplash.com/photo-1775405298533-3e5909b16c43?w=800&q=80',
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_primaryDeepColor, _primaryDarkColor],
                  ),
                ),
              ),
            ),
          ),
          // Dark gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.4, 0.7, 1.0],
                  colors: [
                    _primaryOverlayColor.withAlpha(77),
                    _primaryOverlayColor.withAlpha(26),
                    _primaryOverlayColor.withAlpha(217),
                    _primaryOverlayColor.withAlpha(247),
                  ],
                ),
              ),
            ),
          ),
          // Content layer
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top wordmark row
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'logo.png',
                            height: 36,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'BLOOM',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(38),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withAlpha(64)),
                        ),
                        child: Text(
                          'Mt. Busa · Sarangani',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withAlpha(230),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Hero text block
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ORCHIDACEAE CONSERVATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 3,
                          color: const Color(0xFFE7E1B1).withAlpha(230),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Discover &\nProtect Wild\nOrchids',
                        style: TextStyle(
                          fontSize: 46,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Documenting & preserving the rare Orchidaceae\nof Mt. Busa, one sighting at a time.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withAlpha(166),
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                // Bottom frosted glass card
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(20),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withAlpha(46)),
                        ),
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                        child: Column(
                          children: [
                            // Sign In button
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => LoginScreen(
                                      authController: authController,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                height: 54,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF0D530E),
                                      _primaryGradientColor,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(16),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x4D0D530E),
                                      blurRadius: 20,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Continue as Guest button
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => GuestCatalogScreen(
                                      authController: authController,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                height: 54,
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withAlpha(89),
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_outline_rounded,
                                      size: 18,
                                      color: Colors.white.withAlpha(200),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Continue as Guest',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withAlpha(230),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Guest Catalog
class GuestCatalogScreen extends StatefulWidget {
  const GuestCatalogScreen({required this.authController, super.key});
  final AppAuthController authController;
  @override
  State<GuestCatalogScreen> createState() => _GuestCatalogScreenState();
}

class _GuestCatalogScreenState extends State<GuestCatalogScreen> {
  bool _gridMode = false;
  late Future<List<CatalogSpecies>> _speciesFuture;
  List<CatalogSpecies> _allSpecies = <CatalogSpecies>[];
  List<CatalogSpecies> _filteredSpecies = <CatalogSpecies>[];
  List<CatalogGroup> _filteredGroups = <CatalogGroup>[];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  @override
  void initState() {
    super.initState();
    _startLoad();
    _searchController.addListener(_onSearch);
  }

  void _startLoad() {
    _speciesFuture = _loadSpecies();
    _speciesFuture
        .then((List<CatalogSpecies> list) {
          if (mounted) {
            setState(() {
              _allSpecies = list;
              _recomputeFilter();
            });
          }
        })
        .catchError((_) {
          if (mounted) setState(() {});
        });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final String q = _searchController.text.toLowerCase().trim();
    if (q == _searchQuery) return;
    setState(() {
      _searchQuery = q;
      _recomputeFilter();
    });
  }

  void _recomputeFilter() {
    if (_allSpecies.isEmpty) {
      _filteredSpecies = <CatalogSpecies>[];
      _filteredGroups = <CatalogGroup>[];
      return;
    }
    _filteredSpecies = _searchQuery.isEmpty
        ? _allSpecies
        : _allSpecies
              .where(
                (CatalogSpecies s) =>
                    s.scientificName.toLowerCase().contains(_searchQuery) ||
                    s.commonName.toLowerCase().contains(_searchQuery) ||
                    s.genus.toLowerCase().contains(_searchQuery),
              )
              .toList(growable: false);
    _filteredGroups = _groupSpecies(_filteredSpecies);
  }

  List<CatalogGroup> _groupSpecies(List<CatalogSpecies> species) {
    final Map<String, List<CatalogSpecies>> map =
        <String, List<CatalogSpecies>>{};
    for (final CatalogSpecies s in species) {
      final String key = s.genus.trim().isNotEmpty
          ? s.genus.trim()
          : s.scientificName.trim().split(RegExp(r'\s+')).first;
      map.putIfAbsent(key, () => <CatalogSpecies>[]).add(s);
    }
    final List<String> keys = map.keys.toList()..sort();
    return keys
        .map((String k) => CatalogGroup(title: k, species: map[k]!))
        .toList(growable: false);
  }

  static const String _catalogCacheKey = 'catalog_species';
  Future<List<CatalogSpecies>> _loadSpecies() async {
    try {
      final Map<String, String> sightingThumbs =
          await _loadLatestSightingThumbs();
      final List<dynamic> data = await Supabase.instance.client
          .from('orchids')
          .select(
            'orchid_id, sci_name, common_name, model_3d_url, genus(genus_name), biogeography(picture(*))',
          )
          .order('sci_name', ascending: true)
          .timeout(_kNetworkTimeout);
      final List<CatalogSpecies> species = data
          .whereType<Map>()
          .map((Map item) {
            final Map<String, dynamic> json = Map<String, dynamic>.from(item);
            final String sci = (json['sci_name'] ?? '').toString().trim();
            if (sci.isEmpty) return null;
            final dynamic genusData = json['genus'];
            final String genus = genusData is Map
                ? (genusData['genus_name'] ?? '').toString()
                : '';
            final String imgUrl = _orchidImageUrlFromJson(json);
            final String fallbackUrl = sightingThumbs[sci.toLowerCase()] ?? '';
            final String resolvedUrl = imgUrl.isNotEmpty ? imgUrl : fallbackUrl;
            final String model3dUrl = (json['model_3d_url'] ?? '')
                .toString()
                .trim();
            return CatalogSpecies(
              id: int.tryParse((json['orchid_id'] ?? '').toString()),
              scientificName: sci,
              commonName: (json['common_name'] ?? 'Common Name')
                  .toString()
                  .trim(),
              genus: genus,
              imageUrl: resolvedUrl.isNotEmpty ? resolvedUrl : null,
              model3dUrl: model3dUrl.isNotEmpty ? model3dUrl : null,
            );
          })
          .whereType<CatalogSpecies>()
          .toList(growable: false);
      unawaited(
        OfflineCache.save(
          _catalogCacheKey,
          species.map((CatalogSpecies s) => s.toJson()).toList(),
        ),
      );
      return species;
    } catch (e) {
      final List<CatalogSpecies>? cached = await _loadCachedSpecies(
        _catalogCacheKey,
      );
      if (cached != null) return cached;
      rethrow;
    }
  }

  void _openDetails(CatalogSpecies species) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CatalogSpeciesDetailsScreen(species: species, isGuest: true),
      ),
    );
  }

  String _heroTagFor(CatalogSpecies s) {
    final String slug = s.scientificName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return 'guest-catalog-${slug.isEmpty ? 'unknown' : slug}';
  }

  Widget _buildModeButton({
    required bool selected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: <Color>[Color(0xFF0D530E), _primaryGradientColor],
                )
              : null,
          color: selected ? null : _surfaceSoftColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x330D530E),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: selected ? Colors.white : _primaryColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _appBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // ── Top row
              Row(
                children: <Widget>[
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _surfaceColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: _lineColor),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: _textColor,
                        size: 20,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceSoftStrongColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Guest View',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // ── Title + mode toggle
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    'Orchid Catalog',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      color: _textColor,
                      letterSpacing: -0.5,
                      height: 0.95,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: _lineColor, width: 1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _buildModeButton(
                          selected: !_gridMode,
                          icon: Icons.view_headline_rounded,
                          onTap: () => setState(() => _gridMode = false),
                        ),
                        _buildModeButton(
                          selected: _gridMode,
                          icon: Icons.grid_view_rounded,
                          onTap: () => setState(() => _gridMode = true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // ── Search bar
              TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 14, color: _primarySoftColor),
                decoration: InputDecoration(
                  hintText: 'Search orchids by name or genus...',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: _hintTextColor,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: _primaryColor,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () => setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                            _recomputeFilter();
                          }),
                          child: const Icon(
                            Icons.close_rounded,
                            color: _primaryColor,
                            size: 18,
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: _surfaceSoftColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _surfaceOutlineColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _surfaceOutlineColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: _primaryColor,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // ── Total orchid count
              if (_allSpecies.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.eco_rounded,
                        size: 13,
                        color: Color(0xFF0D530E),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${_allSpecies.length} orchid${_allSpecies.length == 1 ? '' : 's'} recorded',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0D530E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_searchQuery.isNotEmpty) ...<Widget>[
                        const Text(
                          ' · ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                        Text(
                          '${_filteredSpecies.length} matching',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              // ── List / Grid
              Expanded(
                child: FutureBuilder<List<CatalogSpecies>>(
                  future: _speciesFuture,
                  builder:
                      (
                        BuildContext ctx,
                        AsyncSnapshot<List<CatalogSpecies>> snap,
                      ) {
                        if (snap.connectionState != ConnectionState.done &&
                            _allSpecies.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: _primaryColor,
                            ),
                          );
                        }
                        if (snap.hasError && _allSpecies.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.cloud_off_rounded,
                                  size: 52,
                                  color: Color(0xFF0D530E),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Could not load orchid catalog.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF0D530E),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  snap.error.toString(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _mutedTextColor,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextButton.icon(
                                  onPressed: () => setState(_startLoad),
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    color: _primaryColor,
                                  ),
                                  label: const Text(
                                    'Retry',
                                    style: TextStyle(color: _primaryColor),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        if (_filteredSpecies.isEmpty &&
                            _searchQuery.isNotEmpty) {
                          return Center(
                            child: Text(
                              'No orchids match "$_searchQuery".',
                              style: TextStyle(color: _mutedTextColor),
                            ),
                          );
                        }
                        if (_allSpecies.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.eco_outlined,
                                  size: 52,
                                  color: Color(0xFFD0E8CC),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'No orchids in catalog yet.',
                                  style: TextStyle(color: _mutedTextColor),
                                ),
                              ],
                            ),
                          );
                        }
                        return _gridMode
                            ? _buildGrid(_filteredSpecies)
                            : _buildList(_filteredGroups);
                      },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // List view — genus-grouped, same style as CatalogScreen
  Widget _buildList(List<CatalogGroup> groups) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      children: <Widget>[
        for (final CatalogGroup group in groups)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFD0E8CC)),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x140D530E),
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 4,
                          height: 28,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Color(0xFF0D530E),
                                Color(0xFF2A8C2B),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          group.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF306D29),
                            height: 1.05,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final CatalogSpecies species in group.species)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _openDetails(species),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              child: Row(
                                children: <Widget>[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: species.imageUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: species.imageUrl!,
                                            width: 56,
                                            height: 56,
                                            fit: BoxFit.cover,
                                            placeholder: (_, _) => _thumb(),
                                            errorWidget: (_, _, _) => _thumb(),
                                          )
                                        : _thumb(),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          species.scientificName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF306D29),
                                            fontStyle: FontStyle.italic,
                                            fontWeight: FontWeight.w600,
                                            height: 1.2,
                                          ),
                                        ),
                                        if (species.commonName.isNotEmpty &&
                                            species.commonName.toLowerCase() !=
                                                'common name')
                                          Text(
                                            species.commonName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF0D530E),
                                              height: 1.2,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFF0D530E),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Grid view — same card style as CatalogScreen, no favorites
  Widget _buildGrid(List<CatalogSpecies> species) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      itemCount: species.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (BuildContext ctx, int i) {
        final CatalogSpecies item = species[i];
        return GestureDetector(
          onTap: () => _openDetails(item),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFD0E8CC)),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x140D530E),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: item.imageUrl != null
                      ? Hero(
                          tag: _heroTagFor(item),
                          child: CachedNetworkImage(
                            imageUrl: item.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (_, _) => Container(
                              color: const Color(0xFFE8F5E3),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.eco_outlined,
                                color: Color(0xFF0D530E),
                                size: 32,
                              ),
                            ),
                            errorWidget: (_, _, _) => Container(
                              color: const Color(0xFFE8F5E3),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.eco_outlined,
                                color: Color(0xFF0D530E),
                                size: 32,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFFE8F5E3),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.eco_outlined,
                            color: Color(0xFF0D530E),
                            size: 32,
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.scientificName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF306D29),
                          height: 1.2,
                        ),
                      ),
                      if (item.commonName.isNotEmpty &&
                          item.commonName.toLowerCase() !=
                              'common name') ...<Widget>[
                        const SizedBox(height: 3),
                        Text(
                          item.commonName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF0D530E),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _thumb() => Container(
    width: 56,
    height: 56,
    decoration: BoxDecoration(
      color: const Color(0xFFE8F5E3),
      borderRadius: BorderRadius.circular(14),
    ),
    alignment: Alignment.center,
    child: const Icon(Icons.eco_outlined, color: Color(0xFF0D530E), size: 22),
  );
}

//
class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.authController, super.key});
  final AppAuthController authController;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _showPassword = false;
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Mirrors the web sign-in page's "Forgot password?" modal: collects an
  // email and calls Supabase's resetPasswordForEmail, which sends the
  // account holder a reset link (handled by the web reset-password page).
  void _showForgotPasswordDialog() {
    showDialog<void>(
      context: context,
      builder: (_) =>
          _ForgotPasswordDialog(initialEmail: _emailController.text.trim()),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    try {
      await widget.authController.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => AuthenticatedShell(
            authController: widget.authController,
            initialTabIndex: 0,
          ),
        ),
        (route) => false,
      );
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to login right now.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF5DD),
      body: Column(
        children: [
          // Gradient header strip
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 210,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: [0.0, 0.6, 1.0],
                    colors: [
                      Color(0xFF0D530E),
                      Color(0xFF2A8C2B),
                      Color(0xFF188A1C),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: -48,
                right: -48,
                child: Container(
                  width: 192,
                  height: 192,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(18),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -32,
                right: 32,
                child: Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(13),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(38),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Image.asset(
                                'logo.png',
                                height: 30,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'BLOOM',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Welcome back',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Form area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Sign in',
                    style: TextStyle(fontSize: 14, color: _mutedTextLightColor),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'EMAIL ADDRESS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _mutedTextLightColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(
                      fontSize: 15,
                      color: _primarySoftColor,
                    ),
                    decoration: InputDecoration(
                      hintText: 'your@email.com',
                      prefixIcon: const Icon(
                        Icons.mail_outline_rounded,
                        color: _primaryColor,
                        size: 18,
                      ),
                      filled: true,
                      fillColor: _surfaceColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: _surfaceOutlineColor,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: _primaryColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'PASSWORD',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _mutedTextLightColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      GestureDetector(
                        onTap: _showForgotPasswordDialog,
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _primaryColor,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    style: const TextStyle(
                      fontSize: 15,
                      color: _primarySoftColor,
                    ),
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: _primaryColor,
                        size: 18,
                      ),
                      suffixIcon: GestureDetector(
                        onTap: () =>
                            setState(() => _showPassword = !_showPassword),
                        child: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: _mutedTextLightColor,
                          size: 18,
                        ),
                      ),
                      filled: true,
                      fillColor: _surfaceColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: _surfaceOutlineColor,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: _primaryColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  GestureDetector(
                    onTap: _isSubmitting ? null : _submit,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: _isSubmitting
                            ? null
                            : const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF0D530E),
                                  _primaryGradientColor,
                                ],
                              ),
                        color: _isSubmitting ? _surfaceMutedColor : null,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _isSubmitting
                            ? null
                            : const [
                                BoxShadow(
                                  color: Color(0x4D0D530E),
                                  blurRadius: 24,
                                  offset: Offset(0, 8),
                                ),
                              ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _isSubmitting ? 'Signing in…' : 'Continue',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _textOnPrimaryColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            SignUpScreen(authController: widget.authController),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            color: _mutedTextLightColor,
                          ),
                          children: [
                            TextSpan(text: "Don't have an account? "),
                            TextSpan(
                              text: 'Sign Up',
                              style: TextStyle(
                                color: _primaryColor,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Matches the web sign-in page's "Reset your password" modal — collects an
// email and calls Supabase Auth directly, no server round-trip through
// AppAuthController needed for a stateless password-reset request.
class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});
  final String initialEmail;
  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  bool _isSending = false;
  bool _sent = false;
  String? _message;
  Color _messageColor = _primaryColor;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _message = 'Please enter your email address.';
        _messageColor = const Color(0xFFB42318);
      });
      return;
    }
    setState(() {
      _isSending = true;
      _message = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _message =
            'If an account exists for that email, a reset link has been '
            'sent. Check your inbox (and spam folder).';
        _messageColor = _primaryColor;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.message;
        _messageColor = const Color(0xFFB42318);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Could not send the reset email. Please try again.';
        _messageColor = const Color(0xFFB42318);
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _surfaceColor,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reset your password',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Enter the email address on your account and we'll send you "
              'a link to reset your password.',
              style: TextStyle(
                fontSize: 13,
                color: _mutedTextLightColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              enabled: !_isSending && !_sent,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 15, color: _primarySoftColor),
              decoration: InputDecoration(
                hintText: 'you@example.com',
                filled: true,
                fillColor: _surfaceColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: _surfaceOutlineColor,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: _primaryColor,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 10),
              Text(
                _message!,
                style: TextStyle(
                  fontSize: 12.5,
                  color: _messageColor,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (_isSending || _sent) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _sent
                        ? 'Sent'
                        : (_isSending ? 'Sending…' : 'Send Reset Link'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({required this.authController, super.key});
  final AppAuthController authController;
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _affiliationController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  DateTime? _selectedBirthday;
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _birthdayController.dispose();
    _phoneController.dispose();
    _affiliationController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final DateTime today = DateTime.now();
    final DateTime yesterday = today.subtract(const Duration(days: 1));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(today.year - 18, today.month, today.day),
      firstDate: DateTime(1900),
      lastDate: yesterday,
      helpText: 'Select your birthday',
      builder: (BuildContext ctx, Widget? child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _primaryColor,
            onPrimary: Colors.white,
            onSurface: Color(0xFF306D29),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedBirthday = picked;
        _birthdayController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  bool _isValidPhilippinePhone(String phone) {
    final String cleaned = phone.replaceAll(RegExp(r'[\s\-]'), '');
    return RegExp(r'^(\+63|0)\d{10}$').hasMatch(cleaned);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final String firstName = _firstNameController.text.trim();
    final String lastName = _lastNameController.text.trim();
    final String email = _emailController.text.trim();
    final String phone = _phoneController.text.trim();
    final String affiliation = _affiliationController.text.trim();
    final String password = _passwordController.text;
    final String confirmPassword = _confirmPasswordController.text;
    if (firstName.isEmpty || lastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your first and last name.')),
      );
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }
    if (_selectedBirthday == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your birthday.')),
      );
      return;
    }
    if (phone.isEmpty || !_isValidPhilippinePhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid Philippine phone number (e.g. 09XXXXXXXXX or +63XXXXXXXXXX).',
          ),
        ),
      );
      return;
    }
    if (affiliation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your affiliation or institution.'),
        ),
      );
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters.'),
        ),
      );
      return;
    }
    if (password != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match.')));
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    try {
      await widget.authController.login(
        email: email,
        password: password,
        name: '$firstName $lastName',
        firstName: firstName,
        lastName: lastName,
        birthday: _birthdayController.text,
        phoneNumber: phone,
        affiliation: affiliation,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => AuthenticatedShell(
            authController: widget.authController,
            initialTabIndex: 0,
          ),
        ),
        (route) => false,
      );
    } on AuthApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to create account right now.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: _mutedTextLightColor,
      letterSpacing: 0.5,
    ),
  );
  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: _primaryColor, size: 18),
      suffixIcon: suffix,
      filled: true,
      fillColor: _surfaceColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _surfaceOutlineColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primaryColor, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceSoftColor,
      body: Column(
        children: [
          // Gradient header strip
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 175,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: [0.0, 0.6, 1.0],
                    colors: [
                      _primaryDeepColor,
                      Color(0xFF0D530E),
                      _primaryGradientColor,
                    ],
                  ),
                ),
              ),
              Positioned(
                top: -40,
                right: -40,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(15),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(38),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(28, 14, 28, 0),
                      child: Text(
                        'Join BLOOM',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Form area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Create your researcher account',
                    style: TextStyle(fontSize: 14, color: _mutedTextLightColor),
                  ),
                  const SizedBox(height: 20),
                  // First Name & Last Name side by side
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('FIRST NAME'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _firstNameController,
                              style: const TextStyle(
                                fontSize: 15,
                                color: _primarySoftColor,
                              ),
                              decoration: _fieldDecoration(
                                hint: 'Maria',
                                icon: Icons.person_outline_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('LAST NAME'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _lastNameController,
                              style: const TextStyle(
                                fontSize: 15,
                                color: _primarySoftColor,
                              ),
                              decoration: _fieldDecoration(
                                hint: 'Santos',
                                icon: Icons.person_outline_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildLabel('EMAIL ADDRESS'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(
                      fontSize: 15,
                      color: _primarySoftColor,
                    ),
                    decoration: _fieldDecoration(
                      hint: 'your@email.com',
                      icon: Icons.mail_outline_rounded,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildLabel('BIRTHDAY'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _birthdayController,
                    readOnly: true,
                    onTap: _pickBirthday,
                    style: const TextStyle(
                      fontSize: 15,
                      color: _primarySoftColor,
                    ),
                    decoration: _fieldDecoration(
                      hint: 'Tap to select date',
                      icon: Icons.cake_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildLabel('PHONE NUMBER (Philippines)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(
                      fontSize: 15,
                      color: _primarySoftColor,
                    ),
                    decoration: _fieldDecoration(
                      hint: '09XXXXXXXXX or +63XXXXXXXXXX',
                      icon: Icons.phone_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildLabel('AFFILIATION / INSTITUTION / ORGANIZATION'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _affiliationController,
                    style: const TextStyle(
                      fontSize: 15,
                      color: _primarySoftColor,
                    ),
                    decoration: _fieldDecoration(
                      hint: 'University, Research Institute...',
                      icon: Icons.business_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildLabel('PASSWORD'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF306D29),
                    ),
                    decoration: _fieldDecoration(
                      hint: 'Min. 6 characters',
                      icon: Icons.lock_outline_rounded,
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: _surfaceMutedColor,
                          size: 18,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildLabel('RE-TYPE PASSWORD'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF306D29),
                    ),
                    decoration: _fieldDecoration(
                      hint: 'Confirm your password',
                      icon: Icons.lock_outline_rounded,
                      suffix: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: _surfaceMutedColor,
                          size: 18,
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  GestureDetector(
                    onTap: _isSubmitting ? null : _submit,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: _isSubmitting
                            ? null
                            : const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF0D530E),
                                  _primaryGradientColor,
                                ],
                              ),
                        color: _isSubmitting ? _surfaceMutedColor : null,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _isSubmitting
                            ? null
                            : const [
                                BoxShadow(
                                  color: Color(0x4D0D530E),
                                  blurRadius: 24,
                                  offset: Offset(0, 8),
                                ),
                              ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _isSubmitting ? 'Creating account…' : 'Create Account',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _textOnPrimaryColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            LoginScreen(authController: widget.authController),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            color: _mutedTextLightColor,
                          ),
                          children: [
                            TextSpan(text: 'Already have an account? '),
                            TextSpan(
                              text: 'Sign In',
                              style: TextStyle(
                                color: _primaryColor,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    super.key,
  });
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(hintText: hintText),
    );
  }
}

class AuthenticatedShell extends StatefulWidget {
  const AuthenticatedShell({
    required this.authController,
    required this.initialTabIndex,
    super.key,
  });
  final AppAuthController authController;
  final int initialTabIndex;
  @override
  State<AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<AuthenticatedShell> {
  late int _selectedIndex;
  final NotificationController _notificationController =
      NotificationController();
  final Set<int> _activatedTabs = {};
  final List<Widget?> _cachedPages = List.filled(5, null);
  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    _activatedTabs.add(widget.initialTabIndex);
    _notificationController.load();
  }

  @override
  void dispose() {
    _notificationController.dispose();
    super.dispose();
  }

  void _onTabTap(int index) {
    final AppUser? user = widget.authController.user;
    final bool isPendingVerification = user?.isPendingVerification ?? false;
    // Mirrors web's user_profiles.status gating (researcher-dashboard.html
    // ~2185-2206): a researcher awaiting DENR/admin approval only gets Home.
    final bool isPendingApproval = user?.isPendingApproval ?? false;
    if (isPendingApproval && index != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.lock_outline_rounded, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your account is awaiting DENR/admin approval. Only Home is available for now.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0D530E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    if (isPendingVerification && (index == 2 || index == 3)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.lock_outline_rounded, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This feature is locked. Your account is pending admin verification.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0D530E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    setState(() {
      _activatedTabs.add(index);
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppUser? user = widget.authController.user;
    final bool isPending =
        (user?.isPendingVerification ?? false) ||
        (user?.isPendingApproval ?? false);
    final String profileName = user?.name.trim().isNotEmpty == true
        ? user!.name
        : 'Researcher 1';
    final String handleSource = user?.email.trim().isNotEmpty == true
        ? user!.email.split('@').first
        : profileName;
    final String normalizedHandle = handleSource.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    final String profileHandle = normalizedHandle.isNotEmpty
        ? '@$normalizedHandle'
        : '@researcher1';
    Widget pageForIndex(int i) {
      switch (i) {
        case 0:
          return HomeScreen(
            authController: widget.authController,
            notificationController: _notificationController,
          );
        case 1:
          return CatalogScreen(
            authController: widget.authController,
            notificationController: _notificationController,
          );
        case 2:
          return UploadScreen(
            authController: widget.authController,
            notificationController: _notificationController,
          );
        case 3:
          return MapScreen(authController: widget.authController);
        case 4:
          return _ResearcherProfileScreen(
            authController: widget.authController,
            fallbackName: profileName,
            fallbackHandle: profileHandle,
            notificationController: _notificationController,
          );
        default:
          return const SizedBox.shrink();
      }
    }

    const List<IconData> selectedIcons = [
      Icons.home_rounded,
      Icons.library_books_rounded,
      Icons.add_circle_rounded,
      Icons.map_rounded,
      Icons.person_rounded,
    ];
    const List<IconData> unselectedIcons = [
      Icons.home_outlined,
      Icons.library_books_outlined,
      Icons.add_circle_outline_rounded,
      Icons.map_outlined,
      Icons.person_outline_rounded,
    ];
    const List<String> tabLabels = [
      'Home',
      'Catalog',
      'Upload',
      'Map',
      'Profile',
    ];
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: Stack(
              children: [
                IndexedStack(
                  index: _selectedIndex,
                  children: List.generate(5, (i) {
                    if (!_activatedTabs.contains(i))
                      return const SizedBox.shrink();
                    _cachedPages[i] ??= pageForIndex(i);
                    return _cachedPages[i]!;
                  }),
                ),
                // Show notification bell on all tabs except Map (3) and Home (0),
                // since Home has its own notification bell in the header.
                if (_selectedIndex != 3 && _selectedIndex != 0)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 10, 20, 0),
                        child: ListenableBuilder(
                          listenable: _notificationController,
                          builder: (BuildContext context, _) {
                            final int count =
                                _notificationController.unreadCount;
                            return Material(
                              color: Colors.transparent,
                              child: InkResponse(
                                onTap: () => Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => NotificationsScreen(
                                      controller: _notificationController,
                                    ),
                                  ),
                                ),
                                radius: 24,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: <Widget>[
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: _surfaceColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: _lineColor),
                                      ),
                                      child: Icon(
                                        count > 0
                                            ? Icons.notifications_rounded
                                            : Icons.notifications_none_rounded,
                                        color: _primaryColor,
                                        size: 22,
                                      ),
                                    ),
                                    if (count > 0)
                                      Positioned(
                                        right: -4,
                                        top: -4,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: _accentColor,
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 18,
                                            minHeight: 18,
                                          ),
                                          child: Text(
                                            count > 99
                                                ? '99+'
                                                : count.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              height: 1,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _surfaceColor,
          border: Border(top: BorderSide(color: _lineColor, width: 1)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List<Widget>.generate(5, (index) {
                final bool isSelected = index == _selectedIndex;
                final bool isUpload = index == 2;
                if (isUpload) {
                  return GestureDetector(
                    onTap: () => _onTabTap(index),
                    child: Transform.translate(
                      offset: const Offset(0, -16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: isSelected
                                        ? const [
                                            Color(0xFF0D530E),
                                            Color(0xFF2A8C2B),
                                          ]
                                        : const [
                                            Color(0xFF082809),
                                            Color(0xFF0D530E),
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x660D530E),
                                      blurRadius: 16,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isSelected
                                      ? selectedIcons[index]
                                      : unselectedIcons[index],
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                              if (isPending)
                                Positioned(
                                  right: 2,
                                  top: 2,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEA5252),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.lock_rounded,
                                      size: 9,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tabLabels[index],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? _primaryColor
                                  : _mutedTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return GestureDetector(
                  onTap: () => _onTabTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _primaryColor.withAlpha(20)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              isSelected
                                  ? selectedIcons[index]
                                  : unselectedIcons[index],
                              color: isSelected
                                  ? _primaryColor
                                  : _mutedTextColor,
                              size: 22,
                            ),
                            if (isPending && index == 3)
                              Positioned(
                                right: -5,
                                top: -5,
                                child: Container(
                                  width: 13,
                                  height: 13,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEA5252),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.lock_rounded,
                                    size: 7,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tabLabels[index],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected ? _primaryColor : _mutedTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.authController,
    required this.notificationController,
    super.key,
  });
  final AppAuthController authController;
  final NotificationController notificationController;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _dashboardCacheKey = 'home_dashboard';
  late Future<_HomeDashboardData> _dashboardFuture;
  Timer? _greetingTimer;
  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboardData();
    _scheduleGreetingUpdate();
  }

  @override
  void dispose() {
    _greetingTimer?.cancel();
    super.dispose();
  }

  void _scheduleGreetingUpdate() {
    _greetingTimer?.cancel();
    final DateTime now = DateTime.now();
    final DateTime nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _greetingTimer = Timer(nextMinute.difference(now), () {
      if (mounted) setState(() {});
      _scheduleGreetingUpdate();
    });
  }

  String get _greeting {
    final int hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning 🌿';
    if (hour < 17) return 'Good afternoon ☀️';
    return 'Good evening 🌙';
  }

  Future<_HomeDashboardData> _loadDashboardData() async {
    final SupabaseClient supabase = Supabase.instance.client;
    // Each query fails independently so one bad table never zeros everything.
    int totalSpecies = 0;
    int totalSightings = 0;
    int pendingSubmissions = 0;
    SpeciesHighlight? highlight;
    // Total species from the orchids catalog
    try {
      final List<dynamic> orchids = await supabase
          .from('orchids')
          .select('orchid_id')
          .timeout(_kNetworkTimeout);
      totalSpecies = orchids.length;
    } catch (_) {}
    // Recorded sightings count (prefer GIS table, fall back to submissions).
    bool sightingsFromDb = false;
    try {
      final List<dynamic> sightings = await supabase
          .from('orchid_location')
          .select('orchid_location_id')
          .timeout(_kNetworkTimeout);
      totalSightings = sightings.length;
      sightingsFromDb = true;
    } catch (_) {}
    if (!sightingsFromDb || totalSightings == 0) {
      try {
        final List<dynamic> sightings = await supabase
            .from('species_sightings')
            .select('sighting_id')
            .eq('review_status', 'approved')
            .timeout(_kNetworkTimeout);
        if (sightings.isNotEmpty || !sightingsFromDb) {
          totalSightings = sightings.length;
        }
      } catch (_) {}
    }
    // Pending submissions count (global — shown in the hero stat).
    try {
      final List<dynamic> pending = await supabase
          .from('species_sightings')
          .select('sighting_id')
          .eq('review_status', 'pending')
          .timeout(_kNetworkTimeout);
      pendingSubmissions = pending.length;
    } catch (_) {}
    // This researcher's own pending/approved counts — mirrors web's
    // researcher-dashboard.html stat chips, which are scoped to the signed-in
    // researcher rather than catalog-wide totals.
    int myPending = 0;
    int myApproved = 0;
    try {
      final String? email = supabase.auth.currentUser?.email;
      if (email != null && email.isNotEmpty) {
        final List<dynamic> mine = await supabase
            .from('species_sightings')
            .select('review_status')
            .eq('researcher_email', email)
            .timeout(_kNetworkTimeout);
        for (final dynamic row in mine) {
          if (row is! Map) continue;
          final String status = (row['review_status'] ?? '')
              .toString()
              .toLowerCase();
          if (status == 'pending') myPending++;
          if (status == 'approved') myApproved++;
        }
      }
    } catch (_) {}
    // Species of the Day — rotates daily through the full orchid catalog
    try {
      final List<dynamic> allOrchids = await supabase
          .from('orchids')
          .select('orchid_id, sci_name, common_name, biogeography(picture(*))')
          .order('orchid_id', ascending: true)
          .timeout(_kNetworkTimeout);
      if (allOrchids.isNotEmpty) {
        final DateTime now = DateTime.now();
        final int doy = now.difference(DateTime(now.year)).inDays;
        final Map<String, dynamic> row = Map<String, dynamic>.from(
          allOrchids[doy % allOrchids.length] as Map,
        );
        final String sciName = (row['sci_name'] ?? '').toString().trim();
        if (sciName.isNotEmpty) {
          // Prefer whole-plant sighting photo for a richer image
          String imageUrl = '';
          try {
            final List<dynamic> thumbs = await supabase
                .from('species_sightings')
                .select(
                  'created_at, sighting_media(media_category, picture(file_path))',
                )
                .eq('scientific_name', sciName)
                .order('created_at', ascending: false)
                .limit(20)
                .timeout(_kNetworkTimeout);
            outer:
            for (final dynamic row in thumbs) {
              if (row is! Map) continue;
              final List<dynamic> media =
                  (row['sighting_media'] as List?) ?? const <dynamic>[];
              for (final dynamic m in media) {
                if (m is Map && m['media_category'] == 'whole_plant') {
                  final dynamic pic = m['picture'];
                  if (pic is Map) {
                    final String path = (pic['file_path'] ?? '')
                        .toString()
                        .trim();
                    if (path.isNotEmpty) {
                      imageUrl = path;
                      break outer;
                    }
                  }
                }
              }
            }
          } catch (_) {}
          if (imageUrl.isEmpty) imageUrl = _orchidImageUrlFromJson(row);
          highlight = SpeciesHighlight(
            scientificName: sciName,
            commonName: (row['common_name'] ?? '').toString().trim(),
            imageUrl: imageUrl,
          );
        }
      }
    } catch (_) {}
    if (totalSpecies == 0 && totalSightings == 0 && pendingSubmissions == 0) {
      // Every query above failed independently (e.g. offline) rather than
      // genuinely returning empty tables — prefer the last good snapshot
      // over a blank dashboard.
      final dynamic cached = await OfflineCache.load(_dashboardCacheKey);
      if (cached is Map) {
        try {
          return _HomeDashboardData.fromJson(Map<String, dynamic>.from(cached));
        } catch (_) {}
      }
      return const _HomeDashboardData.fallback();
    }
    final _HomeDashboardData result = _HomeDashboardData(
      stats: AppStats(
        totalSpecies: totalSpecies,
        pendingSubmissions: pendingSubmissions,
        totalSightings: totalSightings,
        myPendingCount: myPending,
        myApprovedCount: myApproved,
      ),
      speciesOfTheDay: highlight,
      isFallback: false,
    );
    unawaited(OfflineCache.save(_dashboardCacheKey, result.toJson()));
    return result;
  }

  Future<void> _openProfilePanel(BuildContext context) async {
    final String profileName =
        widget.authController.user?.name.trim().isNotEmpty == true
        ? widget.authController.user!.name
        : 'Researcher 1';
    final String handleSource =
        widget.authController.user?.email.trim().isNotEmpty == true
        ? widget.authController.user!.email.split('@').first
        : profileName;
    final String normalizedHandle = handleSource.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    final String profileHandle = normalizedHandle.isNotEmpty
        ? '@$normalizedHandle'
        : '@researcher1';
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, _, _) => _ProfileOverlayPanel(
        authController: widget.authController,
        fallbackName: profileName,
        fallbackHandle: profileHandle,
        notificationController: widget.notificationController,
      ),
      transitionBuilder: (ctx, animation, _, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String greetingName =
        widget.authController.user?.name.trim().isNotEmpty == true
        ? widget.authController.user!.name.split(' ').first
        : 'Researcher';
    return Scaffold(
      backgroundColor: _appBackgroundColor,
      body: SafeArea(
        child: FutureBuilder<_HomeDashboardData>(
          future: _dashboardFuture,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<_HomeDashboardData> snapshot,
              ) {
                final _HomeDashboardData dashboard =
                    snapshot.data ?? const _HomeDashboardData.fallback();
                final AppStats liveStats = dashboard.stats;
                final SpeciesHighlight? liveHighlight =
                    dashboard.speciesOfTheDay;
                final bool isLoading =
                    snapshot.connectionState == ConnectionState.waiting;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Profile avatar button (opens slide-in panel)
                          AnimatedBuilder(
                            animation: widget.authController,
                            builder: (_, _) {
                              final AppUser? u = widget.authController.user;
                              final String photoUrl =
                                  u?.profilePhotoUrl.trim() ?? '';
                              final String photoB64 =
                                  u?.profilePhotoBase64.trim() ?? '';
                              final String initials =
                                  (u?.name.trim().isNotEmpty == true)
                                  ? u!.name
                                        .trim()
                                        .split(' ')
                                        .take(2)
                                        .map((w) => w[0])
                                        .join()
                                        .toUpperCase()
                                  : 'R';
                              return GestureDetector(
                                onTap: () => _openProfilePanel(context),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _lineColor,
                                      width: 1.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x1A0D530E),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: _buildProfileAvatarChild(
                                      profilePhotoUrl: photoUrl,
                                      profilePhotoBase64: photoB64,
                                      initials: initials,
                                      iconSize: 20,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          // Greeting text
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _greeting,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _mutedTextColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Hello, $greetingName!',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    fontStyle: FontStyle.italic,
                                    color: _textColor,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Notification bell → navigates to NotificationsScreen
                          ListenableBuilder(
                            listenable: widget.notificationController,
                            builder: (_, _) {
                              final int count =
                                  widget.notificationController.unreadCount;
                              return GestureDetector(
                                onTap: () => Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => NotificationsScreen(
                                      controller: widget.notificationController,
                                    ),
                                  ),
                                ),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _surfaceColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _lineColor,
                                      width: 1.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x0A000000),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Icon(
                                        count > 0
                                            ? Icons.notifications_rounded
                                            : Icons.notifications_none_rounded,
                                        color: _primaryColor,
                                        size: 22,
                                      ),
                                      if (count > 0)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            width: 9,
                                            height: 9,
                                            decoration: const BoxDecoration(
                                              color: _accentColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    // Scrollable content
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        children: [
                          if (widget.authController.user?.isPendingApproval ??
                              false)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _statusPendingBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _statusPendingBorder),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.hourglass_top_rounded,
                                    color: _statusPendingText,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Account pending approval',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: _statusPendingText,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'A DENR/admin reviewer needs to approve your account before you can browse the catalog, submit sightings, or use the map.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _statusPendingText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Section: Species of the Day
                          Text(
                            'SPECIES OF THE DAY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: _mutedTextColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (liveHighlight != null)
                            GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => CatalogSpeciesDetailsScreen(
                                    species: CatalogSpecies(
                                      scientificName:
                                          liveHighlight.scientificName,
                                      commonName: liveHighlight.commonName,
                                      imageUrl: liveHighlight.imageUrl,
                                    ),
                                  ),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: SizedBox(
                                  height: 210,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      liveHighlight.imageUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: liveHighlight.imageUrl,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                              placeholder: (_, _) => Container(
                                                color: _surfaceTintColor,
                                                alignment: Alignment.center,
                                                child: const Icon(
                                                  Icons.eco_outlined,
                                                  color: Color(0xFF0D530E),
                                                  size: 36,
                                                ),
                                              ),
                                              errorWidget: (_, _, _) =>
                                                  Container(
                                                    color: _surfaceTintColor,
                                                    alignment: Alignment.center,
                                                    child: const Icon(
                                                      Icons.eco_outlined,
                                                      color: Color(0xFF0D530E),
                                                      size: 36,
                                                    ),
                                                  ),
                                            )
                                          : Container(
                                              color: _surfaceTintColor,
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                Icons.eco_outlined,
                                                color: Color(0xFF0D530E),
                                                size: 36,
                                              ),
                                            ),
                                      // Bottom gradient
                                      const DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            stops: [0.45, 1.0],
                                            colors: [
                                              Colors.transparent,
                                              Color(0xD9061206),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Species info overlay
                                      Positioned(
                                        left: 16,
                                        right: 16,
                                        bottom: 14,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              liveHighlight.scientificName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700,
                                                fontStyle: FontStyle.italic,
                                                color: Colors.white,
                                                height: 1.1,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Text(
                                                  liveHighlight.commonName,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white
                                                        .withAlpha(179),
                                                  ),
                                                ),
                                                Text(
                                                  '  ·  Tap to explore',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white
                                                        .withAlpha(153),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else if (isLoading)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                height: 210,
                                color: _surfaceTintColor,
                                alignment: Alignment.center,
                                child: const CircularProgressIndicator(),
                              ),
                            )
                          else
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                height: 210,
                                color: _surfaceTintColor,
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.eco_outlined,
                                      color: Color(0xFF0D530E),
                                      size: 40,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No species data available',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _mutedTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (!dashboard.isFallback && !isLoading) ...<Widget>[
                            const SizedBox(height: 20),
                            // Section: Bloom Update
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'BLOOM UPDATE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                    color: _mutedTextColor,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF4ADE80),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isLoading ? 'Loading…' : 'Live data',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Main stat card
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF0D530E),
                                    Color(0xFF2A8C2B),
                                  ],
                                ),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x400D530E),
                                    blurRadius: 20,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Species Recorded',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withAlpha(179),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        liveStats.totalSpecies.toString(),
                                        style: const TextStyle(
                                          fontSize: 64,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          height: 0.9,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Text(
                                          'orchid species',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.white.withAlpha(179),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Two mini stat cards
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: _surfaceColor,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x0A000000),
                                          blurRadius: 12,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'My Pending',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _mutedTextColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          liveStats.myPendingCount.toString(),
                                          style: const TextStyle(
                                            fontSize: 38,
                                            fontWeight: FontWeight.w700,
                                            color: _accentColor,
                                            fontStyle: FontStyle.italic,
                                            height: 1.1,
                                          ),
                                        ),
                                        Text(
                                          'under review',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _mutedTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: _surfaceColor,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x0A000000),
                                          blurRadius: 12,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'My Approved',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _mutedTextColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          liveStats.myApprovedCount.toString(),
                                          style: const TextStyle(
                                            fontSize: 38,
                                            fontWeight: FontWeight.w700,
                                            color: _primaryColor,
                                            fontStyle: FontStyle.italic,
                                            height: 1.1,
                                          ),
                                        ),
                                        Text(
                                          'sightings',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _mutedTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ], // end if (!dashboard.isFallback && !isLoading)
                        ],
                      ),
                    ),
                  ],
                );
              },
        ),
      ),
    );
  }
}

class _HomeDashboardData {
  const _HomeDashboardData({
    required this.stats,
    required this.speciesOfTheDay,
    required this.isFallback,
  });
  const _HomeDashboardData.fallback()
    : stats = const AppStats(
        totalSpecies: 0,
        pendingSubmissions: 0,
        totalSightings: 0,
      ),
      speciesOfTheDay = null,
      isFallback = true;
  final AppStats stats;
  final SpeciesHighlight? speciesOfTheDay;
  final bool isFallback;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'stats': stats.toJson(),
    'speciesOfTheDay': speciesOfTheDay?.toJson(),
  };
  static _HomeDashboardData fromJson(Map<String, dynamic> json) =>
      _HomeDashboardData(
        stats: AppStats.fromJson(
          Map<String, dynamic>.from(
            json['stats'] as Map? ?? const <String, dynamic>{},
          ),
        ),
        speciesOfTheDay: json['speciesOfTheDay'] is Map
            ? SpeciesHighlight.fromJson(
                Map<String, dynamic>.from(json['speciesOfTheDay'] as Map),
              )
            : null,
        isFallback: false,
      );
}

class _ResearcherProfileScreen extends StatelessWidget {
  const _ResearcherProfileScreen({
    required this.authController,
    required this.fallbackName,
    required this.fallbackHandle,
    required this.notificationController,
  });
  final AppAuthController authController;
  final String fallbackName;
  final String fallbackHandle;
  final NotificationController notificationController;
  String _resolvedName() {
    final String fromUser = authController.user?.name.trim() ?? '';
    if (fromUser.isNotEmpty) return fromUser;
    final String fromFallback = fallbackName.trim();
    return fromFallback.isNotEmpty ? fromFallback : 'Researcher 1';
  }

  String _resolvedHandle() {
    final String username = authController.user?.username.trim() ?? '';
    if (username.isNotEmpty) {
      return username.startsWith('@') ? username : '@$username';
    }
    final String fromFallback = fallbackHandle.trim();
    if (fromFallback.isNotEmpty) {
      return fromFallback.startsWith('@') ? fromFallback : '@$fromFallback';
    }
    final String fallback = _resolvedName().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return fallback.isNotEmpty ? '@$fallback' : '@researcher1';
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => _EditProfileScreen(
          authController: authController,
          initialName: _resolvedName(),
          initialHandle: _resolvedHandle(),
          initialLocation:
              authController.user?.location.trim().isNotEmpty == true
              ? authController.user!.location
              : 'Mt. Busa, Kiamba, Sarangani Province',
        ),
        transitionsBuilder: (_, animation, _, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(fade),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _openSubmissions(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => const UploadsStatusScreen(),
        transitionsBuilder: (_, animation, _, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(fade),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _openDrafts(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => const UploadSpeciesDraftsScreen(),
        transitionsBuilder: (_, animation, _, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(fade),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await authController.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => WelcomeScreen(authController: authController),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _appBackgroundColor,
      body: AnimatedBuilder(
        animation: authController,
        builder: (BuildContext context, _) {
          final String name = _resolvedName();
          final String handle = _resolvedHandle();
          final String email = authController.user?.email ?? '';
          final String location =
              authController.user?.location.trim().isNotEmpty == true
              ? authController.user!.location
              : 'Mt. Busa, Sarangani';
          final String photoUrl =
              authController.user?.profilePhotoUrl.trim() ?? '';
          final String photoB64 =
              authController.user?.profilePhotoBase64.trim() ?? '';
          final String affiliation =
              authController.user?.affiliation.trim() ?? '';
          final String initials = name.trim().isNotEmpty
              ? name
                    .trim()
                    .split(' ')
                    .take(2)
                    .map((w) => w[0])
                    .join()
                    .toUpperCase()
              : 'R';
          return Column(
            children: [
              // Gradient header
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D530E), Color(0xFF2A8C2B)],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row
                        Row(
                          children: [
                            Text(
                              'Your Profile',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withAlpha(153),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => _openProfile(context),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(38),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit_outlined,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Avatar + info row
                        Row(
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(51),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withAlpha(89),
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: _buildProfileAvatarChild(
                                  profilePhotoUrl: photoUrl,
                                  profilePhotoBase64: photoB64,
                                  initials: initials,
                                  iconSize: 28,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      fontStyle: FontStyle.italic,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    handle,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withAlpha(166),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Location + email meta
                        const SizedBox(height: 14),
                        if (location.isNotEmpty)
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 13,
                                color: Colors.white.withAlpha(153),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withAlpha(179),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.mail_outline_rounded,
                                size: 13,
                                color: Colors.white.withAlpha(153),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withAlpha(179),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (affiliation.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.business_outlined,
                                size: 13,
                                color: Colors.white.withAlpha(153),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  affiliation,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withAlpha(179),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              // Scrollable content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  children: [
                    Text(
                      'ACCOUNT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: _mutedTextColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ProfileMenuItem(
                      icon: Icons.person_outline_rounded,
                      label: 'Edit Profile',
                      onTap: () => _openProfile(context),
                    ),
                    const SizedBox(height: 8),
                    ListenableBuilder(
                      listenable: notificationController,
                      builder: (BuildContext context, _) => _ProfileMenuItem(
                        icon: Icons.upload_file_outlined,
                        label: 'My Submissions',
                        iconColor: const Color(0xFF059669),
                        iconBg: const Color(0xFFD1FAE5),
                        badgeCount: notificationController.unreadCount,
                        onTap: () => _openSubmissions(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ProfileMenuItem(
                      icon: Icons.drafts_outlined,
                      label: 'My Drafts',
                      iconColor: _uploadPrimary,
                      iconBg: const Color(0xFFE8F5E3),
                      onTap: () => _openDrafts(context),
                    ),
                    const SizedBox(height: 20),
                    // Sign out button
                    GestureDetector(
                      onTap: () => _logout(context),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFEE2E2),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.logout_rounded,
                                color: Color(0xFFDC2626),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Sign Out',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        '🌺  BLOOM v1.0.0 · Mt. Busa Orchidaceae Conservation',
                        style: TextStyle(
                          fontSize: 11,
                          color: _mutedTextColor.withAlpha(153),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileOverlayPanel extends StatelessWidget {
  const _ProfileOverlayPanel({
    required this.authController,
    required this.fallbackName,
    required this.fallbackHandle,
    required this.notificationController,
  });
  final AppAuthController authController;
  final String fallbackName;
  final String fallbackHandle;
  final NotificationController notificationController;
  String _resolvedName() {
    final String fromUser = authController.user?.name.trim() ?? '';
    if (fromUser.isNotEmpty) return fromUser;
    final String fromFallback = fallbackName.trim();
    return fromFallback.isNotEmpty ? fromFallback : 'Researcher 1';
  }

  String _resolvedHandle() {
    final String username = authController.user?.username.trim() ?? '';
    if (username.isNotEmpty) {
      return username.startsWith('@') ? username : '@$username';
    }
    final String fromFallback = fallbackHandle.trim();
    if (fromFallback.isNotEmpty) {
      return fromFallback.startsWith('@') ? fromFallback : '@$fromFallback';
    }
    final String fallback = _resolvedName().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return fallback.isNotEmpty ? '@$fallback' : '@researcher1';
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => _EditProfileScreen(
          authController: authController,
          initialName: _resolvedName(),
          initialHandle: _resolvedHandle(),
          initialLocation:
              authController.user?.location.trim().isNotEmpty == true
              ? authController.user!.location
              : 'Mt. Busa, Kiamba, Sarangani Province',
        ),
        transitionsBuilder: (_, animation, _, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(fade),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _openSubmissions(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => const UploadsStatusScreen(),
        transitionsBuilder: (_, animation, _, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(fade),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _openDrafts(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => const UploadSpeciesDraftsScreen(),
        transitionsBuilder: (_, animation, _, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(fade),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await authController.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => WelcomeScreen(authController: authController),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Slide-in panel (80% width)
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.82,
          child: Material(
            color: _appBackgroundColor,
            child: AnimatedBuilder(
              animation: authController,
              builder: (BuildContext context, _) {
                final String name = _resolvedName();
                final String handle = _resolvedHandle();
                final String email = authController.user?.email ?? '';
                final String location =
                    authController.user?.location.trim().isNotEmpty == true
                    ? authController.user!.location
                    : 'Mt. Busa, Sarangani';
                final String photoUrl =
                    authController.user?.profilePhotoUrl.trim() ?? '';
                final String photoB64 =
                    authController.user?.profilePhotoBase64.trim() ?? '';
                final String affiliation =
                    authController.user?.affiliation.trim() ?? '';
                final String initials = name.trim().isNotEmpty
                    ? name
                          .trim()
                          .split(' ')
                          .take(2)
                          .map((w) => w[0])
                          .join()
                          .toUpperCase()
                    : 'R';
                return Column(
                  children: [
                    // Gradient header
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0D530E), Color(0xFF2A8C2B)],
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Edit button row
                              Row(
                                children: [
                                  Text(
                                    'Your Profile',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withAlpha(153),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () => _openProfile(context),
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withAlpha(38),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.edit_outlined,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Avatar + name
                              Row(
                                children: [
                                  Container(
                                    width: 76,
                                    height: 76,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(51),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withAlpha(89),
                                        width: 2,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: _buildProfileAvatarChild(
                                        profilePhotoUrl: photoUrl,
                                        profilePhotoBase64: photoB64,
                                        initials: initials,
                                        iconSize: 28,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            fontStyle: FontStyle.italic,
                                            height: 1.1,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          handle,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.white.withAlpha(166),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              if (location.isNotEmpty)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 13,
                                      color: Colors.white.withAlpha(153),
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        location,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withAlpha(179),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              if (email.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.mail_outline_rounded,
                                      size: 13,
                                      color: Colors.white.withAlpha(153),
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withAlpha(179),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (affiliation.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.business_outlined,
                                      size: 13,
                                      color: Colors.white.withAlpha(153),
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        affiliation,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withAlpha(179),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Scrollable menu
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                        children: [
                          Text(
                            'ACCOUNT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: _mutedTextColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _ProfileMenuItem(
                            icon: Icons.person_outline_rounded,
                            label: 'Edit Profile',
                            onTap: () => _openProfile(context),
                          ),
                          const SizedBox(height: 8),
                          ListenableBuilder(
                            listenable: notificationController,
                            builder: (BuildContext context, _) =>
                                _ProfileMenuItem(
                                  icon: Icons.upload_file_outlined,
                                  label: 'My Submissions',
                                  iconColor: const Color(0xFF059669),
                                  iconBg: const Color(0xFFD1FAE5),
                                  badgeCount:
                                      notificationController.unreadCount,
                                  onTap: () => _openSubmissions(context),
                                ),
                          ),
                          const SizedBox(height: 8),
                          _ProfileMenuItem(
                            icon: Icons.drafts_outlined,
                            label: 'My Drafts',
                            iconColor: _uploadPrimary,
                            iconBg: const Color(0xFFE8F5E3),
                            onTap: () => _openDrafts(context),
                          ),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () => _logout(context),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFFEE2E2),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.logout_rounded,
                                      color: Color(0xFFDC2626),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  const Expanded(
                                    child: Text(
                                      'Sign Out',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: Text(
                              '🌺  BLOOM v1.0.0 · Mt. Busa Orchidaceae Conservation',
                              style: TextStyle(
                                fontSize: 11,
                                color: _mutedTextColor.withAlpha(153),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        // Tap-to-dismiss area (right 18%)
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _EditProfileScreen extends StatefulWidget {
  const _EditProfileScreen({
    required this.authController,
    required this.initialName,
    required this.initialHandle,
    required this.initialLocation,
  });
  final AppAuthController authController;
  final String initialName;
  final String initialHandle;
  final String initialLocation;
  @override
  State<_EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<_EditProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _locationController;
  late final TextEditingController _affiliationController;
  // Newly picked photo (not yet uploaded)
  Uint8List? _pendingPhotoBytes;
  bool _isPickingImage = false;
  bool _isSaving = false;
  AppUser? get _user => widget.authController.user;
  String _initials(String name) {
    final String n = name.trim();
    if (n.isEmpty) return 'R';
    return n.split(' ').take(2).map((w) => w[0]).join().toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    final AppUser? user = _user;
    final String name = user?.name.trim().isNotEmpty == true
        ? user!.name
        : widget.initialName.trim();
    final String username = user?.username.trim().isNotEmpty == true
        ? user!.username
        : widget.initialHandle.trim().replaceFirst(RegExp(r'^@+'), '');
    final String location = user?.location.trim().isNotEmpty == true
        ? user!.location
        : widget.initialLocation.trim();
    _nameController = TextEditingController(
      text: name.isNotEmpty ? name : 'Researcher 1',
    );
    _usernameController = TextEditingController(
      text: username.isNotEmpty ? username : 'researcher1',
    );
    _locationController = TextEditingController(
      text: location.isNotEmpty ? location : 'Mt. Busa',
    );
    _affiliationController = TextEditingController(
      text: user?.affiliation.trim() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _locationController.dispose();
    _affiliationController.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePhoto() async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 800,
      );
      if (file == null || !mounted) return;
      final Uint8List bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _pendingPhotoBytes = bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open gallery.')));
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<String?> _uploadPhoto(Uint8List bytes) async {
    final String? uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return null;
    final String path = 'profile_photos/$uid.jpg';
    await Supabase.instance.client.storage
        .from(kStorageBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    return Supabase.instance.client.storage
        .from(kStorageBucket)
        .getPublicUrl(path);
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;
    final String name = _nameController.text.trim();
    final String username = _usernameController.text.trim().replaceFirst(
      RegExp(r'^@+'),
      '',
    );
    final String location = _locationController.text.trim();
    if (name.isEmpty || username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and username are required.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    try {
      String? photoUrl;
      if (_pendingPhotoBytes != null) {
        photoUrl = await _uploadPhoto(_pendingPhotoBytes!);
      }
      await widget.authController.updateProfile(
        name: name,
        username: username,
        location: location,
        affiliation: _affiliationController.text.trim(),
        profilePhotoUrl: photoUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully.'),
          backgroundColor: Color(0xFF0C4C0D),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildAvatar() {
    final String photoUrl = _user?.profilePhotoUrl.trim() ?? '';
    final String photoB64 = _user?.profilePhotoBase64.trim() ?? '';
    final String ini = _initials(_nameController.text);
    return GestureDetector(
      onTap: _isPickingImage || _isSaving ? null : _pickProfilePhoto,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(38),
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: ClipOval(
              child: _pendingPhotoBytes != null
                  ? Image.memory(
                      _pendingPhotoBytes!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    )
                  : _buildProfileAvatarChild(
                      profilePhotoUrl: photoUrl,
                      profilePhotoBase64: photoB64,
                      initials: ini,
                      iconSize: 38,
                    ),
            ),
          ),
          if (_isPickingImage)
            Container(
              width: 104,
              height: 104,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x66000000),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF0C4C0D), width: 2),
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              size: 16,
              color: Color(0xFF0C4C0D),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco({
    required String label,
    required IconData icon,
    bool readOnly = false,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: _primaryColor.withAlpha(180),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(icon, color: _primaryColor, size: 20),
      filled: true,
      fillColor: readOnly ? _surfaceSoftColor.withAlpha(120) : _surfaceColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _surfaceOutlineColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _surfaceOutlineColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0C4C0D), width: 1.6),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _surfaceOutlineColor.withAlpha(100)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String email = _user?.email ?? '';
    return Scaffold(
      backgroundColor: _appBackgroundColor,
      body: Column(
        children: [
          // ── Green gradient header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFF0D530E), Color(0xFF2A8C2B)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                child: Column(
                  children: [
                    // Back + title
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(38),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Edit Profile',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Avatar
                    _buildAvatar(),
                    const SizedBox(height: 10),
                    Text(
                      'Tap photo to change',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withAlpha(178),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
          // ── Form
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Personal info card
                  Container(
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _surfaceOutlineColor),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x0A0D530E),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personal Information',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _mutedTextColor,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _nameController,
                          enabled: !_isSaving,
                          textCapitalization: TextCapitalization.words,
                          style: TextStyle(
                            fontSize: 15,
                            color: _textColor,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: _inputDeco(
                            label: 'Full Name',
                            icon: Icons.person_rounded,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _usernameController,
                          enabled: !_isSaving,
                          style: TextStyle(
                            fontSize: 15,
                            color: _textColor,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: _inputDeco(
                            label: 'Username',
                            icon: Icons.alternate_email_rounded,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _locationController,
                          enabled: !_isSaving,
                          textCapitalization: TextCapitalization.words,
                          style: TextStyle(
                            fontSize: 15,
                            color: _textColor,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: _inputDeco(
                            label: 'Location',
                            icon: Icons.location_on_outlined,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _affiliationController,
                          enabled: !_isSaving,
                          textCapitalization: TextCapitalization.words,
                          style: TextStyle(
                            fontSize: 15,
                            color: _textColor,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: _inputDeco(
                            label: 'Affiliation / Institution',
                            icon: Icons.business_outlined,
                          ),
                        ),
                        if (email.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 12),
                          TextField(
                            readOnly: true,
                            enabled: false,
                            controller: TextEditingController(text: email),
                            style: TextStyle(
                              fontSize: 15,
                              color: _mutedTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _inputDeco(
                              label: 'Email',
                              icon: Icons.mail_outline_rounded,
                              readOnly: true,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Save button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _primaryColor.withAlpha(120),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = _primaryColor,
    this.iconBg = _surfaceSoftStrongColor,
    this.badgeCount = 0,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final Color iconBg;
  final int badgeCount;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _surfaceOutlineColor, width: 1.5),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 18, color: iconColor),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: _accentColor,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : badgeCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _textColor,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _mutedTextColor,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    required this.authController,
    required this.notificationController,
    super.key,
  });
  final AppAuthController authController;
  final NotificationController notificationController;
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  bool _gridMode = false;
  late Future<List<CatalogSpecies>> _speciesFuture;
  final Set<int> _favorites = <int>{};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Object? _loadError;
  // Cached results — recomputed only when data or query changes, not every build.
  List<CatalogSpecies> _allSpecies = <CatalogSpecies>[];
  List<CatalogSpecies> _filteredSpecies = <CatalogSpecies>[];
  List<CatalogGroup> _filteredGroups = <CatalogGroup>[];
  @override
  void initState() {
    super.initState();
    _startLoad();
    _searchController.addListener(_onSearchChanged);
  }

  void _startLoad() {
    _loadError = null;
    _speciesFuture = _loadCatalogSpecies();
    _speciesFuture
        .then((List<CatalogSpecies> species) {
          if (mounted) {
            setState(() {
              _allSpecies = species;
              _recomputeFilter();
            });
          }
        })
        .catchError((Object e) {
          if (mounted) setState(() => _loadError = e);
        });
  }

  void _onSearchChanged() {
    final String q = _searchController.text.toLowerCase().trim();
    if (q == _searchQuery) return;
    setState(() {
      _searchQuery = q;
      _recomputeFilter();
    });
  }

  void _recomputeFilter() {
    if (_allSpecies.isEmpty) {
      _filteredSpecies = <CatalogSpecies>[];
      _filteredGroups = <CatalogGroup>[];
      return;
    }
    _filteredSpecies = _searchQuery.isEmpty
        ? _allSpecies
        : _allSpecies
              .where(
                (CatalogSpecies s) =>
                    s.scientificName.toLowerCase().contains(_searchQuery) ||
                    s.commonName.toLowerCase().contains(_searchQuery) ||
                    s.genus.toLowerCase().contains(_searchQuery),
              )
              .toList(growable: false);
    _filteredGroups = _groupSpecies(_filteredSpecies);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<CatalogGroup> _groupSpecies(List<CatalogSpecies> allSpecies) {
    final Map<String, List<CatalogSpecies>> grouped =
        <String, List<CatalogSpecies>>{};
    for (final CatalogSpecies species in allSpecies) {
      final String key = species.genus.trim().isNotEmpty
          ? species.genus.trim()
          : species.scientificName.trim().split(RegExp(r'\s+')).first;
      grouped.putIfAbsent(key, () => <CatalogSpecies>[]).add(species);
    }
    final List<String> sortedKeys = grouped.keys.toList(
      growable: false,
    )..sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sortedKeys
        .map(
          (String key) => CatalogGroup(
            title: key,
            species: (grouped[key]!
              ..sort(
                (CatalogSpecies a, CatalogSpecies b) => a.scientificName
                    .toLowerCase()
                    .compareTo(b.scientificName.toLowerCase()),
              )),
          ),
        )
        .toList(growable: false);
  }

  static const String _catalogCacheKey = 'catalog_species';
  Future<List<CatalogSpecies>> _loadCatalogSpecies() async {
    try {
      final Map<String, String> sightingThumbs =
          await _loadLatestSightingThumbs();
      final List<dynamic> data = await Supabase.instance.client
          .from('orchids')
          .select(
            'orchid_id, sci_name, common_name, model_3d_url, genus(genus_name), biogeography(picture(*))',
          )
          .order('sci_name', ascending: true)
          .timeout(_kNetworkTimeout);
      final List<CatalogSpecies> species = data
          .whereType<Map>()
          .map((Map item) {
            final Map<String, dynamic> json = Map<String, dynamic>.from(item);
            final String scientificName = (json['sci_name'] ?? '')
                .toString()
                .trim();
            if (scientificName.isEmpty) return null;
            final dynamic genusData = json['genus'];
            final String genus = genusData is Map
                ? (genusData['genus_name'] ?? '').toString()
                : '';
            final String imageUrl = _orchidImageUrlFromJson(json);
            final String fallbackUrl =
                sightingThumbs[scientificName.toLowerCase()] ?? '';
            final String resolvedUrl = imageUrl.isNotEmpty
                ? imageUrl
                : fallbackUrl;
            final String model3dUrl = (json['model_3d_url'] ?? '')
                .toString()
                .trim();
            return CatalogSpecies(
              id: int.tryParse((json['orchid_id'] ?? '').toString()),
              scientificName: scientificName,
              commonName: (json['common_name'] ?? 'Common Name')
                  .toString()
                  .trim(),
              genus: genus,
              imageUrl: resolvedUrl.isNotEmpty ? resolvedUrl : null,
              model3dUrl: model3dUrl.isNotEmpty ? model3dUrl : null,
            );
          })
          .whereType<CatalogSpecies>()
          .toList(growable: false);
      unawaited(
        OfflineCache.save(
          _catalogCacheKey,
          species.map((CatalogSpecies s) => s.toJson()).toList(),
        ),
      );
      return species;
    } catch (e) {
      final List<CatalogSpecies>? cached = await _loadCachedSpecies(
        _catalogCacheKey,
      );
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<void> _openProfilePanel() async {
    final String profileName =
        widget.authController.user?.name.trim().isNotEmpty == true
        ? widget.authController.user!.name
        : 'Researcher 1';
    final String handleSource =
        widget.authController.user?.email.trim().isNotEmpty == true
        ? widget.authController.user!.email.split('@').first
        : profileName;
    final String normalizedHandle = handleSource.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    final String profileHandle = normalizedHandle.isNotEmpty
        ? '@$normalizedHandle'
        : '@researcher1';
    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, _, _) => _ProfileOverlayPanel(
        authController: widget.authController,
        fallbackName: profileName,
        fallbackHandle: profileHandle,
        notificationController: widget.notificationController,
      ),
      transitionBuilder: (ctx, animation, _, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
  }

  void _openSpeciesDetails(CatalogSpecies species) {
    final bool isPending =
        widget.authController.user?.isPendingVerification ?? false;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CatalogSpeciesDetailsScreen(species: species, isGuest: isPending),
      ),
    );
  }

  String _heroTagFor(CatalogSpecies species) {
    final String slug = species.scientificName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return 'catalog-species-${slug.isEmpty ? 'unknown' : slug}';
  }

  Widget _buildModeButton({
    required bool selected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF0D530E), _primaryGradientColor],
                )
              : null,
          color: selected ? null : _surfaceSoftColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  const BoxShadow(
                    color: Color(0x330D530E),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: selected ? Colors.white : _primaryColor,
        ),
      ),
    );
  }

  Widget _buildCatalogList(List<CatalogGroup> groups) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      children: [
        for (final CatalogGroup group in groups)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFD0E8CC)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x140D530E),
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 28,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF0D530E), Color(0xFF2A8C2B)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          group.title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF306D29),
                            height: 1.05,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final CatalogSpecies species in group.species)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _openSpeciesDetails(species),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  // Thumbnail
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: species.imageUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: species.imageUrl!,
                                            width: 56,
                                            height: 56,
                                            fit: BoxFit.cover,
                                            placeholder: (_, _) => Container(
                                              width: 56,
                                              height: 56,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE8F5E3),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                Icons.eco_outlined,
                                                color: Color(0xFF0D530E),
                                                size: 22,
                                              ),
                                            ),
                                            errorWidget: (_, _, _) => Container(
                                              width: 56,
                                              height: 56,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE8F5E3),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                Icons.eco_outlined,
                                                color: Color(0xFF0D530E),
                                                size: 22,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            width: 56,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE8F5E3),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.eco_outlined,
                                              color: Color(0xFF0D530E),
                                              size: 22,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Name info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          species.scientificName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF306D29),
                                            fontStyle: FontStyle.italic,
                                            fontWeight: FontWeight.w600,
                                            height: 1.2,
                                          ),
                                        ),
                                        if (species.commonName.isNotEmpty &&
                                            species.commonName.toLowerCase() !=
                                                'common name')
                                          Text(
                                            species.commonName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF0D530E),
                                              height: 1.2,
                                            ),
                                          ),
                                        if (species.localName != null &&
                                            species.localName!.isNotEmpty)
                                          Text(
                                            species.localName!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF5A8A54),
                                              fontStyle: FontStyle.italic,
                                              height: 1.2,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Heart button
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (species.id != null) {
                                          if (_favorites.contains(species.id)) {
                                            _favorites.remove(species.id);
                                          } else {
                                            _favorites.add(species.id!);
                                          }
                                        }
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(
                                        species.id != null &&
                                                _favorites.contains(species.id)
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        size: 20,
                                        color:
                                            species.id != null &&
                                                _favorites.contains(species.id)
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFF0D530E),
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFF0D530E),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCatalogGrid(List<CatalogSpecies> allSpecies) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      itemCount: allSpecies.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (BuildContext context, int index) {
        final CatalogSpecies item = allSpecies[index];
        final bool isFav = item.id != null && _favorites.contains(item.id);
        return GestureDetector(
          onTap: () => _openSpeciesDetails(item),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFD0E8CC)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x140D530E),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image area with overlays
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image
                      item.imageUrl != null
                          ? Hero(
                              tag: _heroTagFor(item),
                              child: CachedNetworkImage(
                                imageUrl: item.imageUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                placeholder: (_, _) => Container(
                                  color: const Color(0xFFE8F5E3),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.eco_outlined,
                                    color: Color(0xFF0D530E),
                                    size: 32,
                                  ),
                                ),
                                errorWidget: (_, _, _) => Container(
                                  color: const Color(0xFFE8F5E3),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.eco_outlined,
                                    color: Color(0xFF0D530E),
                                    size: 32,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: const Color(0xFFE8F5E3),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.eco_outlined,
                                color: Color(0xFF0D530E),
                                size: 32,
                              ),
                            ),
                      // Heart button top-right
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (item.id != null) {
                                if (_favorites.contains(item.id)) {
                                  _favorites.remove(item.id);
                                } else {
                                  _favorites.add(item.id!);
                                }
                              }
                            });
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x22000000),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              isFav
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 16,
                              color: isFav
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF0D530E),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Name section
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.scientificName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF306D29),
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      if (item.commonName.isNotEmpty &&
                          item.commonName.toLowerCase() != 'common name') ...[
                        const SizedBox(height: 2),
                        Text(
                          item.commonName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF0D530E),
                            height: 1.2,
                          ),
                        ),
                      ],
                      if (item.localName != null &&
                          item.localName!.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          item.localName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF5A8A54),
                            fontStyle: FontStyle.italic,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _appBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: Colors.transparent,
                child: InkResponse(
                  onTap: _openProfilePanel,
                  radius: 28,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: _lineColor),
                    ),
                    child: const Icon(
                      Icons.sentiment_satisfied_alt_rounded,
                      color: _primaryColor,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Orchid Catalog',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  color: _textColor,
                  letterSpacing: -0.5,
                  height: 0.95,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: _lineColor, width: 1),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModeButton(
                      selected: !_gridMode,
                      icon: Icons.view_headline_rounded,
                      onTap: () => setState(() => _gridMode = false),
                    ),
                    _buildModeButton(
                      selected: _gridMode,
                      icon: Icons.grid_view_rounded,
                      onTap: () => setState(() => _gridMode = true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 14, color: _primarySoftColor),
                decoration: InputDecoration(
                  hintText: 'Search orchids by name or genus...',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: _hintTextColor,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: _primaryColor,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () => setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          }),
                          child: const Icon(
                            Icons.close_rounded,
                            color: _primaryColor,
                            size: 18,
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: _surfaceSoftColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: _surfaceOutlineColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: _surfaceOutlineColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: _primaryColor, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_allSpecies.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.eco_rounded,
                        size: 13,
                        color: Color(0xFF0D530E),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${_allSpecies.length} orchid${_allSpecies.length == 1 ? '' : 's'} recorded',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0D530E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_searchQuery.isNotEmpty) ...[
                        const Text(
                          ' · ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                        Text(
                          '${_filteredSpecies.length} matching',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              Expanded(
                child: FutureBuilder<List<CatalogSpecies>>(
                  future: _speciesFuture,
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<List<CatalogSpecies>> snapshot,
                      ) {
                        if (snapshot.connectionState != ConnectionState.done &&
                            _allSpecies.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: _primaryColor,
                            ),
                          );
                        }
                        if (_loadError != null && _allSpecies.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.cloud_off_rounded,
                                  size: 52,
                                  color: Color(0xFF0D530E),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Could not load orchid catalog.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF0D530E),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _loadError.toString(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _mutedTextColor,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextButton.icon(
                                  onPressed: () => setState(_startLoad),
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    color: _primaryColor,
                                  ),
                                  label: const Text(
                                    'Retry',
                                    style: TextStyle(color: _primaryColor),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        final List<CatalogSpecies> filtered =
                            _filteredSpecies.isNotEmpty ||
                                _allSpecies.isNotEmpty
                            ? _filteredSpecies
                            : (snapshot.data ?? const <CatalogSpecies>[]);
                        final List<CatalogGroup> groups =
                            _filteredGroups.isNotEmpty
                            ? _filteredGroups
                            : _groupSpecies(filtered);
                        if (filtered.isEmpty && _searchQuery.isNotEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.search_off_rounded,
                                  size: 52,
                                  color: Color(0xFFD0E8CC),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'No orchids found for\n"$_searchQuery"',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF0D530E),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                                final Animation<Offset> slide =
                                    Tween<Offset>(
                                      begin: const Offset(0.04, 0),
                                      end: Offset.zero,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeOutCubic,
                                      ),
                                    );
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: slide,
                                    child: child,
                                  ),
                                );
                              },
                          child: _gridMode
                              ? KeyedSubtree(
                                  key: const ValueKey<String>('catalog-grid'),
                                  child: _buildCatalogGrid(filtered),
                                )
                              : KeyedSubtree(
                                  key: const ValueKey<String>('catalog-list'),
                                  child: _buildCatalogList(groups),
                                ),
                        );
                      },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Normalizes a raw endemic_to_philippines DB/JSON value (a bool, or a
// string like "true"/"yes"/"unknown") into the tri-state 'Yes' / 'No' /
// 'Unknown' / '' (unset) used throughout the app's UI, matching the web
// dashboard's Endemic to the Philippines field.
String normalizeEndemicFlag(dynamic raw) {
  if (raw == true) return 'Yes';
  if (raw == false) return 'No';
  final String s = (raw ?? '').toString().trim().toLowerCase();
  if (s.isEmpty) return '';
  if (s == 'true' || s == 'yes' || s == '1') return 'Yes';
  if (s == 'false' || s == 'no' || s == '0') return 'No';
  if (s == 'unknown') return 'Unknown';
  return '';
}

class _SightingTeamMember {
  const _SightingTeamMember(this.name, this.role);
  final String name;
  final String role;
}

class _SightingTeam {
  const _SightingTeam(this.date, this.members);
  final String date;
  final List<_SightingTeamMember> members;
}

class _SpeciesSighting {
  const _SpeciesSighting({
    required this.date,
    required this.location,
    this.latitude,
    this.longitude,
    this.elevationMeters,
    // observation
    this.observationTime = '',
    this.collectionMethod = '',
    this.observationType = '',
    this.voucherCollected = '',
    // location (non-coordinate)
    this.province = '',
    this.municipality = '',
    this.specificSiteZone = '',
    this.specificSite = '',
    // habitat / environment
    this.habitatType = '',
    this.microhabitat = '',
    this.growthSubstrate = '',
    this.hostTreeSpecies = '',
    this.hostTreeDiameter = '',
    this.canopyCover = '',
    this.lightExposure = '',
    this.soilType = '',
    this.nearbyWaterSource = '',
    // taxonomy
    this.localNames = '',
    this.commonNames = '',
    this.endemicToPhilippines = '',
    this.identificationConfidence = '',
    // plant structure
    this.plantHeight = '',
    this.pseudobulbPresent = '',
    this.stemLength = '',
    this.rootLength = '',
    // leaves
    this.leafShape = '',
    this.leafLength = '',
    this.leafWidth = '',
    this.leafTexture = '',
    this.leafArrangement = '',
    this.numberOfLeaves = '',
    // flowers
    this.flowerColor = '',
    this.floweringSeason = '',
    this.numberOfFlowers = '',
    this.flowerDiameter = '',
    this.inflorescenceType = '',
    this.petalCharacteristics = '',
    this.sepalCharacteristics = '',
    this.labellumDescription = '',
    this.fragrance = '',
    this.bloomingStage = '',
    // fruit / seeds
    this.fruitPresent = '',
    this.fruitType = '',
    this.seedCapsuleCondition = '',
    // population / conservation
    this.lifeStage = '',
    this.phenology = '',
    this.populationCount,
    this.populationStatus = '',
    this.threatLevel = '',
    this.threatTypes = '',
    // species value
    this.ethnobotanicalImportance = '',
    this.aestheticAppeal = '',
    this.cultivation = '',
    this.rarity = '',
    this.culturalImportance = '',
    // research
    this.institution = '',
    this.researcherName = '',
    this.teamMembers = const <_SightingTeamMember>[],
    this.researcherNotes = '',
    this.unusualObservations = '',
    // media / study
    this.imageUrl = '',
    this.closeupFlowerUrl = '',
    this.habitatPhotoUrl = '',
    this.studyTitle = '',
    this.studyLink = '',
  });
  final String date;
  final String location;
  final double? latitude;
  final double? longitude;
  final double? elevationMeters;
  // observation
  final String observationTime;
  final String collectionMethod;
  final String observationType;
  final String voucherCollected;
  // location
  final String province;
  final String municipality;
  final String specificSiteZone;
  final String specificSite;
  // habitat
  final String habitatType;
  final String microhabitat;
  final String growthSubstrate;
  final String hostTreeSpecies;
  final String hostTreeDiameter;
  final String canopyCover;
  final String lightExposure;
  final String soilType;
  final String nearbyWaterSource;
  // taxonomy
  final String localNames;
  final String commonNames;
  final String endemicToPhilippines;
  final String identificationConfidence;
  // plant structure
  final String plantHeight;
  final String pseudobulbPresent;
  final String stemLength;
  final String rootLength;
  // leaves
  final String leafShape;
  final String leafLength;
  final String leafWidth;
  final String leafTexture;
  final String leafArrangement;
  final String numberOfLeaves;
  // flowers
  final String flowerColor;
  final String floweringSeason;
  final String numberOfFlowers;
  final String flowerDiameter;
  final String inflorescenceType;
  final String petalCharacteristics;
  final String sepalCharacteristics;
  final String labellumDescription;
  final String fragrance;
  final String bloomingStage;
  // fruit / seeds
  final String fruitPresent;
  final String fruitType;
  final String seedCapsuleCondition;
  // population / conservation
  final String lifeStage;
  final String phenology;
  final int? populationCount;
  final String populationStatus;
  final String threatLevel;
  final String threatTypes;
  // species value
  final String ethnobotanicalImportance;
  final String aestheticAppeal;
  final String cultivation;
  final String rarity;
  final String culturalImportance;
  // research
  final String institution;
  final String researcherName;
  final List<_SightingTeamMember> teamMembers;
  final String researcherNotes;
  final String unusualObservations;
  // media / study
  final String imageUrl;
  final String closeupFlowerUrl;
  final String habitatPhotoUrl;
  final String studyTitle;
  final String studyLink;
  LatLng? get latLng {
    if (latitude == null || longitude == null) return null;
    if (!latitude!.isFinite || !longitude!.isFinite) return null;
    if (latitude == 0.0 && longitude == 0.0) return null;
    return LatLng(latitude!, longitude!);
  }
}

class CatalogSpeciesDetailsScreen extends StatefulWidget {
  const CatalogSpeciesDetailsScreen({
    required this.species,
    this.isGuest = false,
    super.key,
  });
  final CatalogSpecies species;
  final bool isGuest;
  @override
  State<CatalogSpeciesDetailsScreen> createState() =>
      _CatalogSpeciesDetailsScreenState();
}

class _CatalogSpeciesDetailsScreenState
    extends State<CatalogSpeciesDetailsScreen> {
  int _selectedTab = 0;
  int _tappedPinIndex = -1;
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _tabSectionKey = GlobalKey();
  List<_SpeciesSighting> _sightings = const <_SpeciesSighting>[];
  bool _loadingSightings = true;
  List<MapTrail> _trails = const <MapTrail>[];
  List<String> get _scientificParts {
    return widget.species.scientificName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);
  }

  String get _genus {
    if (_scientificParts.isEmpty) {
      return 'Unknown';
    }
    return _scientificParts.first;
  }

  String get _speciesEpithet {
    if (_scientificParts.length <= 1) {
      return widget.species.scientificName;
    }
    return _scientificParts.sublist(1).join(' ');
  }

  // The submitted, DENR-approved sighting record backing the top-level
  // Species Information card — prefers the tapped pin, else the first
  // loaded sighting, so this card always agrees with the Taxonomy &
  // Identification tab instead of relying on the stale catalog-list
  // aggregate fields.
  _SpeciesSighting? get _primarySighting {
    if (_tappedPinIndex >= 0 && _tappedPinIndex < _sightings.length) {
      return _sightings[_tappedPinIndex];
    }
    if (_sightings.isNotEmpty) {
      return _sightings.first;
    }
    return null;
  }

  String get _normalizedCommonName {
    final String fromSighting = _primarySighting?.commonNames.trim() ?? '';
    final String commonName = fromSighting.isNotEmpty
        ? fromSighting
        : widget.species.commonName.trim();
    if (commonName.toLowerCase() == 'common name' || commonName.isEmpty) {
      return '';
    }
    return commonName;
  }

  String get _detailedCommonName {
    if (_normalizedCommonName.isEmpty) {
      return '-';
    }
    if (_normalizedCommonName.toLowerCase() == 'waling-waling') {
      return 'Waling-waling\nSander\'s Vanda';
    }
    return _normalizedCommonName;
  }

  String get _endemicity {
    final String raw = _primarySighting?.endemicToPhilippines.trim() ?? '';
    switch (raw.toLowerCase()) {
      case 'yes':
        return 'Endemic to the Philippines';
      case 'no':
        return 'Not endemic to the Philippines';
      case 'unknown':
        return 'Endemicity unknown';
      default:
        return '-';
    }
  }

  String get _seedSlug {
    final String slug = widget.species.scientificName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) {
      return 'orchid';
    }
    return slug;
  }

  String get _heroTag => 'catalog-species-$_seedSlug';
  String get _localName {
    final String fromSighting = _primarySighting?.localNames.trim() ?? '';
    if (fromSighting.isNotEmpty) {
      return fromSighting;
    }
    if (widget.species.localName != null &&
        widget.species.localName!.isNotEmpty) {
      return widget.species.localName!;
    }
    return '-';
  }

  List<LatLng> get _sightingPins => _sightings
      .map((s) => s.latLng)
      .whereType<LatLng>()
      .toList(growable: false);
  // ── New detail screen helpers
  Widget _detailInfoRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Color(0xFF0D530E),
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Color(0xFF082809),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF5FAF0),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: Color(0xFF082809),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, IconData icon, String label) {
    final bool selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF0D530E), Color(0xFF2A8C2B)],
                  )
                : null,
            color: selected ? null : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? Colors.transparent : const Color(0xFFD0E8CC),
            ),
            boxShadow: selected
                ? [
                    const BoxShadow(
                      color: Color(0x330D530E),
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? Colors.white : const Color(0xFF0D530E),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF0D530E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeciesValueContent() {
    if (_tappedPinIndex < 0 || _tappedPinIndex >= _sightings.length) {
      return const SizedBox.shrink();
    }
    final _SpeciesSighting s = _sightings[_tappedPinIndex];
    Widget infoRow(IconData icon, String label, String value) {
      final bool isBlank = value.trim().isEmpty;
      final String display = isBlank ? '-' : value;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF2A8C2B)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF0D530E),
                    ),
                  ),
                  Text(
                    display,
                    style: TextStyle(
                      fontSize: 14,
                      color: isBlank
                          ? const Color(0xFF9AA6A0)
                          : const Color(0xFF082809),
                      fontWeight: isBlank
                          ? FontWeight.w400
                          : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget divider() => const Divider(height: 1, color: Color(0xFFD0E8CC));
    List<Widget> rows(List<(IconData, String, String)> items) {
      if (items.isEmpty) return [];
      final out = <Widget>[];
      for (int i = 0; i < items.length; i++) {
        if (i > 0) out.add(divider());
        out.add(infoRow(items[i].$1, items[i].$2, items[i].$3));
      }
      return out;
    }

    final String conservationStatus = s.threatLevel.trim().isEmpty
        ? '-'
        : s.threatLevel.trim();
    final String sightingCount = _sightings.length == 1
        ? 'Recorded 1 time in the wild'
        : 'Recorded ${_sightings.length} times in the wild';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Conservation status banner
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D530E), Color(0xFF2A8C2B)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x400D530E),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Conservation Status',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                conservationStatus,
                style: const TextStyle(
                  fontSize: 26,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sightingCount,
                style: const TextStyle(fontSize: 12, color: Color(0xFFE7E1B1)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Taxonomy / identification
        _detailSectionCard(
          title: 'Taxonomy & Identification',
          children: rows([
            (Icons.label_rounded, 'Local Name(s)', s.localNames),
            (Icons.translate_rounded, 'Common Name(s)', s.commonNames),
            (
              Icons.flag_rounded,
              'Endemic to Philippines',
              s.endemicToPhilippines,
            ),
            (
              Icons.verified_rounded,
              'Identification Confidence',
              s.identificationConfidence,
            ),
          ]),
        ),
        // Plant structure
        const SizedBox(height: 12),
        _detailSectionCard(
          title: 'Plant Structure',
          children: rows([
            (Icons.height_rounded, 'Plant Height', s.plantHeight),
            (Icons.circle_outlined, 'Pseudobulb Present', s.pseudobulbPresent),
            (Icons.straighten_rounded, 'Stem Length', s.stemLength),
            (Icons.linear_scale_rounded, 'Root Length', s.rootLength),
          ]),
        ),
        // Leaves
        const SizedBox(height: 12),
        _detailSectionCard(
          title: 'Leaf Characteristics',
          children: rows([
            (Icons.grass_rounded, 'Leaf Shape / Type', s.leafShape),
            (Icons.straighten_rounded, 'Leaf Length', s.leafLength),
            (Icons.swap_horiz_rounded, 'Leaf Width', s.leafWidth),
            (Icons.texture_rounded, 'Leaf Texture', s.leafTexture),
            (
              Icons.format_list_bulleted_rounded,
              'Leaf Arrangement',
              s.leafArrangement,
            ),
            (Icons.tag_rounded, 'Number of Leaves', s.numberOfLeaves),
          ]),
        ),
        // Flowers
        const SizedBox(height: 12),
        _detailSectionCard(
          title: 'Flower Characteristics',
          children: rows([
            (Icons.local_florist_rounded, 'Flower Color', s.flowerColor),
            (
              Icons.calendar_month_rounded,
              'Flowering Season',
              s.floweringSeason,
            ),
            (Icons.tag_rounded, 'Number of Flowers', s.numberOfFlowers),
            (Icons.circle_rounded, 'Flower Diameter', s.flowerDiameter),
            (
              Icons.account_tree_rounded,
              'Inflorescence Type',
              s.inflorescenceType,
            ),
            (
              Icons.spa_rounded,
              'Petal Characteristics',
              s.petalCharacteristics,
            ),
            (
              Icons.spa_outlined,
              'Sepal Characteristics',
              s.sepalCharacteristics,
            ),
            (Icons.star_rounded, 'Labellum Description', s.labellumDescription),
            (Icons.air_rounded, 'Fragrance', s.fragrance),
            (Icons.eco_rounded, 'Blooming Stage', s.bloomingStage),
          ]),
        ),
        // Fruit / seeds
        const SizedBox(height: 12),
        _detailSectionCard(
          title: 'Fruit & Seeds',
          children: rows([
            (Icons.circle_rounded, 'Fruit Present', s.fruitPresent),
            (Icons.category_rounded, 'Fruit Type', s.fruitType),
            (
              Icons.grain_rounded,
              'Seed Capsule Condition',
              s.seedCapsuleCondition,
            ),
          ]),
        ),
        // Population & Threat
        const SizedBox(height: 12),
        _detailSectionCard(
          title: 'Population & Conservation',
          children: rows([
            (
              Icons.groups_rounded,
              'Population Count',
              s.populationCount != null
                  ? '${s.populationCount} individual${s.populationCount == 1 ? '' : 's'}'
                  : '',
            ),
            (Icons.eco_rounded, 'Life Stage', s.lifeStage),
            (Icons.calendar_month_rounded, 'Phenology', s.phenology),
            (Icons.bar_chart_rounded, 'Population Status', s.populationStatus),
            (Icons.warning_amber_rounded, 'Threat Level', s.threatLevel),
          ]),
        ),
        // Species value
        const SizedBox(height: 12),
        _detailSectionCard(
          title: 'Species Value & Importance',
          children: rows([
            (
              Icons.local_pharmacy_rounded,
              'Ethnobotanical Importance',
              s.ethnobotanicalImportance,
            ),
            (Icons.palette_rounded, 'Aesthetic Appeal', s.aestheticAppeal),
            (Icons.yard_rounded, 'Cultivation', s.cultivation),
            (Icons.people_rounded, 'Cultural Importance', s.culturalImportance),
          ]),
        ),
        // Researcher notes
        const SizedBox(height: 12),
        _detailSectionCard(
          title: 'Researcher Notes',
          children: [
            Text(
              s.researcherNotes.trim().isEmpty ? '-' : s.researcherNotes,
              style: TextStyle(
                fontSize: 14,
                color: s.researcherNotes.trim().isEmpty
                    ? const Color(0xFF9AA6A0)
                    : const Color(0xFF082809),
                height: 1.5,
              ),
            ),
          ],
        ),
        // Unusual observations
        const SizedBox(height: 12),
        _detailSectionCard(
          title: 'Unusual Observations',
          children: [
            Text(
              s.unusualObservations.trim().isEmpty
                  ? '-'
                  : s.unusualObservations,
              style: TextStyle(
                fontSize: 14,
                color: s.unusualObservations.trim().isEmpty
                    ? const Color(0xFF9AA6A0)
                    : const Color(0xFF082809),
                height: 1.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDatePill(String date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD0E8CC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 12,
            color: Color(0xFF0D530E),
          ),
          const SizedBox(width: 6),
          Text(
            date,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF082809),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSightingSheet() {
    final flowData = UploadSpeciesFlowData(
      scientificName: widget.species.scientificName,
      genus: widget.species.genus,
      commonNames:
          (widget.species.commonName.isNotEmpty &&
              widget.species.commonName.toLowerCase() != 'common name')
          ? [widget.species.commonName]
          : [],
      mountain: 'Mt. Busa',
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UploadSpeciesInformationScreen(flowData: flowData),
      ),
    );
  }

  Widget _buildSightingsContent() {
    if (_tappedPinIndex < 0 || _tappedPinIndex >= _sightings.length) {
      return const SizedBox.shrink();
    }
    final _SpeciesSighting s = _sightings[_tappedPinIndex];
    Widget infoRow(IconData icon, String label, String value) {
      final bool isBlank = value.trim().isEmpty;
      final String display = isBlank ? '-' : value;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF2A8C2B)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF0D530E),
                    ),
                  ),
                  Text(
                    display,
                    style: TextStyle(
                      fontSize: 14,
                      color: isBlank
                          ? const Color(0xFF9AA6A0)
                          : const Color(0xFF082809),
                      fontWeight: isBlank
                          ? FontWeight.w400
                          : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget divider() => const Divider(height: 1, color: Color(0xFFD0E8CC));
    List<Widget> rows(List<(IconData, String, String)> items) {
      if (items.isEmpty) return [];
      final out = <Widget>[];
      for (int i = 0; i < items.length; i++) {
        if (i > 0) out.add(divider());
        out.add(infoRow(items[i].$1, items[i].$2, items[i].$3));
      }
      return out;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recorded sighting + observation details
        _detailSectionCard(
          title: 'Recorded Sighting',
          children: [
            _buildDatePill(s.date),
            ...rows([
              (
                Icons.schedule_rounded,
                'Time of Observation',
                s.observationTime,
              ),
              (Icons.science_rounded, 'Collection Method', s.collectionMethod),
              (Icons.visibility_rounded, 'Observation Type', s.observationType),
              (
                Icons.inventory_2_rounded,
                'Voucher Specimen Collected',
                s.voucherCollected,
              ),
            ]),
          ],
        ),
        const SizedBox(height: 12),
        // Location — coordinates and elevation are withheld from the
        // public catalog for species-protection reasons.
        _detailSectionCard(
          title: 'Location',
          children: rows([
            (Icons.terrain_rounded, 'Mountain / Site', s.location),
            (Icons.map_rounded, 'Province', s.province),
            (Icons.location_city_rounded, 'Municipality', s.municipality),
            (Icons.layers_rounded, 'Altitude Zone', s.specificSiteZone),
            (Icons.pin_drop_rounded, 'Specific Site', s.specificSite),
          ]),
        ),
        const SizedBox(height: 12),
        _detailSectionCard(
          title: 'Habitat & Environment',
          children: rows([
            (Icons.forest_rounded, 'Habitat Type', s.habitatType),
            (Icons.grass_rounded, 'Microhabitat', s.microhabitat),
            (Icons.foundation_rounded, 'Growth Substrate', s.growthSubstrate),
            (Icons.park_rounded, 'Host Tree Species', s.hostTreeSpecies),
            (
              Icons.straighten_rounded,
              'Host Tree Diameter',
              s.hostTreeDiameter,
            ),
            (Icons.wb_cloudy_rounded, 'Canopy Cover', s.canopyCover),
            (Icons.wb_sunny_rounded, 'Light Exposure', s.lightExposure),
            (Icons.layers_rounded, 'Soil Type', s.soilType),
            (Icons.water_rounded, 'Nearby Water Source', s.nearbyWaterSource),
          ]),
        ),
        const SizedBox(height: 12),
        _detailSectionCard(
          title: 'Contributors',
          children: (() {
            final List<_SightingTeamMember> contributors =
                <_SightingTeamMember>[
                  if (s.researcherName.trim().isNotEmpty)
                    _SightingTeamMember(
                      s.researcherName.trim(),
                      'Head Researcher',
                    ),
                  ...s.teamMembers,
                ];
            return contributors.isNotEmpty
                ? <Widget>[_buildTeamCard(_SightingTeam(s.date, contributors))]
                : <Widget>[
                    const Text(
                      '-',
                      style: TextStyle(fontSize: 14, color: Color(0xFF9AA6A0)),
                    ),
                  ];
          })(),
        ),
      ],
    );
  }

  Widget _buildTeamCard(_SightingTeam team) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E3),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFF0D530E),
            child: Text(
              '${team.date} Sighting Team',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              children: [
                for (int j = 0; j < team.members.length; j++) ...[
                  if (j > 0) const Divider(height: 1, color: Color(0xFFD0E8CC)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                Color(0xFF0D530E),
                                Color(0xFF2A8C2B),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            team.members[j].name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            team.members[j].name,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF082809),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          team.members[j].role,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF0D530E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesContent() {
    if (_tappedPinIndex < 0 || _tappedPinIndex >= _sightings.length) {
      return const SizedBox.shrink();
    }
    final _SpeciesSighting s = _sightings[_tappedPinIndex];
    Widget imageCard(String label, String url) {
      final String resolved = url.isNotEmpty
          ? url
          : (label == 'Whole Plant' ? (widget.species.imageUrl ?? '') : '');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.photo_outlined,
                size: 14,
                color: Color(0xFF0D530E),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0D530E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: resolved.isNotEmpty
                    ? GestureDetector(
                        onTap: () => _openImageFullScreen(resolved, label),
                        child: CachedNetworkImage(
                          imageUrl: resolved,
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => _sightingImagePlaceholder(),
                          errorWidget: (_, _, _) => _sightingImagePlaceholder(),
                        ),
                      )
                    : _sightingImagePlaceholder(),
              ),
              if (resolved.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _openImageFullScreen(resolved, label),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.fullscreen_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    }

    final List<Widget> imageWidgets = <Widget>[];
    imageWidgets.add(imageCard('Whole Plant', s.imageUrl));
    if (s.closeupFlowerUrl.isNotEmpty) {
      imageWidgets.add(const SizedBox(height: 16));
      imageWidgets.add(imageCard('Close-up Flower', s.closeupFlowerUrl));
    }
    if (s.habitatPhotoUrl.isNotEmpty) {
      imageWidgets.add(const SizedBox(height: 16));
      imageWidgets.add(imageCard('Habitat', s.habitatPhotoUrl));
    }
    return _detailSectionCard(
      title: 'Sighting Images  ·  ${s.date}',
      children: imageWidgets,
    );
  }

  void _openImageFullScreen(String imageUrl, String label) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) =>
            _FullScreenImageViewer(imageUrl: imageUrl, label: label),
      ),
    );
  }

  Widget _sightingImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E3),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.eco_outlined, color: Color(0xFF0D530E), size: 36),
    );
  }

  Widget _buildRelatedStudyContent() {
    if (_tappedPinIndex < 0 || _tappedPinIndex >= _sightings.length) {
      return const SizedBox.shrink();
    }
    final _SpeciesSighting s = _sightings[_tappedPinIndex];
    Widget studyRow(
      IconData icon,
      String label,
      String value, {
      bool isLink = false,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF2A8C2B)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF0D530E),
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: isLink
                          ? const Color(0xFF1A73E8)
                          : (value == '-'
                                ? const Color(0xFF9AA6A0)
                                : const Color(0xFF082809)),
                      fontWeight: value == '-'
                          ? FontWeight.w400
                          : FontWeight.w600,
                      decoration: isLink ? TextDecoration.underline : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailSectionCard(
          title: 'Related Study',
          children: [
            studyRow(
              Icons.menu_book_outlined,
              'Study Title',
              s.studyTitle.trim().isEmpty ? '-' : s.studyTitle,
            ),
            const Divider(height: 1, color: Color(0xFFD0E8CC)),
            studyRow(
              Icons.link_rounded,
              'Study Link',
              s.studyLink.trim().isEmpty ? '-' : s.studyLink,
              isLink: s.studyLink.trim().isNotEmpty,
            ),
          ],
        ),
        // Researcher info as secondary context
        const SizedBox(height: 12),
        _detailSectionCard(
          title: 'Submitted By',
          children: [
            studyRow(
              Icons.person_outline_rounded,
              'Researcher',
              s.researcherName.trim().isEmpty ? '-' : s.researcherName,
            ),
            const Divider(height: 1, color: Color(0xFFD0E8CC)),
            studyRow(
              Icons.account_balance_outlined,
              'Institution',
              s.institution.trim().isEmpty ? '-' : s.institution,
            ),
          ],
        ),
      ],
    );
  }

  void _showModel3DDialog() {
    final String? modelUrl = widget.species.model3dUrl;
    if (modelUrl == null || modelUrl.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 420,
                  child: ModelViewer(
                    key: ValueKey<String>(modelUrl),
                    src: modelUrl,
                    alt: '3D model of ${widget.species.scientificName}',
                    autoRotate: true,
                    cameraControls: true,
                    backgroundColor: const Color(0xFFF5FAF0),
                  ),
                ),
              ),
              Positioned(
                top: -14,
                right: -14,
                child: GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF306D29),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Marker _buildPinMarker(LatLng pt, int index) {
    final bool isSelected = _tappedPinIndex == index;
    final String? imageUrl = widget.species.imageUrl;
    return Marker(
      point: pt,
      width: 44.0,
      height: 44.0,
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onTap: () => _onPinTapped(index),
        child: Container(
          width: isSelected ? 44 : 38,
          height: isSelected ? 44 : 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? const Color(0xFF6EE587) : Colors.white,
              width: isSelected ? 3 : 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: imageUrl != null && imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) =>
                        Image.asset('orchidpin.png', fit: BoxFit.cover),
                  )
                : Image.asset('orchidpin.png', fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogMapPreview() {
    final List<LatLng> pins = _sightingPins;
    final int count = pins.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x220D530E),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: double.infinity,
              height: 280,
              child: Stack(
                children: [
                  FlutterMap(
                    options: const MapOptions(
                      initialCenter: LatLng(6.090, 124.713),
                      initialZoom: 13.0,
                      minZoom: 10,
                      maxZoom: 19,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                        userAgentPackageName:
                            'com.example.flutter_application_1',
                        maxNativeZoom: 18,
                        keepBuffer: 2,
                      ),
                      if (!widget.isGuest && _trails.isNotEmpty)
                        PolylineLayer(
                          polylines: buildTrailGlowPolylines(
                            _trails,
                            scale: 0.6,
                          ),
                        ),
                      MarkerLayer(
                        markers: <Marker>[
                          for (int i = 0; i < pins.length; i++)
                            _buildPinMarker(pins[i], i),
                        ],
                      ),
                    ],
                  ),
                  // Fullscreen button
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _CatalogMapFullScreen(
                            scientificName: widget.species.scientificName,
                            pins: pins,
                            isGuest: widget.isGuest,
                            imageUrl: widget.species.imageUrl,
                          ),
                        ),
                      ),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x330D530E),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.fullscreen_rounded,
                          size: 22,
                          color: Color(0xFF0D530E),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _loadingSightings
                  ? Icons.hourglass_empty_rounded
                  : Icons.place_rounded,
              size: 13,
              color: const Color(0xFF0D530E),
            ),
            const SizedBox(width: 5),
            Text(
              _loadingSightings
                  ? 'Loading sightings…'
                  : '$count recorded sighting${count == 1 ? '' : 's'} · tap a pin to explore',
              style: const TextStyle(fontSize: 12, color: Color(0xFF0D530E)),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _loadSightingsFromDb();
    _loadTrails();
  }

  Future<void> _loadTrails() async {
    final List<MapTrail> trails = await MapTrailsCache.load();
    if (mounted) setState(() => _trails = trails);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  String get _sightingsCacheKey =>
      'species_sightings_${widget.species.scientificName.trim().toLowerCase()}';
  Future<void> _loadSightingsFromDb() async {
    List<dynamic> data;
    try {
      final SupabaseClient supabase = Supabase.instance.client;
      data = await supabase
          .from('species_sightings')
          .select(
            'observation_date, observation_time, collection_method, observation_type, voucher_collected, '
            'mountain(mountain_name), specific_site_zone, specific_site_other, latitude, longitude, '
            'elevation_meters, '
            'local_names, common_names, endemic_to_philippines, identification_confidence, '
            'researcher_notes, '
            'sighting_habitat(*), sighting_morphology(*), sighting_conservation(*), '
            'sighting_team_member(*), sighting_media(*, picture(*))',
          )
          .eq('scientific_name', widget.species.scientificName)
          .eq('review_status', 'approved')
          .order('observation_date', ascending: false)
          .timeout(_kNetworkTimeout);
      unawaited(
        OfflineCache.save(
          _sightingsCacheKey,
          data
              .whereType<Map>()
              .map((Map r) => Map<String, dynamic>.from(r))
              .toList(),
        ),
      );
    } catch (_) {
      final dynamic cached = await OfflineCache.load(_sightingsCacheKey);
      data = cached is List ? cached : const <dynamic>[];
    }
    try {
      const List<String> months = <String>[
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final List<_SpeciesSighting> loaded = <_SpeciesSighting>[];
      for (final dynamic row in data) {
        final Map<String, dynamic> r = Map<String, dynamic>.from(row as Map);
        String str(String k) => (r[k] ?? '').toString().trim();
        double? dbl(String k) =>
            r[k] == null ? null : double.tryParse(r[k].toString());
        // Parses a JSONB text array (or plain string) into "a, b, c"
        String jsonArr(String k) {
          final dynamic v = r[k];
          if (v == null) return '';
          if (v is List) {
            return v.map((e) => e.toString()).join(', ');
          }
          final String s = v.toString().trim();
          if (s.startsWith('[')) {
            try {
              final List<dynamic> list = jsonDecode(s) as List<dynamic>;
              return list.map((e) => e.toString()).join(', ');
            } catch (_) {}
          }
          return s;
        }

        // New-style rows (see submitNormalizedSighting) carry habitat/
        // morphology/conservation/team/media detail in joined sub-tables
        // instead of these flat columns — prefer the sub-table value and
        // fall back to the flat column for older rows.
        final Map<String, dynamic> habitat =
            (r['sighting_habitat'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
        final Map<String, dynamic> morphology =
            (r['sighting_morphology'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
        final Map<String, dynamic> conservation =
            (r['sighting_conservation'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
        final List<dynamic> teamMemberRows =
            (r['sighting_team_member'] as List?) ?? <dynamic>[];
        final List<dynamic> mediaRows =
            (r['sighting_media'] as List?) ?? <dynamic>[];
        final Map<String, dynamic>? mountainEmbed = r['mountain'] is Map
            ? (r['mountain'] as Map).cast<String, dynamic>()
            : null;
        String prefStr(
          String flatKey,
          Map<String, dynamic> sub,
          String subKey,
        ) {
          final dynamic v = sub[subKey];
          if (v != null) {
            final String s = v.toString().trim();
            if (s.isNotEmpty) return s;
          }
          return str(flatKey);
        }

        String prefNumStr(
          String flatKey,
          Map<String, dynamic> sub,
          String subKey,
        ) {
          final dynamic v = sub[subKey];
          if (v != null) {
            final String s = v.toString().trim();
            if (s.isNotEmpty && s != '0' && s != '0.0') return s;
          }
          return str(flatKey);
        }

        String prefBoolStr(
          String flatKey,
          Map<String, dynamic> sub,
          String subKey,
        ) {
          final dynamic v = sub[subKey];
          if (v is bool) return v ? 'Yes' : 'No';
          return str(flatKey);
        }

        String prefFirstListStr(
          String flatKey,
          Map<String, dynamic> sub,
          String subKey,
        ) {
          final dynamic v = sub[subKey];
          if (v is List && v.isNotEmpty)
            return v.map((e) => e.toString()).join(', ');
          return jsonArr(flatKey);
        }

        String mediaUrlFor(String category, String flatKey) {
          for (final dynamic m in mediaRows) {
            if (m is Map && m['media_category'] == category) {
              final dynamic pic = m['picture'];
              if (pic is Map) {
                final String path = (pic['file_path'] ?? '').toString().trim();
                if (path.isNotEmpty) return path;
              }
            }
          }
          return str(flatKey);
        }

        String date = str('observation_date');
        try {
          final DateTime d = DateTime.parse(date);
          date = '${months[d.month - 1]}. ${d.day}, ${d.year}';
        } catch (_) {}
        List<_SightingTeamMember> members = const <_SightingTeamMember>[];
        if (teamMemberRows.isNotEmpty) {
          members = teamMemberRows
              .whereType<Map>()
              .map(
                (Map e) => _SightingTeamMember(
                  (e['member_name'] ?? '').toString().trim(),
                  (e['member_role'] ?? '').toString().trim(),
                ),
              )
              .toList(growable: false);
        } else {
          final dynamic teamRaw = r['team_members'];
          try {
            List<dynamic> teamList;
            if (teamRaw is List) {
              teamList = teamRaw;
            } else if (teamRaw is String && teamRaw.trim().isNotEmpty) {
              teamList = jsonDecode(teamRaw) as List<dynamic>;
            } else {
              teamList = <dynamic>[];
            }
            members = teamList
                .map(
                  (dynamic e) => _SightingTeamMember(
                    (e['name'] ?? '').toString().trim(),
                    (e['role'] ?? '').toString().trim(),
                  ),
                )
                .toList(growable: false);
          } catch (_) {}
        }
        final double? elev = dbl('elevation_meters');
        final dynamic popRaw = r['population_count'];
        final int? populationCount = popRaw == null
            ? null
            : int.tryParse(popRaw.toString());
        final String endemicStr = normalizeEndemicFlag(
          r['endemic_to_philippines'],
        );
        final dynamic voucherRaw = r['voucher_collected'];
        final String voucherStr = voucherRaw == null
            ? ''
            : (voucherRaw == true ? 'Yes' : 'No');
        final String mountainLabel = (mountainEmbed?['mountain_name'] ?? '')
            .toString()
            .trim();
        loaded.add(
          _SpeciesSighting(
            date: date.isNotEmpty ? date : 'Unknown date',
            location: mountainLabel.isNotEmpty
                ? mountainLabel
                : 'Unknown location',
            latitude: dbl('latitude'),
            longitude: dbl('longitude'),
            elevationMeters: elev,
            // observation
            observationTime: str('observation_time'),
            collectionMethod: str('collection_method'),
            observationType: str('observation_type'),
            voucherCollected: voucherStr,
            // location
            province: str('province'),
            municipality: str('municipality'),
            specificSiteZone: str('specific_site_zone'),
            specificSite: str('specific_site_other'),
            // habitat
            habitatType: prefStr('habitat_type', habitat, 'habitat_type'),
            microhabitat: prefStr('microhabitat', habitat, 'microhabitat'),
            growthSubstrate: prefStr(
              'growth_substrate',
              habitat,
              'growth_substrate',
            ),
            hostTreeSpecies: prefStr(
              'host_tree_species',
              habitat,
              'host_tree_species',
            ),
            hostTreeDiameter: prefNumStr(
              'host_tree_diameter',
              habitat,
              'host_tree_dbh_cm',
            ),
            canopyCover: prefNumStr(
              'canopy_cover',
              habitat,
              'canopy_cover_percent',
            ),
            lightExposure: prefStr('light_exposure', habitat, 'light_exposure'),
            soilType: prefStr('soil_type', habitat, 'soil_type'),
            nearbyWaterSource: prefStr(
              'nearby_water_source',
              habitat,
              'nearby_water_source',
            ),
            // taxonomy
            localNames: jsonArr('local_names'),
            commonNames: jsonArr('common_names'),
            endemicToPhilippines: endemicStr,
            identificationConfidence: str('identification_confidence'),
            // plant structure
            plantHeight: prefNumStr(
              'plant_height',
              morphology,
              'plant_height_cm',
            ),
            pseudobulbPresent: prefBoolStr(
              'pseudobulb_present',
              morphology,
              'pseudobulb_present',
            ),
            stemLength: prefNumStr('stem_length', morphology, 'stem_length_cm'),
            rootLength: prefNumStr('root_length', morphology, 'root_length_cm'),
            // leaves
            leafShape: prefStr('leaf_shape', morphology, 'leaf_shape'),
            leafLength: prefNumStr('leaf_length', morphology, 'leaf_length_cm'),
            leafWidth: prefNumStr('leaf_width', morphology, 'leaf_width_cm'),
            leafTexture: prefFirstListStr(
              'leaf_texture',
              morphology,
              'leaf_textures',
            ),
            leafArrangement: prefStr(
              'leaf_arrangement',
              morphology,
              'leaf_arrangement',
            ),
            numberOfLeaves: prefNumStr(
              'number_of_leaves',
              morphology,
              'leaf_count',
            ),
            // flowers
            flowerColor: prefStr('flower_color', morphology, 'flower_color'),
            floweringSeason: prefStr(
              'flowering_season',
              morphology,
              'flowering_season',
            ),
            numberOfFlowers: prefNumStr(
              'number_of_flowers',
              morphology,
              'flower_count',
            ),
            flowerDiameter: prefNumStr(
              'flower_diameter',
              morphology,
              'flower_diameter_cm',
            ),
            inflorescenceType: prefStr(
              'inflorescence_type',
              morphology,
              'inflorescence_type',
            ),
            petalCharacteristics: prefStr(
              'petal_characteristics',
              morphology,
              'petal_characteristics',
            ),
            sepalCharacteristics: prefStr(
              'sepal_characteristics',
              morphology,
              'sepal_characteristics',
            ),
            labellumDescription: prefStr(
              'labellum_description',
              morphology,
              'labellum_lip_description',
            ),
            fragrance: prefStr('fragrance', morphology, 'fragrance'),
            bloomingStage: prefStr(
              'blooming_stage',
              morphology,
              'blooming_stage',
            ),
            // fruit
            fruitPresent: prefBoolStr(
              'fruit_present',
              morphology,
              'fruit_present',
            ),
            fruitType: prefStr('fruit_type', morphology, 'fruit_type'),
            seedCapsuleCondition: prefStr(
              'seed_capsule_condition',
              morphology,
              'seed_capsule_condition',
            ),
            // population
            lifeStage: prefStr('life_stage', morphology, 'life_stage'),
            phenology: prefStr('phenology', morphology, 'phenology'),
            populationCount: populationCount,
            populationStatus: prefStr(
              'population_status',
              conservation,
              'population_status',
            ),
            threatLevel: prefStr('threat_level', conservation, 'threat_level'),
            threatTypes: prefFirstListStr(
              'threat_types',
              conservation,
              'threat_types',
            ),
            // species value
            ethnobotanicalImportance: str('ethnobotanical_importance'),
            aestheticAppeal: str('aesthetic_appeal'),
            cultivation: str('cultivation'),
            rarity: str('rarity'),
            culturalImportance: str('cultural_importance'),
            // research
            institution: str('institution'),
            researcherName: str('researcher_name'),
            teamMembers: members,
            researcherNotes: str('researcher_notes'),
            unusualObservations: str('unusual_observations'),
            // media
            imageUrl: mediaUrlFor('whole_plant', 'whole_plant_photo_path'),
            closeupFlowerUrl: mediaUrlFor(
              'closeup_flower',
              'closeup_flower_photo_path',
            ),
            habitatPhotoUrl: mediaUrlFor('habitat', 'habitat_photo_path'),
            studyTitle: str('study_title'),
            studyLink: str('study_link'),
          ),
        );
      }
      if (mounted) {
        setState(() {
          _sightings = loaded;
          _loadingSightings = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSightings = false);
    }
  }

  void _onPinTapped(int index) {
    setState(() => _tappedPinIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _tabSectionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          alignment: 0.0,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final String primaryImage = widget.species.imageUrl ?? '';
    return Scaffold(
      backgroundColor: _surfaceSoftColor,
      floatingActionButton: widget.isGuest
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddSightingSheet,
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_location_alt_rounded, size: 20),
              label: const Text(
                'Log Sighting',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _surfaceSoftColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: _surfaceOutlineColor),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        color: _primaryColor,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '... / Genus / $_genus / Species / ${widget.species.scientificName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: _primaryColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Scrollable body
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero image with gradient fade at bottom
                    Stack(
                      children: [
                        Hero(
                          tag: _heroTag,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(32),
                              bottomRight: Radius.circular(32),
                            ),
                            child: primaryImage.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: primaryImage,
                                    width: double.infinity,
                                    height: 240,
                                    fit: BoxFit.cover,
                                    placeholder: (_, _) => _heroFallback(),
                                    errorWidget: (_, _, _) => _heroFallback(),
                                  )
                                : _heroFallback(),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Color(0xF5F8F7FF), Colors.transparent],
                              ),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(32),
                                bottomRight: Radius.circular(32),
                              ),
                            ),
                          ),
                        ),
                        if ((widget.species.model3dUrl ?? '').isNotEmpty)
                          Positioned(
                            top: 14,
                            right: 14,
                            child: GestureDetector(
                              onTap: _showModel3DDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.view_in_ar_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'View 3D',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Name section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.species.scientificName,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF306D29),
                              height: 1.1,
                            ),
                          ),
                          if (_normalizedCommonName.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _normalizedCommonName,
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF0D530E),
                                height: 1.2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Species info card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _detailSectionCard(
                        title: 'Species Information',
                        children: [
                          _detailInfoRow(label: 'Family', value: 'Orchidaceae'),
                          const Divider(height: 1, color: _surfaceOutlineColor),
                          _detailInfoRow(label: 'Genus', value: _genus),
                          const Divider(height: 1, color: _surfaceOutlineColor),
                          _detailInfoRow(
                            label: 'Species',
                            value: _speciesEpithet,
                          ),
                          const Divider(height: 1, color: _surfaceOutlineColor),
                          _detailInfoRow(
                            label: 'Common Name',
                            value: _detailedCommonName,
                          ),
                          const Divider(height: 1, color: _surfaceOutlineColor),
                          _detailInfoRow(
                            label: 'Local Name',
                            value: _localName,
                          ),
                          const Divider(height: 1, color: Color(0xFFD0E8CC)),
                          _detailInfoRow(
                            label: 'Endemicity',
                            value: _endemicity,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Orchid pin map preview
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildCatalogMapPreview(),
                    ),
                    if (_tappedPinIndex >= 0) ...[
                      SizedBox(key: _tabSectionKey, height: 20),
                      // Selected sighting label
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.place_rounded,
                              size: 14,
                              color: Color(0xFF0D530E),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Sighting #${_tappedPinIndex + 1}  ·  ${_tappedPinIndex < _sightings.length ? _sightings[_tappedPinIndex].date : ''}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0D530E),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Tab selector
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            _buildTabButton(
                              0,
                              Icons.diamond_outlined,
                              'Species Value',
                            ),
                            const SizedBox(width: 8),
                            _buildTabButton(
                              1,
                              Icons.visibility_outlined,
                              'Sightings',
                            ),
                            const SizedBox(width: 8),
                            _buildTabButton(
                              2,
                              Icons.photo_library_outlined,
                              'Images',
                            ),
                            const SizedBox(width: 8),
                            _buildTabButton(
                              3,
                              Icons.menu_book_outlined,
                              'Related Study',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Tab content with fade+slide animation
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position:
                                        Tween<Offset>(
                                          begin: const Offset(0.04, 0),
                                          end: Offset.zero,
                                        ).animate(
                                          CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeOutCubic,
                                          ),
                                        ),
                                    child: child,
                                  ),
                                );
                              },
                          child: KeyedSubtree(
                            key: ValueKey<int>(_selectedTab),
                            child: switch (_selectedTab) {
                              0 => _buildSpeciesValueContent(),
                              1 => _buildSightingsContent(),
                              2 => _buildImagesContent(),
                              _ => _buildRelatedStudyContent(),
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroFallback() {
    return Container(
      width: double.infinity,
      height: 240,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D530E), Color(0xFF2A8C2B)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.eco_outlined, color: Colors.white54, size: 64),
    );
  }
}

// ── Sighting image full-screen viewer (pinch-to-zoom + X to close)
class _FullScreenImageViewer extends StatelessWidget {
  const _FullScreenImageViewer({required this.imageUrl, required this.label});
  final String imageUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, _) =>
                        const CircularProgressIndicator(color: Colors.white70),
                    errorWidget: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Catalog Map Full Screen
class _CatalogMapFullScreen extends StatefulWidget {
  const _CatalogMapFullScreen({
    required this.scientificName,
    required this.pins,
    this.isGuest = false,
    this.imageUrl,
  });
  final String scientificName;
  final List<LatLng> pins;
  final bool isGuest;
  final String? imageUrl;
  @override
  State<_CatalogMapFullScreen> createState() => _CatalogMapFullScreenState();
}

class _CatalogMapFullScreenState extends State<_CatalogMapFullScreen> {
  List<MapTrail> _trails = const <MapTrail>[];
  @override
  void initState() {
    super.initState();
    MapTrailsCache.load().then((List<MapTrail> trails) {
      if (mounted) setState(() => _trails = trails);
    });
  }

  Marker _buildPin(LatLng pt) {
    final String? imageUrl = widget.imageUrl;
    return Marker(
      point: pt,
      width: 44.0,
      height: 44.0,
      alignment: Alignment.bottomCenter,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ClipOval(
          child: imageUrl != null && imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) =>
                      Image.asset('orchidpin.png', fit: BoxFit.cover),
                )
              : Image.asset('orchidpin.png', fit: BoxFit.cover),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(6.090, 124.713),
              initialZoom: 13.0,
              minZoom: 10,
              maxZoom: 19,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.example.flutter_application_1',
                maxNativeZoom: 18,
                keepBuffer: 2,
              ),
              if (!widget.isGuest && _trails.isNotEmpty)
                PolylineLayer(polylines: buildTrailGlowPolylines(_trails)),
              MarkerLayer(
                markers: <Marker>[
                  for (final LatLng pt in widget.pins) _buildPin(pt),
                ],
              ),
            ],
          ),
          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 14,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x330D530E),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFF0D530E),
                  size: 22,
                ),
              ),
            ),
          ),
          // Species name chip at top
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 66,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x330D530E),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                widget.scientificName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF082809),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UploadScreen extends StatefulWidget {
  const UploadScreen({
    required this.authController,
    required this.notificationController,
    super.key,
  });
  final AppAuthController authController;
  final NotificationController notificationController;
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  int _draftCount = 0;
  @override
  void initState() {
    super.initState();
    _refreshDraftCount();
  }

  Future<void> _refreshDraftCount() async {
    final List<Object> results = await Future.wait(<Future<Object>>[
      UploadSpeciesDraftStore.loadDrafts(),
      _WebDraft.load(),
    ]);
    if (!mounted) return;
    final int appCount = (results[0] as List<UploadSpeciesFlowData>).length;
    final int webCount = (results[1] as List<_WebDraft>).length;
    setState(() {
      _draftCount = appCount + webCount;
    });
  }

  Future<void> _openProfilePanel(BuildContext context) async {
    final String profileName =
        widget.authController.user?.name.trim().isNotEmpty == true
        ? widget.authController.user!.name
        : 'Researcher 1';
    final String handleSource =
        widget.authController.user?.email.trim().isNotEmpty == true
        ? widget.authController.user!.email.split('@').first
        : profileName;
    final String normalizedHandle = handleSource.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    final String profileHandle = normalizedHandle.isNotEmpty
        ? '@$normalizedHandle'
        : '@researcher1';
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, _, _) => _ProfileOverlayPanel(
        authController: widget.authController,
        fallbackName: profileName,
        fallbackHandle: profileHandle,
        notificationController: widget.notificationController,
      ),
      transitionBuilder: (ctx, animation, _, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
  }

  Future<void> _openUploadNewSpecies(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const UploadSpeciesRequirementsScreen(),
      ),
    );
    await _refreshDraftCount();
  }

  Future<void> _openDraftUploads(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const UploadSpeciesDraftsScreen(),
      ),
    );
    await _refreshDraftCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _appBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: Colors.transparent,
                child: InkResponse(
                  onTap: () => _openProfilePanel(context),
                  radius: 28,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: _lineColor),
                    ),
                    child: const Icon(
                      Icons.sentiment_satisfied_alt_rounded,
                      color: _primaryColor,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Submit a Sighting',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  color: _textColor,
                  height: 0.95,
                ),
              ),
              const SizedBox(height: 24),
              _UploadActionRow(
                icon: Icons.add_rounded,
                label: 'New Submission',
                onTap: () => _openUploadNewSpecies(context),
              ),
              const SizedBox(height: 18),
              _UploadActionRow(
                icon: Icons.drafts_outlined,
                label: 'My Drafts',
                badgeCount: _draftCount,
                onTap: () => _openDraftUploads(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UploadSpeciesRequirementsScreen extends StatelessWidget {
  const UploadSpeciesRequirementsScreen({super.key});
  void _openSpeciesInformationForm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            UploadSpeciesInformationScreen(flowData: UploadSpeciesFlowData()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _appBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _UploadFormHeader(title: ' New Submission'),
              const SizedBox(height: 24),
              Text(
                'New Submission',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  color: _textColor,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Requirements:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Before you proceed, please note of\nthe following requirements.',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.25,
                          fontStyle: FontStyle.italic,
                          color: _mutedTextColor,
                        ),
                      ),
                      SizedBox(height: 22),
                      _RequirementBullet(text: 'Species Information'),
                      _RequirementBullet(text: 'Common Name', level: 1),
                      _RequirementBullet(text: 'Scientific Name', level: 1),
                      _RequirementBullet(text: 'Genus', level: 1),
                      _RequirementBullet(text: 'Endemicity', level: 1),
                      SizedBox(height: 10),
                      _RequirementBullet(text: 'Species Sightings'),
                      SizedBox(height: 10),
                      _RequirementBullet(text: 'Species Value'),
                      SizedBox(height: 10),
                      _RequirementBullet(
                        text: 'Images',
                        suffix: ' (at least 1, with photo credits)',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: OutlinedButton(
                  onPressed: () => _openSpeciesInformationForm(context),
                  style: _uploadActionButtonStyle(),
                  child: const Text(
                    'CONTINUE',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class AddSpeciesSightingsRequirementsScreen extends StatelessWidget {
  const AddSpeciesSightingsRequirementsScreen({super.key});
  void _openFindSpeciesScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AddSpeciesFindScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _appBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _UploadFormHeader(title: 'Add New Sightings'),
              const SizedBox(height: 24),
              Text(
                'Add New Sightings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Requirements:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Before you proceed, please note of\nthe following requirements.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.25,
                  fontStyle: FontStyle.italic,
                  color: _mutedTextColor,
                ),
              ),
              const SizedBox(height: 22),
              const _RequirementBullet(text: 'Sightings Information'),
              const SizedBox(height: 10),
              const _RequirementBullet(text: 'Image', suffix: ' (at least 1)'),
              const Spacer(),
              Center(
                child: OutlinedButton(
                  onPressed: () => _openFindSpeciesScreen(context),
                  style: _uploadActionButtonStyle(),
                  child: const Text(
                    'CONTINUE',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddSpeciesFindScreen extends StatefulWidget {
  const AddSpeciesFindScreen({super.key});
  @override
  State<AddSpeciesFindScreen> createState() => _AddSpeciesFindScreenState();
}

class _AddSpeciesFindScreenState extends State<AddSpeciesFindScreen> {
  final TextEditingController _familyController = TextEditingController();
  final TextEditingController _genusController = TextEditingController();
  final TextEditingController _scientificNameController =
      TextEditingController();
  // ── Species search autocomplete
  List<CatalogSpecies> _allSpecies = <CatalogSpecies>[];
  bool _isLoadingSpecies = false;
  String _selectedCommonName = '';
  void _autoFillScientificName() {
    final String genus = _genusController.text.trim();
    final String species = _familyController.text.trim();
    // Both fields set via the "Unknown" quick-fill button should collapse to
    // a single "Unknown" rather than concatenating into a garbage binomial
    // like "Unknown Unknown"/"Unknown unknown".
    if (genus.toLowerCase() == 'unknown' &&
        species.toLowerCase() == 'unknown') {
      _scientificNameController.text = 'Unknown';
      return;
    }
    final String autoFilled = <String>[
      genus,
      species,
    ].where((String s) => s.isNotEmpty).join(' ');
    _scientificNameController.text = autoFilled;
  }

  Future<void> _loadAllSpecies() async {
    if (!mounted) return;
    setState(() => _isLoadingSpecies = true);
    try {
      final List<dynamic> data = await Supabase.instance.client
          .from('orchids')
          .select('orchid_id, sci_name, common_name, genus(genus_name)')
          .order('sci_name', ascending: true);
      final List<CatalogSpecies> species = data
          .whereType<Map>()
          .map((Map item) {
            final Map<String, dynamic> json = Map<String, dynamic>.from(item);
            final String sci = (json['sci_name'] ?? '').toString().trim();
            if (sci.isEmpty) return null;
            final dynamic g = json['genus'];
            final String genus = g is Map
                ? (g['genus_name'] ?? '').toString()
                : '';
            return CatalogSpecies(
              id: int.tryParse((json['orchid_id'] ?? '').toString()),
              scientificName: sci,
              commonName: (json['common_name'] ?? '').toString().trim(),
              genus: genus,
            );
          })
          .whereType<CatalogSpecies>()
          .toList(growable: false);
      if (mounted) {
        setState(() {
          _allSpecies = species;
          _isLoadingSpecies = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSpecies = false);
    }
  }

  void _onSpeciesSelected(CatalogSpecies species) {
    setState(() {
      _selectedCommonName = species.commonName;
      _genusController.text = species.genus;
      // Extract species epithet (everything after the genus word)
      final String epithet = species.scientificName.contains(' ')
          ? species.scientificName
                .substring(species.scientificName.indexOf(' ') + 1)
                .trim()
          : '';
      _familyController.text = epithet;
      // Scientific name auto-fills via listener; set directly as fallback
      _scientificNameController.text = species.scientificName;
    });
  }

  @override
  void initState() {
    super.initState();
    _familyController.addListener(_autoFillScientificName);
    _genusController.addListener(_autoFillScientificName);
    _loadAllSpecies();
  }

  @override
  void dispose() {
    _familyController.removeListener(_autoFillScientificName);
    _genusController.removeListener(_autoFillScientificName);
    _familyController.dispose();
    _genusController.dispose();
    _scientificNameController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration() {
    return _uploadInputDecoration();
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
        color: _textColor,
      ),
    );
  }

  void _findSpecies() {
    final String family = _familyController.text.trim();
    final String genus = _genusController.text.trim();
    final String scientificName = _scientificNameController.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddSpeciesFindResultsScreen(
          family: family.isEmpty ? 'Orchidaceae' : family,
          genus: genus.isEmpty ? 'Unknown' : genus,
          scientificName: scientificName.isEmpty ? 'Unknown' : scientificName,
          commonName: _selectedCommonName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _appBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _UploadFormHeader(title: 'Add New Sightings'),
              const SizedBox(height: 24),
              Text(
                'Find Species',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Search by common or scientific name to autofill fields.',
                style: TextStyle(fontSize: 12, color: _mutedTextColor),
              ),
              const SizedBox(height: 12),
              // ── Autocomplete search
              LayoutBuilder(
                builder: (BuildContext ctx, BoxConstraints constraints) {
                  return Autocomplete<CatalogSpecies>(
                    optionsBuilder: (TextEditingValue value) {
                      if (value.text.trim().isEmpty || _allSpecies.isEmpty) {
                        return const Iterable<CatalogSpecies>.empty();
                      }
                      final String q = value.text.trim().toLowerCase();
                      return _allSpecies
                          .where(
                            (CatalogSpecies s) =>
                                s.scientificName.toLowerCase().contains(q) ||
                                s.commonName.toLowerCase().contains(q),
                          )
                          .take(8);
                    },
                    displayStringForOption: (CatalogSpecies s) =>
                        s.scientificName,
                    onSelected: _onSpeciesSelected,
                    fieldViewBuilder:
                        (
                          BuildContext ctx,
                          TextEditingController fieldCtrl,
                          FocusNode focusNode,
                          VoidCallback onSubmitted,
                        ) {
                          return TextField(
                            controller: fieldCtrl,
                            focusNode: focusNode,
                            style: TextStyle(fontSize: 14, color: _textColor),
                            decoration: InputDecoration(
                              hintText: _isLoadingSpecies
                                  ? 'Loading species…'
                                  : 'Search species…',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: _mutedTextColor,
                              ),
                              prefixIcon: _isLoadingSpecies
                                  ? const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _uploadPrimary,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.search_rounded,
                                      color: _uploadPrimary,
                                      size: 20,
                                    ),
                              suffixIcon: fieldCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.clear_rounded,
                                        size: 18,
                                        color: _uploadPrimary,
                                      ),
                                      onPressed: () {
                                        fieldCtrl.clear();
                                        setState(
                                          () => _selectedCommonName = '',
                                        );
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: _uploadSubCardBg,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: _uploadBorderColor,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: _uploadBorderColor,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: _uploadPrimary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          );
                        },
                    optionsViewBuilder:
                        (
                          BuildContext ctx,
                          AutocompleteOnSelected<CatalogSpecies> onSelected,
                          Iterable<CatalogSpecies> options,
                        ) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(16),
                              color: _surfaceColor,
                              child: SizedBox(
                                width: constraints.maxWidth,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 280,
                                  ),
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    separatorBuilder: (_, _) => Divider(
                                      height: 1,
                                      color: _lineColor,
                                      indent: 56,
                                    ),
                                    itemBuilder: (_, int i) {
                                      final CatalogSpecies s = options
                                          .elementAt(i);
                                      return InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () => onSelected(s),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: _uploadSubCardBg,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: const Icon(
                                                  Icons.eco_rounded,
                                                  size: 18,
                                                  color: _uploadPrimary,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      s.scientificName,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                        color: _textColor,
                                                      ),
                                                    ),
                                                    if (s.commonName.isNotEmpty)
                                                      Text(
                                                        s.commonName,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              _mutedTextColor,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              const Icon(
                                                Icons.arrow_forward_ios_rounded,
                                                size: 12,
                                                color: _uploadPrimary,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                  );
                },
              ),
              // ── Divider between search and manual fields
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: _lineColor)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'or fill in manually',
                        style: TextStyle(fontSize: 11, color: _mutedTextColor),
                      ),
                    ),
                    Expanded(child: Divider(color: _lineColor)),
                  ],
                ),
              ),
              // ── Manual fields (autofilled when species selected)
              _fieldLabel('Genus'),
              const SizedBox(height: 4),
              SizedBox(
                height: 34,
                child: TextField(
                  controller: _genusController,
                  decoration: _fieldDecoration(),
                ),
              ),
              const SizedBox(height: 8),
              _fieldLabel('Species'),
              const SizedBox(height: 4),
              SizedBox(
                height: 34,
                child: TextField(
                  controller: _familyController,
                  decoration: _fieldDecoration(),
                ),
              ),
              const SizedBox(height: 8),
              _fieldLabel('Scientific Name'),
              const SizedBox(height: 4),
              SizedBox(
                height: 34,
                child: TextField(
                  controller: _scientificNameController,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                  decoration: _fieldDecoration().copyWith(
                    hintText:
                        'Auto-filled from Genus + Species, or type manually',
                  ),
                ),
              ),
              // ── Selected species confirmation chip
              if (_selectedCommonName.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _uploadSubCardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _uploadBorderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: _uploadPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Common name: $_selectedCommonName',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _uploadPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Center(
                child: FilledButton(
                  onPressed: _findSpecies,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 7,
                    ),
                    minimumSize: const Size(136, 42),
                  ),
                  child: const Text(
                    'FIND',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddSpeciesFindResultsScreen extends StatelessWidget {
  const AddSpeciesFindResultsScreen({
    required this.family,
    required this.genus,
    required this.scientificName,
    required this.commonName,
    super.key,
  });
  final String family;
  final String genus;
  final String scientificName;
  final String commonName;
  void _openSightingsInformationForm(BuildContext context) {
    final UploadSpeciesFlowData flowData = UploadSpeciesFlowData(
      family: family,
      genus: genus,
      scientificName: scientificName,
      commonNames: commonName.trim().isEmpty
          ? <String>[]
          : <String>[commonName],
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UploadSpeciesSightingsScreen(
          flowData: flowData,
          flowTitle: 'Add New Sightings',
          showSpeciesValueStep: false,
        ),
      ),
    );
  }

  Widget _labelText(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
        color: _textColor,
      ),
    );
  }

  Widget _valueText(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, top: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          color: _mutedTextColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _appBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _UploadFormHeader(title: 'Add New Sightings'),
              const SizedBox(height: 24),
              Text(
                'Find Species',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '1 Species Found',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  color: _mutedTextColor,
                ),
              ),
              const SizedBox(height: 14),
              _labelText('Family'),
              _valueText(family),
              const SizedBox(height: 6),
              _labelText('Genus'),
              _valueText(genus),
              const SizedBox(height: 6),
              _labelText('Scientific Name'),
              _valueText(scientificName),
              const SizedBox(height: 6),
              _labelText('Common Name'),
              _valueText(commonName),
              const SizedBox(height: 18),
              Center(
                child: FilledButton(
                  onPressed: () => _openSightingsInformationForm(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    minimumSize: const Size(150, 45),
                  ),
                  child: const Text(
                    'CONTINUE',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UploadSpeciesImageDraft {
  UploadSpeciesImageDraft({
    required this.path,
    required this.sizeBytes,
    this.photoCredit = '',
    this.category = 'specimen_photo',
  });
  final String path;
  final int sizeBytes;
  String photoCredit;
  String category;
  UploadSpeciesImageDraft copy() {
    return UploadSpeciesImageDraft(
      path: path,
      sizeBytes: sizeBytes,
      photoCredit: photoCredit,
      category: category,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'path': path,
    'sizeBytes': sizeBytes,
    'photoCredit': photoCredit,
    'category': category,
  };
  factory UploadSpeciesImageDraft.fromJson(Map<String, dynamic> json) {
    return UploadSpeciesImageDraft(
      path: (json['path'] ?? '').toString(),
      sizeBytes: int.tryParse((json['sizeBytes'] ?? '0').toString()) ?? 0,
      photoCredit: (json['photoCredit'] ?? '').toString(),
      category: (json['category'] ?? 'specimen_photo').toString(),
    );
  }
}

class UploadContributorDraft {
  UploadContributorDraft({required this.name, required this.position});
  final String name;
  final String position;
  UploadContributorDraft copy() {
    return UploadContributorDraft(name: name, position: position);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'position': position,
  };
  factory UploadContributorDraft.fromJson(Map<String, dynamic> json) {
    return UploadContributorDraft(
      name: (json['name'] ?? '').toString(),
      position: (json['position'] ?? '').toString(),
    );
  }
}

class UploadRelatedStudyEntry {
  UploadRelatedStudyEntry({
    this.title = '',
    this.link = '',
    this.filePath = '',
  });
  String title;
  String link;
  String filePath;
  bool get isEmpty =>
      title.trim().isEmpty && link.trim().isEmpty && filePath.trim().isEmpty;
  UploadRelatedStudyEntry copy() {
    return UploadRelatedStudyEntry(
      title: title,
      link: link,
      filePath: filePath,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'title': title,
    'link': link,
    'filePath': filePath,
  };
  factory UploadRelatedStudyEntry.fromJson(Map<String, dynamic> json) {
    return UploadRelatedStudyEntry(
      title: (json['title'] ?? '').toString(),
      link: (json['link'] ?? json['url'] ?? '').toString(),
      filePath: (json['filePath'] ?? json['file_url'] ?? '').toString(),
    );
  }
}

class UploadSpeciesFlowData {
  UploadSpeciesFlowData({
    this.draftId,
    this.supabaseSightingId,
    String? entryId,
    this.location = '',
    this.family = '',
    this.genus = '',
    this.scientificName = '',
    List<String>? commonNames,
    List<String>? localNames,
    this.identificationConfidence = 'Confirmed',
    this.endemicToPhilippines = '',
    this.leafType = '',
    this.flowerColor = '',
    this.floweringFromMonth = '',
    this.floweringToMonth = '',
    this.plantHeight = '',
    this.pseudobulbPresent = '',
    this.stemLength = '',
    this.rootLength = '',
    this.numberOfLeaves = '',
    this.leafShape = '',
    this.leafLength = '',
    this.leafWidth = '',
    this.leafTexture = '',
    this.leafArrangement = '',
    this.numberOfFlowers = '',
    this.flowerDiameter = '',
    this.inflorescenceType = '',
    this.petalCharacteristics = '',
    this.sepalCharacteristics = '',
    this.labellumDescription = '',
    this.fragrance = '',
    this.bloomingStage = '',
    this.fruitPresent = '',
    this.fruitType = '',
    this.seedCapsuleCondition = '',
    this.observationDate = '',
    this.observationTime = '',
    this.collectionMethod = '',
    this.observationType = '',
    this.voucherSpecimenCollected = false,
    this.numberLocated = '',
    this.ethnobotanicalImportance = '',
    this.aestheticAppeal = '',
    this.cultivation = '',
    this.rarity = '',
    this.culturalImportance = '',
    this.lifeStage = '',
    this.phenology = '',
    this.populationStatus = '',
    this.threatLevel = '',
    List<String>? threatTypes,
    this.latitude = '',
    this.longitude = '',
    this.province = '',
    this.municipality = '',
    this.mountain = '',
    this.altitude = '',
    this.elevation = '',
    this.habitatType = '',
    this.microHabitat = '',
    this.specificSite = '',
    this.specificSiteZone = '',
    this.growthSubstrate = '',
    this.hostTreeSpecies = '',
    this.hostTreeDiameter = '',
    this.canopyCover = '',
    this.lightExposure = '',
    this.soilType = '',
    this.nearbyWaterSource = '',
    this.videoPath = '',
    List<UploadRelatedStudyEntry>? relatedStudies,
    this.headResearcher = '',
    this.teamMembers = '',
    this.institution = '',
    this.researcherNotes = '',
    this.unusualObservations = '',
    List<UploadSpeciesImageDraft>? images,
    List<UploadContributorDraft>? contributors,
    DateTime? updatedAt,
  }) : entryId = (entryId != null && entryId.trim().isNotEmpty)
           ? entryId
           : _generateEntryId(),
       commonNames = commonNames ?? <String>[],
       localNames = localNames ?? <String>[],
       threatTypes = threatTypes ?? <String>[],
       relatedStudies = relatedStudies ?? <UploadRelatedStudyEntry>[],
       images = images ?? <UploadSpeciesImageDraft>[],
       contributors = contributors ?? <UploadContributorDraft>[],
       updatedAt = updatedAt ?? DateTime.now();
  String? draftId;
  // The sighting_id assigned by Supabase when this draft was synced to the
  // species_sightings table. Null until the first successful cloud sync.
  int? supabaseSightingId;
  String entryId;
  String location;
  String family;
  String genus;
  String scientificName;
  List<String> commonNames;
  List<String> localNames;
  String identificationConfidence;
  // 'Yes' / 'No' / 'Unknown' / '' (unset) — tri-state to match the web
  // dashboard's Endemic to the Philippines field, including the "Unknown"
  // option DAO 2026-20 lookups fall back to when a species isn't listed.
  String endemicToPhilippines;
  String get commonName => commonNames.isNotEmpty ? commonNames.first : '';
  String leafType;
  String flowerColor;
  String floweringFromMonth;
  String floweringToMonth;
  String plantHeight;
  String pseudobulbPresent;
  String stemLength;
  String rootLength;
  String numberOfLeaves;
  String leafShape;
  String leafLength;
  String leafWidth;
  String leafTexture;
  String leafArrangement;
  String numberOfFlowers;
  String flowerDiameter;
  String inflorescenceType;
  String petalCharacteristics;
  String sepalCharacteristics;
  String labellumDescription;
  String fragrance;
  String bloomingStage;
  String fruitPresent;
  String fruitType;
  String seedCapsuleCondition;
  String observationDate;
  String observationTime;
  String collectionMethod;
  String observationType;
  bool voucherSpecimenCollected;
  String numberLocated;
  String ethnobotanicalImportance;
  String aestheticAppeal;
  String cultivation;
  String rarity;
  String culturalImportance;
  String lifeStage;
  String phenology;
  String populationStatus;
  String threatLevel;
  List<String> threatTypes;
  String latitude;
  String longitude;
  String province;
  String municipality;
  String mountain;
  String altitude;
  String elevation;
  String habitatType;
  String microHabitat;
  String specificSite;
  String specificSiteZone;
  String growthSubstrate;
  String hostTreeSpecies;
  String hostTreeDiameter;
  String canopyCover;
  String lightExposure;
  String soilType;
  String nearbyWaterSource;
  String videoPath;
  List<UploadRelatedStudyEntry> relatedStudies;
  String headResearcher;
  String teamMembers;
  String institution;
  String researcherNotes;
  String unusualObservations;
  List<UploadSpeciesImageDraft> images;
  List<UploadContributorDraft> contributors;
  DateTime updatedAt;
  UploadSpeciesFlowData copy() {
    return UploadSpeciesFlowData(
      draftId: draftId,
      supabaseSightingId: supabaseSightingId,
      entryId: entryId,
      location: location,
      family: family,
      genus: genus,
      scientificName: scientificName,
      commonNames: List<String>.from(commonNames),
      localNames: List<String>.from(localNames),
      identificationConfidence: identificationConfidence,
      endemicToPhilippines: endemicToPhilippines,
      leafType: leafType,
      flowerColor: flowerColor,
      floweringFromMonth: floweringFromMonth,
      floweringToMonth: floweringToMonth,
      plantHeight: plantHeight,
      pseudobulbPresent: pseudobulbPresent,
      stemLength: stemLength,
      rootLength: rootLength,
      numberOfLeaves: numberOfLeaves,
      leafShape: leafShape,
      leafLength: leafLength,
      leafWidth: leafWidth,
      leafTexture: leafTexture,
      leafArrangement: leafArrangement,
      numberOfFlowers: numberOfFlowers,
      flowerDiameter: flowerDiameter,
      inflorescenceType: inflorescenceType,
      petalCharacteristics: petalCharacteristics,
      sepalCharacteristics: sepalCharacteristics,
      labellumDescription: labellumDescription,
      fragrance: fragrance,
      bloomingStage: bloomingStage,
      fruitPresent: fruitPresent,
      fruitType: fruitType,
      seedCapsuleCondition: seedCapsuleCondition,
      observationDate: observationDate,
      observationTime: observationTime,
      collectionMethod: collectionMethod,
      observationType: observationType,
      voucherSpecimenCollected: voucherSpecimenCollected,
      numberLocated: numberLocated,
      ethnobotanicalImportance: ethnobotanicalImportance,
      aestheticAppeal: aestheticAppeal,
      cultivation: cultivation,
      rarity: rarity,
      culturalImportance: culturalImportance,
      lifeStage: lifeStage,
      phenology: phenology,
      populationStatus: populationStatus,
      threatLevel: threatLevel,
      threatTypes: List<String>.from(threatTypes),
      latitude: latitude,
      longitude: longitude,
      province: province,
      municipality: municipality,
      mountain: mountain,
      altitude: altitude,
      elevation: elevation,
      habitatType: habitatType,
      microHabitat: microHabitat,
      specificSite: specificSite,
      specificSiteZone: specificSiteZone,
      growthSubstrate: growthSubstrate,
      hostTreeSpecies: hostTreeSpecies,
      hostTreeDiameter: hostTreeDiameter,
      canopyCover: canopyCover,
      lightExposure: lightExposure,
      soilType: soilType,
      nearbyWaterSource: nearbyWaterSource,
      videoPath: videoPath,
      relatedStudies: relatedStudies
          .map((UploadRelatedStudyEntry e) => e.copy())
          .toList(),
      headResearcher: headResearcher,
      teamMembers: teamMembers,
      institution: institution,
      researcherNotes: researcherNotes,
      unusualObservations: unusualObservations,
      images: images
          .map((UploadSpeciesImageDraft image) => image.copy())
          .toList(growable: false),
      contributors: contributors
          .map((UploadContributorDraft contributor) => contributor.copy())
          .toList(growable: false),
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'draftId': draftId,
      'supabaseSightingId': supabaseSightingId,
      'entryId': entryId,
      'location': location,
      'family': family,
      'genus': genus,
      'scientificName': scientificName,
      'commonName': commonName,
      'commonNames': commonNames,
      'localNames': localNames,
      'identificationConfidence': identificationConfidence,
      'endemicToPhilippines': endemicToPhilippines,
      'leafType': leafType,
      'flowerColor': flowerColor,
      'floweringFromMonth': floweringFromMonth,
      'floweringToMonth': floweringToMonth,
      'plantHeight': plantHeight,
      'pseudobulbPresent': pseudobulbPresent,
      'stemLength': stemLength,
      'rootLength': rootLength,
      'numberOfLeaves': numberOfLeaves,
      'leafShape': leafShape,
      'leafLength': leafLength,
      'leafWidth': leafWidth,
      'leafTexture': leafTexture,
      'leafArrangement': leafArrangement,
      'numberOfFlowers': numberOfFlowers,
      'flowerDiameter': flowerDiameter,
      'inflorescenceType': inflorescenceType,
      'petalCharacteristics': petalCharacteristics,
      'sepalCharacteristics': sepalCharacteristics,
      'labellumDescription': labellumDescription,
      'fragrance': fragrance,
      'bloomingStage': bloomingStage,
      'fruitPresent': fruitPresent,
      'fruitType': fruitType,
      'seedCapsuleCondition': seedCapsuleCondition,
      'observationDate': observationDate,
      'observationTime': observationTime,
      'collectionMethod': collectionMethod,
      'observationType': observationType,
      'voucherSpecimenCollected': voucherSpecimenCollected,
      'numberLocated': numberLocated,
      'ethnobotanicalImportance': ethnobotanicalImportance,
      'aestheticAppeal': aestheticAppeal,
      'cultivation': cultivation,
      'rarity': rarity,
      'culturalImportance': culturalImportance,
      'lifeStage': lifeStage,
      'phenology': phenology,
      'populationStatus': populationStatus,
      'threatLevel': threatLevel,
      'threatTypes': threatTypes,
      'latitude': latitude,
      'longitude': longitude,
      'province': province,
      'municipality': municipality,
      'mountain': mountain,
      'altitude': altitude,
      'elevation': elevation,
      'habitatType': habitatType,
      'microHabitat': microHabitat,
      'specificSite': specificSite,
      'specificSiteZone': specificSiteZone,
      'growthSubstrate': growthSubstrate,
      'hostTreeSpecies': hostTreeSpecies,
      'hostTreeDiameter': hostTreeDiameter,
      'canopyCover': canopyCover,
      'lightExposure': lightExposure,
      'soilType': soilType,
      'nearbyWaterSource': nearbyWaterSource,
      'videoPath': videoPath,
      'relatedStudies': relatedStudies
          .map((UploadRelatedStudyEntry e) => e.toJson())
          .toList(growable: false),
      'headResearcher': headResearcher,
      'teamMembers': teamMembers,
      'institution': institution,
      'researcherNotes': researcherNotes,
      'unusualObservations': unusualObservations,
      'images': images
          .map((UploadSpeciesImageDraft image) => image.toJson())
          .toList(growable: false),
      'contributors': contributors
          .map((UploadContributorDraft contributor) => contributor.toJson())
          .toList(growable: false),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UploadSpeciesFlowData.fromJson(Map<String, dynamic> json) {
    final dynamic rawImages = json['images'];
    final dynamic rawContributors = json['contributors'];
    final List<UploadSpeciesImageDraft> parsedImages = rawImages is List
        ? rawImages
              .whereType<Map>()
              .map(
                (Map<dynamic, dynamic> item) =>
                    UploadSpeciesImageDraft.fromJson(
                      Map<String, dynamic>.from(item),
                    ),
              )
              .toList(growable: false)
        : <UploadSpeciesImageDraft>[];
    final List<UploadContributorDraft> parsedContributors =
        rawContributors is List
        ? rawContributors
              .whereType<Map>()
              .map(
                (Map<dynamic, dynamic> item) => UploadContributorDraft.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : <UploadContributorDraft>[];
    return UploadSpeciesFlowData(
      draftId: (json['draftId'] ?? '').toString().trim().isEmpty
          ? null
          : (json['draftId'] ?? '').toString(),
      supabaseSightingId: json['supabaseSightingId'] is int
          ? json['supabaseSightingId'] as int
          : int.tryParse((json['supabaseSightingId'] ?? '').toString()),
      entryId: (json['entryId'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      family: (json['family'] ?? '').toString(),
      genus: (json['genus'] ?? '').toString(),
      scientificName: (json['scientificName'] ?? '').toString(),
      commonNames: () {
        final dynamic raw = json['commonNames'];
        if (raw is List) {
          return raw
              .map((dynamic e) => e.toString())
              .where((String s) => s.trim().isNotEmpty)
              .toList();
        }
        final String single = (json['commonName'] ?? '').toString().trim();
        return single.isNotEmpty ? <String>[single] : <String>[];
      }(),
      localNames: () {
        final dynamic raw = json['localNames'];
        if (raw is List) {
          return raw
              .map((dynamic e) => e.toString())
              .where((String s) => s.trim().isNotEmpty)
              .toList();
        }
        return <String>[];
      }(),
      identificationConfidence:
          (json['identificationConfidence'] ?? 'Confirmed').toString(),
      endemicToPhilippines: normalizeEndemicFlag(json['endemicToPhilippines']),
      leafType: (json['leafType'] ?? '').toString(),
      flowerColor: (json['flowerColor'] ?? '').toString(),
      floweringFromMonth: (json['floweringFromMonth'] ?? '').toString(),
      floweringToMonth: (json['floweringToMonth'] ?? '').toString(),
      plantHeight: (json['plantHeight'] ?? '').toString(),
      pseudobulbPresent: (json['pseudobulbPresent'] ?? '').toString(),
      stemLength: (json['stemLength'] ?? '').toString(),
      rootLength: (json['rootLength'] ?? '').toString(),
      numberOfLeaves: (json['numberOfLeaves'] ?? '').toString(),
      leafShape: (json['leafShape'] ?? '').toString(),
      leafLength: (json['leafLength'] ?? '').toString(),
      leafWidth: (json['leafWidth'] ?? '').toString(),
      leafTexture: (json['leafTexture'] ?? '').toString(),
      leafArrangement: (json['leafArrangement'] ?? '').toString(),
      numberOfFlowers: (json['numberOfFlowers'] ?? '').toString(),
      flowerDiameter: (json['flowerDiameter'] ?? '').toString(),
      inflorescenceType: (json['inflorescenceType'] ?? '').toString(),
      petalCharacteristics: (json['petalCharacteristics'] ?? '').toString(),
      sepalCharacteristics: (json['sepalCharacteristics'] ?? '').toString(),
      labellumDescription: (json['labellumDescription'] ?? '').toString(),
      fragrance: (json['fragrance'] ?? '').toString(),
      bloomingStage: (json['bloomingStage'] ?? '').toString(),
      fruitPresent: (json['fruitPresent'] ?? '').toString(),
      fruitType: (json['fruitType'] ?? '').toString(),
      seedCapsuleCondition: (json['seedCapsuleCondition'] ?? '').toString(),
      observationDate: (json['observationDate'] ?? '').toString(),
      observationTime: (json['observationTime'] ?? '').toString(),
      collectionMethod: (json['collectionMethod'] ?? '').toString(),
      observationType: (json['observationType'] ?? '').toString(),
      voucherSpecimenCollected: json['voucherSpecimenCollected'] == true,
      numberLocated: (json['numberLocated'] ?? '').toString(),
      ethnobotanicalImportance: (json['ethnobotanicalImportance'] ?? '')
          .toString(),
      aestheticAppeal: (json['aestheticAppeal'] ?? '').toString(),
      cultivation: (json['cultivation'] ?? '').toString(),
      rarity: (json['rarity'] ?? '').toString(),
      culturalImportance: (json['culturalImportance'] ?? '').toString(),
      lifeStage: (json['lifeStage'] ?? '').toString(),
      phenology: (json['phenology'] ?? '').toString(),
      populationStatus: (json['populationStatus'] ?? '').toString(),
      threatLevel: (json['threatLevel'] ?? '').toString(),
      threatTypes: () {
        final dynamic raw = json['threatTypes'];
        if (raw is List) {
          return raw
              .map((dynamic e) => e.toString())
              .where((String s) => s.trim().isNotEmpty)
              .toList();
        }
        // Legacy single-value drafts saved before threat type became
        // multi-select stored one string under 'threatType'.
        final String single = (json['threatType'] ?? '').toString().trim();
        return single.isNotEmpty ? <String>[single] : <String>[];
      }(),
      latitude: (json['latitude'] ?? '').toString(),
      longitude: (json['longitude'] ?? '').toString(),
      province: (json['province'] ?? '').toString(),
      municipality: (json['municipality'] ?? '').toString(),
      mountain: (json['mountain'] ?? '').toString(),
      altitude: (json['altitude'] ?? '').toString(),
      elevation: (json['elevation'] ?? '').toString(),
      habitatType: (json['habitatType'] ?? '').toString(),
      microHabitat: (json['microHabitat'] ?? '').toString(),
      specificSite: (json['specificSite'] ?? '').toString(),
      specificSiteZone: (json['specificSiteZone'] ?? '').toString(),
      growthSubstrate: (json['growthSubstrate'] ?? '').toString(),
      hostTreeSpecies: (json['hostTreeSpecies'] ?? '').toString(),
      hostTreeDiameter: (json['hostTreeDiameter'] ?? '').toString(),
      canopyCover: (json['canopyCover'] ?? '').toString(),
      lightExposure: (json['lightExposure'] ?? '').toString(),
      soilType: (json['soilType'] ?? '').toString(),
      nearbyWaterSource: (json['nearbyWaterSource'] ?? '').toString(),
      videoPath: (json['videoPath'] ?? '').toString(),
      relatedStudies: () {
        final dynamic raw = json['relatedStudies'];
        if (raw is List) {
          return raw
              .whereType<Map>()
              .map(
                (Map e) => UploadRelatedStudyEntry.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList();
        }
        // Legacy single-study drafts saved title/link/file as flat fields.
        final String legacyTitle = (json['studyTitle'] ?? '').toString();
        final String legacyLink = (json['studyLink'] ?? '').toString();
        final String legacyFile = (json['studyFilePath'] ?? '').toString();
        if (legacyTitle.trim().isEmpty &&
            legacyLink.trim().isEmpty &&
            legacyFile.trim().isEmpty) {
          return <UploadRelatedStudyEntry>[];
        }
        return <UploadRelatedStudyEntry>[
          UploadRelatedStudyEntry(
            title: legacyTitle,
            link: legacyLink,
            filePath: legacyFile,
          ),
        ];
      }(),
      headResearcher: (json['headResearcher'] ?? '').toString(),
      teamMembers: (json['teamMembers'] ?? '').toString(),
      institution: (json['institution'] ?? '').toString(),
      researcherNotes: (json['researcherNotes'] ?? '').toString(),
      unusualObservations: (json['unusualObservations'] ?? '').toString(),
      images: parsedImages,
      contributors: parsedContributors,
      updatedAt:
          DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

/// Writes a sighting the same way the web app does (`submitNormalizedSighting`
/// in researcher-dashboard.html): sub-tables (`sighting_habitat`,
/// `sighting_morphology`, `sighting_conservation`) are written first, then
/// `species_sightings` is written with the resulting FK ids, then
/// `sighting_team_member` and `sighting_media` rows follow. DENR's review
/// screens join on those FK columns — writing flat legacy columns instead
/// (as the old mobile code did) makes a submission invisible to reviewers
/// even though the row technically exists.
///
/// [existingSightingId] switches to update-in-place mode (used for draft
/// resaves and DENR-revision resubmits): existing sub-table rows are
/// updated by their current FK id instead of new ones being inserted, so a
/// resubmit doesn't leave orphaned sub-table rows behind.
Future<Map<String, dynamic>> submitNormalizedSighting({
  required UploadSpeciesFlowData draft,
  required String entryId,
  required String researcherEmail,
  required String researcherName,
  required String reviewStatus,
  int? existingSightingId,
  List<String> wholePlantPhotoUrls = const <String>[],
  List<String> closeupFlowerPhotoUrls = const <String>[],
  List<String> habitatPhotoUrls = const <String>[],
  List<String> wholePlantPhotographers = const <String>[],
  List<String> closeupFlowerPhotographers = const <String>[],
  List<String> habitatPhotographers = const <String>[],
}) async {
  final SupabaseClient supabase = Supabase.instance.client;
  double? numOrNull(String v) {
    final String t = v.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  int? intOrNull(String v) {
    final String t = v.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t) ?? double.tryParse(t)?.round();
  }

  String? strOrNull(String v) => v.trim().isEmpty ? null : v.trim();
  bool? yesNo(String v) {
    final String t = v.trim().toLowerCase();
    if (t.isEmpty) return null;
    return t == 'yes' || t == 'true';
  }

  final String floweringSeason = <String>[
    draft.floweringFromMonth.trim(),
    draft.floweringToMonth.trim(),
  ].where((String s) => s.isNotEmpty).join(' – ');
  final List<String> threatTypes = draft.threatTypes
      .map((String t) => t.trim())
      .where((String t) => t.isNotEmpty)
      .toList();
  final Map<String, dynamic> habitatPayload = <String, dynamic>{
    'habitat_type': strOrNull(draft.habitatType),
    'microhabitat': strOrNull(draft.microHabitat),
    'growth_substrate': strOrNull(draft.growthSubstrate),
    'host_tree_species': strOrNull(draft.hostTreeSpecies),
    'host_tree_dbh_cm': numOrNull(draft.hostTreeDiameter),
    'canopy_cover_percent': numOrNull(draft.canopyCover),
    'light_exposure': strOrNull(draft.lightExposure),
    'soil_type': strOrNull(draft.soilType),
    'nearby_water_source': strOrNull(draft.nearbyWaterSource),
  };
  final Map<String, dynamic> morphologyPayload = <String, dynamic>{
    'plant_height_cm': numOrNull(draft.plantHeight),
    'pseudobulb_present': yesNo(draft.pseudobulbPresent),
    'stem_length_cm': numOrNull(draft.stemLength),
    'root_length_cm': numOrNull(draft.rootLength),
    'leaf_count': intOrNull(draft.numberOfLeaves),
    'leaf_shape': strOrNull(
      draft.leafShape.isNotEmpty ? draft.leafShape : draft.leafType,
    ),
    'leaf_length_cm': numOrNull(draft.leafLength),
    'leaf_width_cm': numOrNull(draft.leafWidth),
    'leaf_textures': draft.leafTexture.trim().isNotEmpty
        ? <String>[draft.leafTexture.trim()]
        : <String>[],
    'leaf_arrangement': strOrNull(draft.leafArrangement),
    'flower_color': strOrNull(draft.flowerColor),
    'flower_count': intOrNull(draft.numberOfFlowers),
    'flower_diameter_cm': numOrNull(draft.flowerDiameter),
    'inflorescence_type': strOrNull(draft.inflorescenceType),
    'petal_characteristics': strOrNull(draft.petalCharacteristics),
    'sepal_characteristics': strOrNull(draft.sepalCharacteristics),
    'labellum_lip_description': strOrNull(draft.labellumDescription),
    'fragrance': strOrNull(draft.fragrance),
    'blooming_stage': strOrNull(draft.bloomingStage),
    'flowering_season': strOrNull(floweringSeason),
    'fruit_present': yesNo(draft.fruitPresent),
    'fruit_type': strOrNull(draft.fruitType),
    'seed_capsule_condition': strOrNull(draft.seedCapsuleCondition),
    'life_stage': strOrNull(draft.lifeStage),
    'phenology': strOrNull(draft.phenology),
    'population_count': intOrNull(draft.numberLocated),
  };
  final Map<String, dynamic> conservationPayload = <String, dynamic>{
    'population_status': strOrNull(draft.populationStatus),
    'threat_level': strOrNull(draft.threatLevel),
    'threat_types': threatTypes,
  };
  // Mountain lookup by name (defaults to Mt. Busa, matching web).
  final String mountainName = draft.mountain.trim().isEmpty
      ? 'Mt. Busa'
      : draft.mountain.trim();
  int? mountainId;
  try {
    final Map<String, dynamic>? mt = await supabase
        .from('mountain')
        .select('mountain_id')
        .ilike('mountain_name', mountainName)
        .maybeSingle();
    mountainId = mt?['mountain_id'] as int?;
  } catch (_) {
    mountainId = null;
  }
  Future<int> upsertSub(
    String table,
    String pkCol,
    int? existingId,
    Map<String, dynamic> payload,
  ) async {
    if (existingId != null) {
      await supabase.from(table).update(payload).eq(pkCol, existingId);
      return existingId;
    }
    final Map<String, dynamic> inserted = await supabase
        .from(table)
        .insert(payload)
        .select(pkCol)
        .single();
    return inserted[pkCol] as int;
  }

  int? existingHabitatId;
  int? existingMorphologyId;
  int? existingConservationId;
  if (existingSightingId != null) {
    final Map<String, dynamic>? ex = await supabase
        .from('species_sightings')
        .select(
          'sighting_habitat_id, sighting_morphology_id, sighting_conservation_id',
        )
        .eq('sighting_id', existingSightingId)
        .maybeSingle();
    existingHabitatId = ex?['sighting_habitat_id'] as int?;
    existingMorphologyId = ex?['sighting_morphology_id'] as int?;
    existingConservationId = ex?['sighting_conservation_id'] as int?;
  }
  final int habitatId = await upsertSub(
    'sighting_habitat',
    'sighting_habitat_id',
    existingHabitatId,
    habitatPayload,
  );
  final int morphologyId = await upsertSub(
    'sighting_morphology',
    'sighting_morphology_id',
    existingMorphologyId,
    morphologyPayload,
  );
  final int conservationId = await upsertSub(
    'sighting_conservation',
    'sighting_conservation_id',
    existingConservationId,
    conservationPayload,
  );
  final List<Map<String, String>> relatedStudyEntries = draft.relatedStudies
      .where((UploadRelatedStudyEntry e) => !e.isEmpty)
      .map(
        (UploadRelatedStudyEntry e) => <String, String>{
          'title': e.title.trim(),
          'link': e.link.trim(),
          'file_url': e.filePath.trim(),
        },
      )
      .toList();
  final String relatedStudy = relatedStudyEntries.isNotEmpty
      ? jsonEncode(relatedStudyEntries)
      : '';
  final Map<String, dynamic> mainPayload = <String, dynamic>{
    'entry_id': entryId,
    'researcher_email': researcherEmail,
    'researcher_name': strOrNull(researcherName),
    'scientific_name': draft.scientificName.trim().isEmpty
        ? 'Unknown'
        : draft.scientificName.trim(),
    'common_names': draft.commonNames
        .where((String s) => s.trim().isNotEmpty)
        .toList(),
    'local_names': draft.localNames
        .where((String s) => s.trim().isNotEmpty)
        .toList(),
    'identification_confidence':
        strOrNull(draft.identificationConfidence) ?? 'Unidentified',
    'observation_date': strOrNull(draft.observationDate),
    'observation_time': strOrNull(draft.observationTime),
    'collection_method': strOrNull(draft.collectionMethod),
    'observation_type': strOrNull(draft.observationType),
    'voucher_collected': draft.voucherSpecimenCollected,
    'mountain_id': mountainId,
    'specific_site_zone': strOrNull(draft.specificSiteZone),
    'specific_site_other': strOrNull(draft.specificSite),
    'latitude': double.tryParse(draft.latitude.trim()) ?? 0.0,
    'longitude': double.tryParse(draft.longitude.trim()) ?? 0.0,
    'elevation_meters': numOrNull(draft.elevation),
    'endemic_to_philippines': strOrNull(draft.endemicToPhilippines),
    'sighting_habitat_id': habitatId,
    'sighting_morphology_id': morphologyId,
    'sighting_conservation_id': conservationId,
    'related_study': relatedStudy.isNotEmpty ? relatedStudy : null,
    'researcher_notes': strOrNull(draft.researcherNotes),
    'review_status': reviewStatus,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
  Map<String, dynamic> resultRow;
  final int sightingId;
  if (existingSightingId != null) {
    final List<dynamic> updated = await supabase
        .from('species_sightings')
        .update(mainPayload)
        .eq('sighting_id', existingSightingId)
        .select('sighting_id, entry_id, scientific_name, review_status');
    resultRow = updated.isNotEmpty
        ? Map<String, dynamic>.from(updated.first as Map)
        : <String, dynamic>{'sighting_id': existingSightingId};
    sightingId = existingSightingId;
  } else {
    final List<dynamic> inserted = await supabase
        .from('species_sightings')
        .insert(mainPayload)
        .select('sighting_id, entry_id, scientific_name, review_status');
    resultRow = Map<String, dynamic>.from(inserted.first as Map);
    sightingId = resultRow['sighting_id'] as int;
  }
  // Team members: delete-then-reinsert, matching web.
  await supabase
      .from('sighting_team_member')
      .delete()
      .eq('sighting_id', sightingId);
  final List<Map<String, dynamic>> teamRows = draft.contributors
      .where((UploadContributorDraft c) => c.name.trim().isNotEmpty)
      .map(
        (UploadContributorDraft c) => <String, dynamic>{
          'sighting_id': sightingId,
          'member_name': c.name.trim(),
          'member_role': strOrNull(c.position),
        },
      )
      .toList();
  if (teamRows.isNotEmpty) {
    await supabase.from('sighting_team_member').insert(teamRows);
  }
  // Media: upsert `picture` rows by file_path, then link via sighting_media.
  Future<void> insertMediaGroup(
    List<String> urls,
    String category,
    List<String> photographers,
  ) async {
    for (int i = 0; i < urls.length; i++) {
      final String url = urls[i];
      if (url.isEmpty) continue;
      try {
        final Map<String, dynamic> pic = await supabase
            .from('picture')
            .upsert(<String, dynamic>{
              'file_path': url,
            }, onConflict: 'file_path')
            .select('picture_id')
            .single();
        final int? pictureId = pic['picture_id'] as int?;
        if (pictureId != null) {
          await supabase.from('sighting_media').insert(<String, dynamic>{
            'sighting_id': sightingId,
            'picture_id': pictureId,
            'media_category': category,
            'photographer_name': i < photographers.length
                ? strOrNull(photographers[i])
                : null,
            'sort_order': i,
          });
        }
      } catch (_) {
        // Non-fatal: one bad photo shouldn't sink the whole submission.
      }
    }
  }

  await insertMediaGroup(
    wholePlantPhotoUrls,
    'whole_plant',
    wholePlantPhotographers,
  );
  await insertMediaGroup(
    closeupFlowerPhotoUrls,
    'closeup_flower',
    closeupFlowerPhotographers,
  );
  await insertMediaGroup(habitatPhotoUrls, 'habitat', habitatPhotographers);
  return resultRow;
}

class UploadSpeciesFlowValidators {
  static String? validateSpeciesInformation(UploadSpeciesFlowData data) {
    if (data.scientificName.trim().isEmpty) {
      return 'Scientific Name is required.';
    }
    if (data.observationDate.trim().isEmpty) {
      return 'Date of Observation is required.';
    }
    return null;
  }

  static String? validateSightings(UploadSpeciesFlowData data) {
    return null;
  }

  static String? validateSpeciesValues(UploadSpeciesFlowData data) {
    return null;
  }

  static String? validateImagesAndContributors(UploadSpeciesFlowData data) {
    if (data.headResearcher.trim().isEmpty) {
      return 'Head Observer / Researcher Name is required.';
    }
    return null;
  }

  static bool isReadyToUpload(UploadSpeciesFlowData data) {
    return validateSpeciesInformation(data) == null &&
        validateSightings(data) == null &&
        validateSpeciesValues(data) == null &&
        validateImagesAndContributors(data) == null;
  }
}

class UploadSpeciesDraftStore {
  static const String _draftsKey = 'upload_species_drafts_v1';
  static String _generatedDraftId(UploadSpeciesFlowData draft, int index) {
    final int updatedAtSeed = draft.updatedAt.microsecondsSinceEpoch;
    return '$updatedAtSeed-$index';
  }

  static Future<List<UploadSpeciesFlowData>> loadDrafts() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String encoded = prefs.getString(_draftsKey) ?? '';
    if (encoded.trim().isEmpty) {
      return <UploadSpeciesFlowData>[];
    }
    try {
      final dynamic decoded = jsonDecode(encoded);
      if (decoded is! List) {
        return <UploadSpeciesFlowData>[];
      }
      final List<UploadSpeciesFlowData> drafts = decoded
          .whereType<Map>()
          .map(
            (Map<dynamic, dynamic> item) =>
                UploadSpeciesFlowData.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: true);
      bool updatedMissingIds = false;
      for (int i = 0; i < drafts.length; i++) {
        final UploadSpeciesFlowData draft = drafts[i];
        final String existingId = (draft.draftId ?? '').trim();
        if (existingId.isEmpty) {
          draft.draftId = _generatedDraftId(draft, i);
          updatedMissingIds = true;
        }
      }
      drafts.sort(
        (UploadSpeciesFlowData a, UploadSpeciesFlowData b) =>
            b.updatedAt.compareTo(a.updatedAt),
      );
      if (updatedMissingIds) {
        await _persist(drafts);
      }
      return drafts;
    } catch (_) {
      return <UploadSpeciesFlowData>[];
    }
  }

  static Future<void> saveDraft(UploadSpeciesFlowData source) async {
    final List<UploadSpeciesFlowData> drafts = await loadDrafts();
    if (source.draftId == null || source.draftId!.trim().isEmpty) {
      source.draftId = DateTime.now().microsecondsSinceEpoch.toString();
    }
    source.updatedAt = DateTime.now();
    // Local-first: persist immediately so saving a draft is instant and
    // works with no network at all, then sync to Supabase (visible on web
    // and other devices) in the background. syncUnsyncedDrafts() picks up
    // the resulting supabaseSightingId next time the drafts list opens.
    final UploadSpeciesFlowData toSave = source.copy();
    final int existingIndex = drafts.indexWhere(
      (UploadSpeciesFlowData draft) => draft.draftId == toSave.draftId,
    );
    if (existingIndex == -1) {
      drafts.insert(0, toSave);
    } else {
      drafts[existingIndex] = toSave;
    }
    await _persist(drafts);
    unawaited(_syncDraftToSupabase(source));
  }

  // Upsert the draft into species_sightings (+ sub-tables) via the Supabase
  // client so it is visible on the web and synced across devices. Routes
  // through submitNormalizedSighting so drafts land in the same normalized
  // shape DENR's review screens actually read.
  static Future<void> _syncDraftToSupabase(UploadSpeciesFlowData draft) async {
    try {
      await _doSyncDraftToSupabase(draft).timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('[DraftSync] FINAL FAIL for draft: $e');
    }
  }

  static Future<void> _doSyncDraftToSupabase(
    UploadSpeciesFlowData draft,
  ) async {
    final SupabaseClient supabase = Supabase.instance.client;
    final String? email = supabase.auth.currentUser?.email;
    if (email == null || email.isEmpty) return;
    final String entryId =
        'MOBILE-DRAFT-${draft.draftId ?? DateTime.now().microsecondsSinceEpoch}';
    final String researcherName = await _resolveResearcherName(supabase, email);
    final Map<String, dynamic> result = await submitNormalizedSighting(
      draft: draft,
      entryId: entryId,
      researcherEmail: email,
      researcherName: researcherName,
      reviewStatus: 'draft',
      existingSightingId: draft.supabaseSightingId,
    );
    final dynamic sightingId = result['sighting_id'];
    if (sightingId is int) {
      draft.supabaseSightingId = sightingId;
      debugPrint('[DraftSync] sighting_id=$sightingId');
    } else {
      debugPrint('[DraftSync] no sighting_id returned for $entryId');
    }
  }

  /// Syncs every local draft that has not yet reached Supabase.
  /// Called on draft-list open so drafts created before the sync fix
  /// are pushed automatically without the user having to re-save.
  static Future<void> syncUnsyncedDrafts() async {
    try {
      final List<UploadSpeciesFlowData> drafts = await loadDrafts();
      bool anyUpdated = false;
      for (final UploadSpeciesFlowData draft in drafts) {
        if (draft.supabaseSightingId == null) {
          await _syncDraftToSupabase(draft);
          if (draft.supabaseSightingId != null) {
            anyUpdated = true;
          }
        }
      }
      if (anyUpdated) {
        await _persist(drafts);
      }
    } catch (_) {}
  }

  static Future<void> deleteDraft(String draftId) async {
    final String normalizedId = draftId.trim();
    if (normalizedId.isEmpty) {
      return;
    }
    final List<UploadSpeciesFlowData> drafts = await loadDrafts();
    // Find the draft's Supabase sighting_id before removing it locally.
    final UploadSpeciesFlowData? found = drafts
        .cast<UploadSpeciesFlowData?>()
        .firstWhere(
          (UploadSpeciesFlowData? d) => d?.draftId == normalizedId,
          orElse: () => null,
        );
    if (found != null) {
      await _deleteFromSupabase(found);
    }
    drafts.removeWhere(
      (UploadSpeciesFlowData draft) => draft.draftId == normalizedId,
    );
    await _persist(drafts);
  }

  // Delete the corresponding species_sightings draft row from Supabase.
  static Future<void> _deleteFromSupabase(UploadSpeciesFlowData draft) async {
    try {
      final SupabaseClient supabase = Supabase.instance.client;
      if (supabase.auth.currentUser == null) return;
      final String entryId = 'MOBILE-DRAFT-${draft.draftId ?? ''}';
      if (draft.supabaseSightingId != null) {
        await supabase
            .from('species_sightings')
            .delete()
            .eq('sighting_id', draft.supabaseSightingId!)
            .eq('review_status', 'draft');
      } else {
        await supabase
            .from('species_sightings')
            .delete()
            .eq('entry_id', entryId)
            .eq('review_status', 'draft');
      }
    } catch (_) {
      // Non-fatal; local deletion still proceeds.
    }
  }

  static Future<void> deleteDraftData(UploadSpeciesFlowData source) async {
    final List<UploadSpeciesFlowData> drafts = await loadDrafts();
    if (drafts.isEmpty) {
      return;
    }
    final String normalizedId = (source.draftId ?? '').trim();
    if (normalizedId.isNotEmpty) {
      drafts.removeWhere(
        (UploadSpeciesFlowData draft) => draft.draftId == normalizedId,
      );
      await _persist(drafts);
      return;
    }
    final String sourceScientificName = source.scientificName.trim();
    final int sourceUpdatedAt = source.updatedAt.microsecondsSinceEpoch;
    final String sourceFirstImagePath = source.images.isNotEmpty
        ? source.images.first.path.trim()
        : '';
    drafts.removeWhere((UploadSpeciesFlowData draft) {
      final String draftScientificName = draft.scientificName.trim();
      final int draftUpdatedAt = draft.updatedAt.microsecondsSinceEpoch;
      final String draftFirstImagePath = draft.images.isNotEmpty
          ? draft.images.first.path.trim()
          : '';
      return draftScientificName == sourceScientificName &&
          draftUpdatedAt == sourceUpdatedAt &&
          draftFirstImagePath == sourceFirstImagePath;
    });
    await _persist(drafts);
  }

  static Future<void> clearAllDrafts() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftsKey);
  }

  static Future<void> _persist(List<UploadSpeciesFlowData> drafts) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      drafts
          .map((UploadSpeciesFlowData draft) => draft.toJson())
          .toList(growable: false),
    );
    await prefs.setString(_draftsKey, encoded);
  }
}

class DraftSubmissionException implements Exception {
  DraftSubmissionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Resolves the researcher's display name for `species_sightings.researcher_name`.
/// Prefers user_profiles (the cross-platform source of truth, kept in sync
/// by both this app and the web dashboard's profile editors) over the
/// app-local 'name' auth metadata key, since accounts created on the web
/// never populate that key and would otherwise submit with an empty name
/// — which is what caused the DENR dashboard to show the researcher's
/// email instead of their name for app-submitted sightings.
Future<String> _resolveResearcherName(
  SupabaseClient supabase,
  String userEmail,
) async {
  final String? authUserId = supabase.auth.currentUser?.id;
  if (authUserId != null) {
    try {
      final Map<String, dynamic>? row = await supabase
          .from('user_profiles')
          .select('full_name, first_name, last_name')
          .eq('id', authUserId)
          .maybeSingle();
      final String full = (row?['full_name'] as String?)?.trim() ?? '';
      if (full.isNotEmpty) return full;
      final String first = (row?['first_name'] as String?)?.trim() ?? '';
      final String last = (row?['last_name'] as String?)?.trim() ?? '';
      final String joined = <String>[
        first,
        last,
      ].where((String s) => s.isNotEmpty).join(' ');
      if (joined.isNotEmpty) return joined;
    } catch (_) {
      // Fall through to metadata-based resolution below.
    }
  }
  final Map<String, dynamic> userMeta = Map<String, dynamic>.from(
    supabase.auth.currentUser?.userMetadata ?? <String, dynamic>{},
  );
  final String metaName = (userMeta['name'] ?? '').toString().trim();
  if (metaName.isNotEmpty) return metaName;
  final String metaFirst = (userMeta['firstName'] ?? '').toString().trim();
  final String metaLast = (userMeta['lastName'] ?? '').toString().trim();
  final String metaJoined = <String>[
    metaFirst,
    metaLast,
  ].where((String s) => s.isNotEmpty).join(' ');
  if (metaJoined.isNotEmpty) return metaJoined;
  return userEmail.contains('@') ? userEmail.split('@').first : userEmail;
}

class UploadSpeciesDraftSubmissionApi {
  UploadSpeciesDraftSubmissionApi();
  void dispose() {}
  String _extractFileName(String path) {
    final String normalized = path.replaceAll('\\', '/').trim();
    if (normalized.isEmpty) return 'image.jpg';
    final List<String> segments = normalized.split('/');
    final String candidate = segments.isNotEmpty ? segments.last.trim() : '';
    return candidate.isNotEmpty ? candidate : 'image.jpg';
  }

  String _inferContentType(String fileName) {
    final String lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<String?> _uploadImage(
    SupabaseClient supabase,
    String imagePath,
    int index,
  ) async {
    Uint8List bytes;
    try {
      bytes = await XFile(imagePath).readAsBytes();
    } catch (_) {
      return null;
    }
    if (bytes.isEmpty) return null;
    final String fileName = _extractFileName(imagePath);
    final String storagePath =
        'sightings/${DateTime.now().millisecondsSinceEpoch}_${index}_$fileName';
    try {
      await supabase.storage
          .from(kStorageBucket)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: _inferContentType(fileName)),
          );
      return supabase.storage.from(kStorageBucket).getPublicUrl(storagePath);
    } catch (_) {
      return null;
    }
  }

  // Uploads every local (non-http) image in [draft], grouped by category,
  // returning parallel url/photographer lists ready for submitNormalizedSighting.
  Future<
    ({
      List<String> wholePlantUrls,
      List<String> wholePlantCredits,
      List<String> closeupFlowerUrls,
      List<String> closeupFlowerCredits,
      List<String> habitatUrls,
      List<String> habitatCredits,
    })
  >
  _uploadDraftImages(
    SupabaseClient supabase,
    UploadSpeciesFlowData draft,
  ) async {
    final List<Future<String?>> uploadFutures = <Future<String?>>[];
    for (int i = 0; i < draft.images.length; i++) {
      final String path = draft.images[i].path.trim();
      uploadFutures.add(
        path.isEmpty || path.startsWith('http')
            ? Future<String?>.value(path.isEmpty ? null : path)
            : _uploadImage(supabase, path, i),
      );
    }
    final List<String?> uploadedUrls = await Future.wait(uploadFutures);
    final List<String> wholePlantUrls = <String>[];
    final List<String> wholePlantCredits = <String>[];
    final List<String> closeupFlowerUrls = <String>[];
    final List<String> closeupFlowerCredits = <String>[];
    final List<String> habitatUrls = <String>[];
    final List<String> habitatCredits = <String>[];
    for (int i = 0; i < draft.images.length; i++) {
      final String? url = i < uploadedUrls.length ? uploadedUrls[i] : null;
      if (url == null || url.isEmpty) continue;
      switch (draft.images[i].category) {
        case 'whole_plant':
          wholePlantUrls.add(url);
          wholePlantCredits.add(draft.images[i].photoCredit);
          break;
        case 'closeup_flower':
          closeupFlowerUrls.add(url);
          closeupFlowerCredits.add(draft.images[i].photoCredit);
          break;
        case 'habitat_photo':
          habitatUrls.add(url);
          habitatCredits.add(draft.images[i].photoCredit);
          break;
      }
    }
    return (
      wholePlantUrls: wholePlantUrls,
      wholePlantCredits: wholePlantCredits,
      closeupFlowerUrls: closeupFlowerUrls,
      closeupFlowerCredits: closeupFlowerCredits,
      habitatUrls: habitatUrls,
      habitatCredits: habitatCredits,
    );
  }

  Future<Map<String, dynamic>> submitDraft(UploadSpeciesFlowData draft) async {
    // Route to UPDATE when this originated from a web (species_sightings) draft
    final String? draftId = draft.draftId;
    if (draftId != null && draftId.startsWith('WEB-SIGHTING-')) {
      final String sightingIdStr = draftId.substring('WEB-SIGHTING-'.length);
      return _updateWebSightingDraft(sightingIdStr, draft);
    }
    final SupabaseClient supabase = Supabase.instance.client;
    final String userEmail = supabase.auth.currentUser?.email ?? '';
    final String userName = await _resolveResearcherName(supabase, userEmail);
    final media = await _uploadDraftImages(supabase, draft);
    final String entryId = 'BLOOM-${DateTime.now().microsecondsSinceEpoch}';
    try {
      return await submitNormalizedSighting(
        draft: draft,
        entryId: entryId,
        researcherEmail: userEmail,
        researcherName: userName,
        reviewStatus: 'pending',
        existingSightingId: draft.supabaseSightingId,
        wholePlantPhotoUrls: media.wholePlantUrls,
        wholePlantPhotographers: media.wholePlantCredits,
        closeupFlowerPhotoUrls: media.closeupFlowerUrls,
        closeupFlowerPhotographers: media.closeupFlowerCredits,
        habitatPhotoUrls: media.habitatUrls,
        habitatPhotographers: media.habitatCredits,
      );
    } catch (e) {
      throw DraftSubmissionException('Submission failed: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> _updateWebSightingDraft(
    String sightingIdStr,
    UploadSpeciesFlowData draft,
  ) async {
    final SupabaseClient supabase = Supabase.instance.client;
    final String userEmail = supabase.auth.currentUser?.email ?? '';
    final String userName = await _resolveResearcherName(supabase, userEmail);
    final media = await _uploadDraftImages(supabase, draft);
    final int? id = int.tryParse(sightingIdStr);
    try {
      if (id == null) {
        // Fall back to entry_id lookup for the sighting_id upsertSub needs.
        final Map<String, dynamic>? existing = await supabase
            .from('species_sightings')
            .select('sighting_id')
            .eq('entry_id', sightingIdStr)
            .maybeSingle();
        final int? resolvedId = existing?['sighting_id'] as int?;
        if (resolvedId == null) {
          throw DraftSubmissionException(
            'Could not resolve sighting for entry_id $sightingIdStr',
          );
        }
        return await submitNormalizedSighting(
          draft: draft,
          entryId: sightingIdStr,
          researcherEmail: userEmail,
          researcherName: userName.isNotEmpty
              ? userName
              : draft.headResearcher.trim(),
          reviewStatus: 'pending',
          existingSightingId: resolvedId,
          wholePlantPhotoUrls: media.wholePlantUrls,
          wholePlantPhotographers: media.wholePlantCredits,
          closeupFlowerPhotoUrls: media.closeupFlowerUrls,
          closeupFlowerPhotographers: media.closeupFlowerCredits,
          habitatPhotoUrls: media.habitatUrls,
          habitatPhotographers: media.habitatCredits,
        );
      }
      final Map<String, dynamic> result = await submitNormalizedSighting(
        draft: draft,
        entryId: draft.entryId,
        researcherEmail: userEmail,
        researcherName: userName.isNotEmpty
            ? userName
            : draft.headResearcher.trim(),
        reviewStatus: 'pending',
        existingSightingId: id,
        wholePlantPhotoUrls: media.wholePlantUrls,
        wholePlantPhotographers: media.wholePlantCredits,
        closeupFlowerPhotoUrls: media.closeupFlowerUrls,
        closeupFlowerPhotographers: media.closeupFlowerCredits,
        habitatPhotoUrls: media.habitatUrls,
        habitatPhotographers: media.habitatCredits,
      );
      return <String, dynamic>{
        'status': 'submitted',
        'submissionCount': draft.images.length.toString(),
        'sighting_id': result['sighting_id'],
      };
    } catch (e) {
      throw DraftSubmissionException('Submission failed: ${e.toString()}');
    }
  }
}

class UploadSpeciesInformationScreen extends StatefulWidget {
  const UploadSpeciesInformationScreen({required this.flowData, super.key});
  final UploadSpeciesFlowData flowData;
  @override
  State<UploadSpeciesInformationScreen> createState() =>
      _UploadSpeciesInformationScreenState();
}

class _UploadSpeciesInformationScreenState
    extends State<UploadSpeciesInformationScreen> {
  late final UploadSpeciesFlowData _flowData;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _familyFieldKey = GlobalKey();
  final GlobalKey _genusFieldKey = GlobalKey();
  final GlobalKey _scientificNameFieldKey = GlobalKey();
  final GlobalKey _confidenceFieldKey = GlobalKey();
  final GlobalKey _dateFieldKey = GlobalKey();
  final GlobalKey _numberLocatedFieldKey = GlobalKey();
  String? _familyError;
  String? _genusError;
  String? _scientificNameError;
  String? _confidenceError;
  String? _dateError;
  String? _numberLocatedError;
  final TextEditingController _familyController = TextEditingController();
  final TextEditingController _genusController = TextEditingController();
  final TextEditingController _scientificNameController =
      TextEditingController();
  final List<TextEditingController> _commonNameControllers =
      <TextEditingController>[];
  final List<TextEditingController> _localNameControllers =
      <TextEditingController>[];
  final TextEditingController _numberLocatedController =
      TextEditingController();
  final FocusNode _genusFocusNode = FocusNode();
  final FocusNode _familyFocusNode = FocusNode();
  List<String> _genusSuggestions = <String>[];
  List<String> _speciesEpithetSuggestions = <String>[];
  static const int _maxCommonNames = 5;
  static const int _maxLocalNames = 5;
  static const List<String> _confidenceOptions = <String>[
    'Confirmed',
    'Probable',
    'Unidentified',
  ];
  String _identificationConfidence = 'Confirmed';
  static const List<String> _collectionMethodOptions = <String>[
    'Transect',
    'Quadrat',
    'Opportunistic',
    'Random Survey',
  ];
  static const List<String> _observationTypeOptions = <String>[
    'Live Specimen',
    'Flowering',
    'Fruiting',
    'Dead Specimen',
    'Photographic Only',
  ];
  // 'Yes' / 'No' / 'Unknown' / '' (unset) — tri-state, matching the web
  // dashboard's Endemic to the Philippines field.
  String _endemicToPhilippines = '';
  // DAO 2026-20 Auto-Detect status message shown under the Endemic to the
  // Philippines field, matching the web dashboard's autoDetectEndemicStatus().
  String? _endemicStatus;
  Color _endemicStatusColor = _uploadPrimary;
  DateTime? _observationDate;
  TimeOfDay? _observationTime;
  String? _selectedCollectionMethod;
  String? _selectedObservationType;
  bool _voucherSpecimenCollected = false;
  bool _isSavingDraft = false;
  void _autoFillScientificName() {
    final String genus = _genusController.text.trim();
    final String species = _familyController.text.trim();
    // Both fields set via the "Unknown" quick-fill button should collapse to
    // a single "Unknown" rather than concatenating into a garbage binomial
    // like "Unknown Unknown"/"Unknown unknown".
    if (genus.toLowerCase() == 'unknown' &&
        species.toLowerCase() == 'unknown') {
      _scientificNameController.text = 'Unknown';
      return;
    }
    final String autoFilled = <String>[
      genus,
      species,
    ].where((String s) => s.isNotEmpty).join(' ');
    _scientificNameController.text = autoFilled;
  }

  // Looks the Scientific Name up against the DAO 2026-20 orchid list and
  // fills in Endemic to the Philippines, using the endemism flag each
  // reference entry carries — mirrors the web dashboard's
  // autoDetectEndemicStatus(). DAO 2026-20 only covers threatened species,
  // so a species it doesn't list gives no endemism evidence either way —
  // that's recorded as "Unknown", not "No".
  void _autoDetectEndemicStatus() {
    final String sciName = _scientificNameController.text.trim();
    if (sciName.isEmpty) {
      setState(() {
        _endemicStatus = 'Enter the Scientific Name first.';
        _endemicStatusColor = const Color(0xFFB42318);
      });
      return;
    }
    final DaoOrchidRef? match = findDaoOrchidMatch(sciName);
    setState(() {
      if (match != null) {
        _endemicToPhilippines = match.endemic ? 'Yes' : 'No';
        _endemicStatus =
            'Matched "${match.fullName}" in DAO 2026-20 — set to '
            '${match.endemic ? 'Yes' : 'No'}.';
        _endemicStatusColor = _uploadPrimary;
      } else {
        _endemicToPhilippines = 'Unknown';
        _endemicStatus =
            '"$sciName" was not found in DAO 2026-20 — endemicity set to '
            'Unknown.';
        _endemicStatusColor = const Color(0xFF64748B);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _flowData = widget.flowData;
    _familyController.text = _flowData.family;
    _genusController.text = _flowData.genus;
    // Restore or auto-generate scientific name
    _scientificNameController.text = _flowData.scientificName.isNotEmpty
        ? _flowData.scientificName
        : <String>[
            _flowData.genus,
            _flowData.family,
          ].where((String s) => s.isNotEmpty).join(' ');
    _familyController.addListener(_autoFillScientificName);
    _genusController.addListener(_autoFillScientificName);
    final List<String> names = _flowData.commonNames.isNotEmpty
        ? _flowData.commonNames
        : <String>[''];
    for (final String name in names) {
      _commonNameControllers.add(TextEditingController(text: name));
    }
    final List<String> localNames = _flowData.localNames.isNotEmpty
        ? _flowData.localNames
        : <String>[''];
    for (final String name in localNames) {
      _localNameControllers.add(TextEditingController(text: name));
    }
    _identificationConfidence = _flowData.identificationConfidence;
    _numberLocatedController.text = _flowData.numberLocated;
    _endemicToPhilippines = _flowData.endemicToPhilippines;
    // Auto-set to today/now when empty, matching the web dashboard's
    // submission modal (still freely editable by the researcher).
    _observationDate = _flowData.observationDate.isEmpty
        ? DateTime.now()
        : (DateTime.tryParse(_flowData.observationDate) ?? DateTime.now());
    _observationTime = () {
      if (_flowData.observationTime.isEmpty) return TimeOfDay.now();
      final List<String> parts = _flowData.observationTime.split(':');
      if (parts.length >= 2) {
        final int? h = int.tryParse(parts[0]);
        final int? m = int.tryParse(parts[1]);
        if (h != null && m != null) return TimeOfDay(hour: h, minute: m);
      }
      return TimeOfDay.now();
    }();
    _selectedCollectionMethod = _flowData.collectionMethod.isEmpty
        ? null
        : _flowData.collectionMethod;
    _selectedObservationType = _flowData.observationType.isEmpty
        ? null
        : _flowData.observationType;
    _voucherSpecimenCollected = _flowData.voucherSpecimenCollected;
    _loadTaxonomySuggestions();
  }

  // Backs genus/species autocomplete with the same taxonomy tables the web
  // dashboard's suggestion picker uses (researcher-dashboard.html
  // loadSpeciesNameSuggestions): `genus` is the authoritative genus list,
  // and species epithets are derived from `orchids.sci_name` by stripping
  // the leading genus word — so both platforms suggest the same names.
  Widget _autocompleteOptionsView(
    BuildContext context,
    AutocompleteOnSelected<String> onSelected,
    Iterable<String> options,
  ) {
    final List<String> list = options.take(6).toList();
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220, maxWidth: 320),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: list.length,
            itemBuilder: (context, index) {
              final String option = list[index];
              return InkWell(
                onTap: () => onSelected(option),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Text(option, style: _uploadInputTextStyle),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _loadTaxonomySuggestions() async {
    try {
      final SupabaseClient supabase = Supabase.instance.client;
      final results = await Future.wait(<Future<List<dynamic>>>[
        supabase
            .from('genus')
            .select('genus_name')
            .order('genus_name', ascending: true),
        supabase
            .from('orchids')
            .select('sci_name')
            .order('sci_name', ascending: true),
      ]);
      final Set<String> genusNames = <String>{};
      for (final dynamic row in results[0]) {
        final String name =
            (row is Map ? row['genus_name'] : null)?.toString().trim() ?? '';
        if (name.isNotEmpty) genusNames.add(name);
      }
      final Set<String> epithets = <String>{};
      for (final dynamic row in results[1]) {
        final String sci =
            (row is Map ? row['sci_name'] : null)?.toString().trim() ?? '';
        if (sci.isEmpty) continue;
        final List<String> parts = sci.split(RegExp(r'\s+'));
        if (parts.length > 1) {
          final String epithet = parts.sublist(1).join(' ').trim();
          if (epithet.isNotEmpty) epithets.add(epithet);
        }
      }
      if (!mounted) return;
      setState(() {
        _genusSuggestions = genusNames.toList()..sort();
        _speciesEpithetSuggestions = epithets.toList()..sort();
      });
    } catch (error, stackTrace) {
      // Non-fatal: suggestions are a convenience, not a requirement to
      // submit. Logged (not swallowed silently) so a broken suggestions
      // list is visible in the debug console instead of just failing quiet.
      debugPrint('_loadTaxonomySuggestions failed: $error\n$stackTrace');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _genusFocusNode.dispose();
    _familyFocusNode.dispose();
    _familyController.removeListener(_autoFillScientificName);
    _genusController.removeListener(_autoFillScientificName);
    _familyController.dispose();
    _genusController.dispose();
    _scientificNameController.dispose();
    for (final TextEditingController c in _commonNameControllers) {
      c.dispose();
    }
    for (final TextEditingController c in _localNameControllers) {
      c.dispose();
    }
    _numberLocatedController.dispose();
    super.dispose();
  }

  void _syncFlowDataFromForm() {
    _flowData.family = _familyController.text.trim();
    _flowData.genus = _genusController.text.trim();
    _flowData.scientificName = _scientificNameController.text.trim();
    _flowData.commonNames = _commonNameControllers
        .map((TextEditingController c) => c.text.trim())
        .where((String s) => s.isNotEmpty)
        .toList();
    _flowData.localNames = _localNameControllers
        .map((TextEditingController c) => c.text.trim())
        .where((String s) => s.isNotEmpty)
        .toList();
    _flowData.identificationConfidence = _identificationConfidence;
    _flowData.endemicToPhilippines = _endemicToPhilippines;
    _flowData.observationDate = _observationDate != null
        ? '${_observationDate!.year.toString().padLeft(4, '0')}-'
              '${_observationDate!.month.toString().padLeft(2, '0')}-'
              '${_observationDate!.day.toString().padLeft(2, '0')}'
        : '';
    _flowData.observationTime = _observationTime != null
        ? '${_observationTime!.hour.toString().padLeft(2, '0')}:'
              '${_observationTime!.minute.toString().padLeft(2, '0')}'
        : '';
    _flowData.collectionMethod = (_selectedCollectionMethod ?? '').trim();
    _flowData.observationType = (_selectedObservationType ?? '').trim();
    _flowData.voucherSpecimenCollected = _voucherSpecimenCollected;
    _flowData.numberLocated = _numberLocatedController.text.trim();
  }

  Future<void> _openSpeciesSightingsForm() async {
    _syncFlowDataFromForm();
    setState(() {
      _familyError = null;
      _genusError = null;
      _scientificNameError = _flowData.scientificName.trim().isEmpty
          ? 'Scientific Name is required'
          : null;
      _confidenceError = null;
      _dateError = _flowData.observationDate.trim().isEmpty
          ? 'Date of observation is required'
          : null;
      _numberLocatedError = null;
    });
    GlobalKey? firstErrorKey;
    if (_scientificNameError != null) {
      firstErrorKey = _scientificNameFieldKey;
    } else if (_dateError != null) {
      firstErrorKey = _dateFieldKey;
    }
    if (firstErrorKey != null) {
      final BuildContext? ctx = firstErrorKey.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          alignment: 0.1,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UploadSpeciesSightingsScreen(flowData: _flowData),
      ),
    );
  }

  Future<void> _saveDraft() async {
    if (_isSavingDraft) return;
    setState(() => _isSavingDraft = true);
    try {
      _syncFlowDataFromForm();
      await UploadSpeciesDraftStore.saveDraft(_flowData);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Draft saved.')));
      Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save draft right now.')),
      );
    } finally {
      if (mounted) setState(() => _isSavingDraft = false);
    }
  }

  InputDecoration _fieldDecoration() {
    return _uploadInputDecoration();
  }

  Widget _dropdownField({
    required String hint,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    String? errorText,
  }) {
    return DropdownButtonFormField<String>(
      isDense: true,
      isExpanded: true,
      initialValue: _matchDropdownOption(value, options),
      items: options
          .map(
            (String option) =>
                DropdownMenuItem<String>(value: option, child: Text(option)),
          )
          .toList(growable: false),
      onChanged: onChanged,
      style: _uploadInputTextStyle,
      decoration: _fieldDecoration().copyWith(
        hintText: hint,
        hintStyle: _uploadHintTextStyle,
        errorText: errorText,
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(text, style: _uploadFieldLabelStyle);
  }

  Widget _unknownButton(VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: _uploadPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        minimumSize: const Size(0, 46),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: _uploadBorderColor, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: _uploadSubCardBg,
      ),
      child: const Text('Unknown', style: TextStyle(fontSize: 13)),
    );
  }

  Widget _pickerField({
    required String value,
    required String hint,
    required IconData icon,
    required VoidCallback onTap,
    String? errorText,
  }) {
    final bool hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: _surfaceColor,
              border: Border.all(
                color: hasError ? const Color(0xFFB00020) : _uploadBorderColor,
                width: hasError ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    value.isEmpty ? hint : value,
                    style: value.isEmpty
                        ? _uploadHintTextStyle
                        : _uploadInputTextStyle,
                  ),
                ),
                Icon(icon, size: 18, color: _uploadPrimary),
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(
              errorText,
              style: TextStyle(fontSize: 12, color: Color(0xFFB00020)),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _uploadBg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _UploadFormHeader(
                title: 'New Submission',
                sectionTitle: 'Basic Taxonomic Information',
                step: 1,
                totalSteps: 5,
                stepIcon: Icons.eco_outlined,
                entryId: _flowData.entryId,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // ── Species Information Card
                    _uploadFormCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.eco_outlined,
                                size: 16,
                                color: _uploadPrimary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Species Information',
                                style: _uploadSectionTitleStyle,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _fieldLabel('Genus *'),
                          const SizedBox(height: 6),
                          Row(
                            key: _genusFieldKey,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: RawAutocomplete<String>(
                                  textEditingController: _genusController,
                                  focusNode: _genusFocusNode,
                                  optionsBuilder: (TextEditingValue value) {
                                    final String query = value.text
                                        .trim()
                                        .toLowerCase();
                                    if (query.isEmpty)
                                      return const Iterable<String>.empty();
                                    return _genusSuggestions.where(
                                      (String s) =>
                                          s.toLowerCase().contains(query),
                                    );
                                  },
                                  fieldViewBuilder:
                                      (
                                        context,
                                        controller,
                                        focusNode,
                                        onFieldSubmitted,
                                      ) {
                                        return TextField(
                                          controller: controller,
                                          focusNode: focusNode,
                                          style: _uploadInputTextStyle,
                                          onChanged: (_) {
                                            if (_genusError != null) {
                                              setState(
                                                () => _genusError = null,
                                              );
                                            }
                                          },
                                          decoration: _fieldDecoration()
                                              .copyWith(errorText: _genusError),
                                        );
                                      },
                                  optionsViewBuilder:
                                      (context, onSelected, options) =>
                                          _autocompleteOptionsView(
                                            context,
                                            onSelected,
                                            options,
                                          ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _unknownButton(
                                () => setState(
                                  () => _genusController.text = 'Unknown',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _fieldLabel('Species'),
                          const SizedBox(height: 6),
                          Row(
                            key: _familyFieldKey,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: RawAutocomplete<String>(
                                  textEditingController: _familyController,
                                  focusNode: _familyFocusNode,
                                  optionsBuilder: (TextEditingValue value) {
                                    final String query = value.text
                                        .trim()
                                        .toLowerCase();
                                    if (query.isEmpty)
                                      return const Iterable<String>.empty();
                                    return _speciesEpithetSuggestions.where(
                                      (String s) =>
                                          s.toLowerCase().contains(query),
                                    );
                                  },
                                  fieldViewBuilder:
                                      (
                                        context,
                                        controller,
                                        focusNode,
                                        onFieldSubmitted,
                                      ) {
                                        return TextField(
                                          controller: controller,
                                          focusNode: focusNode,
                                          style: _uploadInputTextStyle,
                                          onChanged: (_) {
                                            if (_familyError != null) {
                                              setState(
                                                () => _familyError = null,
                                              );
                                            }
                                          },
                                          decoration: _fieldDecoration()
                                              .copyWith(
                                                hintText: 'e.g. amabilis',
                                                hintStyle: _uploadHintTextStyle,
                                                errorText: _familyError,
                                              ),
                                        );
                                      },
                                  optionsViewBuilder:
                                      (context, onSelected, options) =>
                                          _autocompleteOptionsView(
                                            context,
                                            onSelected,
                                            options,
                                          ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _unknownButton(
                                () => setState(
                                  () => _familyController.text = 'Unknown',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _fieldLabel(
                            'Scientific Name (Binomial Nomenclature) *',
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            key: _scientificNameFieldKey,
                            controller: _scientificNameController,
                            style: _uploadInputTextStyle.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                            decoration: _fieldDecoration().copyWith(
                              hintText:
                                  'Auto-filled from Genus + Species, or type manually',
                              hintStyle: _uploadHintTextStyle.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                              errorText: _scientificNameError,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _uploadFieldLabelWithTooltip(
                            'Vernacular / Common Names',
                            'Non-scientific names the orchid is known by, including local dialect and regional names.',
                          ),
                          const SizedBox(height: 6),
                          ...List<Widget>.generate(
                            _commonNameControllers.length,
                            (int i) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: TextField(
                                      controller: _commonNameControllers[i],
                                      style: _uploadInputTextStyle,
                                      decoration: _fieldDecoration().copyWith(
                                        hintText: 'Enter name ${i + 1}',
                                      ),
                                    ),
                                  ),
                                  if (_commonNameControllers.length >
                                      1) ...<Widget>[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _commonNameControllers[i].dispose();
                                          _commonNameControllers.removeAt(i);
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        size: 22,
                                        color: _uploadPrimary,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          if (_commonNameControllers.length < _maxCommonNames)
                            TextButton.icon(
                              onPressed: () => setState(
                                () => _commonNameControllers.add(
                                  TextEditingController(),
                                ),
                              ),
                              icon: const Icon(
                                Icons.add,
                                size: 16,
                                color: _uploadPrimary,
                              ),
                              label: const Text(
                                'Add another name',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _uploadPrimary,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          const SizedBox(height: 14),
                          _uploadFieldLabelWithTooltip(
                            'Local Names',
                            'Names used in local dialects or indigenous languages specific to the area where the orchid was found.',
                          ),
                          const SizedBox(height: 6),
                          ...List<Widget>.generate(
                            _localNameControllers.length,
                            (int i) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: TextField(
                                      controller: _localNameControllers[i],
                                      style: _uploadInputTextStyle,
                                      decoration: _fieldDecoration().copyWith(
                                        hintText: 'Enter local name ${i + 1}',
                                      ),
                                    ),
                                  ),
                                  if (_localNameControllers.length >
                                      1) ...<Widget>[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _localNameControllers[i].dispose();
                                          _localNameControllers.removeAt(i);
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        size: 22,
                                        color: _uploadPrimary,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          if (_localNameControllers.length < _maxLocalNames)
                            TextButton.icon(
                              onPressed: () => setState(
                                () => _localNameControllers.add(
                                  TextEditingController(),
                                ),
                              ),
                              icon: const Icon(
                                Icons.add,
                                size: 16,
                                color: _uploadPrimary,
                              ),
                              label: const Text(
                                'Add another local name',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _uploadPrimary,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          const SizedBox(height: 12),
                          _uploadFieldLabelWithTooltip(
                            'Taxonomic Identification Confidence',
                            'How certain you are of the species identification. Confirmed: verified by an expert. Probable: likely but not confirmed. Unidentified: species unknown.',
                          ),
                          const SizedBox(height: 6),
                          Column(
                            key: _confidenceFieldKey,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              _dropdownField(
                                hint: 'Select confidence level',
                                value: _identificationConfidence.isEmpty
                                    ? null
                                    : _identificationConfidence,
                                options: _confidenceOptions,
                                onChanged: (String? value) {
                                  if (value != null) {
                                    if (_confidenceError != null) {
                                      setState(() => _confidenceError = null);
                                    }
                                    setState(
                                      () => _identificationConfidence = value,
                                    );
                                  }
                                },
                                errorText: _confidenceError,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _uploadFieldLabelWithTooltip(
                            'Endemic to the Philippines',
                            'Species found naturally only in the Philippines and nowhere else in the world.',
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _dropdownField(
                                  hint: 'Select yes, no, or unknown',
                                  value: _endemicToPhilippines.isEmpty
                                      ? null
                                      : _endemicToPhilippines,
                                  options: const <String>[
                                    'Yes',
                                    'No',
                                    'Unknown',
                                  ],
                                  onChanged: (String? value) {
                                    if (value != null) {
                                      setState(() {
                                        _endemicToPhilippines = value;
                                        _endemicStatus = null;
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 46,
                                child: OutlinedButton(
                                  onPressed: _autoDetectEndemicStatus,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _uploadPrimary,
                                    side: const BorderSide(
                                      color: _uploadPrimary,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  child: const Text('Auto-Detect'),
                                ),
                              ),
                            ],
                          ),
                          if (_endemicStatus != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _endemicStatus!,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: _endemicStatusColor,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ── Observation / Collection Details Card
                    _uploadFormCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Row(
                            children: <Widget>[
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: _uploadPrimary,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Observation & Collection Details',
                                style: _uploadSectionTitleStyle,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  key: _dateFieldKey,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    _fieldLabel('Date of Observation *'),
                                    const SizedBox(height: 6),
                                    _pickerField(
                                      value: _observationDate != null
                                          ? '${_observationDate!.year.toString().padLeft(4, '0')}-'
                                                '${_observationDate!.month.toString().padLeft(2, '0')}-'
                                                '${_observationDate!.day.toString().padLeft(2, '0')}'
                                          : '',
                                      hint: 'Select date',
                                      icon: Icons.calendar_today_outlined,
                                      onTap: () async {
                                        final DateTime? picked =
                                            await showDatePicker(
                                              context: context,
                                              initialDate:
                                                  _observationDate ??
                                                  DateTime.now(),
                                              firstDate: DateTime(2000),
                                              lastDate: DateTime.now(),
                                            );
                                        if (picked != null) {
                                          if (_dateError != null) {
                                            setState(() => _dateError = null);
                                          }
                                          setState(
                                            () => _observationDate = picked,
                                          );
                                        }
                                      },
                                      errorText: _dateError,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    _fieldLabel('Time'),
                                    const SizedBox(height: 6),
                                    _pickerField(
                                      value: _observationTime != null
                                          ? _observationTime!.format(context)
                                          : '',
                                      hint: 'Select time',
                                      icon: Icons.access_time_outlined,
                                      onTap: () async {
                                        final TimeOfDay? picked =
                                            await showTimePicker(
                                              context: context,
                                              initialTime:
                                                  _observationTime ??
                                                  TimeOfDay.now(),
                                            );
                                        if (picked != null) {
                                          setState(
                                            () => _observationTime = picked,
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _uploadFieldLabelWithTooltip(
                            'Sampling Methodology',
                            'Method used to survey and locate the orchid. Transect: along a fixed line; Quadrat: within a bounded area; Opportunistic: casual sighting; Random Survey: no fixed pattern.',
                          ),
                          const SizedBox(height: 6),
                          _dropdownField(
                            hint: 'Select collection method',
                            value: _selectedCollectionMethod,
                            options: _collectionMethodOptions,
                            onChanged: (String? value) => setState(
                              () => _selectedCollectionMethod = value,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _uploadFieldLabelWithTooltip(
                            'Specimen Observation Type',
                            'Physical state of the orchid at the time of observation (e.g., alive and flowering, dead, or recorded only by photo).',
                          ),
                          const SizedBox(height: 6),
                          _dropdownField(
                            hint: 'Select observation type',
                            value: _selectedObservationType,
                            options: _observationTypeOptions,
                            onChanged: (String? value) => setState(
                              () => _selectedObservationType = value,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _uploadFieldLabelWithTooltip(
                            'Voucher Specimen Collected',
                            'Whether a physical specimen was taken and deposited in a herbarium for future scientific verification.',
                          ),
                          const SizedBox(height: 6),
                          _dropdownField(
                            hint: 'Select yes or no',
                            value: _voucherSpecimenCollected ? 'Yes' : 'No',
                            options: const <String>['Yes', 'No'],
                            onChanged: (String? value) {
                              if (value != null) {
                                setState(
                                  () => _voucherSpecimenCollected =
                                      value == 'Yes',
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          _fieldLabel('Number of Orchids in this Area'),
                          const SizedBox(height: 6),
                          Column(
                            key: _numberLocatedFieldKey,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              TextField(
                                controller: _numberLocatedController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: false,
                                      signed: false,
                                    ),
                                style: _uploadInputTextStyle,
                                onChanged: (_) {
                                  if (_numberLocatedError != null) {
                                    setState(() => _numberLocatedError = null);
                                  }
                                },
                                decoration: _fieldDecoration().copyWith(
                                  hintText: 'e.g. 25',
                                  errorText: _numberLocatedError,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _uploadNextButton(
                      onPressed: _openSpeciesSightingsForm,
                      label: 'Next — Location & Habitat',
                    ),
                    const SizedBox(height: 8),
                    _uploadSaveDraftButton(
                      onPressed: _isSavingDraft ? null : _saveDraft,
                      label: _isSavingDraft
                          ? 'Saving Draft...'
                          : 'Save as Draft',
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── DAO 2026-20 reference (Threat Level "Check DAO 2026-20" helper)
// Curated, offline reference data ported from
// BLOOOM-main/frontend/dao-2026-20-orchid-reference.js so the mobile app's
// Threat Level field has the same in-app guide the web researcher dashboard
// does. Sourced from DENR Administrative Order No. 2026-20, "Updated
// National List of Threatened Philippine Plants and Their Categories"
// (Sec. 4.9, Sec. 4.13, Sec. 6) — this replaced the app's earlier IUCN Red
// List-based reference now that DAO 2026-20 is the governing classification
// used for Philippine orchid conservation status.
class DaoCategoryDef {
  const DaoCategoryDef({
    required this.code,
    required this.label,
    required this.color,
    required this.bg,
    required this.definition,
    required this.criteria,
  });
  final String code;
  final String label;
  final Color color;
  final Color bg;
  final String definition;
  final String criteria;
}

const List<DaoCategoryDef> kDao202620Categories = <DaoCategoryDef>[
  DaoCategoryDef(
    code: 'CR',
    label: 'Critically Endangered',
    color: Color(0xFFB91C1C),
    bg: Color(0xFFFEF2F2),
    definition:
        'A species, subspecies, variety, or other infraspecific categories '
        'facing extremely high risk of extinction in the wild in the '
        'immediate future.',
    criteria: 'DAO 2026-20, Sec. 4.13.1.',
  ),
  DaoCategoryDef(
    code: 'EN',
    label: 'Endangered',
    color: Color(0xFFC2410C),
    bg: Color(0xFFFFF7ED),
    definition:
        'A species, subspecies, variety, or forma that is not critically '
        'endangered but whose survival in the wild is unlikely if the '
        'causal factors continue operating.',
    criteria: 'DAO 2026-20, Sec. 4.13.2.',
  ),
  DaoCategoryDef(
    code: 'VU',
    label: 'Vulnerable',
    color: Color(0xFFA16207),
    bg: Color(0xFFFEFCE8),
    definition:
        'A species or subspecies, variety, forma or other infraspecific '
        'categories of plant that is not critically endangered nor '
        'endangered but is under threat from adverse factors throughout '
        'its range and is likely to move to the endangered category in '
        'the future.',
    criteria: 'DAO 2026-20, Sec. 4.13.3.',
  ),
  DaoCategoryDef(
    code: 'OTS',
    label: 'Other Threatened Species',
    color: Color(0xFF6D28D9),
    bg: Color(0xFFF5F3FF),
    definition:
        'A species, subspecies, varieties, or other infraspecific '
        'categories that is not critically endangered, endangered nor '
        'vulnerable but is under threat from adverse factors, such as '
        'over collection throughout its range, and is likely to move to '
        'the vulnerable category in the near future.',
    criteria: 'DAO 2026-20, Sec. 4.13.4.',
  ),
  DaoCategoryDef(
    code: 'NL',
    label: 'Not Listed',
    color: Color(0xFF475569),
    bg: Color(0xFFF8FAFC),
    definition:
        'Not included in the DAO 2026-20 threatened plant list — treated '
        'as an Other Wildlife Species (OWS).',
    criteria:
        'DAO 2026-20, Sec. 4.9 / Sec. 7. Absence from the list is not a '
        'formal safety assessment; it means DENR has not placed this '
        'species in a threatened category.',
  ),
];

class DaoOrchidRef {
  const DaoOrchidRef({
    required this.sci,
    required this.fullName,
    required this.common,
    required this.genus,
    required this.category,
    required this.endemic,
  });
  final String sci;
  final String fullName;
  final String common;
  final String genus;
  final String category;
  final bool endemic;
}

// sci: clean binomial ("Genus species") used for matching against the
// submission form's Scientific Name field | fullName: exact name with
// authorship as printed in DAO 2026-20 | common: common/local name as
// printed (empty where DAO 2026-20 gives none) | category: code from
// kDao202620Categories | endemic: true where DAO 2026-20 marks the species
// with the endemism asterisk. Every Orchidaceae entry in DAO 2026-20 Sec. 6
// is included — all 108 species across Categories A-D.
const List<DaoOrchidRef> kDao202620OrchidReference = <DaoOrchidRef>[
  // -- Category A: Critically Endangered (32) ----------------------------
  DaoOrchidRef(
    sci: 'Amesiella monticola',
    fullName: 'Amesiella monticola Cootes & D.P.Banks',
    common: 'montane amesiella',
    genus: 'Amesiella',
    category: 'CR',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Bulbophyllum cootesii',
    fullName: 'Bulbophyllum cootesii M.A.Clem.',
    common: 'Cootes bulbophyllum',
    genus: 'Bulbophyllum',
    category: 'CR',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Ceratocentron fesselii',
    fullName: 'Ceratocentron fesselii Senghas',
    common: 'Fessel horned orchid',
    genus: 'Ceratocentron',
    category: 'CR',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Corybas boholensis',
    fullName: 'Corybas boholensis Tandang, R.Bustam., T.Reyes Jr. & S.P.Lyon',
    common: 'Bohol helmet orchid',
    genus: 'Corybas',
    category: 'CR',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Corybas hamiguitanensis',
    fullName: 'Corybas hamiguitanensis Tandang, Galindon & R.Bustam.',
    common: 'Hamiguitan helmet orchid',
    genus: 'Corybas',
    category: 'CR',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Corybas kaiganganianus',
    fullName: 'Corybas kaiganganianus Tandang, A.S.Rob. & M.D.Angeles',
    common: 'limestone helmet orchid',
    genus: 'Corybas',
    category: 'CR',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Dendrobium schuetzei',
    fullName: 'Dendrobium schuetzei Rolfe',
    common: 'Scheutze sanggumay',
    genus: 'Dendrobium',
    category: 'CR',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Gastrochilus calceolaris',
    fullName: 'Gastrochilus calceolaris (Buch.-Ham. ex Sm.) D.Don',
    common: '',
    genus: 'Gastrochilus',
    category: 'CR',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Grammatophyllum ravanii',
    fullName: 'Grammatophyllum ravanii D.Tiu',
    common: 'Ravan giant orchid',
    genus: 'Grammatophyllum',
    category: 'CR',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Grammatophyllum speciosum',
    fullName: 'Grammatophyllum speciosum Blume',
    common: 'malatubo, giant orchid',
    genus: 'Grammatophyllum',
    category: 'CR',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Grammatophyllum wallisii',
    fullName: 'Grammatophyllum wallisii Rchb.f',
    common: 'Wallis giant orchid',
    genus: 'Grammatophyllum',
    category: 'CR',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Mycaranthes leonardoi',
    fullName: 'Mycaranthes leonardoi Ferreras & Suarez',
    common: 'Leonardo mycaranthes',
    genus: 'Mycaranthes',
    category: 'CR',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Paphiopedilum acmodontum',
    fullName: 'Paphiopedilum acmodontum Schoser ex M.W.Wood',
    common: 'pointed-tooth lady slipper orchid',
    genus: 'Paphiopedilum',
    category: 'CR',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Paphiopedilum adductum',
    fullName: 'Paphiopedilum adductum Asher',
    common: 'Mindanao lady slipper orchid',
    genus: 'Paphiopedilum',
    category: 'CR',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Paphiopedilum argus',
    fullName: 'Paphiopedilum argus (Rchb.f.) Stein',
    common: 'spotted-petal lady slipper orchid',
    genus: 'Paphiopedilum',
    category: 'CR',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Paphiopedilum barbatum',
    fullName: 'Paphiopedilum barbatum (Lindl.) Pfitzer',
    common: 'bearded lady slipper orchid',
    genus: 'Paphiopedilum',
    category: 'CR',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Paphiopedilum ciliolare',
    fullName: 'Paphiopedilum ciliolare (Rchb.f.) Stein',
    common: 'short-haired lady slipper orchid',
    genus: 'Paphiopedilum',
    category: 'CR',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Paphiopedilum fowliei',
    fullName: 'Paphiopedilum fowliei Birk',
    common: 'Fowlie lady slipper orchid',
    genus: 'Paphiopedilum',
    category: 'CR',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Paphiopedilum haynaldianum',
    fullName: 'Paphiopedilum haynaldianum (Rchb.f.) Stein',
    common: 'Haynald lady slipper orchid',
    genus: 'Paphiopedilum',
    category: 'CR',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Paphiopedilum hennisianum',
    fullName: 'Paphiopedilum hennisianum (M.W.Wood) Fowlie',
    common: 'Hennis lady slipper orchid',
    genus: 'Paphiopedilum',
    category: 'CR',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Paphiopedilum lowii',
    fullName: 'Paphiopedilum lowii (Lindl.) Stein.',
    common: 'Low lady slipper orchid',
    genus: 'Paphiopedilum',
    category: 'CR',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Paphiopedilum parnatanum',
    fullName: 'Paphiopedilum parnatanum Cavestro',
    common: "Parnata's lady slipper orchid",
    genus: 'Paphiopedilum',
    category: 'CR',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Paphiopedilum philippinense',
    fullName: 'Paphiopedilum philippinense (Rchb.f.) Stein',
    common: 'Philippine lady slipper orchid',
    genus: 'Paphiopedilum',
    category: 'CR',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Paphiopedilum randsii',
    fullName: 'Paphiopedilum randsii Fowlie',
    common: 'Rands lady slipper orchid',
    genus: 'Paphiopedilum',
    category: 'CR',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Paphiopedilum urbanianum',
    fullName: 'Paphiopedilum urbanianum Fowlie',
    common: 'Urban lady slipper orchid',
    genus: 'Paphiopedilum',
    category: 'CR',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Phalaenopsis micholitzii',
    fullName: 'Phalaenopsis micholitzii Rolfe',
    common: 'Micholitz moth orchid',
    genus: 'Phalaenopsis',
    category: 'CR',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Phragmorchis teretifolia',
    fullName: 'Phragmorchis teretifolia L.O.Williams',
    common: '',
    genus: 'Phragmorchis',
    category: 'CR',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Renanthera caloptera',
    fullName: 'Renanthera caloptera (Rchb.f.) Kocyan & Schult.',
    common: '',
    genus: 'Renanthera',
    category: 'CR',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Stigmatodactylus aquamarinus',
    fullName: 'Stigmatodactylus aquamarinus A.S.Rob. & Gironella',
    common: '',
    genus: 'Stigmatodactylus',
    category: 'CR',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Stigmatodactylus dalagangpalawanicum',
    fullName: 'Stigmatodactylus dalagangpalawanicum A.S.Rob',
    common: '',
    genus: 'Stigmatodactylus',
    category: 'CR',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Vanda lamellata',
    fullName: 'Vanda lamellata Lindl.',
    common: 'bo-o',
    genus: 'Vanda',
    category: 'CR',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Vanda sanderiana',
    fullName: 'Vanda sanderiana Rchb.f.',
    common: 'waling-waling',
    genus: 'Vanda',
    category: 'CR',
    endemic: true,
  ),

  // -- Category B: Endangered (48) -----------------------------------------
  DaoOrchidRef(
    sci: 'Amesiella philippinensis',
    fullName: 'Amesiella philippinensis (Ames) Garay',
    common: 'Philippine amesiella',
    genus: 'Amesiella',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Aerides lawrenceae',
    fullName: 'Aerides lawrenceae Rchb.f.',
    common: "Lawrence cat's tail orchid",
    genus: 'Aerides',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Arachnis flos-aeris',
    fullName: 'Arachnis flos-aeris (L.) Rchb.f.',
    common: 'scorpion orchid',
    genus: 'Arachnis',
    category: 'EN',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Bulbophyllum cumingii',
    fullName: 'Bulbophyllum cumingii (Lindl.) Rchb.f.',
    common: 'Cuming bulbophyllum',
    genus: 'Bulbophyllum',
    category: 'EN',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Bulbophyllum facetum',
    fullName: 'Bulbophyllum facetum Garay, Hamer & Siegerist',
    common: '',
    genus: 'Bulbophyllum',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Bulbophyllum loherianum',
    fullName: 'Bulbophyllum loherianum (Kraenzl.) Ames',
    common: 'Loher bulbophyllum',
    genus: 'Bulbophyllum',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Bulbophyllum piestoglossum',
    fullName: 'Bulbophyllum piestoglossum J.J.Verm.',
    common: '',
    genus: 'Bulbophyllum',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Bulbophyllum nymphopolitanum',
    fullName: 'Bulbophyllum nymphopolitanum Kraenzl.',
    common: '',
    genus: 'Bulbophyllum',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Bulbophyllum savaiense',
    fullName:
        'Bulbophyllum savaiense Schltr. ssp. subcubicum (J.J.Sm.) J.J.Verm.',
    common: '',
    genus: 'Bulbophyllum',
    category: 'EN',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Bulbophyllum stellatum',
    fullName: 'Bulbophyllum stellatum Ames',
    common: '',
    genus: 'Bulbophyllum',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Cleisostoma sagittatum',
    fullName: 'Cleisostoma sagittatum Blume',
    common: '',
    genus: 'Cleisostoma',
    category: 'EN',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Coelogyne confusa',
    fullName: 'Coelogyne confusa Ames',
    common: '',
    genus: 'Coelogyne',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Coelogyne palawanensis',
    fullName: 'Coelogyne palawanensis Ames',
    common: 'Palawan coelogyne',
    genus: 'Coelogyne',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Corybas circinatus',
    fullName: 'Corybas circinatus Tandang & R.Bustam.',
    common: 'Palawan helmet orchid',
    genus: 'Corybas',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Corybas laceratus',
    fullName: 'Corybas laceratus L.O.Williams',
    common: 'saw-toothed helmet orchid',
    genus: 'Corybas',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Corybas merrillii',
    fullName: 'Corybas merrillii (Ames) Ames',
    common: 'Merrill helmet orchid',
    genus: 'Corybas',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Corybas ramosianus',
    fullName: 'Corybas ramosianus J.Dransf.',
    common: 'Ramos helmet orchid',
    genus: 'Corybas',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Cylindrolobus oliviacamposiae',
    fullName: 'Cylindrolobus oliviacamposiae Naive, Mabanta & Cootes',
    common: '',
    genus: 'Cylindrolobus',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Cymbidium aliciae',
    fullName: 'Cymbidium aliciae Quisumb.',
    common: '',
    genus: 'Cymbidium',
    category: 'EN',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Cymbidium ensifolium',
    fullName: 'Cymbidium ensifolium (L.) Sw.',
    common: '',
    genus: 'Cymbidium',
    category: 'EN',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Dendrobium bullenianum',
    fullName: 'Dendrobium bullenianum Rchb.f',
    common: 'Bullen dendrobium',
    genus: 'Dendrobium',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Dendrobium goldschmidtianum',
    fullName: 'Dendrobium goldschmidtianum Kraenzl.',
    common: 'Goldschmidt dendrobium',
    genus: 'Dendrobium',
    category: 'EN',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Dendrobium lunatum',
    fullName: 'Dendrobium lunatum Lindl.',
    common: 'Moonlight dendrobium',
    genus: 'Dendrobium',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Dendrochilum kopfii',
    fullName: 'Dendrochilum kopfii Luckel',
    common: 'Kopf dendrochilum',
    genus: 'Dendrochilum',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Grammatophyllum martae',
    fullName: 'Grammatophyllum martae Quisumb. ex Valmayor & D.Tiu',
    common: 'Marta dapugay',
    genus: 'Grammatophyllum',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Grammatophyllum measuresianum',
    fullName: 'Grammatophyllum measuresianum Sander',
    common: 'Measures dapugay',
    genus: 'Grammatophyllum',
    category: 'EN',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Phalaenopsis amabilis',
    fullName: 'Phalaenopsis amabilis (L.) Blume',
    common: 'mariposa',
    genus: 'Phalaenopsis',
    category: 'EN',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Phalaenopsis hieroglyphica',
    fullName: 'Phalaenopsis hieroglyphica (Rchb.f.) H.R.Sweet',
    common: 'hieroglyphic moth orchid',
    genus: 'Phalaenopsis',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Phalaenopsis lindenii',
    fullName: 'Phalaenopsis lindenii Loher',
    common: 'Linden moth orchid',
    genus: 'Phalaenopsis',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Phalaenopsis lueddemanniana',
    fullName: 'Phalaenopsis lueddemanniana Rchb.f.',
    common: 'Lueddemann moth orchid',
    genus: 'Phalaenopsis',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Phalaenopsis pallens',
    fullName: 'Phalaenopsis pallens (Lindl.) Rchb.f.',
    common: 'pale moth orchid',
    genus: 'Phalaenopsis',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Phalaenopsis philippinensis',
    fullName: 'Phalaenopsis philippinensis Golamco ex Fowlie & C.Z.Tsang',
    common: 'Philippine moth orchid',
    genus: 'Phalaenopsis',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Phalaenopsis pulchra',
    fullName: 'Phalaenopsis pulchra (Rchb.f.) H.R.Sweet',
    common: 'beautiful moth orchid',
    genus: 'Phalaenopsis',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Phalaenopsis reichenbachiana',
    fullName: 'Phalaenopsis reichenbachiana Rchb.f. & Sander',
    common: 'Reichenbach moth orchid',
    genus: 'Phalaenopsis',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Phalaenopsis sanderiana',
    fullName: 'Phalaenopsis sanderiana Rchb.f.',
    common: 'Sander moth orchid',
    genus: 'Phalaenopsis',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Phalaenopsis schilleriana',
    fullName: 'Phalaenopsis schilleriana Rchb.f.',
    common: 'Schiller moth orchid',
    genus: 'Phalaenopsis',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Phalaenopsis stuartiana',
    fullName: 'Phalaenopsis stuartiana Rchb.f.',
    common: 'Stuart moth orchid',
    genus: 'Phalaenopsis',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Pseuderia samarana',
    fullName: 'Pseuderia samarana Z.D.Meneses & Cootes',
    common: '',
    genus: 'Pseuderia',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Renanthera monachica',
    fullName: 'Renanthera monachica Ames',
    common: 'dancing lady fire orchid',
    genus: 'Renanthera',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Renanthera philippinensis',
    fullName: 'Renanthera philippinensis (Ames & Quisumb.) L.O.Williams',
    common: 'Philippine fire orchid',
    genus: 'Renanthera',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Renanthera storiei',
    fullName: 'Renanthera storiei Rchb.f.',
    common: 'Storie fire orchid',
    genus: 'Renanthera',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Trichoglottis fasciata',
    fullName: 'Trichoglottis fasciata Rchb.f.',
    common: 'hairy-lipped orchid',
    genus: 'Trichoglottis',
    category: 'EN',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Trichoglottis loheriana',
    fullName: 'Trichoglottis loheriana (Kraenzl.) L.O.Williams',
    common: 'Loher hairy-lipped orchid',
    genus: 'Trichoglottis',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Trichoglottis luzonensis',
    fullName: 'Trichoglottis luzonensis (Ames) Ames',
    common: 'Luzon hairy-lipped orchid',
    genus: 'Trichoglottis',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Vanda javierae',
    fullName: 'Vanda javierae D.Tiu ex Fessel & Luckel',
    common: 'Javier vanda',
    genus: 'Vanda',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Vanda luzonica',
    fullName: 'Vanda luzonica Loher ex Rolfe',
    common: 'Luzon vanda',
    genus: 'Vanda',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Vanda merrillii',
    fullName: 'Vanda merrillii Ames & Quisumb.',
    common: 'Merrill vanda',
    genus: 'Vanda',
    category: 'EN',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Vanda scandens',
    fullName: 'Vanda scandens Holttum',
    common: 'climbing vanda',
    genus: 'Vanda',
    category: 'EN',
    endemic: false,
  ),

  // -- Category C: Vulnerable (27) -----------------------------------------
  DaoOrchidRef(
    sci: 'Aerides leeana',
    fullName: 'Aerides leeana Rchb.f.',
    common: '',
    genus: 'Aerides',
    category: 'VU',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Aerides quinquevulnera',
    fullName: 'Aerides quinquevulnera Lindl.',
    common: 'five-wound aerides',
    genus: 'Aerides',
    category: 'VU',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Blepharoglossum palawanense',
    fullName: 'Blepharoglossum palawanense (Ames) L.Li',
    common: '',
    genus: 'Blepharoglossum',
    category: 'VU',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Bulbophyllum curranii',
    fullName: 'Bulbophyllum curranii Ames',
    common: 'Curran bulbophyllum',
    genus: 'Bulbophyllum',
    category: 'VU',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Bulbophyllum papulosum',
    fullName: 'Bulbophyllum papulosum Garay',
    common: '',
    genus: 'Bulbophyllum',
    category: 'VU',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Cymboglossum palawanense',
    fullName: 'Cymboglossum palawanense (Ames) Ormerod & Cootes',
    common: '',
    genus: 'Cymboglossum',
    category: 'VU',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Dendrobium nemorale',
    fullName: 'Dendrobium nemorale L.O.Williams',
    common: '',
    genus: 'Dendrobium',
    category: 'VU',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Dendrobium sanderae',
    fullName: 'Dendrobium sanderae Rolfe',
    common: 'Sander dendrobium',
    genus: 'Dendrobium',
    category: 'VU',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Dendrobium secundum',
    fullName: 'Dendrobium secundum (Blume) Lindl. ex Wall.',
    common: '',
    genus: 'Dendrobium',
    category: 'VU',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Dendrobium usterioides',
    fullName: 'Dendrobium usterioides Ames',
    common: '',
    genus: 'Dendrobium',
    category: 'VU',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Dendrobium victoria-reginae',
    fullName: 'Dendrobium victoria-reginae Loher',
    common: 'Queen Victoria dendrobium',
    genus: 'Dendrobium',
    category: 'VU',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Dendrochilum ignisiflorum',
    fullName: 'Dendrochilum ignisiflorum M.N.Tamayo & R.Bustam.',
    common: 'fire dendrochilum',
    genus: 'Dendrochilum',
    category: 'VU',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Dendrochilum kingii',
    fullName: 'Dendrochilum kingii (Hook.f.) J.J.Sm.',
    common: 'King dendrochilum',
    genus: 'Dendrochilum',
    category: 'VU',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Dilochia deleoniae',
    fullName: 'Dilochia deleoniae Tandang & Galindon',
    common: 'De Leon ground orchid',
    genus: 'Dilochia',
    category: 'VU',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Epigeneium stella-silvae',
    fullName: 'Epigeneium stella-silvae (Loher & Kraenzl.) Summerh.',
    common: 'Stella Silva epigeneium',
    genus: 'Epigeneium',
    category: 'VU',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Epigeneium treacherianum',
    fullName: 'Epigeneium treacherianum (Rchb.f ex Hook.f.) Summerh.',
    common: '',
    genus: 'Epigeneium',
    category: 'VU',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Grammatophyllum multiflorum',
    fullName: 'Grammatophyllum multiflorum Lindl.',
    common: 'rosa mia',
    genus: 'Grammatophyllum',
    category: 'VU',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Grammatophyllum scriptum',
    fullName: 'Grammatophyllum scriptum (L.) Blume',
    common: 'dapugay',
    genus: 'Grammatophyllum',
    category: 'VU',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Phalaenopsis aphrodite',
    fullName: 'Phalaenopsis aphrodite Rchb.f',
    common: 'aphrodite moth orchid',
    genus: 'Phalaenopsis',
    category: 'VU',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Phalaenopsis bastianii',
    fullName: 'Phalaenopsis bastianii O.Gruss & Roellke',
    common: 'mariposa',
    genus: 'Phalaenopsis',
    category: 'VU',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Phalaenopsis cornu-cervi',
    fullName: 'Phalaenopsis cornu-cervi (Breda) Blume & Rchb.f.',
    common: "deer's horn moth orchid",
    genus: 'Phalaenopsis',
    category: 'VU',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Phalaenopsis equestris',
    fullName: 'Phalaenopsis equestris (Schauer) Rchb.f',
    common: 'moth orchid',
    genus: 'Phalaenopsis',
    category: 'VU',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Phalaenopsis fasciata',
    fullName: 'Phalaenopsis fasciata Rchb.f.',
    common: '',
    genus: 'Phalaenopsis',
    category: 'VU',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Phalaenopsis mariae',
    fullName: 'Phalaenopsis mariae Burb. ex R.Warner & H.Williams',
    common: 'Maria moth orchid',
    genus: 'Phalaenopsis',
    category: 'VU',
    endemic: false,
  ),
  DaoOrchidRef(
    sci: 'Pinalia curranii',
    fullName: 'Pinalia curranii (Leav.) W.Suarez & Cootes',
    common: '',
    genus: 'Pinalia',
    category: 'VU',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Renanthera matutina',
    fullName: 'Renanthera matutina Lindl.',
    common: '',
    genus: 'Renanthera',
    category: 'VU',
    endemic: true,
  ),
  DaoOrchidRef(
    sci: 'Vandopsis lissochiloides',
    fullName: 'Vandopsis lissochiloides (Gaudich.) Pfitzer',
    common: '',
    genus: 'Vandopsis',
    category: 'VU',
    endemic: false,
  ),

  // -- Category D: Other Threatened Species (1) ----------------------------
  DaoOrchidRef(
    sci: 'Acanthophippium mantinianum',
    fullName: 'Acanthophippium mantinianum L.Linden & Cogn.',
    common: 'Mantin acanthophippium',
    genus: 'Acanthophippium',
    category: 'OTS',
    endemic: true,
  ),
];

DaoCategoryDef? _daoCategoryByCode(String code) {
  for (final DaoCategoryDef cat in kDao202620Categories) {
    if (cat.code == code) return cat;
  }
  return null;
}

// DAO 2026-20 category code -> the Threat Level dropdown option label used
// on the upload form (Page: Conservation & Threat Data).
const Map<String, String> kDao202620CategoryToThreatLevelOption =
    <String, String>{
      'CR': 'Critically Endangered',
      'EN': 'Endangered',
      'VU': 'Vulnerable',
      'OTS': 'Other Threatened Species',
    };

String _normalizeDaoSciName(String value) {
  final String v = value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  return v.endsWith('.') ? v.substring(0, v.length - 1) : v;
}

// Looks a Scientific Name up against the DAO 2026-20 orchid list — shared by
// the Threat Level and Endemicity auto-detect helpers on the upload form.
DaoOrchidRef? findDaoOrchidMatch(String scientificName) {
  final String target = _normalizeDaoSciName(scientificName);
  if (target.isEmpty) return null;
  for (final DaoOrchidRef ref in kDao202620OrchidReference) {
    if (_normalizeDaoSciName(ref.sci) == target) return ref;
  }
  return null;
}

Future<void> showDaoGuideDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (BuildContext context) => const _DaoGuideDialog(),
  );
}

class _DaoGuideDialog extends StatefulWidget {
  const _DaoGuideDialog();
  @override
  State<_DaoGuideDialog> createState() => _DaoGuideDialogState();
}

class _DaoGuideDialogState extends State<_DaoGuideDialog> {
  bool _searchTab = false;
  final TextEditingController _searchController = TextEditingController();
  String _categoryFilter = '';
  String _genusFilter = '';
  static const Color _headerStart = Color(0xFF145A1E);
  static const Color _headerEnd = Color(0xFF3D6C36);
  List<String> get _genusOptions {
    final List<String> genera =
        kDao202620OrchidReference
            .map((DaoOrchidRef s) => s.genus)
            .toSet()
            .toList()
          ..sort();
    return genera;
  }

  List<DaoOrchidRef> get _filteredSpecies {
    final String query = _searchController.text.trim().toLowerCase();
    return kDao202620OrchidReference
        .where((DaoOrchidRef s) {
          if (_categoryFilter.isNotEmpty && s.category != _categoryFilter) {
            return false;
          }
          if (_genusFilter.isNotEmpty && s.genus != _genusFilter) {
            return false;
          }
          if (query.isEmpty) return true;
          final String haystack =
              '${s.sci} ${s.fullName} ${s.common} ${s.genus}'.toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _tabButton(String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        margin: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? _headerStart : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isActive ? _headerStart : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGuideTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final DaoCategoryDef cat in kDao202620Categories)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cat.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cat.color.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${cat.label} (${cat.code})',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: cat.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cat.definition,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: cat.color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  cat.criteria,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSearchTab() {
    final List<DaoOrchidRef> results = _filteredSpecies;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: _uploadInputDecoration(
            hintText: 'Search scientific, common name, or genus...',
          ).copyWith(prefixIcon: const Icon(Icons.search_rounded, size: 18)),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: DropdownButtonFormField<String>(
                isDense: true,
                initialValue: _categoryFilter.isEmpty ? null : _categoryFilter,
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('All Categories'),
                  ),
                  for (final DaoCategoryDef cat in kDao202620Categories)
                    DropdownMenuItem<String>(
                      value: cat.code,
                      child: Text('${cat.label} (${cat.code})'),
                    ),
                ],
                onChanged: (String? value) =>
                    setState(() => _categoryFilter = value ?? ''),
                decoration: _uploadInputDecoration(hintText: 'All Categories'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                isDense: true,
                initialValue: _genusFilter.isEmpty ? null : _genusFilter,
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('All Genera'),
                  ),
                  for (final String genus in _genusOptions)
                    DropdownMenuItem<String>(value: genus, child: Text(genus)),
                ],
                onChanged: (String? value) =>
                    setState(() => _genusFilter = value ?? ''),
                decoration: _uploadInputDecoration(hintText: 'All Genera'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '${results.length} of ${kDao202620OrchidReference.length} DAO 2026-20 orchid species',
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 6),
        if (results.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No matches found.',
              style: TextStyle(
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                color: Color(0xFF94A3B8),
              ),
            ),
          )
        else
          for (final DaoOrchidRef s in results)
            Builder(
              builder: (BuildContext context) {
                final DaoCategoryDef? cat = _daoCategoryByCode(s.category);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Flexible(
                                      child: Text(
                                        s.sci,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontStyle: FontStyle.italic,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF145A1E),
                                        ),
                                      ),
                                    ),
                                    if (s.endemic) ...<Widget>[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0FDFA),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFF99F6E4),
                                          ),
                                        ),
                                        child: const Text(
                                          'Endemic',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F766E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  s.common.isEmpty
                                      ? 'No recorded common/local name'
                                      : s.common,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  s.fullName,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (cat != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: cat.bg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: cat.color),
                              ),
                              child: Text(
                                cat.label,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: cat.color,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        const SizedBox(height: 4),
        const Text(
          'This lists every orchid species in DENR Administrative Order '
          'No. 2026-20, "Updated National List of Threatened Philippine '
          'Plants and Their Categories." A species not appearing here is '
          'not formally placed in a threatened category by DENR — record '
          'it as "Not Listed," which is not the same as confirmed safe.',
          style: TextStyle(
            fontSize: 10.5,
            color: Color(0xFF94A3B8),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: screenSize.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[_headerStart, _headerEnd],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'DAO 2026-20 Reference Guide',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Official DENR AO No. 2026-20 threat categories — '
                          'no need to leave BLOOM.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFD1F2D8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Row(
                children: <Widget>[
                  _tabButton(
                    'DAO 2026-20 Threat Category Guide',
                    !_searchTab,
                    () => setState(() => _searchTab = false),
                  ),
                  _tabButton(
                    'Search Assessed Orchids',
                    _searchTab,
                    () => setState(() => _searchTab = true),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: _searchTab
                    ? _buildSearchTab()
                    : _buildCategoryGuideTab(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UploadSpeciesValueScreen extends StatefulWidget {
  const UploadSpeciesValueScreen({required this.flowData, super.key});
  final UploadSpeciesFlowData flowData;
  @override
  State<UploadSpeciesValueScreen> createState() =>
      _UploadSpeciesValueScreenState();
}

class _UploadSpeciesValueScreenState extends State<UploadSpeciesValueScreen> {
  late final UploadSpeciesFlowData _flowData;
  static const List<String> _ethnobotanicalOptions = <String>[
    'Medicinal use',
    'Traditional remedy',
    'Food flavoring',
    'Ritual and ceremonial use',
    'No documented use',
  ];
  static const List<String> _aestheticAppealOptions = <String>[
    'Large vibrant blooms',
    'Distinctive petal pattern',
    'Fragrant flowers',
    'Elegant growth habit',
    'High ornamental value',
  ];
  static const List<String> _cultivationOptions = <String>[
    'Easy to cultivate',
    'Moderate care required',
    'Advanced care required',
    'Best in greenhouse conditions',
    'Suitable for home growers',
  ];
  static const List<String> _culturalImportanceOptions = <String>[
    'Regional symbol species',
    'Used in local celebrations',
    'Important to indigenous knowledge',
    'Cultural heritage value',
    'No major cultural record',
  ];
  static const List<String> _lifeStageOptions = <String>[
    'Seedling',
    'Juvenile',
    'Mature',
  ];
  static const List<String> _phenologyOptions = <String>[
    'Vegetative',
    'Budding',
    'Flowering',
    'Fruiting',
  ];
  static const List<String> _populationStatusOptions = <String>[
    'Abundant',
    'Common',
    'Rare',
  ];
  static const List<String> _threatLevelOptions = <String>[
    'Critically Endangered',
    'Endangered',
    'Vulnerable',
    'Other Threatened Species',
    'Not Listed',
  ];
  static const List<String> _threatTypeOptions = <String>[
    'Logging',
    'Collection',
    'Fire',
    'Land Conversion',
  ];
  String? _selectedEthnobotanicalImportance;
  String? _selectedAestheticAppeal;
  String? _selectedCultivation;
  String? _selectedCulturalImportance;
  String? _selectedLifeStage;
  String? _selectedPhenology;
  String? _selectedPopulationStatus;
  String? _selectedThreatLevel;
  final List<String> _selectedThreatTypes = <String>[];
  bool _isSavingDraft = false;
  // "Type your own" mode per dropdown — lets a researcher enter a value
  // that isn't in the predefined list, saved to the DB as free text.
  bool _ethnobotanicalCustom = false;
  bool _aestheticCustom = false;
  bool _cultivationCustom = false;
  bool _culturalCustom = false;
  bool _lifeStageCustom = false;
  bool _phenologyCustom = false;
  bool _populationStatusCustom = false;
  bool _threatLevelCustom = false;
  final TextEditingController _ethnobotanicalCustomController =
      TextEditingController();
  final TextEditingController _aestheticCustomController =
      TextEditingController();
  final TextEditingController _cultivationCustomController =
      TextEditingController();
  final TextEditingController _culturalCustomController =
      TextEditingController();
  final TextEditingController _lifeStageCustomController =
      TextEditingController();
  final TextEditingController _phenologyCustomController =
      TextEditingController();
  final TextEditingController _populationStatusCustomController =
      TextEditingController();
  final TextEditingController _threatLevelCustomController =
      TextEditingController();
  final TextEditingController _threatTypeCustomController =
      TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _lifeStageKey = GlobalKey();
  final GlobalKey _phenologyKey = GlobalKey();
  final GlobalKey _populationStatusKey = GlobalKey();
  final GlobalKey _threatLevelKey = GlobalKey();
  String? _lifeStageError;
  String? _phenologyError;
  String? _populationStatusError;
  String? _threatLevelError;
  // DAO 2026-20 Auto-Detect status message shown under the Threat Level
  // field, matching the web dashboard's autoDetectThreatLevel() helper.
  String? _threatLevelStatus;
  Color _threatLevelStatusColor = const Color(0xFF145A1E);
  @override
  void initState() {
    super.initState();
    _flowData = widget.flowData;
    _selectedEthnobotanicalImportance = _seedEditable(
      _flowData.ethnobotanicalImportance,
      _ethnobotanicalOptions,
      _ethnobotanicalCustomController,
      (bool v) => _ethnobotanicalCustom = v,
    );
    _selectedAestheticAppeal = _seedEditable(
      _flowData.aestheticAppeal,
      _aestheticAppealOptions,
      _aestheticCustomController,
      (bool v) => _aestheticCustom = v,
    );
    _selectedCultivation = _seedEditable(
      _flowData.cultivation,
      _cultivationOptions,
      _cultivationCustomController,
      (bool v) => _cultivationCustom = v,
    );
    _selectedCulturalImportance = _seedEditable(
      _flowData.culturalImportance,
      _culturalImportanceOptions,
      _culturalCustomController,
      (bool v) => _culturalCustom = v,
    );
    _selectedLifeStage = _seedEditable(
      _flowData.lifeStage,
      _lifeStageOptions,
      _lifeStageCustomController,
      (bool v) => _lifeStageCustom = v,
    );
    _selectedPhenology = _seedEditable(
      _flowData.phenology,
      _phenologyOptions,
      _phenologyCustomController,
      (bool v) => _phenologyCustom = v,
    );
    _selectedPopulationStatus = _seedEditable(
      _flowData.populationStatus,
      _populationStatusOptions,
      _populationStatusCustomController,
      (bool v) => _populationStatusCustom = v,
    );
    _selectedThreatLevel = _seedEditable(
      _flowData.threatLevel,
      _threatLevelOptions,
      _threatLevelCustomController,
      (bool v) => _threatLevelCustom = v,
    );
    _selectedThreatTypes.addAll(
      _flowData.threatTypes.where((String t) => t.trim().isNotEmpty),
    );
    // Auto-run the DAO 2026-20 lookup once on load if Threat Level hasn't
    // been set yet, matching the "automatically input" behavior requested
    // for this field — still freely overridable via the dropdown or the
    // Auto-Detect button afterward.
    if ((_selectedThreatLevel ?? '').trim().isEmpty) {
      _applyThreatLevelDetection(silent: true);
    }
  }

  // Looks the Scientific Name (set on Page 1, Basic Taxonomic Information)
  // up against the DAO 2026-20 orchid list and fills in Threat Level —
  // mirrors the web dashboard's autoDetectThreatLevel(). The dropdown stays
  // enabled afterward so a researcher can still correct it by hand.
  void _applyThreatLevelDetection({bool silent = false}) {
    final String sciName = _flowData.scientificName.trim();
    if (sciName.isEmpty) {
      if (!silent) {
        _threatLevelStatus =
            'Enter the Scientific Name on Page 1 (Basic Taxonomic '
            'Information) first.';
        _threatLevelStatusColor = const Color(0xFFB42318);
      }
      return;
    }
    final DaoOrchidRef? match = findDaoOrchidMatch(sciName);
    if (match != null) {
      final String label =
          kDao202620CategoryToThreatLevelOption[match.category] ??
          match.category;
      _selectedThreatLevel = label;
      _threatLevelCustom = false;
      _threatLevelError = null;
      _threatLevelStatus =
          'Matched "${match.fullName}" in DAO 2026-20 — set to $label.';
      _threatLevelStatusColor = const Color(0xFF145A1E);
    } else {
      _selectedThreatLevel = 'Not Listed';
      _threatLevelCustom = false;
      _threatLevelError = null;
      _threatLevelStatus =
          '"$sciName" was not found in the DAO 2026-20 threatened list — '
          'set to Not Listed.';
      _threatLevelStatusColor = const Color(0xFF64748B);
    }
  }

  void _autoDetectThreatLevel() {
    setState(_applyThreatLevelDetection);
  }

  // Seeds a dropdown+type-your-own field: if the stored value isn't one of
  // the predefined options, treat it as a custom value the researcher typed
  // in previously and pre-fill the "type your own" text field with it.
  String? _seedEditable(
    String storedValue,
    List<String> options,
    TextEditingController customController,
    void Function(bool) setCustom,
  ) {
    final String v = storedValue.trim();
    if (v.isEmpty) return null;
    if (!options.contains(v)) {
      setCustom(true);
      customController.text = v;
    }
    return v;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _ethnobotanicalCustomController.dispose();
    _aestheticCustomController.dispose();
    _cultivationCustomController.dispose();
    _culturalCustomController.dispose();
    _lifeStageCustomController.dispose();
    _phenologyCustomController.dispose();
    _populationStatusCustomController.dispose();
    _threatLevelCustomController.dispose();
    _threatTypeCustomController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration() {
    return _uploadInputDecoration();
  }

  Widget _fieldLabel(String text) {
    return Text(text, style: _uploadFieldLabelStyle);
  }

  void _syncFlowDataFromForm() {
    _flowData.ethnobotanicalImportance =
        (_selectedEthnobotanicalImportance ?? '').trim();
    _flowData.aestheticAppeal = (_selectedAestheticAppeal ?? '').trim();
    _flowData.cultivation = (_selectedCultivation ?? '').trim();
    _flowData.culturalImportance = (_selectedCulturalImportance ?? '').trim();
    _flowData.lifeStage = (_selectedLifeStage ?? '').trim();
    _flowData.phenology = (_selectedPhenology ?? '').trim();
    _flowData.populationStatus = (_selectedPopulationStatus ?? '').trim();
    _flowData.threatLevel = (_selectedThreatLevel ?? '').trim();
    _flowData.threatTypes = List<String>.from(_selectedThreatTypes);
  }

  Future<void> _openImagesScreen() async {
    _syncFlowDataFromForm();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UploadSpeciesImagesScreen(flowData: _flowData),
      ),
    );
  }

  Future<void> _saveDraft() async {
    if (_isSavingDraft) return;
    setState(() => _isSavingDraft = true);
    try {
      _syncFlowDataFromForm();
      await UploadSpeciesDraftStore.saveDraft(_flowData);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Draft saved.')));
      Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save draft right now.')),
      );
    } finally {
      if (mounted) setState(() => _isSavingDraft = false);
    }
  }

  static const String _otherSentinel = 'Other';
  // Plain dropdown (no search box) that also lets the researcher type a
  // custom value when the one they need isn't in the predefined list
  // picking "Other" reveals a free-text field whose value is what actually
  // gets saved to the database.
  Widget _buildDropdownField({
    required String label,
    required String hint,
    required String? value,
    required List<String> options,
    required bool isCustom,
    required TextEditingController customController,
    required void Function(String? value, bool isCustom) onChanged,
    String? errorText,
    String? labelActionText,
    VoidCallback? onLabelAction,
  }) {
    final List<String> resolvedOptions = <String>[...options, _otherSentinel];
    final String? dropdownValue = isCustom
        ? _otherSentinel
        : _matchDropdownOption(value, options);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: <Widget>[
            _fieldLabel(label),
            if (onLabelAction != null && labelActionText != null) ...<Widget>[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onLabelAction,
                child: Text(
                  labelActionText,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _uploadPrimary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          isDense: true,
          isExpanded: true,
          initialValue: dropdownValue,
          items: resolvedOptions
              .map(
                (String option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(growable: false),
          onChanged: (String? picked) {
            if (picked == _otherSentinel) {
              onChanged(
                customController.text.trim().isEmpty
                    ? null
                    : customController.text.trim(),
                true,
              );
            } else {
              onChanged(picked, false);
            }
          },
          style: _uploadInputTextStyle,
          decoration: _fieldDecoration().copyWith(
            hintText: hint,
            errorText: errorText,
          ),
        ),
        if (isCustom) ...<Widget>[
          const SizedBox(height: 8),
          TextField(
            controller: customController,
            style: _uploadInputTextStyle,
            decoration: _fieldDecoration().copyWith(
              hintText: 'Type your own value',
            ),
            onChanged: (String text) =>
                onChanged(text.trim().isEmpty ? null : text.trim(), true),
          ),
        ],
      ],
    );
  }

  // Multi-select (chips, no search box) that also lets the researcher add
  // threat types beyond the predefined list — matches the web dashboard's
  // "choose one or more" checkbox group for Threat Type.
  Widget _buildThreatTypeField() {
    final List<String> customValues = _selectedThreatTypes
        .where((String t) => !_threatTypeOptions.contains(t))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _fieldLabel('Threat Type'),
        const SizedBox(height: 2),
        Text(
          'Choose one or more.',
          style: TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: _mutedTextColor,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final String option in _threatTypeOptions)
              FilterChip(
                label: Text(option),
                selected: _selectedThreatTypes.contains(option),
                onSelected: (bool isSelected) {
                  setState(() {
                    if (isSelected) {
                      _selectedThreatTypes.add(option);
                    } else {
                      _selectedThreatTypes.remove(option);
                    }
                  });
                },
              ),
            for (final String custom in customValues)
              InputChip(
                label: Text(custom),
                onDeleted: () {
                  setState(() => _selectedThreatTypes.remove(custom));
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _threatTypeCustomController,
                style: _uploadInputTextStyle,
                decoration: _fieldDecoration().copyWith(
                  hintText: 'Type your own threat type',
                ),
                onSubmitted: (_) => _addCustomThreatType(),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _addCustomThreatType,
              child: const Text('Add'),
            ),
          ],
        ),
      ],
    );
  }

  void _addCustomThreatType() {
    final String text = _threatTypeCustomController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      if (!_selectedThreatTypes.contains(text)) {
        _selectedThreatTypes.add(text);
      }
      _threatTypeCustomController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _uploadBg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _UploadFormHeader(
                title: 'New Submission',
                step: 4,
                totalSteps: 5,
                stepIcon: Icons.analytics_outlined,
                sectionTitle: 'Ecological & Value Data',
                entryId: _flowData.entryId,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // ── Ecological / Biological Data
                    _uploadFormCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Icon(
                                Icons.science_outlined,
                                size: 16,
                                color: _uploadPrimary,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Ecological / Biological Data',
                                style: _uploadSectionTitleStyle,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Column(
                            key: _lifeStageKey,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDropdownField(
                                label: 'Life Stage',
                                hint: 'Select life stage',
                                value: _selectedLifeStage,
                                options: _lifeStageOptions,
                                isCustom: _lifeStageCustom,
                                customController: _lifeStageCustomController,
                                errorText: _lifeStageError,
                                onChanged: (String? value, bool isCustom) {
                                  setState(() {
                                    _lifeStageError = null;
                                    _lifeStageCustom = isCustom;
                                    _selectedLifeStage = value;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Column(
                            key: _phenologyKey,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDropdownField(
                                label: 'Phenology',
                                hint: 'Select phenology',
                                value: _selectedPhenology,
                                options: _phenologyOptions,
                                isCustom: _phenologyCustom,
                                customController: _phenologyCustomController,
                                errorText: _phenologyError,
                                onChanged: (String? value, bool isCustom) {
                                  setState(() {
                                    _phenologyError = null;
                                    _phenologyCustom = isCustom;
                                    _selectedPhenology = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ── Conservation & Threat Data
                    _uploadFormCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Icon(
                                Icons.shield_outlined,
                                size: 16,
                                color: _uploadPrimary,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Conservation & Threat Data',
                                style: _uploadSectionTitleStyle,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Column(
                            key: _populationStatusKey,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDropdownField(
                                label: 'Population Status',
                                hint: 'Select population status',
                                value: _selectedPopulationStatus,
                                options: _populationStatusOptions,
                                isCustom: _populationStatusCustom,
                                customController:
                                    _populationStatusCustomController,
                                errorText: _populationStatusError,
                                onChanged: (String? value, bool isCustom) {
                                  setState(() {
                                    _populationStatusError = null;
                                    _populationStatusCustom = isCustom;
                                    _selectedPopulationStatus = value;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Column(
                            key: _threatLevelKey,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDropdownField(
                                label: 'Threat Level',
                                hint: 'Select threat level',
                                value: _selectedThreatLevel,
                                options: _threatLevelOptions,
                                isCustom: _threatLevelCustom,
                                customController: _threatLevelCustomController,
                                errorText: _threatLevelError,
                                labelActionText: '(Check DAO 2026-20)',
                                onLabelAction: () =>
                                    showDaoGuideDialog(context),
                                onChanged: (String? value, bool isCustom) {
                                  setState(() {
                                    _threatLevelError = null;
                                    _threatLevelCustom = isCustom;
                                    _selectedThreatLevel = value;
                                    _threatLevelStatus = null;
                                  });
                                },
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  onPressed: _autoDetectThreatLevel,
                                  icon: const Icon(
                                    Icons.auto_fix_high_rounded,
                                    size: 15,
                                  ),
                                  label: const Text('Auto-Detect'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _uploadPrimary,
                                    side: const BorderSide(
                                      color: _uploadPrimary,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ),
                              if (_threatLevelStatus != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _threatLevelStatus!,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: _threatLevelStatusColor,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildThreatTypeField(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ── Species Value
                    _uploadFormCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Icon(
                                Icons.star_outline_rounded,
                                size: 16,
                                color: _uploadPrimary,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Species Value',
                                style: _uploadSectionTitleStyle,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildDropdownField(
                            label: 'Ethnobotanical Importance',
                            hint: 'Select ethnobotanical importance',
                            value: _selectedEthnobotanicalImportance,
                            options: _ethnobotanicalOptions,
                            isCustom: _ethnobotanicalCustom,
                            customController: _ethnobotanicalCustomController,
                            onChanged: (String? value, bool isCustom) {
                              setState(() {
                                _ethnobotanicalCustom = isCustom;
                                _selectedEthnobotanicalImportance = value;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          _buildDropdownField(
                            label: 'Aesthetic Appeal',
                            hint: 'Select aesthetic appeal',
                            value: _selectedAestheticAppeal,
                            options: _aestheticAppealOptions,
                            isCustom: _aestheticCustom,
                            customController: _aestheticCustomController,
                            onChanged: (String? value, bool isCustom) {
                              setState(() {
                                _aestheticCustom = isCustom;
                                _selectedAestheticAppeal = value;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          _buildDropdownField(
                            label: 'Cultivation',
                            hint: 'Select cultivation level',
                            value: _selectedCultivation,
                            options: _cultivationOptions,
                            isCustom: _cultivationCustom,
                            customController: _cultivationCustomController,
                            onChanged: (String? value, bool isCustom) {
                              setState(() {
                                _cultivationCustom = isCustom;
                                _selectedCultivation = value;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          _buildDropdownField(
                            label: 'Cultural Importance',
                            hint: 'Select cultural importance',
                            value: _selectedCulturalImportance,
                            options: _culturalImportanceOptions,
                            isCustom: _culturalCustom,
                            customController: _culturalCustomController,
                            onChanged: (String? value, bool isCustom) {
                              setState(() {
                                _culturalCustom = isCustom;
                                _selectedCulturalImportance = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _uploadNextButton(
                      onPressed: _openImagesScreen,
                      label: 'Next — Media & Researchers',
                    ),
                    const SizedBox(height: 8),
                    _uploadSaveDraftButton(
                      onPressed: _isSavingDraft ? null : _saveDraft,
                      label: _isSavingDraft
                          ? 'Saving Draft...'
                          : 'Save as Draft',
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UploadSpeciesSightingsScreen extends StatefulWidget {
  const UploadSpeciesSightingsScreen({
    required this.flowData,
    this.flowTitle = 'New Submission',
    this.showSpeciesValueStep = true,
    super.key,
  });
  final UploadSpeciesFlowData flowData;
  final String flowTitle;
  final bool showSpeciesValueStep;
  @override
  State<UploadSpeciesSightingsScreen> createState() =>
      _UploadSpeciesSightingsScreenState();
}

class _UploadSpeciesSightingsScreenState
    extends State<UploadSpeciesSightingsScreen> {
  late final UploadSpeciesFlowData _flowData;
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _mountainController = TextEditingController();
  final TextEditingController _altitudeController = TextEditingController();
  final TextEditingController _elevationController = TextEditingController();
  static const List<String> _habitatTypeOptions = <String>[
    'lowland forest',
    'montane forest',
    'mossy forest',
    'Others',
  ];
  static const List<String> _microHabitatOptions = <String>[
    'Canopy',
    'understory',
    'forest floor',
    'rock surface',
  ];
  static const List<String> _specificSiteOptions = <String>[
    'trail',
    'ridge',
    'streamside',
    'Other',
  ];
  static const List<String> _growthSubstrateOptions = <String>[
    'tree bark',
    'soil',
    'rock',
    'decaying wood',
  ];
  static const List<String> _lightExposureOptions = <String>[
    'full shade',
    'partial',
    'direct',
  ];
  static const List<String> _soilTypeOptions = <String>[
    'Sandy soil',
    'Clay soil',
    'Loamy soil',
    'Rocky soil',
    'Volcanic soil',
    'Laterite soil',
  ];
  static const List<String> _nearbyWaterSourceOptions = <String>[
    'River',
    'Stream',
    'Spring',
    'Waterfall',
    'Seepage area',
    'None',
    'Unidentified',
  ];
  String? _selectedHabitatType;
  String? _selectedMicroHabitat;
  String? _selectedSpecificSite;
  String? _selectedGrowthSubstrate;
  String? _selectedLightExposure;
  String? _selectedSoilType;
  String? _selectedNearbyWaterSource;
  // "Which Trail" — mirrors the web dashboard's map_trails-backed dropdown
  // with GPS-proximity auto-suggestion (autoDetectTrailFromCoords).
  static const double _trailProximityMeters = 300;
  List<MapTrail> _trails = <MapTrail>[];
  bool _trailsLoading = false;
  String? _selectedTrailName;
  late TextEditingController _otherSpecificSiteController;
  late TextEditingController _otherHabitatTypeController;
  late TextEditingController _hostTreeSpeciesController;
  late TextEditingController _hostTreeDiameterController;
  late TextEditingController _canopyCoverController;
  bool _isResolvingLocation = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _locationFieldKey = GlobalKey();
  final GlobalKey _mountainFieldKey = GlobalKey();
  final GlobalKey _altitudeFieldKey = GlobalKey();
  final GlobalKey _elevationFieldKey = GlobalKey();
  final GlobalKey _habitatTypeFieldKey = GlobalKey();
  final GlobalKey _microHabitatFieldKey = GlobalKey();
  String? _locationError;
  String? _coordinateError;
  String? _mountainError;
  String? _altitudeError;
  String? _elevationError;
  String? _habitatTypeError;
  String? _microHabitatError;
  bool _isSavingDraft = false;
  @override
  void initState() {
    super.initState();
    _flowData = widget.flowData;
    _locationController.text = _flowData.location;
    _latitudeController.text = _flowData.latitude;
    _longitudeController.text = _flowData.longitude;
    _mountainController.text = 'Mt. Busa';
    _altitudeController.text = _flowData.altitude;
    _elevationController.text = _flowData.elevation;
    _latitudeController.addListener(_reverseGeocodeFromCoordinates);
    _longitudeController.addListener(_reverseGeocodeFromCoordinates);
    _latitudeController.addListener(_autoDetectTrailFromCoords);
    _longitudeController.addListener(_autoDetectTrailFromCoords);
    _selectedHabitatType = _flowData.habitatType.trim().isEmpty
        ? null
        : _flowData.habitatType.trim();
    _selectedMicroHabitat = _flowData.microHabitat.trim().isEmpty
        ? null
        : _flowData.microHabitat.trim();
    _selectedSpecificSite = _flowData.specificSiteZone.trim().isEmpty
        ? null
        : _flowData.specificSiteZone.trim();
    if (_selectedSpecificSite == 'trail') {
      _selectedTrailName = _flowData.specificSite.trim().isEmpty
          ? null
          : _flowData.specificSite.trim();
    }
    _selectedGrowthSubstrate = _flowData.growthSubstrate.trim().isEmpty
        ? null
        : _flowData.growthSubstrate.trim();
    _selectedLightExposure = _flowData.lightExposure.trim().isEmpty
        ? null
        : _flowData.lightExposure.trim();
    _selectedSoilType = _flowData.soilType.trim().isEmpty
        ? null
        : _flowData.soilType.trim();
    _selectedNearbyWaterSource = _flowData.nearbyWaterSource.trim().isEmpty
        ? null
        : _flowData.nearbyWaterSource.trim();
    _otherSpecificSiteController = TextEditingController(
      text: _selectedSpecificSite == 'Other' ? _flowData.specificSite : '',
    );
    _otherHabitatTypeController = TextEditingController();
    _hostTreeSpeciesController = TextEditingController(
      text: _flowData.hostTreeSpecies,
    );
    _hostTreeDiameterController = TextEditingController(
      text: _flowData.hostTreeDiameter,
    );
    _canopyCoverController = TextEditingController(text: _flowData.canopyCover);
    _loadTrails();
  }

  Future<void> _loadTrails() async {
    if (!mounted) return;
    setState(() => _trailsLoading = true);
    try {
      final List<MapTrail> trails = await MapTrailsCache.load();
      if (!mounted) return;
      setState(() {
        _trails = trails;
        _trailsLoading = false;
      });
      _autoDetectTrailFromCoords();
    } catch (_) {
      if (mounted) setState(() => _trailsLoading = false);
    }
  }

  // Local flat-earth projection distance from a point to a line segment
  // accurate enough over the few-km span of a mountain trail. Mirrors web's
  // distanceToSegmentMeters (researcher-dashboard.html).
  double _distanceToSegmentMeters(LatLng p, LatLng a, LatLng b) {
    const double mPerDegLat = 111320;
    final double mPerDegLng = 111320 * cos(a.latitude * pi / 180);
    final double px = (p.longitude - a.longitude) * mPerDegLng;
    final double py = (p.latitude - a.latitude) * mPerDegLat;
    final double bx = (b.longitude - a.longitude) * mPerDegLng;
    final double by = (b.latitude - a.latitude) * mPerDegLat;
    final double lenSq = bx * bx + by * by;
    double t = lenSq > 0 ? (px * bx + py * by) / lenSq : 0;
    t = t.clamp(0.0, 1.0);
    final double dx = px - t * bx;
    final double dy = py - t * by;
    return sqrt(dx * dx + dy * dy);
  }

  double _distanceToTrailMeters(LatLng p, MapTrail trail) {
    if (trail.points.isEmpty) return double.infinity;
    if (trail.points.length == 1) {
      return Geolocator.distanceBetween(
        p.latitude,
        p.longitude,
        trail.points.first.latitude,
        trail.points.first.longitude,
      );
    }
    double min = double.infinity;
    for (int i = 0; i < trail.points.length - 1; i++) {
      final double d = _distanceToSegmentMeters(
        p,
        trail.points[i],
        trail.points[i + 1],
      );
      if (d < min) min = d;
    }
    return min;
  }

  // Auto-suggests the nearest mapped trail once GPS coordinates are filled,
  // matching web's autoDetectTrailFromCoords — only when the researcher
  // hasn't already picked a trail themselves.
  void _autoDetectTrailFromCoords() {
    if (_trails.isEmpty || _selectedTrailName != null) return;
    final double? lat = double.tryParse(_latitudeController.text.trim());
    final double? lng = double.tryParse(_longitudeController.text.trim());
    if (lat == null || lng == null) return;
    MapTrail? best;
    double bestDistance = double.infinity;
    for (final MapTrail trail in _trails) {
      final double d = _distanceToTrailMeters(LatLng(lat, lng), trail);
      if (d < bestDistance) {
        bestDistance = d;
        best = trail;
      }
    }
    if (best == null || bestDistance > _trailProximityMeters) return;
    if (!mounted) return;
    setState(() {
      _selectedSpecificSite = 'trail';
      _selectedTrailName = best!.name;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _locationController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _mountainController.dispose();
    _altitudeController.dispose();
    _elevationController.dispose();
    _otherSpecificSiteController.dispose();
    _otherHabitatTypeController.dispose();
    _hostTreeSpeciesController.dispose();
    _hostTreeDiameterController.dispose();
    _canopyCoverController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration([String? hintText]) {
    return _uploadInputDecoration(hintText: hintText);
  }

  Widget _fieldLabel(String text) {
    return Text(text, style: _uploadFieldLabelStyle);
  }

  String _firstNonEmpty(Map<String, dynamic> address, List<String> keys) {
    for (final String key in keys) {
      final String value = (address[key] ?? '').toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  Future<void> _useGpsLocation() async {
    if (_isResolvingLocation) return;
    setState(() => _isResolvingLocation = true);
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enable location services to use GPS.'),
            ),
          );
        }
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is required.')),
          );
        }
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is permanently denied.'),
            ),
          );
        }
        return;
      }
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;
      String locationLabel =
          '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      String province = '';
      String municipality = '';
      try {
        final Uri uri = Uri.https(
          'nominatim.openstreetmap.org',
          '/reverse',
          <String, String>{
            'format': 'jsonv2',
            'lat': position.latitude.toString(),
            'lon': position.longitude.toString(),
          },
        );
        final http.Response response = await http.get(
          uri,
          headers: <String, String>{'User-Agent': 'bloom-mobile-upload/1.0'},
        );
        if (response.statusCode == 200) {
          final dynamic decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final dynamic addressDynamic = decoded['address'];
            if (addressDynamic is Map) {
              final Map<String, dynamic> address = Map<String, dynamic>.from(
                addressDynamic,
              );
              municipality = _firstNonEmpty(address, <String>[
                'municipality',
                'city',
                'town',
                'village',
              ]);
              province = _firstNonEmpty(address, <String>[
                'province',
                'state',
                'region',
              ]);
              final String resolved = <String>[
                municipality,
                province,
              ].where((String s) => s.isNotEmpty).join(', ');
              if (resolved.isNotEmpty) locationLabel = resolved;
            }
          }
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _locationController.text = locationLabel;
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
        _altitudeController.text = position.altitude.toStringAsFixed(1);
        // GPS altitude as an immediate placeholder; refined below by the
        // terrain-elevation lookup once it returns (matches web behavior).
        _elevationController.text = position.altitude.toStringAsFixed(1);
      });
      _flowData.province = province;
      _flowData.municipality = municipality;
      final double? terrainElevation = await fetchOpenElevationMeters(
        position.latitude,
        position.longitude,
      );
      if (terrainElevation != null && mounted) {
        setState(() {
          _elevationController.text = terrainElevation.toStringAsFixed(1);
        });
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to get the current GPS location.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResolvingLocation = false);
    }
  }

  Future<void> _reverseGeocodeFromCoordinates() async {
    final double? lat = double.tryParse(_latitudeController.text.trim());
    final double? lng = double.tryParse(_longitudeController.text.trim());
    if (lat == null || lng == null) return;
    if (!mounted) return;
    setState(() => _isResolvingLocation = true);
    try {
      final Uri uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/reverse',
        <String, String>{
          'format': 'jsonv2',
          'lat': lat.toString(),
          'lon': lng.toString(),
        },
      );
      final http.Response response = await http.get(
        uri,
        headers: <String, String>{'User-Agent': 'bloom-mobile-upload/1.0'},
      );
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final dynamic addressDynamic = decoded['address'];
          if (addressDynamic is Map) {
            final Map<String, dynamic> address = Map<String, dynamic>.from(
              addressDynamic,
            );
            final String municipality = _firstNonEmpty(address, <String>[
              'municipality',
              'city',
              'town',
              'village',
            ]);
            final String province = _firstNonEmpty(address, <String>[
              'province',
              'state',
              'region',
            ]);
            final String resolved = <String>[
              municipality,
              province,
            ].where((String s) => s.isNotEmpty).join(', ');
            if (!mounted) return;
            setState(() {
              if (resolved.isNotEmpty) {
                _locationController.text = resolved;
              } else {
                _locationController.text =
                    '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
              }
            });
            _flowData.province = province;
            _flowData.municipality = municipality;
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isResolvingLocation = false);
    final double? terrainElevation = await fetchOpenElevationMeters(lat, lng);
    if (terrainElevation != null && mounted) {
      setState(() {
        _elevationController.text = terrainElevation.toStringAsFixed(1);
      });
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    String? hintText,
    TextInputType? keyboardType,
  }) {
    return SizedBox(
      height: 34,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: _fieldDecoration(hintText),
      ),
    );
  }

  List<String> _optionsWithExistingValue(
    List<String> options,
    String? selectedValue,
  ) {
    final String normalized = (selectedValue ?? '').trim();
    if (normalized.isEmpty || options.contains(normalized)) {
      return options;
    }
    return <String>[normalized, ...options];
  }

  Widget _buildSearchableDropdownField({
    required String label,
    required String hint,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    String? tooltip,
  }) {
    final List<String> resolvedOptions = _optionsWithExistingValue(
      options,
      value,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tooltip != null
            ? _uploadFieldLabelWithTooltip(label, tooltip)
            : _fieldLabel(label),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          isDense: true,
          isExpanded: true,
          initialValue: _matchDropdownOption(value, resolvedOptions),
          items: resolvedOptions
              .map(
                (String option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(growable: false),
          onChanged: onChanged,
          style: _uploadInputTextStyle,
          decoration: _uploadInputDecoration(hintText: hint),
        ),
      ],
    );
  }

  void _syncFlowDataFromForm() {
    _flowData.location = _locationController.text.trim();
    _flowData.latitude = _latitudeController.text.trim();
    _flowData.longitude = _longitudeController.text.trim();
    _flowData.mountain = 'Mt. Busa';
    _flowData.altitude = _altitudeController.text.trim();
    _flowData.elevation = _elevationController.text.trim();
    _flowData.habitatType = (_selectedHabitatType ?? '').trim();
    if (_selectedHabitatType == 'Others') {
      _flowData.habitatType = _otherHabitatTypeController.text.trim();
    }
    _flowData.microHabitat = (_selectedMicroHabitat ?? '').trim();
    _flowData.specificSiteZone = (_selectedSpecificSite ?? '').trim();
    // specific_site_other mirrors web: trail name when zone is "trail", the
    // free-text description when "Other", empty otherwise (ridge/streamside
    // carry no extra text — the zone value itself is enough).
    if (_selectedSpecificSite == 'trail') {
      _flowData.specificSite = (_selectedTrailName ?? '').trim();
    } else if (_selectedSpecificSite == 'Other') {
      _flowData.specificSite = _otherSpecificSiteController.text.trim();
    } else {
      _flowData.specificSite = '';
    }
    _flowData.growthSubstrate = (_selectedGrowthSubstrate ?? '').trim();
    _flowData.hostTreeSpecies = _selectedGrowthSubstrate == 'tree bark'
        ? _hostTreeSpeciesController.text.trim()
        : '';
    _flowData.hostTreeDiameter = _selectedGrowthSubstrate == 'tree bark'
        ? _hostTreeDiameterController.text.trim()
        : '';
    _flowData.canopyCover = _canopyCoverController.text.trim();
    _flowData.lightExposure = (_selectedLightExposure ?? '').trim();
    _flowData.soilType = (_selectedSoilType ?? '').trim();
    _flowData.nearbyWaterSource = (_selectedNearbyWaterSource ?? '').trim();
  }

  Future<void> _showNextPlaceholder() async {
    _syncFlowDataFromForm();
    setState(() {
      _locationError = null;
      _coordinateError = null;
      _mountainError = null;
      _altitudeError = null;
      _elevationError = null;
      _habitatTypeError = null;
      _microHabitatError = null;
    });
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UploadSpeciesMorphologyScreen(
          flowData: _flowData,
          showSpeciesValueStep: widget.showSpeciesValueStep,
        ),
      ),
    );
  }

  Future<void> _saveDraft() async {
    if (_isSavingDraft) return;
    setState(() => _isSavingDraft = true);
    try {
      _syncFlowDataFromForm();
      await UploadSpeciesDraftStore.saveDraft(_flowData);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Draft saved.')));
      Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save draft right now.')),
      );
    } finally {
      if (mounted) setState(() => _isSavingDraft = false);
    }
  }

  List<Widget> _buildSightingDetailsForm() {
    return <Widget>[
      const SizedBox(height: 10),
      _buildSearchableDropdownField(
        label: 'Growth Substrate',
        hint: 'Select growth substrate',
        value: _selectedGrowthSubstrate,
        options: _growthSubstrateOptions,
        tooltip:
            'The surface or material the orchid grows on (e.g., tree bark, rock, soil, or another plant).',
        onChanged: (String? value) {
          setState(() {
            _selectedGrowthSubstrate = value;
          });
        },
      ),
      if (_selectedGrowthSubstrate == 'tree bark') ...<Widget>[
        const SizedBox(height: 10),
        _fieldLabel('Tree Species'),
        const SizedBox(height: 4),
        _buildField(
          controller: _hostTreeSpeciesController,
          hintText: 'Enter host tree species',
        ),
        const SizedBox(height: 6),
        _uploadFieldLabelWithTooltip(
          'Diameter / DBH (cm)',
          'Diameter at Breast Height — trunk diameter measured at 1.3 m above ground on the host tree.',
        ),
        const SizedBox(height: 4),
        _buildField(
          controller: _hostTreeDiameterController,
          hintText: 'Enter DBH in cm',
          keyboardType: TextInputType.number,
        ),
      ],
      const SizedBox(height: 10),
      _fieldLabel('Environmental Data'),
      const SizedBox(height: 8),
      _uploadFieldLabelWithTooltip(
        'Canopy Cover (%)',
        'Estimated percentage of the sky blocked by tree canopy directly above the orchid (0 = open sky, 100 = fully covered).',
      ),
      const SizedBox(height: 4),
      _buildField(
        controller: _canopyCoverController,
        hintText: 'Enter percentage (0-100)',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      const SizedBox(height: 8),
      _buildSearchableDropdownField(
        label: 'Light Exposure',
        hint: 'Select light exposure',
        value: _selectedLightExposure,
        options: _lightExposureOptions,
        tooltip:
            'Amount of sunlight the orchid receives at its location (e.g., full sun, partial shade, or deep shade).',
        onChanged: (String? value) {
          setState(() {
            _selectedLightExposure = value;
          });
        },
      ),
      const SizedBox(height: 8),
      Column(
        key: _habitatTypeFieldKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildSearchableDropdownField(
            label: 'Habitat Type',
            hint: 'Select habitat type',
            value: _selectedHabitatType,
            options: _habitatTypeOptions,
            tooltip:
                'General type of forest or environment where the orchid was observed (e.g., lowland forest, mossy forest).',
            onChanged: (String? value) {
              if (_habitatTypeError != null) {
                setState(() => _habitatTypeError = null);
              }
              setState(() {
                _selectedHabitatType = value;
              });
            },
          ),
          if (_selectedHabitatType == 'Others') ...<Widget>[
            const SizedBox(height: 8),
            _fieldLabel('Specify Habitat Type'),
            const SizedBox(height: 4),
            _buildField(
              controller: _otherHabitatTypeController,
              hintText: 'Enter habitat type',
            ),
          ],
          if (_habitatTypeError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 12),
              child: Text(
                _habitatTypeError!,
                style: TextStyle(fontSize: 12, color: Color(0xFFB00020)),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Column(
        key: _microHabitatFieldKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildSearchableDropdownField(
            label: 'Microhabitat',
            hint: 'Select microhabitat',
            value: _selectedMicroHabitat,
            options: _microHabitatOptions,
            tooltip:
                'Specific micro-location within the broader habitat where the orchid was found (e.g., canopy, understory, forest floor).',
            onChanged: (String? value) {
              if (_microHabitatError != null) {
                setState(() => _microHabitatError = null);
              }
              setState(() {
                _selectedMicroHabitat = value;
              });
            },
          ),
          if (_microHabitatError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 12),
              child: Text(
                _microHabitatError!,
                style: TextStyle(fontSize: 12, color: Color(0xFFB00020)),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      _buildSearchableDropdownField(
        label: 'Soil Type',
        hint: 'Select soil type',
        value: _selectedSoilType,
        options: _soilTypeOptions,
        onChanged: (String? value) {
          setState(() {
            _selectedSoilType = value;
          });
        },
      ),
      const SizedBox(height: 8),
      _buildSearchableDropdownField(
        label: 'Nearby Water Source',
        hint: 'Select water source',
        value: _selectedNearbyWaterSource,
        options: _nearbyWaterSourceOptions,
        onChanged: (String? value) {
          setState(() {
            _selectedNearbyWaterSource = value;
          });
        },
      ),
      const SizedBox(height: 24),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _uploadBg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _UploadFormHeader(
                title: widget.flowTitle,
                sectionTitle: 'Location & Habitat',
                step: 2,
                totalSteps: 5,
                stepIcon: Icons.location_on_outlined,
                entryId: _flowData.entryId,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // ── Geographical Location Card
                    _uploadFormCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Row(
                            children: <Widget>[
                              Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: _uploadPrimary,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Geographical / Location Data',
                                style: _uploadSectionTitleStyle,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _fieldLabel('GPS Location'),
                          const SizedBox(height: 6),
                          Column(
                            key: _locationFieldKey,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              _uploadSubCard(
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: TextField(
                                        controller: _locationController,
                                        readOnly: true,
                                        style: _uploadInputTextStyle,
                                        decoration: _fieldDecoration(
                                          'Tap Acquire GPS to fill location',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton.icon(
                                      onPressed: _isResolvingLocation
                                          ? null
                                          : _useGpsLocation,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _uploadPrimary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        elevation: 0,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      icon: Icon(
                                        _isResolvingLocation
                                            ? Icons.sync_rounded
                                            : Icons.my_location_rounded,
                                        size: 16,
                                      ),
                                      label: Text(
                                        _isResolvingLocation
                                            ? 'Locating...'
                                            : 'Use GPS',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_locationError != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 6,
                                    left: 12,
                                  ),
                                  child: Text(
                                    _locationError!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFB00020),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _uploadFieldLabelWithTooltip(
                            'GPS Coordinates',
                            'Precise geographic coordinates (latitude and longitude) of where the orchid was observed.',
                          ),
                          const SizedBox(height: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        _fieldLabel('Latitude'),
                                        const SizedBox(height: 4),
                                        TextField(
                                          controller: _latitudeController,
                                          style: _uploadInputTextStyle,
                                          keyboardType: TextInputType.number,
                                          onChanged: (_) {
                                            if (_coordinateError != null) {
                                              setState(
                                                () => _coordinateError = null,
                                              );
                                            }
                                          },
                                          decoration: _fieldDecoration(
                                            'e.g. 7.123456',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        _fieldLabel('Longitude'),
                                        const SizedBox(height: 4),
                                        TextField(
                                          controller: _longitudeController,
                                          style: _uploadInputTextStyle,
                                          keyboardType: TextInputType.number,
                                          onChanged: (_) {
                                            if (_coordinateError != null) {
                                              setState(
                                                () => _coordinateError = null,
                                              );
                                            }
                                          },
                                          decoration: _fieldDecoration(
                                            'e.g. 125.123456',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (_coordinateError != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 6,
                                    left: 12,
                                  ),
                                  child: Text(
                                    _coordinateError!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFB00020),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _fieldLabel('Mountain / General Location'),
                          const SizedBox(height: 6),
                          Column(
                            key: _mountainFieldKey,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              _buildField(
                                controller: _mountainController,
                                hintText: 'Mt. Busa',
                              ),
                              if (_mountainError != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 6,
                                    left: 12,
                                  ),
                                  child: Text(
                                    _mountainError!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFB00020),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSearchableDropdownField(
                            label: 'Specific Site / Ecological Zone',
                            hint: 'Trail, Ridge, Streamside, Others…',
                            value: _selectedSpecificSite,
                            options: _specificSiteOptions,
                            onChanged: (String? value) => setState(() {
                              _selectedSpecificSite = value;
                              if (value != 'trail') {
                                _selectedTrailName = null;
                              }
                            }),
                          ),
                          if (_selectedSpecificSite == 'Other') ...<Widget>[
                            const SizedBox(height: 10),
                            _fieldLabel('Specify Alternative Site'),
                            const SizedBox(height: 6),
                            _buildField(
                              controller: _otherSpecificSiteController,
                              hintText: 'Enter site description',
                            ),
                          ],
                          if (_selectedSpecificSite == 'trail') ...<Widget>[
                            const SizedBox(height: 10),
                            _fieldLabel('Which Trail'),
                            const SizedBox(height: 6),
                            _trailsLoading
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : DropdownButtonFormField<String>(
                                    isDense: true,
                                    isExpanded: true,
                                    initialValue: _matchDropdownOption(
                                      _selectedTrailName,
                                      _optionsWithExistingValue(
                                        _trails
                                            .map((MapTrail t) => t.name)
                                            .toList(),
                                        _selectedTrailName,
                                      ),
                                    ),
                                    items:
                                        _optionsWithExistingValue(
                                              _trails
                                                  .map((MapTrail t) => t.name)
                                                  .toList(),
                                              _selectedTrailName,
                                            )
                                            .map(
                                              (String option) =>
                                                  DropdownMenuItem<String>(
                                                    value: option,
                                                    child: Text(option),
                                                  ),
                                            )
                                            .toList(growable: false),
                                    onChanged: (String? value) {
                                      setState(() {
                                        _selectedTrailName = value;
                                      });
                                    },
                                    style: _uploadInputTextStyle,
                                    decoration: _fieldDecoration(
                                      'Select the nearest mapped trail',
                                    ),
                                  ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  key: _altitudeFieldKey,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    _uploadFieldLabelWithTooltip(
                                      'Altitude (m)',
                                      'Height of the observation site above sea level, in meters.',
                                    ),
                                    const SizedBox(height: 6),
                                    _buildField(
                                      controller: _altitudeController,
                                      hintText: 'e.g. 800',
                                      keyboardType: TextInputType.number,
                                    ),
                                    if (_altitudeError != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 6,
                                          left: 12,
                                        ),
                                        child: Text(
                                          _altitudeError!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFB00020),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  key: _elevationFieldKey,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    _uploadFieldLabelWithTooltip(
                                      'Elevation (m)',
                                      'Vertical height of the terrain surface at the observation point above sea level.',
                                    ),
                                    const SizedBox(height: 6),
                                    _buildField(
                                      controller: _elevationController,
                                      hintText: 'e.g. 1500',
                                      keyboardType: TextInputType.number,
                                    ),
                                    if (_elevationError != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 6,
                                          left: 12,
                                        ),
                                        child: Text(
                                          _elevationError!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFB00020),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ── Habitat Information Card
                    _uploadFormCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Row(
                            children: <Widget>[
                              Icon(
                                Icons.forest_outlined,
                                size: 16,
                                color: _uploadPrimary,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Habitat Information',
                                style: _uploadSectionTitleStyle,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ..._buildSightingDetailsForm(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _uploadNextButton(
                      onPressed: _showNextPlaceholder,
                      label: 'Next — Morphology',
                    ),
                    const SizedBox(height: 8),
                    _uploadSaveDraftButton(
                      onPressed: _isSavingDraft ? null : _saveDraft,
                      label: _isSavingDraft
                          ? 'Saving Draft...'
                          : 'Save as Draft',
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UploadSpeciesMorphologyScreen extends StatefulWidget {
  const UploadSpeciesMorphologyScreen({
    required this.flowData,
    this.showSpeciesValueStep = true,
    super.key,
  });
  final UploadSpeciesFlowData flowData;
  final bool showSpeciesValueStep;
  @override
  State<UploadSpeciesMorphologyScreen> createState() =>
      _UploadSpeciesMorphologyScreenState();
}

class _UploadSpeciesMorphologyScreenState
    extends State<UploadSpeciesMorphologyScreen> {
  late final UploadSpeciesFlowData _flowData;
  static const List<String> _flowerColorOptions = <String>[
    'White',
    'Cream',
    'Yellow',
    'Orange',
    'Pink',
    'Purple',
    'Red',
    'Green',
    'Brown',
    'Multicolor',
    'Other...',
  ];
  static const List<String> _monthOptions = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const List<String> _pseudobulbOptions = <String>['Yes', 'No'];
  static const List<String> _leafShapeOptions = <String>[
    'Linear & Narrow',
    'Rounded & Oval',
    'Pointy or Tapered',
    'Reversed',
    'Specialized Shapes',
  ];
  static const List<String> _leafTextureOptions = <String>[
    'Smooth',
    'Leathery',
    'Hairy or Fuzzy',
    'Thin or Fragile',
  ];
  static const List<String> _leafArrangementOptions = <String>[
    'Alternate',
    'Opposite',
    'Whorled',
  ];
  static const List<String> _inflorescenceTypeOptions = <String>[
    'Raceme',
    'Spike',
    'Panicle',
    'Solitary',
  ];
  static const List<String> _petalCharacteristicsOptions = <String>[
    'Obovate',
    'Elliptic',
    'Spatulate',
  ];
  static const List<String> _labellumOptions = <String>[
    'Trilobed (Three-lobed)',
    'Saccate (Bag-like)',
    'Spurred',
  ];
  static const List<String> _fragranceOptions = <String>[
    'None',
    'Faint',
    'Strong',
    'Sweet',
    'Musky',
    'Spicy',
  ];
  static const List<String> _bloomingStageOptions = <String>[
    'Budding',
    'Anthesis (Early)',
    'Full Bloom',
    'Senescent',
  ];
  static const List<String> _fruitTypeOptions = <String>[
    'Capsule',
    'Pod',
    'Berry',
  ];
  static const List<String> _seedCapsuleConditionOptions = <String>[
    'Immature (Green)',
    'Mature (Yellow/Brown)',
    'Dehisced (Split)',
    'Aborted',
  ];
  String? _selectedLeafType;
  String? _selectedFlowerColor;
  late TextEditingController _flowerColorCustomController;
  String? _selectedFloweringFromMonth;
  String? _selectedFloweringToMonth;
  bool _floweringSeasonUnknown = false;
  bool _isSavingDraft = false;
  // Plant Structure
  late TextEditingController _plantHeightController;
  String? _selectedPseudobulbPresent;
  late TextEditingController _stemLengthController;
  late TextEditingController _rootLengthController;
  // Leaves
  late TextEditingController _numberOfLeavesController;
  String? _selectedLeafShape;
  late TextEditingController _leafLengthController;
  late TextEditingController _leafWidthController;
  List<String> _selectedLeafTexture = <String>[];
  String? _selectedLeafArrangement;
  // Flowers
  late TextEditingController _numberOfFlowersController;
  late TextEditingController _flowerDiameterController;
  String? _selectedInflorescenceType;
  String? _selectedPetalCharacteristics;
  late TextEditingController _sepalCharacteristicsController;
  String? _selectedLabellumDescription;
  String? _selectedFragrance;
  String? _selectedBloomingStage;
  // Fruits/Seeds
  String? _selectedFruitPresent;
  String? _selectedFruitType;
  String? _selectedSeedCapsuleCondition;
  @override
  void initState() {
    super.initState();
    _flowData = widget.flowData;
    _selectedLeafType = _flowData.leafType.trim().isEmpty
        ? null
        : _flowData.leafType;
    final String savedColor = _flowData.flowerColor.trim();
    final bool isKnownColor = _flowerColorOptions
        .where((String o) => o != 'Other...')
        .contains(savedColor);
    if (savedColor.isEmpty) {
      _selectedFlowerColor = null;
      _flowerColorCustomController = TextEditingController();
    } else if (isKnownColor) {
      _selectedFlowerColor = savedColor;
      _flowerColorCustomController = TextEditingController();
    } else {
      _selectedFlowerColor = 'Other...';
      _flowerColorCustomController = TextEditingController(text: savedColor);
    }
    _floweringSeasonUnknown = _flowData.floweringFromMonth == 'Unknown';
    _selectedFloweringFromMonth =
        _flowData.floweringFromMonth.trim().isEmpty ||
            _flowData.floweringFromMonth == 'Unknown'
        ? null
        : _flowData.floweringFromMonth;
    _selectedFloweringToMonth =
        _flowData.floweringToMonth.trim().isEmpty ||
            _flowData.floweringToMonth == 'Unknown'
        ? null
        : _flowData.floweringToMonth;
    // Plant Structure
    _plantHeightController = TextEditingController(text: _flowData.plantHeight);
    _selectedPseudobulbPresent = _flowData.pseudobulbPresent.trim().isEmpty
        ? null
        : _flowData.pseudobulbPresent;
    _stemLengthController = TextEditingController(text: _flowData.stemLength);
    _rootLengthController = TextEditingController(text: _flowData.rootLength);
    // Leaves
    _numberOfLeavesController = TextEditingController(
      text: _flowData.numberOfLeaves,
    );
    _selectedLeafShape = _flowData.leafShape.trim().isEmpty
        ? null
        : _flowData.leafShape;
    _leafLengthController = TextEditingController(text: _flowData.leafLength);
    _leafWidthController = TextEditingController(text: _flowData.leafWidth);
    _selectedLeafTexture = _flowData.leafTexture.trim().isEmpty
        ? <String>[]
        : _flowData.leafTexture.split(',').map((String s) => s.trim()).toList();
    _selectedLeafArrangement = _flowData.leafArrangement.trim().isEmpty
        ? null
        : _flowData.leafArrangement;
    // Flowers
    _numberOfFlowersController = TextEditingController(
      text: _flowData.numberOfFlowers,
    );
    _flowerDiameterController = TextEditingController(
      text: _flowData.flowerDiameter,
    );
    _selectedInflorescenceType = _flowData.inflorescenceType.trim().isEmpty
        ? null
        : _flowData.inflorescenceType;
    _selectedPetalCharacteristics =
        _flowData.petalCharacteristics.trim().isEmpty
        ? null
        : _flowData.petalCharacteristics;
    _sepalCharacteristicsController = TextEditingController(
      text: _flowData.sepalCharacteristics,
    );
    _selectedLabellumDescription = _flowData.labellumDescription.trim().isEmpty
        ? null
        : _flowData.labellumDescription;
    _selectedFragrance = _flowData.fragrance.trim().isEmpty
        ? null
        : _flowData.fragrance;
    _selectedBloomingStage = _flowData.bloomingStage.trim().isEmpty
        ? null
        : _flowData.bloomingStage;
    // Fruits/Seeds
    _selectedFruitPresent = _flowData.fruitPresent.trim().isEmpty
        ? null
        : _flowData.fruitPresent;
    _selectedFruitType = _flowData.fruitType.trim().isEmpty
        ? null
        : _flowData.fruitType;
    _selectedSeedCapsuleCondition =
        _flowData.seedCapsuleCondition.trim().isEmpty
        ? null
        : _flowData.seedCapsuleCondition;
  }

  @override
  void dispose() {
    _plantHeightController.dispose();
    _stemLengthController.dispose();
    _rootLengthController.dispose();
    _numberOfLeavesController.dispose();
    _leafLengthController.dispose();
    _leafWidthController.dispose();
    _flowerColorCustomController.dispose();
    _numberOfFlowersController.dispose();
    _flowerDiameterController.dispose();
    _sepalCharacteristicsController.dispose();
    super.dispose();
  }

  void _syncFlowDataFromForm() {
    _flowData.leafType = (_selectedLeafType ?? '').trim();
    _flowData.flowerColor = _selectedFlowerColor == 'Other...'
        ? _flowerColorCustomController.text.trim()
        : (_selectedFlowerColor ?? '').trim();
    if (_floweringSeasonUnknown) {
      _flowData.floweringFromMonth = 'Unknown';
      _flowData.floweringToMonth = 'Unknown';
    } else {
      _flowData.floweringFromMonth = (_selectedFloweringFromMonth ?? '').trim();
      _flowData.floweringToMonth = (_selectedFloweringToMonth ?? '').trim();
    }
    // Plant Structure
    _flowData.plantHeight = _plantHeightController.text.trim();
    _flowData.pseudobulbPresent = (_selectedPseudobulbPresent ?? '').trim();
    _flowData.stemLength = _stemLengthController.text.trim();
    _flowData.rootLength = _rootLengthController.text.trim();
    // Leaves
    _flowData.numberOfLeaves = _numberOfLeavesController.text.trim();
    _flowData.leafShape = (_selectedLeafShape ?? '').trim();
    _flowData.leafLength = _leafLengthController.text.trim();
    _flowData.leafWidth = _leafWidthController.text.trim();
    _flowData.leafTexture = _selectedLeafTexture.join(', ');
    _flowData.leafArrangement = (_selectedLeafArrangement ?? '').trim();
    // Flowers
    _flowData.numberOfFlowers = _numberOfFlowersController.text.trim();
    _flowData.flowerDiameter = _flowerDiameterController.text.trim();
    _flowData.inflorescenceType = (_selectedInflorescenceType ?? '').trim();
    _flowData.petalCharacteristics = (_selectedPetalCharacteristics ?? '')
        .trim();
    _flowData.sepalCharacteristics = _sepalCharacteristicsController.text
        .trim();
    _flowData.labellumDescription = (_selectedLabellumDescription ?? '').trim();
    _flowData.fragrance = (_selectedFragrance ?? '').trim();
    _flowData.bloomingStage = (_selectedBloomingStage ?? '').trim();
    // Fruits/Seeds
    _flowData.fruitPresent = (_selectedFruitPresent ?? '').trim();
    _flowData.fruitType = (_selectedFruitType ?? '').trim();
    _flowData.seedCapsuleCondition = (_selectedSeedCapsuleCondition ?? '')
        .trim();
  }

  void _openNextStep() {
    _syncFlowDataFromForm();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => widget.showSpeciesValueStep
            ? UploadSpeciesValueScreen(flowData: _flowData)
            : UploadSpeciesImagesScreen(flowData: _flowData),
      ),
    );
  }

  Future<void> _saveDraft() async {
    if (_isSavingDraft) return;
    setState(() => _isSavingDraft = true);
    try {
      _syncFlowDataFromForm();
      await UploadSpeciesDraftStore.saveDraft(_flowData);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Draft saved.')));
      Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save draft right now.')),
      );
    } finally {
      if (mounted) setState(() => _isSavingDraft = false);
    }
  }

  InputDecoration _fieldDecoration() => _uploadInputDecoration();
  Widget _dropdownField({
    required String hint,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      isDense: true,
      isExpanded: true,
      initialValue: _matchDropdownOption(value, options),
      items: options
          .map(
            (String option) =>
                DropdownMenuItem<String>(value: option, child: Text(option)),
          )
          .toList(growable: false),
      onChanged: onChanged,
      style: _uploadInputTextStyle,
      decoration: _fieldDecoration().copyWith(
        hintText: hint,
        hintStyle: _uploadHintTextStyle,
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(text, style: _uploadFieldLabelStyle);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _uploadBg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _UploadFormHeader(
                title: 'New Submission',
                step: 3,
                totalSteps: 5,
                stepIcon: Icons.local_florist_outlined,
                sectionTitle: 'Morphological Characteristics',
                entryId: _flowData.entryId,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // ── Plant Structure
                    _uploadFormCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Icon(
                                Icons.grass_outlined,
                                size: 16,
                                color: _uploadPrimary,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Plant Structure',
                                style: _uploadSectionTitleStyle,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _fieldLabel('Plant Height (cm)'),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _plantHeightController,
                            keyboardType: TextInputType.number,
                            style: _uploadInputTextStyle,
                            decoration: _fieldDecoration().copyWith(
                              hintText: 'Enter plant height in cm',
                            ),
                          ),
                          const SizedBox(height: 10),
                          _uploadFieldLabelWithTooltip(
                            'Pseudobulb Present',
                            'A swollen, bulb-like stem segment found in many orchids, used to store water and nutrients.',
                          ),
                          const SizedBox(height: 4),
                          _dropdownField(
                            hint: 'Select yes or no',
                            value: _selectedPseudobulbPresent,
                            options: _pseudobulbOptions,
                            onChanged: (String? value) {
                              setState(() {
                                _selectedPseudobulbPresent = value;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    _fieldLabel('Stem Length (cm)'),
                                    const SizedBox(height: 4),
                                    TextField(
                                      controller: _stemLengthController,
                                      keyboardType: TextInputType.number,
                                      style: _uploadInputTextStyle,
                                      decoration: _fieldDecoration().copyWith(
                                        hintText: 'cm',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    _fieldLabel('Root Length (cm)'),
                                    const SizedBox(height: 4),
                                    TextField(
                                      controller: _rootLengthController,
                                      keyboardType: TextInputType.number,
                                      style: _uploadInputTextStyle,
                                      decoration: _fieldDecoration().copyWith(
                                        hintText: 'cm',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ── Leaves
                    _uploadFormCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Icon(
                                Icons.eco_outlined,
                                size: 16,
                                color: _uploadPrimary,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Leaves',
                                style: _uploadSectionTitleStyle,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _fieldLabel('Number of Leaves'),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _numberOfLeavesController,
                            keyboardType: TextInputType.number,
                            style: _uploadInputTextStyle,
                            decoration: _fieldDecoration().copyWith(
                              hintText: 'Enter number of leaves',
                            ),
                          ),
                          const SizedBox(height: 10),
                          _fieldLabel('Leaf Shape'),
                          const SizedBox(height: 4),
                          _dropdownField(
                            hint: 'Select leaf shape',
                            value: _selectedLeafShape,
                            options: _leafShapeOptions,
                            onChanged: (String? value) {
                              setState(() {
                                _selectedLeafShape = value;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    _fieldLabel('Leaf Length (cm)'),
                                    const SizedBox(height: 4),
                                    TextField(
                                      controller: _leafLengthController,
                                      keyboardType: TextInputType.number,
                                      style: _uploadInputTextStyle,
                                      decoration: _fieldDecoration().copyWith(
                                        hintText: 'Length',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    _fieldLabel('Leaf Width (cm)'),
                                    const SizedBox(height: 4),
                                    TextField(
                                      controller: _leafWidthController,
                                      keyboardType: TextInputType.number,
                                      style: _uploadInputTextStyle,
                                      decoration: _fieldDecoration().copyWith(
                                        hintText: 'Width',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _uploadFieldLabelWithTooltip(
                            'Leaf Surface Texture',
                            'Physical texture of the leaf surface (e.g., smooth, waxy, hairy, or rough).',
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Multiple selections allowed',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _leafTextureOptions
                                .map((String option) {
                                  final bool selected = _selectedLeafTexture
                                      .contains(option);
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (selected) {
                                          _selectedLeafTexture.remove(option);
                                        } else {
                                          _selectedLeafTexture.add(option);
                                        }
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? _uploadPrimary
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: selected
                                              ? _uploadPrimary
                                              : _uploadBorderColor,
                                          width: 1.5,
                                        ),
                                        boxShadow: selected
                                            ? <BoxShadow>[
                                                BoxShadow(
                                                  color: _uploadPrimary
                                                      .withValues(alpha: 0.18),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Text(
                                        option,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: selected
                                              ? Colors.white
                                              : const Color(0xFF306D29),
                                        ),
                                      ),
                                    ),
                                  );
                                })
                                .toList(growable: false),
                          ),
                          const SizedBox(height: 10),
                          _uploadFieldLabelWithTooltip(
                            'Leaf Arrangement',
                            'How leaves are organized along the stem (e.g., alternate, opposite, or in a basal rosette).',
                          ),
                          const SizedBox(height: 4),
                          _dropdownField(
                            hint: 'Select leaf arrangement',
                            value: _selectedLeafArrangement,
                            options: _leafArrangementOptions,
                            onChanged: (String? value) {
                              setState(() {
                                _selectedLeafArrangement = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ── Flowers
                    _uploadFormCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Icon(
                                Icons.local_florist_outlined,
                                size: 16,
                                color: _uploadPrimary,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Flowers',
                                style: _uploadSectionTitleStyle,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _fieldLabel('Flower Color'),
                          const SizedBox(height: 4),
                          _dropdownField(
                            hint: 'Select flower color',
                            value: _selectedFlowerColor,
                            options: _flowerColorOptions,
                            onChanged: (String? value) {
                              setState(() {
                                _selectedFlowerColor = value;
                                if (value != 'Other...') {
                                  _flowerColorCustomController.clear();
                                }
                              });
                            },
                          ),
                          if (_selectedFlowerColor == 'Other...')
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextField(
                                controller: _flowerColorCustomController,
                                style: _uploadInputTextStyle,
                                decoration: _fieldDecoration().copyWith(
                                  hintText: 'Describe the flower color',
                                  hintStyle: _uploadHintTextStyle,
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    _fieldLabel('No. of Flowers'),
                                    const SizedBox(height: 4),
                                    TextField(
                                      controller: _numberOfFlowersController,
                                      keyboardType: TextInputType.number,
                                      style: _uploadInputTextStyle,
                                      decoration: _fieldDecoration().copyWith(
                                        hintText: 'Count',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    _fieldLabel('Diameter (cm)'),
                                    const SizedBox(height: 4),
                                    TextField(
                                      controller: _flowerDiameterController,
                                      keyboardType: TextInputType.number,
                                      style: _uploadInputTextStyle,
                                      decoration: _fieldDecoration().copyWith(
                                        hintText: 'cm',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _uploadFieldLabelWithTooltip(
                            'Inflorescence Type',
                            'The arrangement pattern of multiple flowers on the flower stalk (e.g., raceme, panicle, or solitary).',
                          ),
                          const SizedBox(height: 4),
                          _dropdownField(
                            hint: 'Select inflorescence type',
                            value: _selectedInflorescenceType,
                            options: _inflorescenceTypeOptions,
                            onChanged: (String? value) {
                              setState(() {
                                _selectedInflorescenceType = value;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          _uploadFieldLabelWithTooltip(
                            'Petal Characteristics',
                            'Descriptors for the shape, texture, or markings of the inner flower parts.',
                          ),
                          const SizedBox(height: 4),
                          _dropdownField(
                            hint: 'Select petal characteristics',
                            value: _selectedPetalCharacteristics,
                            options: _petalCharacteristicsOptions,
                            onChanged: (String? value) {
                              setState(() {
                                _selectedPetalCharacteristics = value;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          _uploadFieldLabelWithTooltip(
                            'Sepal Characteristics',
                            'Description of the outer protective parts surrounding the flower, usually leaf-like and located below the petals.',
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _sepalCharacteristicsController,
                            style: _uploadInputTextStyle,
                            decoration: _fieldDecoration().copyWith(
                              hintText: 'Describe sepal characteristics',
                            ),
                          ),
                          const SizedBox(height: 10),
                          _uploadFieldLabelWithTooltip(
                            'Labellum / Lip Description',
                            'The distinctive modified petal unique to orchids. It is often elaborately patterned or shaped to attract specific pollinators.',
                          ),
                          const SizedBox(height: 4),
                          _dropdownField(
                            hint: 'Select labellum type',
                            value: _selectedLabellumDescription,
                            options: _labellumOptions,
                            onChanged: (String? value) {
                              setState(() {
                                _selectedLabellumDescription = value;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    _uploadFieldLabelWithTooltip(
                                      'Fragrance',
                                      'Scent intensity of the flower at time of observation.',
                                    ),
                                    const SizedBox(height: 4),
                                    _dropdownField(
                                      hint: 'Level',
                                      value: _selectedFragrance,
                                      options: _fragranceOptions,
                                      onChanged: (String? value) {
                                        setState(() {
                                          _selectedFragrance = value;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    _uploadFieldLabelWithTooltip(
                                      'Blooming Stage',
                                      'Current developmental stage of the flower at time of observation (e.g., bud, fully open, wilting).',
                                    ),
                                    const SizedBox(height: 4),
                                    _dropdownField(
                                      hint: 'Stage',
                                      value: _selectedBloomingStage,
                                      options: _bloomingStageOptions,
                                      onChanged: (String? value) {
                                        setState(() {
                                          _selectedBloomingStage = value;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _uploadFieldLabelWithTooltip(
                            'Flowering Season',
                            'The months during which this orchid typically produces flowers.',
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: <Widget>[
                              Checkbox(
                                value: _floweringSeasonUnknown,
                                onChanged: (bool? v) {
                                  setState(() {
                                    _floweringSeasonUnknown = v ?? false;
                                    if (_floweringSeasonUnknown) {
                                      _selectedFloweringFromMonth = null;
                                      _selectedFloweringToMonth = null;
                                    }
                                  });
                                },
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              const Text(
                                'Unknown',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                          if (!_floweringSeasonUnknown) ...<Widget>[
                            const SizedBox(height: 4),
                            Row(
                              children: <Widget>[
                                const Text(
                                  'From',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _dropdownField(
                                    hint: 'Month',
                                    value: _selectedFloweringFromMonth,
                                    options: _monthOptions,
                                    onChanged: (String? value) {
                                      setState(() {
                                        _selectedFloweringFromMonth = value;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'to',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _dropdownField(
                                    hint: 'Month',
                                    value: _selectedFloweringToMonth,
                                    options: _monthOptions,
                                    onChanged: (String? value) {
                                      setState(() {
                                        _selectedFloweringToMonth = value;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ── Fruits / Seeds
                    _uploadFormCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Icon(
                                Icons.spa_outlined,
                                size: 16,
                                color: _uploadPrimary,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Fruits / Seeds',
                                style: _uploadSectionTitleStyle,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _fieldLabel('Fruit Present'),
                          const SizedBox(height: 4),
                          _dropdownField(
                            hint: 'Select yes or no',
                            value: _selectedFruitPresent,
                            options: _pseudobulbOptions,
                            onChanged: (String? value) {
                              setState(() {
                                _selectedFruitPresent = value;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          _fieldLabel('Fruit Type'),
                          const SizedBox(height: 4),
                          _dropdownField(
                            hint: 'Select fruit type',
                            value: _selectedFruitType,
                            options: _fruitTypeOptions,
                            onChanged: (String? value) {
                              setState(() {
                                _selectedFruitType = value;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          _uploadFieldLabelWithTooltip(
                            'Seed Capsule Condition',
                            'Maturity and physical state of the seed pod if present (e.g., immature, mature, dehisced/open).',
                          ),
                          const SizedBox(height: 4),
                          _dropdownField(
                            hint: 'Select seed capsule condition',
                            value: _selectedSeedCapsuleCondition,
                            options: _seedCapsuleConditionOptions,
                            onChanged: (String? value) {
                              setState(() {
                                _selectedSeedCapsuleCondition = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _uploadNextButton(
                      onPressed: _openNextStep,
                      label: 'Next — Ecological Data',
                    ),
                    const SizedBox(height: 8),
                    _uploadSaveDraftButton(
                      onPressed: _isSavingDraft ? null : _saveDraft,
                      label: _isSavingDraft
                          ? 'Saving Draft...'
                          : 'Save as Draft',
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContributorEntry {
  _ContributorEntry({
    String name = '',
    this.selectedPosition,
    String other = '',
  }) : nameController = TextEditingController(text: name),
       otherController = TextEditingController(text: other);
  final TextEditingController nameController;
  final TextEditingController otherController;
  String? selectedPosition;
  void dispose() {
    nameController.dispose();
    otherController.dispose();
  }

  static const List<String> positionOptions = <String>[
    'Lead Researcher',
    'Field Assistant',
    'Data Recorder',
    'Photographer',
    'Botanist',
    'Student',
    'Observer',
    'Other',
  ];
}

class _RelatedStudyFormEntry {
  _RelatedStudyFormEntry({String title = '', String link = '', this.filePath})
    : titleController = TextEditingController(text: title),
      linkController = TextEditingController(text: link);
  final TextEditingController titleController;
  final TextEditingController linkController;
  String? filePath;
  String get fileName => (filePath ?? '').split('/').last.split('\\').last;
  void dispose() {
    titleController.dispose();
    linkController.dispose();
  }
}

class UploadSpeciesImagesScreen extends StatefulWidget {
  const UploadSpeciesImagesScreen({required this.flowData, super.key});
  final UploadSpeciesFlowData flowData;
  @override
  State<UploadSpeciesImagesScreen> createState() =>
      _UploadSpeciesImagesScreenState();
}

class _UploadSpeciesImagesScreenState extends State<UploadSpeciesImagesScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  // Original (uncompressed) photos are kept — see _pickImagesForCategory
  // so GPS EXIF survives for offline coordinate auto-fill; the size cap is
  // correspondingly higher than a typical re-encoded upload limit.
  static const int _maxImageBytes = 12 * 1024 * 1024;
  static const String _catSpecimen = 'specimen_photo';
  static const String _catWholePlant = 'whole_plant';
  static const String _catCloseupFlower = 'closeup_flower';
  static const String _catHabitat = 'habitat_photo';
  late final UploadSpeciesFlowData _flowData;
  final List<UploadSpeciesImageDraft> _specimenPhotos =
      <UploadSpeciesImageDraft>[];
  final List<UploadSpeciesImageDraft> _wholePlantPhotos =
      <UploadSpeciesImageDraft>[];
  final List<UploadSpeciesImageDraft> _closeupFlowerPhotos =
      <UploadSpeciesImageDraft>[];
  final List<UploadSpeciesImageDraft> _habitatPhotos =
      <UploadSpeciesImageDraft>[];
  final Map<String, Uint8List> _imageBytesCache = <String, Uint8List>{};
  String? _videoPath;
  bool _isPickingImage = false;
  bool _isPickingVideo = false;
  bool _isSavingDraft = false;
  String? _headResearcherError;
  late final TextEditingController _headResearcherController;
  late final TextEditingController _institutionController;
  late final TextEditingController _researcherNotesController;
  late final TextEditingController _unusualObservationsController;
  final List<_RelatedStudyFormEntry> _relatedStudyEntries =
      <_RelatedStudyFormEntry>[];
  final List<_ContributorEntry> _contributorEntries = <_ContributorEntry>[];
  @override
  void initState() {
    super.initState();
    _flowData = widget.flowData;
    for (final UploadSpeciesImageDraft image in _flowData.images) {
      _listForCategory(image.category).add(
        UploadSpeciesImageDraft(
          path: image.path,
          sizeBytes: image.sizeBytes,
          photoCredit: image.photoCredit,
          category: image.category,
        ),
      );
      _loadPreviewForPath(image.path);
    }
    _videoPath = _flowData.videoPath.trim().isEmpty
        ? null
        : _flowData.videoPath.trim();
    _headResearcherController = TextEditingController(
      text: _flowData.headResearcher.trim(),
    );
    _institutionController = TextEditingController(text: _flowData.institution);
    _researcherNotesController = TextEditingController(
      text: _flowData.researcherNotes,
    );
    _unusualObservationsController = TextEditingController(
      text: _flowData.unusualObservations,
    );
    for (final UploadRelatedStudyEntry study in _flowData.relatedStudies) {
      _relatedStudyEntries.add(
        _RelatedStudyFormEntry(
          title: study.title,
          link: study.link,
          filePath: study.filePath.trim().isEmpty ? null : study.filePath,
        ),
      );
    }
    if (_relatedStudyEntries.isEmpty) {
      _relatedStudyEntries.add(_RelatedStudyFormEntry());
    }
    if (_flowData.contributors.isNotEmpty) {
      for (final UploadContributorDraft c in _flowData.contributors) {
        final bool isKnown = _ContributorEntry.positionOptions
            .where((String s) => s != 'Other')
            .contains(c.position);
        _contributorEntries.add(
          _ContributorEntry(
            name: c.name,
            selectedPosition: c.position.trim().isEmpty
                ? null
                : (isKnown ? c.position : 'Other'),
            other: isKnown ? '' : c.position,
          ),
        );
      }
    }
    if (_contributorEntries.isEmpty) {
      _contributorEntries.add(_ContributorEntry());
    }
  }

  @override
  void dispose() {
    _headResearcherController.dispose();
    _institutionController.dispose();
    _researcherNotesController.dispose();
    _unusualObservationsController.dispose();
    for (final _RelatedStudyFormEntry e in _relatedStudyEntries) {
      e.dispose();
    }
    for (final _ContributorEntry e in _contributorEntries) {
      e.dispose();
    }
    super.dispose();
  }

  List<UploadSpeciesImageDraft> _listForCategory(String category) {
    switch (category) {
      case _catWholePlant:
        return _wholePlantPhotos;
      case _catCloseupFlower:
        return _closeupFlowerPhotos;
      case _catHabitat:
        return _habitatPhotos;
      default:
        return _specimenPhotos;
    }
  }

  String _formatFileSize(int bytes) {
    final double mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }

  Future<void> _loadPreviewForPath(String path) async {
    if (_imageBytesCache.containsKey(path)) {
      return;
    }
    try {
      final Uint8List bytes = await XFile(path).readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        _imageBytesCache[path] = bytes;
      });
    } catch (_) {}
  }

  /// Reverse-geocodes EXIF-extracted coordinates and stores the place name in
  /// [_flowData.location] so the sightings form has a human-readable label.
  Future<void> _geocodeExifCoords(double lat, double lng) async {
    try {
      final Uri uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/reverse',
        <String, String>{
          'format': 'jsonv2',
          'lat': lat.toString(),
          'lon': lng.toString(),
        },
      );
      final http.Response response = await http.get(
        uri,
        headers: <String, String>{'User-Agent': 'bloom-mobile-upload/1.0'},
      );
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final dynamic addr = decoded['address'];
          if (addr is Map) {
            final Map<String, dynamic> a = Map<String, dynamic>.from(addr);
            String pick(List<String> keys) {
              for (final k in keys) {
                final v = (a[k] ?? '').toString().trim();
                if (v.isNotEmpty) return v;
              }
              return '';
            }

            final String municipality = pick(<String>[
              'municipality',
              'city',
              'town',
              'village',
            ]);
            final String province = pick(<String>[
              'province',
              'state',
              'region',
            ]);
            final String resolved = <String>[
              municipality,
              province,
            ].where((s) => s.isNotEmpty).join(', ');
            if (resolved.isNotEmpty && _flowData.location.trim().isEmpty) {
              _flowData.location = resolved;
            }
            if (_flowData.province.trim().isEmpty) {
              _flowData.province = province;
            }
            if (_flowData.municipality.trim().isEmpty) {
              _flowData.municipality = municipality;
            }
          }
        }
      }
    } catch (_) {}
    if (_flowData.elevation.trim().isEmpty) {
      final double? terrainElevation = await fetchOpenElevationMeters(lat, lng);
      if (terrainElevation != null) {
        _flowData.elevation = terrainElevation.toStringAsFixed(1);
      }
    }
  }

  Future<void> _pickImagesForCategory(String category) async {
    if (_isPickingImage) {
      return;
    }
    setState(() {
      _isPickingImage = true;
    });
    try {
      // No imageQuality/maxWidth here on purpose: image_picker recompresses
      // through those, which strips EXIF (including GPS) on most devices
      // that would silently break the auto-fill-coordinates-from-photo
      // feature below. Picking the original file keeps the GPS tag intact.
      final List<XFile> picked = await _imagePicker.pickMultiImage();
      if (picked.isEmpty) {
        return;
      }
      final List<UploadSpeciesImageDraft> targetList = _listForCategory(
        category,
      );
      int skipped = 0;
      int added = 0;
      for (final XFile file in picked) {
        if (targetList.any(
          (UploadSpeciesImageDraft img) => img.path == file.path,
        )) {
          continue;
        }
        final Uint8List bytes = await file.readAsBytes();
        if (bytes.lengthInBytes > _maxImageBytes) {
          skipped++;
          continue;
        }
        targetList.add(
          UploadSpeciesImageDraft(
            path: file.path,
            sizeBytes: bytes.lengthInBytes,
            category: category,
          ),
        );
        _imageBytesCache[file.path] = bytes;
        added++;
      }
      if (!mounted) {
        return;
      }
      setState(() {});
      if (skipped > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$skipped image(s) exceeded 5 MB and were skipped.'),
          ),
        );
      } else if (added > 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$added image(s) added.')));
      }
      // Auto-fill GPS from EXIF — scan every uploaded image until one has coords.
      if (added > 0 &&
          _flowData.latitude.trim().isEmpty &&
          _flowData.longitude.trim().isEmpty) {
        for (final XFile img in picked) {
          final Uint8List? bytes = _imageBytesCache[img.path];
          if (bytes == null) continue;
          final gps = await _extractGpsFromExif(bytes);
          if (gps != null && mounted) {
            _flowData.latitude = gps.lat.toStringAsFixed(6);
            _flowData.longitude = gps.lng.toStringAsFixed(6);
            _geocodeExifCoords(gps.lat, gps.lng);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'GPS from photo: ${gps.lat.toStringAsFixed(5)}, '
                  '${gps.lng.toStringAsFixed(5)} — coordinates auto-saved.',
                ),
                duration: const Duration(seconds: 4),
              ),
            );
            break;
          }
        }
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open gallery right now.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  Future<void> _pickVideo() async {
    if (_isPickingVideo) {
      return;
    }
    setState(() {
      _isPickingVideo = true;
    });
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );
      if (!mounted) {
        return;
      }
      if (video != null) {
        setState(() {
          _videoPath = video.path;
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to pick video right now.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingVideo = false;
        });
      }
    }
  }

  void _removeImageFromCategory(String category, int index) {
    final List<UploadSpeciesImageDraft> list = _listForCategory(category);
    if (index < 0 || index >= list.length) {
      return;
    }
    setState(() {
      _imageBytesCache.remove(list[index].path);
      list.removeAt(index);
    });
  }

  void _syncFlowDataFromForm() {
    _flowData.images = <UploadSpeciesImageDraft>[
      ..._specimenPhotos,
      ..._wholePlantPhotos,
      ..._closeupFlowerPhotos,
      ..._habitatPhotos,
    ].map((UploadSpeciesImageDraft img) => img.copy()).toList(growable: false);
    _flowData.videoPath = _videoPath ?? '';
    _flowData.headResearcher = _headResearcherController.text.trim();
    _flowData.institution = _institutionController.text.trim();
    _flowData.researcherNotes = _researcherNotesController.text.trim();
    _flowData.unusualObservations = _unusualObservationsController.text.trim();
    _flowData.relatedStudies = _relatedStudyEntries
        .map(
          (_RelatedStudyFormEntry e) => UploadRelatedStudyEntry(
            title: e.titleController.text.trim(),
            link: e.linkController.text.trim(),
            filePath: e.filePath ?? '',
          ),
        )
        .toList();
    _flowData.contributors = _contributorEntries
        .where((e) => e.nameController.text.trim().isNotEmpty)
        .map(
          (e) => UploadContributorDraft(
            name: e.nameController.text.trim(),
            position: e.selectedPosition == 'Other'
                ? (e.otherController.text.trim().isEmpty
                      ? 'Other'
                      : e.otherController.text.trim())
                : (e.selectedPosition ?? ''),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _pickStudyFile(int index) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['pdf', 'doc', 'docx', 'txt', 'ppt', 'pptx'],
      withData: false,
      withReadStream: false,
    );
    if (result != null && result.files.isNotEmpty) {
      final PlatformFile file = result.files.first;
      setState(() {
        _relatedStudyEntries[index].filePath = file.path;
      });
    }
  }

  void _addRelatedStudy() {
    setState(() {
      _relatedStudyEntries.add(_RelatedStudyFormEntry());
    });
  }

  void _removeRelatedStudy(int index) {
    setState(() {
      _relatedStudyEntries[index].dispose();
      _relatedStudyEntries.removeAt(index);
    });
  }

  Widget _buildRelatedStudyEntry(int index) {
    final _RelatedStudyFormEntry entry = _relatedStudyEntries[index];
    final bool hasFile = (entry.filePath ?? '').trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_relatedStudyEntries.length > 1)
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Study ${index + 1}',
                  style: _uploadFieldLabelStyle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _removeRelatedStudy(index),
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: _uploadPrimary,
                ),
              ),
            ],
          ),
        if (_relatedStudyEntries.length > 1) const SizedBox(height: 8),
        // Title of Study
        Text('Title of Study', style: _uploadFieldLabelStyle),
        const SizedBox(height: 6),
        TextField(
          controller: entry.titleController,
          style: _uploadInputTextStyle,
          decoration: _uploadInputDecoration(
            hintText: 'Enter the title of the related study',
          ),
        ),
        const SizedBox(height: 12),
        // Source Link
        Text('Source Link', style: _uploadFieldLabelStyle),
        const SizedBox(height: 6),
        TextField(
          controller: entry.linkController,
          style: _uploadInputTextStyle,
          keyboardType: TextInputType.url,
          decoration: _uploadInputDecoration(hintText: 'https://doi.org/...')
              .copyWith(
                prefixIcon: const Icon(
                  Icons.link_rounded,
                  size: 18,
                  color: _uploadPrimary,
                ),
              ),
        ),
        const SizedBox(height: 12),
        // File Upload
        Text('Upload Study File', style: _uploadFieldLabelStyle),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _pickStudyFile(index),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5FAF0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD0E8CC), width: 1.5),
            ),
            child: hasFile
                ? Row(
                    children: <Widget>[
                      const Icon(
                        Icons.description_outlined,
                        size: 20,
                        color: _uploadPrimary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entry.fileName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF082809),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          entry.filePath = null;
                        }),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: _uploadPrimary,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const <Widget>[
                      Icon(
                        Icons.upload_file_rounded,
                        size: 20,
                        color: _uploadPrimary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Tap to attach a file',
                        style: TextStyle(
                          fontSize: 13,
                          color: _uploadPrimary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Accepted: PDF, DOC, DOCX, PPT, PPTX, TXT',
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF9CA3AF),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Future<void> _saveDraft() async {
    if (_isSavingDraft) return;
    // Validate required field
    if (_headResearcherController.text.trim().isEmpty) {
      setState(
        () => _headResearcherError = 'Head Researcher name is required.',
      );
      return;
    }
    setState(() {
      _isSavingDraft = true;
    });
    try {
      _syncFlowDataFromForm();
      await UploadSpeciesDraftStore.saveDraft(_flowData);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft saved. You can upload it later.')),
      );
      Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save draft right now.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingDraft = false;
        });
      }
    }
  }

  Widget _buildAddButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: _uploadActionButtonStyle(),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildPhotoSlot(
    UploadSpeciesImageDraft image,
    String category,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _lineColor, width: 1.1),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: _imageBytesCache[image.path] != null
                      ? Image.memory(
                          _imageBytesCache[image.path]!,
                          fit: BoxFit.cover,
                        )
                      : ColoredBox(
                          color: _surfaceTintColor,
                          child: Icon(
                            Icons.image_outlined,
                            color: _mutedTextColor,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Photo ${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatFileSize(image.sizeBytes),
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: _mutedTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFF7A2C22),
                ),
                onPressed: () => _removeImageFromCategory(category, index),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Photo Credit',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 36,
            child: TextFormField(
              initialValue: image.photoCredit,
              onChanged: (String v) {
                image.photoCredit = v.trim();
              },
              style: _uploadInputTextStyle,
              decoration: _uploadInputDecoration(hintText: 'Photographer name'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection({
    required String label,
    required String category,
    required List<UploadSpeciesImageDraft> images,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: _uploadFieldLabelStyle),
        const SizedBox(height: 6),
        _buildAddButton(
          label: 'Add Images',
          icon: Icons.add_photo_alternate_outlined,
          onPressed: _isPickingImage
              ? null
              : () => _pickImagesForCategory(category),
        ),
        for (int i = 0; i < images.length; i++)
          _buildPhotoSlot(images[i], category, i),
      ],
    );
  }

  Widget _buildNotesField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: _uploadFieldLabelStyle),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: _uploadInputTextStyle,
          decoration: _uploadInputDecoration(hintText: hint).copyWith(
            errorText: errorText,
            errorStyle: const TextStyle(fontSize: 11),
          ),
          onChanged: errorText != null
              ? (_) => setState(() => _headResearcherError = null)
              : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _uploadBg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _UploadFormHeader(
                title: 'New Submission',
                step: 5,
                totalSteps: 5,
                stepIcon: Icons.camera_alt_outlined,
                sectionTitle: 'Media & Researcher Notes',
                entryId: _flowData.entryId,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // ── Multimedia Documentation
                    _uploadFormCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Multimedia Documentation',
                            style: _uploadSectionTitleStyle,
                          ),
                          const SizedBox(height: 14),
                          _buildCategorySection(
                            label: 'Specimen Photos',
                            category: _catSpecimen,
                            images: _specimenPhotos,
                          ),
                          const SizedBox(height: 14),
                          _buildCategorySection(
                            label: 'Whole Plant',
                            category: _catWholePlant,
                            images: _wholePlantPhotos,
                          ),
                          const SizedBox(height: 14),
                          _buildCategorySection(
                            label: 'Close-up Flower',
                            category: _catCloseupFlower,
                            images: _closeupFlowerPhotos,
                          ),
                          const SizedBox(height: 14),
                          _buildCategorySection(
                            label: 'Habitat Photo',
                            category: _catHabitat,
                            images: _habitatPhotos,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // ── Video Documentation
                    _uploadFormCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Video Documentation',
                            style: _uploadSectionTitleStyle,
                          ),
                          const SizedBox(height: 12),
                          _buildAddButton(
                            label: _isPickingVideo
                                ? 'Selecting...'
                                : 'Add Video',
                            icon: Icons.videocam_outlined,
                            onPressed: _isPickingVideo ? null : _pickVideo,
                          ),
                          if (_videoPath != null) ...<Widget>[
                            const SizedBox(height: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: _appBackgroundColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _lineColor, width: 1),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.videocam_outlined,
                                    color: _primaryColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _videoPath!
                                          .split('/')
                                          .last
                                          .split('\\')
                                          .last,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _textColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Remove video',
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Color(0xFF7A2C22),
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() {
                                      _videoPath = null;
                                    }),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // ── Contributors
                    _uploadFormCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Contributors',
                            style: _uploadSectionTitleStyle,
                          ),
                          const SizedBox(height: 14),
                          // Head Researcher (first)
                          _buildNotesField(
                            label: 'Head Observer / Researcher Name *',
                            controller: _headResearcherController,
                            hint: 'Full name of lead researcher',
                            errorText: _headResearcherError,
                          ),
                          const SizedBox(height: 14),
                          Divider(color: _lineColor, height: 1),
                          const SizedBox(height: 14),
                          // Team Members (name + position dropdown)
                          Text('Team Members', style: _uploadFieldLabelStyle),
                          const SizedBox(height: 10),
                          ...List<Widget>.generate(_contributorEntries.length, (
                            int i,
                          ) {
                            final _ContributorEntry entry =
                                _contributorEntries[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Text(
                                        'Member ${i + 1}',
                                        style: _uploadFieldLabelStyle,
                                      ),
                                      const Spacer(),
                                      if (_contributorEntries.length > 1)
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _contributorEntries[i].dispose();
                                              _contributorEntries.removeAt(i);
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                            size: 20,
                                            color: Color(0xFF7A2C22),
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: entry.nameController,
                                    style: _uploadInputTextStyle,
                                    decoration: _uploadInputDecoration(
                                      hintText: 'Enter member name',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    isDense: true,
                                    isExpanded: true,
                                    initialValue: entry.selectedPosition,
                                    items: _ContributorEntry.positionOptions
                                        .map(
                                          (String opt) =>
                                              DropdownMenuItem<String>(
                                                value: opt,
                                                child: Text(
                                                  opt,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                        )
                                        .toList(growable: false),
                                    onChanged: (String? val) {
                                      setState(
                                        () => entry.selectedPosition = val,
                                      );
                                    },
                                    style: _uploadInputTextStyle,
                                    decoration: _uploadInputDecoration(
                                      hintText: 'Select position',
                                    ),
                                  ),
                                  if (entry.selectedPosition ==
                                      'Other') ...<Widget>[
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: entry.otherController,
                                      style: _uploadInputTextStyle,
                                      decoration: _uploadInputDecoration(
                                        hintText: 'Please specify role',
                                      ),
                                    ),
                                  ],
                                  if (i < _contributorEntries.length - 1)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: Divider(
                                        color: _lineColor,
                                        height: 1,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                          TextButton.icon(
                            onPressed: () {
                              setState(
                                () => _contributorEntries.add(
                                  _ContributorEntry(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.add,
                              size: 16,
                              color: _uploadPrimary,
                            ),
                            label: const Text(
                              'Add Member',
                              style: TextStyle(
                                fontSize: 13,
                                color: _uploadPrimary,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Divider(color: _lineColor, height: 1),
                          const SizedBox(height: 14),
                          // Institution (last)
                          _buildNotesField(
                            label: 'Institution / Organization',
                            controller: _institutionController,
                            hint: 'Enter institution or organization',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // ── Notes & Remarks
                    _uploadFormCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Notes & Remarks',
                            style: _uploadSectionTitleStyle,
                          ),
                          const SizedBox(height: 14),
                          _buildNotesField(
                            label: 'Researcher Notes',
                            controller: _researcherNotesController,
                            hint: 'Enter field notes or remarks',
                            maxLines: 4,
                          ),
                          const SizedBox(height: 10),
                          _buildNotesField(
                            label: 'Unusual Observations',
                            controller: _unusualObservationsController,
                            hint: 'Describe any unusual findings',
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // ── Related Study
                    _uploadFormCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Text(
                                'Related Study',
                                style: _uploadSectionTitleStyle,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E3),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Optional',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _uploadPrimary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          for (int i = 0; i < _relatedStudyEntries.length; i++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: i == _relatedStudyEntries.length - 1
                                    ? 0
                                    : 18,
                              ),
                              child: _buildRelatedStudyEntry(i),
                            ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: _addRelatedStudy,
                            icon: const Icon(
                              Icons.add_circle_outline_rounded,
                              size: 18,
                              color: _uploadPrimary,
                            ),
                            label: const Text(
                              'Add Another Study',
                              style: TextStyle(
                                color: _uploadPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Draft-first flow: save here, then submit from My Drafts after review/edit.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: _mutedTextColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _uploadSaveDraftButton(
                onPressed: _isSavingDraft ? null : _saveDraft,
                label: _isSavingDraft ? 'Saving Draft...' : 'Save as Draft',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WebDraft {
  const _WebDraft({
    required this.draftId,
    required this.updatedAt,
    required this.scientificName,
    required this.rawData,
  });
  final String draftId;
  final DateTime updatedAt;
  final String scientificName;
  final Map<String, dynamic> rawData;
  static Future<List<_WebDraft>> load() async {
    try {
      final SupabaseClient supabase = Supabase.instance.client;
      final String? email = supabase.auth.currentUser?.email;
      if (email == null || email.isEmpty) return const <_WebDraft>[];
      final List<dynamic> rows = await supabase
          .from('species_sightings')
          .select(
            '*, sighting_habitat(*), sighting_morphology(*), '
            'sighting_conservation(*), sighting_team_member(*)',
          )
          .eq('researcher_email', email)
          .eq('review_status', 'draft')
          .order('updated_at', ascending: false)
          .timeout(_kNetworkTimeout);
      return rows
          .whereType<Map>()
          // Exclude mobile-synced rows — those are owned by local app storage,
          // not by the web, even though they now exist in Supabase.
          .where(
            (Map row) => !((row['entry_id'] ?? '').toString().startsWith(
              'MOBILE-DRAFT-',
            )),
          )
          .map((Map row) {
            final String sciName = (row['scientific_name'] ?? '')
                .toString()
                .trim();
            final DateTime updatedAt =
                DateTime.tryParse(
                  (row['updated_at'] ?? row['created_at'] ?? '').toString(),
                ) ??
                DateTime.now();
            final Map<String, dynamic> data = Map<String, dynamic>.from(row);
            return _WebDraft(
              draftId: (row['sighting_id'] ?? row['entry_id'] ?? '').toString(),
              updatedAt: updatedAt,
              scientificName: sciName,
              rawData: data,
            );
          })
          .toList(growable: false);
    } catch (_) {
      return const <_WebDraft>[];
    }
  }

  static Future<void> delete(String sightingId) async {
    final int? id = int.tryParse(sightingId);
    if (id != null) {
      await Supabase.instance.client
          .from('species_sightings')
          .delete()
          .eq('sighting_id', id);
    } else {
      await Supabase.instance.client
          .from('species_sightings')
          .delete()
          .eq('entry_id', sightingId);
    }
  }

  UploadSpeciesFlowData toFlowData() {
    final Map<String, dynamic> r = rawData;
    String str(String key) => (r[key] ?? '').toString().trim();
    String numStr(String key) {
      final dynamic v = r[key];
      if (v == null) return '';
      final String s = v.toString().trim();
      if (s == '0' || s == '0.0') return '';
      return s;
    }

    // New-style submissions (see submitNormalizedSighting) write habitat/
    // morphology/conservation/team data into sub-tables instead of the flat
    // legacy columns on species_sightings, so prefer the joined sub-table
    // value and fall back to the flat column only for older rows.
    final Map<String, dynamic> habitat =
        (r['sighting_habitat'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final Map<String, dynamic> morphology =
        (r['sighting_morphology'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final Map<String, dynamic> conservation =
        (r['sighting_conservation'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final List<dynamic> teamMemberRows =
        (r['sighting_team_member'] as List?) ?? <dynamic>[];
    String prefStr(String flatKey, Map<String, dynamic> sub, String subKey) {
      final dynamic v = sub[subKey];
      if (v != null) {
        final String s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return str(flatKey);
    }

    String prefNumStr(String flatKey, Map<String, dynamic> sub, String subKey) {
      final dynamic v = sub[subKey];
      if (v != null) {
        final String s = v.toString().trim();
        if (s.isNotEmpty && s != '0' && s != '0.0') return s;
      }
      return numStr(flatKey);
    }

    String prefBoolStr(
      String flatKey,
      Map<String, dynamic> sub,
      String subKey,
    ) {
      final dynamic v = sub[subKey];
      if (v is bool) return v ? 'yes' : 'no';
      return str(flatKey);
    }

    String prefFirstListStr(
      String flatKey,
      Map<String, dynamic> sub,
      String subKey,
    ) {
      final dynamic v = sub[subKey];
      if (v is List && v.isNotEmpty) return v.first.toString().trim();
      return str(flatKey);
    }

    List<String> prefListStr(
      String flatKey,
      Map<String, dynamic> sub,
      String subKey,
    ) {
      final dynamic v = sub[subKey];
      if (v is List && v.isNotEmpty) {
        return v
            .map((dynamic e) => e.toString().trim())
            .where((String s) => s.isNotEmpty)
            .toList();
      }
      final String single = str(flatKey);
      return single.isNotEmpty ? <String>[single] : <String>[];
    }

    List<UploadRelatedStudyEntry> parseRelatedStudies(String key) {
      final dynamic raw = r[key];
      if (raw == null) return <UploadRelatedStudyEntry>[];
      dynamic decoded = raw;
      if (raw is String) {
        final String trimmed = raw.trim();
        if (trimmed.isEmpty) return <UploadRelatedStudyEntry>[];
        try {
          decoded = jsonDecode(trimmed);
        } catch (_) {
          return <UploadRelatedStudyEntry>[];
        }
      }
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(
              (Map e) => UploadRelatedStudyEntry.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList();
      }
      if (decoded is Map) {
        // Legacy single-study rows stored one JSON object instead of an array.
        final UploadRelatedStudyEntry entry = UploadRelatedStudyEntry.fromJson(
          Map<String, dynamic>.from(decoded),
        );
        return entry.isEmpty
            ? <UploadRelatedStudyEntry>[]
            : <UploadRelatedStudyEntry>[entry];
      }
      return <UploadRelatedStudyEntry>[];
    }

    List<String> parseArr(String key) {
      final dynamic v = r[key];
      if (v == null) return <String>[];
      if (v is List) {
        return v.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
      }
      final String s = v.toString().trim();
      if (s.isEmpty || s == '[]') return <String>[];
      if (s.startsWith('[')) {
        try {
          return (jsonDecode(s) as List<dynamic>)
              .map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList();
        } catch (_) {}
      }
      return <String>[s];
    }

    String floweringFrom = '', floweringTo = '';
    final String fs = prefStr(
      'flowering_season',
      morphology,
      'flowering_season',
    );
    if (fs.contains('–')) {
      final List<String> parts = fs.split('–');
      floweringFrom = parts[0].trim();
      floweringTo = parts.length > 1 ? parts[1].trim() : '';
    } else if (fs.contains('-')) {
      final List<String> parts = fs.split('-');
      floweringFrom = parts[0].trim();
      floweringTo = parts.length > 1 ? parts[1].trim() : '';
    } else {
      floweringFrom = fs;
    }
    // Prefer the joined sighting_team_member rows (what submitNormalizedSighting
    // writes); fall back to the flat team_members column for older rows.
    List<UploadContributorDraft> teamContributors;
    String teamStr;
    if (teamMemberRows.isNotEmpty) {
      teamContributors = teamMemberRows
          .whereType<Map>()
          .map(
            (Map m) => UploadContributorDraft(
              name: (m['member_name'] ?? '').toString().trim(),
              position: (m['member_role'] ?? '').toString().trim(),
            ),
          )
          .where((UploadContributorDraft c) => c.name.isNotEmpty)
          .toList();
      teamStr = teamContributors
          .map((UploadContributorDraft c) => c.name)
          .join(', ');
    } else {
      teamContributors = <UploadContributorDraft>[];
      final dynamic teamRaw = r['team_members'];
      try {
        List<dynamic> teamList = <dynamic>[];
        if (teamRaw is List) {
          teamList = teamRaw;
        } else if (teamRaw is String && teamRaw.trim().isNotEmpty) {
          teamList = jsonDecode(teamRaw) as List<dynamic>;
        }
        teamContributors = teamList
            .whereType<Map>()
            .map(
              (Map e) => UploadContributorDraft(
                name: (e['name'] ?? '').toString().trim(),
                position: (e['role'] ?? '').toString().trim(),
              ),
            )
            .where((UploadContributorDraft c) => c.name.isNotEmpty)
            .toList();
        teamStr = teamContributors
            .map((UploadContributorDraft c) => c.name)
            .join(', ');
      } catch (_) {
        teamStr = (teamRaw ?? '').toString().trim();
      }
    }
    final String conf = str('identification_confidence');
    // species_sightings.genus is written by the web app's submit flow but
    // not always by this app's (see submitNormalizedSighting), so fall back
    // to deriving genus/species-epithet from scientific_name the same way
    // researcher-dashboard.html's openDraftForEditing does — otherwise
    // reopening a cloud-stored draft here would leave Genus/Species blank
    // even though Scientific Name is restored correctly.
    final String sciNameForSplit = str('scientific_name');
    final String genusVal = str('genus').isNotEmpty
        ? str('genus')
        : (sciNameForSplit.isNotEmpty
              ? sciNameForSplit.split(RegExp(r'\s+')).first
              : '');
    final String familyVal =
        (sciNameForSplit.isNotEmpty &&
            genusVal.isNotEmpty &&
            sciNameForSplit.toLowerCase().startsWith(genusVal.toLowerCase()))
        ? sciNameForSplit.substring(genusVal.length).trim()
        : '';
    return UploadSpeciesFlowData(
      draftId: 'WEB-SIGHTING-$draftId',
      entryId: str('entry_id'),
      genus: genusVal,
      family: familyVal,
      scientificName: str('scientific_name'),
      commonNames: parseArr('common_names'),
      localNames: parseArr('local_names'),
      identificationConfidence: conf.isNotEmpty ? conf : 'Confirmed',
      endemicToPhilippines: normalizeEndemicFlag(r['endemic_to_philippines']),
      observationDate: str('observation_date'),
      observationTime: str('observation_time'),
      collectionMethod: str('collection_method'),
      observationType: str('observation_type'),
      voucherSpecimenCollected: r['voucher_collected'] == true,
      mountain: str('mountain_name'),
      province: str('province'),
      municipality: str('municipality'),
      specificSite: str('specific_site_other'),
      specificSiteZone: str('specific_site_zone'),
      latitude: numStr('latitude'),
      longitude: numStr('longitude'),
      elevation: numStr('elevation_meters'),
      habitatType: prefStr('habitat_type', habitat, 'habitat_type'),
      microHabitat: prefStr('microhabitat', habitat, 'microhabitat'),
      growthSubstrate: prefStr('growth_substrate', habitat, 'growth_substrate'),
      hostTreeSpecies: prefStr(
        'host_tree_species',
        habitat,
        'host_tree_species',
      ),
      hostTreeDiameter: prefNumStr(
        'host_tree_diameter',
        habitat,
        'host_tree_dbh_cm',
      ),
      canopyCover: prefNumStr('canopy_cover', habitat, 'canopy_cover_percent'),
      lightExposure: prefStr('light_exposure', habitat, 'light_exposure'),
      soilType: prefStr('soil_type', habitat, 'soil_type'),
      nearbyWaterSource: prefStr(
        'nearby_water_source',
        habitat,
        'nearby_water_source',
      ),
      plantHeight: prefNumStr('plant_height', morphology, 'plant_height_cm'),
      pseudobulbPresent: prefBoolStr(
        'pseudobulb_present',
        morphology,
        'pseudobulb_present',
      ),
      stemLength: prefNumStr('stem_length', morphology, 'stem_length_cm'),
      rootLength: prefNumStr('root_length', morphology, 'root_length_cm'),
      numberOfLeaves: prefNumStr('number_of_leaves', morphology, 'leaf_count'),
      leafShape: prefStr('leaf_shape', morphology, 'leaf_shape'),
      leafLength: prefNumStr('leaf_length', morphology, 'leaf_length_cm'),
      leafWidth: prefNumStr('leaf_width', morphology, 'leaf_width_cm'),
      leafTexture: prefFirstListStr(
        'leaf_texture',
        morphology,
        'leaf_textures',
      ),
      leafArrangement: prefStr(
        'leaf_arrangement',
        morphology,
        'leaf_arrangement',
      ),
      flowerColor: prefStr('flower_color', morphology, 'flower_color'),
      numberOfFlowers: prefNumStr(
        'number_of_flowers',
        morphology,
        'flower_count',
      ),
      flowerDiameter: prefNumStr(
        'flower_diameter',
        morphology,
        'flower_diameter_cm',
      ),
      inflorescenceType: prefStr(
        'inflorescence_type',
        morphology,
        'inflorescence_type',
      ),
      petalCharacteristics: prefStr(
        'petal_characteristics',
        morphology,
        'petal_characteristics',
      ),
      sepalCharacteristics: prefStr(
        'sepal_characteristics',
        morphology,
        'sepal_characteristics',
      ),
      labellumDescription: prefStr(
        'labellum_description',
        morphology,
        'labellum_lip_description',
      ),
      fragrance: prefStr('fragrance', morphology, 'fragrance'),
      bloomingStage: prefStr('blooming_stage', morphology, 'blooming_stage'),
      floweringFromMonth: floweringFrom,
      floweringToMonth: floweringTo,
      fruitPresent: prefBoolStr('fruit_present', morphology, 'fruit_present'),
      fruitType: prefStr('fruit_type', morphology, 'fruit_type'),
      seedCapsuleCondition: prefStr(
        'seed_capsule_condition',
        morphology,
        'seed_capsule_condition',
      ),
      lifeStage: prefStr('life_stage', morphology, 'life_stage'),
      phenology: prefStr('phenology', morphology, 'phenology'),
      numberLocated: prefNumStr(
        'population_count',
        morphology,
        'population_count',
      ),
      populationStatus: prefStr(
        'population_status',
        conservation,
        'population_status',
      ),
      threatLevel: prefStr('threat_level', conservation, 'threat_level'),
      threatTypes: prefListStr('threat_types', conservation, 'threat_types'),
      institution: str('institution'),
      teamMembers: teamStr,
      contributors: teamContributors,
      headResearcher: str('researcher_name'),
      researcherNotes: str('researcher_notes'),
      unusualObservations: str('unusual_observations'),
      ethnobotanicalImportance: str('ethnobotanical_importance'),
      aestheticAppeal: str('aesthetic_appeal'),
      cultivation: str('cultivation'),
      rarity: str('rarity'),
      culturalImportance: str('cultural_importance'),
      relatedStudies: parseRelatedStudies('related_study'),
      updatedAt: updatedAt,
    );
  }
}

class _AnyDraft {
  _AnyDraft.fromApp(UploadSpeciesFlowData d)
    : app = d,
      web = null,
      updatedAt = d.updatedAt;
  _AnyDraft.fromWeb(_WebDraft d) : app = null, web = d, updatedAt = d.updatedAt;
  final UploadSpeciesFlowData? app;
  final _WebDraft? web;
  final DateTime updatedAt;
  bool get isWeb => web != null;
}

class UploadSpeciesDraftsScreen extends StatefulWidget {
  const UploadSpeciesDraftsScreen({super.key});
  @override
  State<UploadSpeciesDraftsScreen> createState() =>
      _UploadSpeciesDraftsScreenState();
}

class _UploadSpeciesDraftsScreenState extends State<UploadSpeciesDraftsScreen> {
  final UploadSpeciesDraftSubmissionApi _submissionApi =
      UploadSpeciesDraftSubmissionApi();
  late Future<List<_AnyDraft>> _allDraftsFuture;
  String? _submittingDraftKey;
  @override
  void initState() {
    super.initState();
    // Show local drafts immediately (no network needed) instead of blocking
    // on a sync of every unsynced draft first — that made the whole screen
    // hang offline. Sync runs in the background and refreshes the list if it
    // changes anything (e.g. a synced mobile draft losing its "Web" badge).
    _allDraftsFuture = _loadAllDrafts();
    UploadSpeciesDraftStore.syncUnsyncedDrafts().then((_) {
      if (mounted) _reloadDrafts();
    });
  }

  @override
  void dispose() {
    _submissionApi.dispose();
    super.dispose();
  }

  Future<List<_AnyDraft>> _loadAllDrafts() async {
    final List<Object> results = await Future.wait(<Future<Object>>[
      UploadSpeciesDraftStore.loadDrafts(),
      _WebDraft.load(),
    ]);
    final List<UploadSpeciesFlowData> appDrafts =
        results[0] as List<UploadSpeciesFlowData>;
    final List<_WebDraft> webDrafts = results[1] as List<_WebDraft>;
    // IDs of web sightings that the user is currently editing locally.
    final Set<String> locallyEditedWebIds = appDrafts
        .where(
          (UploadSpeciesFlowData d) =>
              d.draftId?.startsWith('WEB-SIGHTING-') == true,
        )
        .map(
          (UploadSpeciesFlowData d) =>
              d.draftId!.substring('WEB-SIGHTING-'.length),
        )
        .toSet();
    // Supabase sighting_ids that already correspond to a local mobile draft,
    // so we don't show the same draft twice (once as local, once as web).
    final Set<String> mobileSyncedWebIds = appDrafts
        .where(
          (UploadSpeciesFlowData d) =>
              d.supabaseSightingId != null &&
              !(d.draftId?.startsWith('WEB-SIGHTING-') ?? false),
        )
        .map((UploadSpeciesFlowData d) => d.supabaseSightingId!.toString())
        .toSet();
    final List<_AnyDraft> combined = <_AnyDraft>[
      // Regular local app drafts (including those synced to Supabase).
      ...appDrafts
          .where(
            (UploadSpeciesFlowData d) =>
                !(d.draftId?.startsWith('WEB-SIGHTING-') ?? false),
          )
          .map(_AnyDraft.fromApp),
      // Locally-edited web drafts (full edit/submit UI).
      ...appDrafts
          .where(
            (UploadSpeciesFlowData d) =>
                d.draftId?.startsWith('WEB-SIGHTING-') == true,
          )
          .map(_AnyDraft.fromApp),
      // Web/remote drafts that are neither locally edited nor already in local store.
      ...webDrafts
          .where(
            (_WebDraft d) =>
                !locallyEditedWebIds.contains(d.draftId) &&
                !mobileSyncedWebIds.contains(d.draftId),
          )
          .map(_AnyDraft.fromWeb),
    ];
    combined.sort(
      (_AnyDraft a, _AnyDraft b) => b.updatedAt.compareTo(a.updatedAt),
    );
    return combined;
  }

  void _reloadDrafts() {
    setState(() {
      _allDraftsFuture = _loadAllDrafts();
    });
  }

  Future<void> _editWebDraft(_WebDraft draft) async {
    final UploadSpeciesFlowData flowData = draft.toFlowData();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            UploadSpeciesInformationScreen(flowData: flowData.copy()),
      ),
    );
    _reloadDrafts();
  }

  String _webDraftKey(_WebDraft draft) => 'WEB-SIGHTING-${draft.draftId}';
  String _formatDraftTimestamp(DateTime timestamp) {
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[timestamp.month - 1]} ${timestamp.day}, ${timestamp.year}';
  }

  Future<Uint8List?> _loadDraftPreview(String path) async {
    final String normalized = path.trim();
    if (normalized.isEmpty) {
      return null;
    }
    try {
      return await XFile(normalized).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Widget _buildDraftPreview(UploadSpeciesFlowData draft) {
    if (draft.images.isEmpty || draft.images.first.path.trim().isEmpty) {
      return Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          color: _surfaceTintColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _lineColor),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.image_outlined, color: _mutedTextColor),
      );
    }
    return FutureBuilder<Uint8List?>(
      future: _loadDraftPreview(draft.images.first.path),
      builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
        final Uint8List? bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: _surfaceTintColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _lineColor),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.broken_image_outlined, color: _mutedTextColor),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(bytes, width: 78, height: 78, fit: BoxFit.cover),
        );
      },
    );
  }

  Future<void> _editDraft(UploadSpeciesFlowData draft) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UploadSpeciesInformationScreen(flowData: draft.copy()),
      ),
    );
    _reloadDrafts();
  }

  String _draftKey(UploadSpeciesFlowData draft, {int fallback = 0}) {
    final String draftId = (draft.draftId ?? '').trim();
    if (draftId.isNotEmpty) {
      return draftId;
    }
    return '${draft.updatedAt.microsecondsSinceEpoch}-$fallback';
  }

  Future<void> _submitDraft(
    UploadSpeciesFlowData draft,
    String draftKey,
  ) async {
    if (_submittingDraftKey != null) {
      return;
    }
    final String? validationError =
        UploadSpeciesFlowValidators.validateSpeciesInformation(draft) ??
        UploadSpeciesFlowValidators.validateSightings(draft) ??
        UploadSpeciesFlowValidators.validateSpeciesValues(draft) ??
        UploadSpeciesFlowValidators.validateImagesAndContributors(draft);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Draft is incomplete: $validationError Continue editing first.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _submittingDraftKey = draftKey;
    });
    try {
      final Map<String, dynamic> result = await _submissionApi.submitDraft(
        draft,
      );
      final String draftId = (draft.draftId ?? '').trim();
      if (draftId.isNotEmpty && !draftId.startsWith('WEB-SIGHTING-')) {
        // Only delete from local store for regular app drafts.
        // Web sighting drafts are updated in the DB by _updateWebSightingDraft.
        await UploadSpeciesDraftStore.deleteDraft(draftId);
      }
      if (!mounted) {
        return;
      }
      _reloadDrafts();
      final int submissionCount =
          int.tryParse((result['submissionCount'] ?? '').toString()) ??
          draft.images.length;
      final String safeName = draft.scientificName.trim().isEmpty
          ? 'Unnamed species'
          : draft.scientificName.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Submission pending review: $safeName ($submissionCount image(s) uploaded).',
          ),
        ),
      );
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const UploadsStatusScreen()),
      );
    } on DraftSubmissionException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to submit draft right now. Please try again later.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submittingDraftKey = null;
        });
      }
    }
  }

  Future<void> _confirmDeleteDraft(UploadSpeciesFlowData draft) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Draft',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to delete this draft? This action cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await UploadSpeciesDraftStore.deleteDraftData(draft);
    if (!mounted) return;
    _reloadDrafts();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Draft deleted.')));
  }

  void _showSubmitPreview(
    BuildContext context,
    UploadSpeciesFlowData draft,
    String draftKey,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _DraftSubmitPreviewSheet(
        draft: draft,
        onConfirmSubmit: () => _submitDraft(draft, draftKey),
      ),
    );
  }

  Widget _buildAppDraftCard(
    UploadSpeciesFlowData draft,
    String currentDraftKey,
  ) {
    final String draftTitle = draft.scientificName.trim().isNotEmpty
        ? draft.scientificName.trim()
        : 'Unnamed species draft';
    final bool isSubmittingCurrentDraft =
        _submittingDraftKey == currentDraftKey;
    final bool isComplete =
        draft.scientificName.trim().isNotEmpty &&
        draft.observationDate.trim().isNotEmpty &&
        draft.location.trim().isNotEmpty &&
        draft.latitude.trim().isNotEmpty &&
        draft.longitude.trim().isNotEmpty &&
        draft.headResearcher.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _lineColor),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildDraftPreview(draft),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        draftTitle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _textColor,
                          fontStyle: draft.scientificName.trim().isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Updated ${_formatDraftTimestamp(draft.updatedAt)}',
                        style: TextStyle(fontSize: 11, color: _mutedTextColor),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${draft.images.length} image(s) · ${draft.contributors.where((UploadContributorDraft c) => c.name.trim().isNotEmpty).length} contributor(s)',
                        style: TextStyle(fontSize: 11, color: _mutedTextColor),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isComplete
                              ? const Color(0xFFE6F4EA)
                              : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isComplete
                              ? '✓ Ready to submit'
                              : '⚠ Missing required fields',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isComplete
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFE65100),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _lineColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editDraft(draft),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryColor,
                      side: BorderSide(color: _primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isSubmittingCurrentDraft
                        ? null
                        : () => _showSubmitPreview(
                            context,
                            draft,
                            currentDraftKey,
                          ),
                    icon: isSubmittingCurrentDraft
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(
                      isSubmittingCurrentDraft ? 'Submitting...' : 'Submit',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _confirmDeleteDraft(draft),
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: Colors.red,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFFEBEE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebDraftCard(_WebDraft draft) {
    final String title = draft.scientificName.isNotEmpty
        ? draft.scientificName
        : 'Untitled draft';
    final String observationDate = (draft.rawData['observation_date'] ?? '')
        .toString()
        .trim();
    final String location =
        (draft.rawData['mountain_name'] ?? draft.rawData['location'] ?? '')
            .toString()
            .trim();
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _lineColor),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E3),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _lineColor),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.language_rounded,
                    color: _primaryColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _textColor,
                                fontStyle: draft.scientificName.isEmpty
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Web',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Updated ${_formatDraftTimestamp(draft.updatedAt)}',
                        style: TextStyle(fontSize: 11, color: _mutedTextColor),
                      ),
                      if (observationDate.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          'Observed: $observationDate',
                          style: TextStyle(
                            fontSize: 11,
                            color: _mutedTextColor,
                          ),
                        ),
                      ],
                      if (location.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          'Location: $location',
                          style: TextStyle(
                            fontSize: 11,
                            color: _mutedTextColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _lineColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editWebDraft(draft),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryColor,
                      side: BorderSide(color: _primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _submittingDraftKey == _webDraftKey(draft)
                        ? null
                        : () {
                            final UploadSpeciesFlowData flowData = draft
                                .toFlowData();
                            _showSubmitPreview(
                              context,
                              flowData,
                              _webDraftKey(draft),
                            );
                          },
                    icon: _submittingDraftKey == _webDraftKey(draft)
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(
                      _submittingDraftKey == _webDraftKey(draft)
                          ? 'Submitting...'
                          : 'Submit',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _confirmDeleteWebDraft(draft),
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: Colors.red,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFFEBEE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteWebDraft(_WebDraft draft) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Web Draft',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This will delete the draft from the website as well. This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _WebDraft.delete(draft.draftId);
      if (!mounted) return;
      _reloadDrafts();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Web draft deleted.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete web draft.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _appBackgroundColor,
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _UploadFormHeader(title: 'My Drafts'),
                    const SizedBox(height: 16),
                    Expanded(
                      child: FutureBuilder<List<_AnyDraft>>(
                        future: _allDraftsFuture,
                        builder:
                            (
                              BuildContext context,
                              AsyncSnapshot<List<_AnyDraft>> snapshot,
                            ) {
                              if (snapshot.connectionState !=
                                  ConnectionState.done) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final List<_AnyDraft> all =
                                  snapshot.data ?? <_AnyDraft>[];
                              if (all.isEmpty) {
                                return Center(
                                  child: Text(
                                    'No drafts saved yet.',
                                    style: TextStyle(
                                      color: _mutedTextColor,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                );
                              }
                              return ListView.separated(
                                itemCount: all.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (BuildContext context, int index) {
                                  final _AnyDraft entry = all[index];
                                  if (entry.isWeb) {
                                    return _buildWebDraftCard(entry.web!);
                                  }
                                  final UploadSpeciesFlowData draft =
                                      entry.app!;
                                  final String key = _draftKey(
                                    draft,
                                    fallback: index,
                                  );
                                  return _buildAppDraftCard(draft, key);
                                },
                              );
                            },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftSubmitPreviewSheet extends StatelessWidget {
  const _DraftSubmitPreviewSheet({
    required this.draft,
    required this.onConfirmSubmit,
  });
  final UploadSpeciesFlowData draft;
  final VoidCallback onConfirmSubmit;
  String _fileBasename(String path) =>
      path.replaceAll('\\', '/').split('/').last;
  Widget _imageGrid(List<UploadSpeciesImageDraft> images) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 88,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: images.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (BuildContext context, int i) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FutureBuilder<Uint8List>(
                future: XFile(images[i].path).readAsBytes(),
                builder: (BuildContext context, AsyncSnapshot<Uint8List> snap) {
                  if (snap.hasData) {
                    return Image.memory(
                      snap.data!,
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                    );
                  }
                  return Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3F4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.image_outlined,
                      color: Color(0xFFBDBDBD),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _fileRow(IconData icon, String label, String filename) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF80868B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: <Widget>[
                Icon(icon, size: 14, color: const Color(0xFF0D530E)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    filename,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF306D29),
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF5F6368),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        ...rows,
      ],
    );
  }

  Widget _row(
    String label,
    String value, {
    bool required = false,
    bool missing = false,
  }) {
    final bool empty = value.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF80868B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: missing
                ? Row(
                    children: <Widget>[
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: Color(0xFFE65100),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Required — not filled',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE65100),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : empty
                ? const Text(
                    '—',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFBDBDBD),
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : Text(
                    value.trim(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF306D29),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasName = draft.scientificName.trim().isNotEmpty;
    final bool hasDate = draft.observationDate.trim().isNotEmpty;
    final bool hasLocation = draft.location.trim().isNotEmpty;
    final bool hasCoords =
        draft.latitude.trim().isNotEmpty && draft.longitude.trim().isNotEmpty;
    final bool hasHeadResearcher = draft.headResearcher.trim().isNotEmpty;
    final bool isReady =
        hasName && hasDate && hasLocation && hasCoords && hasHeadResearcher;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ScrollController sc) => Column(
        children: <Widget>[
          // Handle
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFDADCE0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Review Before Submitting',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF306D29),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  color: const Color(0xFF5F6368),
                ),
              ],
            ),
          ),
          if (!isReady)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFB74D)),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFE65100),
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Some required fields are missing. Fill them before submitting.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFE65100),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              controller: sc,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: <Widget>[
                _section('SPECIES INFORMATION', <Widget>[
                  _row(
                    'Scientific Name',
                    draft.scientificName,
                    required: true,
                    missing: !hasName,
                  ),
                  _row('Common Name', draft.commonName),
                  _row(
                    'Local Name(s)',
                    draft.localNames
                        .where((String n) => n.trim().isNotEmpty)
                        .join(', '),
                  ),
                  _row('Family', draft.family),
                  _row('Genus', draft.genus),
                  _row('ID Confidence', draft.identificationConfidence),
                  _row(
                    'Endemic to PH',
                    draft.endemicToPhilippines.isEmpty
                        ? '-'
                        : draft.endemicToPhilippines,
                  ),
                ]),
                _section('SIGHTING & LOCATION', <Widget>[
                  _row(
                    'Date of Observation',
                    draft.observationDate,
                    required: true,
                    missing: !hasDate,
                  ),
                  _row('Time', draft.observationTime),
                  _row(
                    'Location',
                    draft.location,
                    required: true,
                    missing: !hasLocation,
                  ),
                  _row(
                    'Coordinates',
                    hasCoords ? '${draft.latitude}, ${draft.longitude}' : '',
                    required: true,
                    missing: !hasCoords,
                  ),
                  _row('Province', draft.province),
                  _row('Municipality', draft.municipality),
                  _row('Mountain', draft.mountain),
                  _row('Altitude', draft.altitude),
                  _row('Elevation', draft.elevation),
                  _row('Specific Site', draft.specificSite),
                  _row('Habitat Type', draft.habitatType),
                  _row('Micro-habitat', draft.microHabitat),
                  _row('Growth Substrate', draft.growthSubstrate),
                  _row('Host Tree Species', draft.hostTreeSpecies),
                  _row('Host Tree Diameter', draft.hostTreeDiameter),
                  _row('Canopy Cover', draft.canopyCover),
                  _row('Light Exposure', draft.lightExposure),
                  _row('Soil Type', draft.soilType),
                  _row('Nearby Water Source', draft.nearbyWaterSource),
                  _row('Observation Type', draft.observationType),
                  _row('Collection Method', draft.collectionMethod),
                  _row(
                    'Voucher Specimen',
                    draft.voucherSpecimenCollected ? 'Yes' : 'No',
                  ),
                  _row('Number Located', draft.numberLocated),
                ]),
                _section('PLANT STRUCTURE', <Widget>[
                  _row('Plant Height', draft.plantHeight),
                  _row('Pseudobulb Present', draft.pseudobulbPresent),
                  _row('Stem Length', draft.stemLength),
                  _row('Root Length', draft.rootLength),
                ]),
                _section('LEAVES', <Widget>[
                  _row('Leaf Type', draft.leafType),
                  _row('Leaf Shape', draft.leafShape),
                  _row('Number of Leaves', draft.numberOfLeaves),
                  _row('Leaf Length', draft.leafLength),
                  _row('Leaf Width', draft.leafWidth),
                  _row('Leaf Texture', draft.leafTexture),
                  _row('Leaf Arrangement', draft.leafArrangement),
                ]),
                _section('FLOWERS', <Widget>[
                  _row('Flower Color', draft.flowerColor),
                  _row('Number of Flowers', draft.numberOfFlowers),
                  _row('Flower Diameter', draft.flowerDiameter),
                  _row('Inflorescence Type', draft.inflorescenceType),
                  _row('Petal Characteristics', draft.petalCharacteristics),
                  _row('Sepal Characteristics', draft.sepalCharacteristics),
                  _row('Labellum / Lip', draft.labellumDescription),
                  _row('Fragrance', draft.fragrance),
                  _row('Blooming Stage', draft.bloomingStage),
                  _row('Flowering From', draft.floweringFromMonth),
                  _row('Flowering To', draft.floweringToMonth),
                ]),
                _section('FRUITS & SEEDS', <Widget>[
                  _row('Fruit Present', draft.fruitPresent),
                  _row('Fruit Type', draft.fruitType),
                  _row('Seed Capsule Condition', draft.seedCapsuleCondition),
                ]),
                _section('ECOLOGICAL DATA', <Widget>[
                  _row('Life Stage', draft.lifeStage),
                  _row('Phenology', draft.phenology),
                  _row('Population Status', draft.populationStatus),
                  _row('Threat Level', draft.threatLevel),
                  _row('Threat Type', draft.threatTypes.join(', ')),
                  _row(
                    'Ethnobotanical Importance',
                    draft.ethnobotanicalImportance,
                  ),
                  _row('Cultural Importance', draft.culturalImportance),
                  _row('Aesthetic Appeal', draft.aestheticAppeal),
                  _row('Cultivation', draft.cultivation),
                ]),
                _section('IMAGES & CONTRIBUTORS', <Widget>[
                  _row('Images', '${draft.images.length} image(s)'),
                  if (draft.images.isNotEmpty) _imageGrid(draft.images),
                  _row(
                    'Head Researcher',
                    draft.headResearcher,
                    required: true,
                    missing: !hasHeadResearcher,
                  ),
                  _row(
                    'Team Members',
                    draft.contributors
                        .where(
                          (UploadContributorDraft c) =>
                              c.name.trim().isNotEmpty,
                        )
                        .map(
                          (UploadContributorDraft c) =>
                              c.position.trim().isNotEmpty
                              ? '${c.name} (${c.position})'
                              : c.name,
                        )
                        .join(', '),
                  ),
                  _row('Institution', draft.institution),
                ]),
                _section('ATTACHED FILES', <Widget>[
                  if (draft.videoPath.trim().isNotEmpty)
                    _fileRow(
                      Icons.videocam_rounded,
                      'Video',
                      _fileBasename(draft.videoPath),
                    ),
                  for (final UploadRelatedStudyEntry study
                      in draft.relatedStudies)
                    if (study.filePath.trim().isNotEmpty)
                      _fileRow(
                        Icons.attach_file_rounded,
                        'Study File',
                        _fileBasename(study.filePath),
                      ),
                  if (draft.videoPath.trim().isEmpty &&
                      draft.relatedStudies.every(
                        (UploadRelatedStudyEntry s) =>
                            s.filePath.trim().isEmpty,
                      ))
                    _row('Files', ''),
                ]),
                _section(
                  'RELATED STUDY',
                  draft.relatedStudies.isEmpty
                      ? <Widget>[
                          _row('Study Title', ''),
                          _row('Study Link', ''),
                        ]
                      : <Widget>[
                          for (
                            int i = 0;
                            i < draft.relatedStudies.length;
                            i++
                          ) ...<Widget>[
                            _row(
                              'Study ${i + 1} Title',
                              draft.relatedStudies[i].title,
                            ),
                            _row(
                              'Study ${i + 1} Link',
                              draft.relatedStudies[i].link,
                            ),
                            if (draft.relatedStudies[i].filePath
                                .trim()
                                .isNotEmpty)
                              _row(
                                'Study ${i + 1} File',
                                _fileBasename(draft.relatedStudies[i].filePath),
                              ),
                          ],
                        ],
                ),
                _section('NOTES & REMARKS', <Widget>[
                  _row('Researcher Notes', draft.researcherNotes),
                  _row('Unusual Observations', draft.unusualObservations),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isReady
                    ? () {
                        Navigator.pop(context);
                        onConfirmSubmit();
                      }
                    : null,
                icon: const Icon(Icons.send_rounded),
                label: Text(
                  isReady ? 'Submit Now' : 'Fill Required Fields First',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D530E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SubmissionStatusItem {
  const SubmissionStatusItem({
    required this.imageUrl,
    required this.title,
    required this.uploadedDate,
    required this.status,
    required this.statusColor,
  });
  final String imageUrl;
  final String title;
  final String uploadedDate;
  final String status;
  final Color statusColor;
  factory SubmissionStatusItem.fromJson(Map<String, dynamic> json) {
    final String title = (json['scientificName'] ?? '').toString().trim();
    final String statusRaw = (json['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final String imageUrlRaw = (json['imageUrl'] ?? '').toString().trim();
    return SubmissionStatusItem(
      imageUrl: imageUrlRaw,
      title: title.isNotEmpty ? title : 'Unnamed species',
      uploadedDate: _formatDate((json['uploadedAt'] ?? '').toString()),
      status: _statusLabel(statusRaw),
      statusColor: _statusColor(statusRaw),
    );
  }
  static String _formatDate(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) {
      return 'Unknown date';
    }
    try {
      final DateTime parsed = DateTime.parse(value);
      const List<String> months = <String>[
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
    } catch (_) {
      return value;
    }
  }

  static String _statusLabel(String status) => reviewStatusLabel(status);
  static Color _statusColor(String status) {
    return reviewStatusColor(status);
  }
}

class _SubmissionFull {
  const _SubmissionFull({
    required this.entryId,
    required this.sightingId,
    required this.scientificName,
    required this.commonNames,
    required this.localNames,
    required this.identificationConfidence,
    required this.endemicToPhilippines,
    required this.status,
    required this.statusColor,
    required this.uploadedDate,
    required this.imageUrl,
    required this.researcherName,
    required this.observationDate,
    required this.observationTime,
    required this.collectionMethod,
    required this.observationType,
    required this.voucherCollected,
    required this.mountainName,
    required this.province,
    required this.municipality,
    required this.specificSite,
    required this.latitude,
    required this.longitude,
    required this.elevationMeters,
    required this.habitatType,
    required this.microhabitat,
    required this.growthSubstrate,
    required this.hostTreeSpecies,
    required this.lightExposure,
    required this.soilType,
    required this.nearbyWaterSource,
    required this.plantHeight,
    required this.stemLength,
    required this.rootLength,
    required this.pseudobulbPresent,
    required this.leafCount,
    required this.leafShape,
    required this.leafLength,
    required this.leafWidth,
    required this.leafArrangement,
    required this.flowerColor,
    required this.flowerCount,
    required this.flowerDiameter,
    required this.inflorescenceType,
    required this.petalCharacteristics,
    required this.sepalCharacteristics,
    required this.labellumDescription,
    required this.fragrance,
    required this.bloomingStage,
    required this.floweringSeason,
    required this.fruitPresent,
    required this.fruitType,
    required this.seedCapsuleCondition,
    required this.lifeStage,
    required this.phenology,
    required this.populationCount,
    required this.populationStatus,
    required this.threatLevel,
    required this.threatTypes,
    required this.institution,
    required this.teamMembers,
    required this.researcherNotes,
    required this.relatedStudy,
    required this.reviewNotes,
    required this.closeupFlowerUrl,
    required this.habitatPhotoUrl,
  });
  final String entryId;
  final String sightingId;
  bool get is3d => entryId.startsWith('BLOOM-3D-');
  final String scientificName;
  final String commonNames;
  final String localNames;
  final String identificationConfidence;
  final String endemicToPhilippines;
  final String status;
  final Color statusColor;
  final String uploadedDate;
  final String imageUrl;
  final String researcherName;
  final String observationDate;
  final String observationTime;
  final String collectionMethod;
  final String observationType;
  final bool voucherCollected;
  final String mountainName;
  final String province;
  final String municipality;
  final String specificSite;
  final String latitude;
  final String longitude;
  final String elevationMeters;
  final String habitatType;
  final String microhabitat;
  final String growthSubstrate;
  final String hostTreeSpecies;
  final String lightExposure;
  final String soilType;
  final String nearbyWaterSource;
  final String plantHeight;
  final String stemLength;
  final String rootLength;
  final String pseudobulbPresent;
  final String leafCount;
  final String leafShape;
  final String leafLength;
  final String leafWidth;
  final String leafArrangement;
  final String flowerColor;
  final String flowerCount;
  final String flowerDiameter;
  final String inflorescenceType;
  final String petalCharacteristics;
  final String sepalCharacteristics;
  final String labellumDescription;
  final String fragrance;
  final String bloomingStage;
  final String floweringSeason;
  final String fruitPresent;
  final String fruitType;
  final String seedCapsuleCondition;
  final String lifeStage;
  final String phenology;
  final String populationCount;
  final String populationStatus;
  final String threatLevel;
  final String threatTypes;
  final String institution;
  final String teamMembers;
  final String researcherNotes;
  final String relatedStudy;
  final String reviewNotes;
  final String closeupFlowerUrl;
  final String habitatPhotoUrl;
  static String _jsonArrayToString(dynamic raw) {
    if (raw == null) return '';
    if (raw is List) return raw.map((e) => e.toString()).join(', ');
    final String s = raw.toString().trim();
    if (s.startsWith('[')) {
      try {
        final List<dynamic> list = jsonDecode(s) as List<dynamic>;
        return list.map((e) => e.toString()).join(', ');
      } catch (_) {}
    }
    return s;
  }

  static _SubmissionFull fromRow(Map<dynamic, dynamic> row) {
    final String statusRaw = (row['review_status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final Color statusColor = reviewStatusColor(statusRaw);
    final String statusLabel = reviewStatusLabel(statusRaw);
    final String rawDate = (row['created_at'] ?? '').toString().trim();
    String uploadedDate = rawDate;
    try {
      final DateTime d = DateTime.parse(rawDate);
      const List<String> months = <String>[
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      uploadedDate = '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {}
    final dynamic teamRaw = row['team_members'];
    String teamMembersStr = '';
    try {
      List<dynamic> teamList;
      if (teamRaw is List) {
        teamList = teamRaw;
      } else if (teamRaw is String && teamRaw.trim().isNotEmpty) {
        teamList = jsonDecode(teamRaw) as List<dynamic>;
      } else {
        teamList = <dynamic>[];
      }
      teamMembersStr = teamList
          .map((dynamic e) {
            if (e is Map) {
              final String name = (e['name'] ?? '').toString().trim();
              final String role = (e['role'] ?? '').toString().trim();
              return role.isNotEmpty ? '$name ($role)' : name;
            }
            return e.toString().trim();
          })
          .where((String s) => s.isNotEmpty)
          .join(', ');
    } catch (_) {
      teamMembersStr = (teamRaw ?? '').toString().trim();
    }
    String str(String key) => (row[key] ?? '').toString().trim();
    String num(String key) {
      final dynamic v = row[key];
      if (v == null) return '';
      return v.toString().trim();
    }

    String photo(String key) => _orchidImageUrl(str(key));
    bool boolean(String key) {
      final dynamic v = row[key];
      if (v == true) return true;
      final String s = v?.toString().toLowerCase() ?? '';
      return s == 'true' || s == 'yes' || s == '1';
    }

    // New-style rows (see submitNormalizedSighting) carry habitat/
    // morphology/conservation/team/media detail in joined sub-tables
    // instead of these flat columns.
    final Map<String, dynamic> habitat =
        (row['sighting_habitat'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final Map<String, dynamic> morphology =
        (row['sighting_morphology'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final Map<String, dynamic> conservation =
        (row['sighting_conservation'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final List<dynamic> teamMemberRows =
        (row['sighting_team_member'] as List?) ?? <dynamic>[];
    final List<dynamic> mediaRows =
        (row['sighting_media'] as List?) ?? <dynamic>[];
    final Map<String, dynamic>? mountainEmbed = row['mountain'] is Map
        ? (row['mountain'] as Map).cast<String, dynamic>()
        : null;
    String prefStr(String flatKey, Map<String, dynamic> sub, String subKey) {
      final dynamic v = sub[subKey];
      if (v != null) {
        final String s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return str(flatKey);
    }

    String prefNumStr(String flatKey, Map<String, dynamic> sub, String subKey) {
      final dynamic v = sub[subKey];
      if (v != null) {
        final String s = v.toString().trim();
        if (s.isNotEmpty && s != '0' && s != '0.0') return s;
      }
      return num(flatKey);
    }

    String prefBoolStr(
      String flatKey,
      Map<String, dynamic> sub,
      String subKey,
    ) {
      final dynamic v = sub[subKey];
      if (v is bool) return v ? 'Yes' : 'No';
      return str(flatKey);
    }

    String prefFirstListStr(
      String flatKey,
      Map<String, dynamic> sub,
      String subKey,
    ) {
      final dynamic v = sub[subKey];
      if (v is List && v.isNotEmpty)
        return v.map((e) => e.toString()).join(', ');
      return _jsonArrayToString(row[flatKey]);
    }

    String mediaPhoto(String category, String flatKey) {
      for (final dynamic m in mediaRows) {
        if (m is Map && m['media_category'] == category) {
          final dynamic pic = m['picture'];
          if (pic is Map) {
            final String path = (pic['file_path'] ?? '').toString().trim();
            if (path.isNotEmpty) return _orchidImageUrl(path);
          }
        }
      }
      return photo(flatKey);
    }

    if (teamMemberRows.isNotEmpty) {
      teamMembersStr = teamMemberRows
          .whereType<Map>()
          .map((Map e) {
            final String name = (e['member_name'] ?? '').toString().trim();
            final String role = (e['member_role'] ?? '').toString().trim();
            return role.isNotEmpty ? '$name ($role)' : name;
          })
          .where((String s) => s.isNotEmpty)
          .join(', ');
    }
    final String mountainLabel = (mountainEmbed?['mountain_name'] ?? '')
        .toString()
        .trim();
    return _SubmissionFull(
      entryId: str('entry_id'),
      sightingId: str('sighting_id'),
      scientificName: str('scientific_name'),
      commonNames: _jsonArrayToString(row['common_names']),
      localNames: _jsonArrayToString(row['local_names']),
      identificationConfidence: str('identification_confidence'),
      endemicToPhilippines: normalizeEndemicFlag(row['endemic_to_philippines']),
      status: statusLabel,
      statusColor: statusColor,
      uploadedDate: uploadedDate,
      imageUrl: mediaPhoto('whole_plant', 'whole_plant_photo_path'),
      researcherName: str('researcher_name'),
      observationDate: str('observation_date'),
      observationTime: str('observation_time'),
      collectionMethod: str('collection_method'),
      observationType: str('observation_type'),
      voucherCollected: boolean('voucher_collected'),
      mountainName: mountainLabel,
      province: str('province'),
      municipality: str('municipality'),
      specificSite: str('specific_site_zone').isNotEmpty
          ? str('specific_site_zone')
          : str('specific_site_other'),
      latitude: num('latitude'),
      longitude: num('longitude'),
      elevationMeters: num('elevation_meters'),
      habitatType: prefStr('habitat_type', habitat, 'habitat_type'),
      microhabitat: prefStr('microhabitat', habitat, 'microhabitat'),
      growthSubstrate: prefStr('growth_substrate', habitat, 'growth_substrate'),
      hostTreeSpecies: prefStr(
        'host_tree_species',
        habitat,
        'host_tree_species',
      ),
      lightExposure: prefStr('light_exposure', habitat, 'light_exposure'),
      soilType: prefStr('soil_type', habitat, 'soil_type'),
      nearbyWaterSource: prefStr(
        'nearby_water_source',
        habitat,
        'nearby_water_source',
      ),
      plantHeight: prefNumStr('plant_height', morphology, 'plant_height_cm'),
      stemLength: prefNumStr('stem_length', morphology, 'stem_length_cm'),
      rootLength: prefNumStr('root_length', morphology, 'root_length_cm'),
      pseudobulbPresent: prefBoolStr(
        'pseudobulb_present',
        morphology,
        'pseudobulb_present',
      ),
      leafCount: prefNumStr('number_of_leaves', morphology, 'leaf_count'),
      leafShape: prefStr('leaf_shape', morphology, 'leaf_shape'),
      leafLength: prefNumStr('leaf_length', morphology, 'leaf_length_cm'),
      leafWidth: prefNumStr('leaf_width', morphology, 'leaf_width_cm'),
      leafArrangement: prefStr(
        'leaf_arrangement',
        morphology,
        'leaf_arrangement',
      ),
      flowerColor: prefStr('flower_color', morphology, 'flower_color'),
      flowerCount: prefNumStr('number_of_flowers', morphology, 'flower_count'),
      flowerDiameter: prefNumStr(
        'flower_diameter',
        morphology,
        'flower_diameter_cm',
      ),
      inflorescenceType: prefStr(
        'inflorescence_type',
        morphology,
        'inflorescence_type',
      ),
      petalCharacteristics: prefStr(
        'petal_characteristics',
        morphology,
        'petal_characteristics',
      ),
      sepalCharacteristics: prefStr(
        'sepal_characteristics',
        morphology,
        'sepal_characteristics',
      ),
      labellumDescription: prefStr(
        'labellum_description',
        morphology,
        'labellum_lip_description',
      ),
      fragrance: prefStr('fragrance', morphology, 'fragrance'),
      bloomingStage: prefStr('blooming_stage', morphology, 'blooming_stage'),
      floweringSeason: prefStr(
        'flowering_season',
        morphology,
        'flowering_season',
      ),
      fruitPresent: prefBoolStr('fruit_present', morphology, 'fruit_present'),
      fruitType: prefStr('fruit_type', morphology, 'fruit_type'),
      seedCapsuleCondition: prefStr(
        'seed_capsule_condition',
        morphology,
        'seed_capsule_condition',
      ),
      lifeStage: prefStr('life_stage', morphology, 'life_stage'),
      phenology: prefStr('phenology', morphology, 'phenology'),
      populationCount: prefNumStr(
        'population_count',
        morphology,
        'population_count',
      ),
      populationStatus: prefStr(
        'population_status',
        conservation,
        'population_status',
      ),
      threatLevel: prefStr('threat_level', conservation, 'threat_level'),
      threatTypes: prefFirstListStr(
        'threat_types',
        conservation,
        'threat_types',
      ),
      institution: str('institution'),
      teamMembers: teamMembersStr,
      researcherNotes: str('researcher_notes'),
      relatedStudy: str('related_study'),
      reviewNotes: str('review_notes'),
      closeupFlowerUrl: mediaPhoto(
        'closeup_flower',
        'closeup_flower_photo_path',
      ),
      habitatPhotoUrl: mediaPhoto('habitat', 'habitat_photo_path'),
    );
  }
}

class UploadsStatusScreen extends StatefulWidget {
  const UploadsStatusScreen({super.key});
  @override
  State<UploadsStatusScreen> createState() => _UploadsStatusScreenState();
}

class _UploadsStatusScreenState extends State<UploadsStatusScreen> {
  static const String _cacheKey = 'my_submissions';
  late final Future<List<_SubmissionFull>> _itemsFuture;
  @override
  void initState() {
    super.initState();
    _itemsFuture = _loadSubmissions();
  }

  Future<List<_SubmissionFull>> _loadSubmissions() async {
    try {
      final SupabaseClient supabase = Supabase.instance.client;
      final String userEmail = supabase.auth.currentUser?.email ?? '';
      final List<dynamic> data = await supabase
          .from('species_sightings')
          .select(
            'entry_id, sighting_id, scientific_name, review_status, '
            'common_names, local_names, identification_confidence, endemic_to_philippines, '
            'created_at, observation_date, observation_time, collection_method, '
            'observation_type, voucher_collected, mountain(mountain_name), '
            'specific_site_zone, specific_site_other, latitude, longitude, elevation_meters, '
            'researcher_notes, related_study, '
            'sighting_habitat(*), sighting_morphology(*), sighting_conservation(*), '
            'sighting_team_member(*), sighting_media(*, picture(*))',
          )
          .eq('researcher_email', userEmail)
          .order('created_at', ascending: false)
          .timeout(_kNetworkTimeout);
      final List<Map<String, dynamic>> rows = data
          .whereType<Map>()
          .map((Map r) => Map<String, dynamic>.from(r))
          .toList(growable: false);
      // Cache raw rows (not the parsed model) so _SubmissionFull.fromRow
      // stays the single source of truth for how a row is interpreted.
      unawaited(OfflineCache.save(_cacheKey, rows));
      return rows
          .where(
            (Map row) =>
                (row['review_status'] ?? '').toString().toLowerCase() !=
                'draft',
          )
          .map(_SubmissionFull.fromRow)
          .toList(growable: false);
    } catch (_) {
      final dynamic cached = await OfflineCache.load(_cacheKey);
      if (cached is List) {
        try {
          return cached
              .whereType<Map>()
              .map((Map r) => Map<String, dynamic>.from(r))
              .where(
                (Map row) =>
                    (row['review_status'] ?? '').toString().toLowerCase() !=
                    'draft',
              )
              .map(_SubmissionFull.fromRow)
              .toList(growable: false);
        } catch (_) {}
      }
      return const <_SubmissionFull>[];
    }
  }

  Widget _buildList(List<_SubmissionFull> items) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No submissions yet.',
          style: TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: _mutedTextColor,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (BuildContext context, int index) {
        final _SubmissionFull item = items[index];
        return GestureDetector(
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _SubmissionDetailSheet(item: item),
          ),
          child: _UploadStatusTile(
            imageUrl: item.imageUrl,
            title: item.scientificName.isNotEmpty
                ? item.scientificName
                : 'Unnamed species',
            uploadedDate: item.uploadedDate,
            status: item.status,
            statusColor: item.statusColor,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _appBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _UploadFormHeader(title: 'My Submissions'),
              const SizedBox(height: 14),
              // ── Submissions list
              Expanded(
                child: FutureBuilder<List<_SubmissionFull>>(
                  future: _itemsFuture,
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<List<_SubmissionFull>> snapshot,
                      ) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final List<_SubmissionFull> sightings =
                            (snapshot.data ?? const <_SubmissionFull>[])
                                .where((s) => !s.is3d)
                                .toList();
                        return _buildList(sightings);
                      },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmissionDetailSheet extends StatelessWidget {
  const _SubmissionDetailSheet({required this.item});
  final _SubmissionFull item;
  Widget _section(String title, List<Widget> rows) {
    final List<Widget> nonEmpty = rows
        .whereType<_DetailRow>()
        .where((_DetailRow r) => r.value.trim().isNotEmpty)
        .toList(growable: false);
    if (nonEmpty.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF5F6368),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        ...nonEmpty,
      ],
    );
  }

  _DetailRow _row(String label, String value) =>
      _DetailRow(label: label, value: value);
  Widget _photoRow(String label, String url) {
    if (url.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF80868B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: url,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(
                height: 180,
                color: const Color(0xFFF1F4F7),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              ),
              errorWidget: (_, _, _) => Container(
                height: 100,
                color: const Color(0xFFF1F4F7),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: Color(0xFFBDBDBD),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ScrollController sc) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDADCE0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.scientificName.isNotEmpty
                              ? item.scientificName
                              : 'Unnamed species',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF306D29),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: item.statusColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: item.statusColor.withAlpha(80),
                            ),
                          ),
                          child: Text(
                            item.status,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: item.statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    color: const Color(0xFF5F6368),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: <Widget>[
                  // ── Photos first for quick visual review
                  if (item.imageUrl.isNotEmpty ||
                      item.closeupFlowerUrl.isNotEmpty ||
                      item.habitatPhotoUrl.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    const Text(
                      'PHOTOS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5F6368),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _photoRow('Whole Plant', item.imageUrl),
                    _photoRow('Close-up Flower', item.closeupFlowerUrl),
                    _photoRow('Habitat', item.habitatPhotoUrl),
                  ],
                  _section('IDENTIFICATION', <Widget>[
                    _row('Scientific Name', item.scientificName),
                    _row('Common Name(s)', item.commonNames),
                    _row('Local Name(s)', item.localNames),
                    _row('Confidence', item.identificationConfidence),
                    _row('Endemic to Philippines', item.endemicToPhilippines),
                  ]),
                  _section('SIGHTING & LOCATION', <Widget>[
                    _row('Submitted', item.uploadedDate),
                    _row('Researcher', item.researcherName),
                    _row('Date of Observation', item.observationDate),
                    _row('Time', item.observationTime),
                    _row('Mountain / Site', item.mountainName),
                    _row('Province', item.province),
                    _row('Municipality', item.municipality),
                    _row('Specific Site', item.specificSite),
                    _row(
                      'Coordinates',
                      item.latitude.isNotEmpty && item.longitude.isNotEmpty
                          ? '${item.latitude}, ${item.longitude}'
                          : '',
                    ),
                    _row('Elevation (m)', item.elevationMeters),
                    _row('Collection Method', item.collectionMethod),
                    _row('Observation Type', item.observationType),
                    _row(
                      'Voucher Specimen',
                      item.voucherCollected ? 'Yes' : 'No',
                    ),
                  ]),
                  _section('HABITAT', <Widget>[
                    _row('Habitat Type', item.habitatType),
                    _row('Micro-habitat', item.microhabitat),
                    _row('Growth Substrate', item.growthSubstrate),
                    _row('Host Tree Species', item.hostTreeSpecies),
                    _row('Light Exposure', item.lightExposure),
                    _row('Soil Type', item.soilType),
                    _row('Nearby Water Source', item.nearbyWaterSource),
                  ]),
                  _section('PLANT STRUCTURE', <Widget>[
                    _row('Plant Height', item.plantHeight),
                    _row('Stem Length', item.stemLength),
                    _row('Root Length', item.rootLength),
                    _row('Pseudobulb Present', item.pseudobulbPresent),
                  ]),
                  _section('LEAVES', <Widget>[
                    _row('Leaf Count', item.leafCount),
                    _row('Leaf Shape', item.leafShape),
                    _row('Leaf Length', item.leafLength),
                    _row('Leaf Width', item.leafWidth),
                    _row('Leaf Arrangement', item.leafArrangement),
                  ]),
                  _section('FLOWERS', <Widget>[
                    _row('Flower Color', item.flowerColor),
                    _row('Flower Count', item.flowerCount),
                    _row('Flower Diameter', item.flowerDiameter),
                    _row('Inflorescence Type', item.inflorescenceType),
                    _row('Petal Characteristics', item.petalCharacteristics),
                    _row('Sepal Characteristics', item.sepalCharacteristics),
                    _row('Labellum / Lip', item.labellumDescription),
                    _row('Fragrance', item.fragrance),
                    _row('Blooming Stage', item.bloomingStage),
                    _row('Flowering Season', item.floweringSeason),
                  ]),
                  _section('FRUITS & SEEDS', <Widget>[
                    _row('Fruit Present', item.fruitPresent),
                    _row('Fruit Type', item.fruitType),
                    _row('Seed Capsule Condition', item.seedCapsuleCondition),
                  ]),
                  _section('POPULATION & THREATS', <Widget>[
                    _row('Life Stage', item.lifeStage),
                    _row('Phenology', item.phenology),
                    _row('Population Count', item.populationCount),
                    _row('Population Status', item.populationStatus),
                    _row('Threat Level', item.threatLevel),
                    _row('Threat Types', item.threatTypes),
                  ]),
                  _section('TEAM & INSTITUTION', <Widget>[
                    _row('Institution', item.institution),
                    _row('Team Members', item.teamMembers),
                  ]),
                  if (item.relatedStudy.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    const Text(
                      'RELATED STUDY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5F6368),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.relatedStudy,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF306D29),
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (item.researcherNotes.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    const Text(
                      'RESEARCHER NOTES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5F6368),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAF8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDDE8DD)),
                      ),
                      child: Text(
                        item.researcherNotes,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF306D29),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  if (item.reviewNotes.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    const Text(
                      'REVIEWER NOTES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5F6368),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFE082)),
                      ),
                      child: Text(
                        item.reviewNotes,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF5D4037),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  if (item.status == reviewStatusLabel('revision')) ...<Widget>[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _editAndResubmit(context),
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Edit & Resubmit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Reuses the same "web draft" edit path drafts already use
  /// (`_editWebDraft` in UploadSpeciesDraftsScreen): fetch the full row with
  /// its normalized sub-tables, hand it to the wizard, and let `submitDraft`
  /// route it through `_updateWebSightingDraft` (update-in-place, not a
  /// duplicate insert) when the researcher resubmits.
  Future<void> _editAndResubmit(BuildContext context) async {
    final int? sightingId = int.tryParse(item.sightingId);
    if (sightingId == null) return;
    try {
      final Map<String, dynamic>? row = await Supabase.instance.client
          .from('species_sightings')
          .select(
            '*, sighting_habitat(*), sighting_morphology(*), '
            'sighting_conservation(*), sighting_team_member(*)',
          )
          .eq('sighting_id', sightingId)
          .maybeSingle();
      if (row == null) return;
      final _WebDraft draft = _WebDraft(
        draftId: item.sightingId,
        updatedAt: DateTime.now(),
        scientificName: item.scientificName,
        rawData: Map<String, dynamic>.from(row),
      );
      final UploadSpeciesFlowData flowData = draft.toFlowData();
      if (!context.mounted) return;
      Navigator.of(context).pop();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              UploadSpeciesInformationScreen(flowData: flowData.copy()),
        ),
      );
    } catch (_) {}
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF80868B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim(),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF306D29),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadStatusTile extends StatelessWidget {
  const _UploadStatusTile({
    required this.imageUrl,
    required this.title,
    required this.uploadedDate,
    required this.status,
    required this.statusColor,
  });
  final String imageUrl;
  final String title;
  final String uploadedDate;
  final String status;
  final Color statusColor;
  @override
  Widget build(BuildContext context) {
    final bool hasImageUrl = imageUrl.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _lineColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: hasImageUrl
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 78,
                      height: 78,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        width: 78,
                        height: 78,
                        color: const Color(0xFFF1F4F7),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_outlined,
                          size: 30,
                          color: _primaryColor,
                        ),
                      ),
                      errorWidget: (_, _, _) => Container(
                        width: 78,
                        height: 78,
                        color: const Color(0xFFF1F4F7),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          size: 30,
                          color: _primaryColor,
                        ),
                      ),
                    )
                  : Container(
                      width: 78,
                      height: 78,
                      color: const Color(0xFFF1F4F7),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_outlined,
                        size: 30,
                        color: _primaryColor,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Uploaded: $uploadedDate',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: _mutedTextColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Text(
                          'Status: ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                            color: _textColor,
                          ),
                        ),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _closeUploadFlow(BuildContext context) {
  final NavigatorState navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.popUntil((Route<dynamic> route) => route.isFirst);
  }
}

const TextStyle _uploadSectionTitleStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w700,
  color: _uploadPrimary,
  letterSpacing: 0.3,
);
TextStyle get _uploadFieldLabelStyle => TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w500,
  color: _kIsDark ? const Color(0xFFBCC4CF) : _primarySoftColor,
);
TextStyle get _uploadInputTextStyle =>
    TextStyle(fontSize: 14, color: _textColor);
const TextStyle _uploadHintTextStyle = TextStyle(
  fontSize: 14,
  color: _hintTextColor,
);
Widget _uploadFieldLabelWithTooltip(String label, String tooltip) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: <Widget>[
      Text(label, style: _uploadFieldLabelStyle),
      const SizedBox(width: 4),
      Tooltip(
        message: tooltip,
        triggerMode: TooltipTriggerMode.tap,
        preferBelow: true,
        showDuration: const Duration(seconds: 4),
        child: const Icon(Icons.info_outline, size: 14, color: _hintTextColor),
      ),
    ],
  );
}

// Guards DropdownButtonFormField against values loaded from drafts (e.g. the
// web dashboard) that don't exactly match this app's option casing/wording,
// which would otherwise trip the "exactly one item" assertion and crash.
String? _matchDropdownOption(String? value, List<String> options) {
  if (value == null || value.isEmpty) return null;
  if (options.contains(value)) return value;
  for (final String option in options) {
    if (option.toLowerCase() == value.toLowerCase()) return option;
  }
  return null;
}

InputDecoration _uploadInputDecoration({String? hintText}) {
  return InputDecoration(
    isDense: true,
    hintText: hintText,
    hintStyle: _uploadHintTextStyle,
    filled: true,
    fillColor: _surfaceColor,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: _uploadBorderColor, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: _uploadPrimary, width: 1.8),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Color(0xFFB84040), width: 1),
    ),
  );
}

ButtonStyle _uploadActionButtonStyle({bool fullWidth = false}) {
  return OutlinedButton.styleFrom(
    foregroundColor: _uploadPrimary,
    side: BorderSide(color: _uploadPrimary, width: 1.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    minimumSize: fullWidth
        ? const Size(double.infinity, 50)
        : const Size(130, 46),
  );
}

String _generateEntryId() {
  final DateTime now = DateTime.now();
  final String date =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  final int rand = (now.microsecondsSinceEpoch % 10000).abs();
  return 'ORD-$date-${rand.toString().padLeft(4, '0')}';
}

/// Card-like container wrapping a single form section.
Widget _uploadFormCard(Widget child) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
    decoration: BoxDecoration(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _uploadBorderColor, width: 1),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: _kIsDark ? const Color(0x1A0D530E) : const Color(0x0A0D530E),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

/// Light-purple sub-section card used inside form cards.
Widget _uploadSubCard({required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
    decoration: BoxDecoration(
      color: _uploadSubCardBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _uploadBorderColor, width: 1),
    ),
    child: child,
  );
}

/// Full-width gradient Next button.
Widget _uploadNextButton({
  required VoidCallback? onPressed,
  String label = 'Continue',
  IconData trailingIcon = Icons.arrow_forward_rounded,
}) {
  final bool enabled = onPressed != null;
  return Material(
    borderRadius: BorderRadius.circular(12),
    color: Colors.transparent,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: enabled
                ? const <Color>[_uploadPrimary, _uploadPrimaryDark]
                : const <Color>[Color(0xFF9CA3AF), Color(0xFF9CA3AF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              Icon(trailingIcon, size: 18, color: Colors.white),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Outlined Save Draft button.
Widget _uploadSaveDraftButton({
  required VoidCallback? onPressed,
  String label = 'Save as Draft',
}) {
  return OutlinedButton.icon(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: _uploadPrimary,
      side: BorderSide(color: _uploadPrimary, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      minimumSize: const Size(double.infinity, 50),
      padding: const EdgeInsets.symmetric(vertical: 12),
    ),
    icon: const Icon(Icons.save_outlined, size: 18),
    label: Text(
      label,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
  );
}

class _UploadFormHeader extends StatelessWidget {
  const _UploadFormHeader({
    required this.title,
    this.sectionTitle = '',
    this.step = 0,
    this.totalSteps = 5,
    this.stepIcon = Icons.eco_outlined,
    this.entryId = '',
  });
  final String title;
  final String sectionTitle;
  final int step;
  final int totalSteps;
  final IconData stepIcon;
  final String entryId;
  @override
  Widget build(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[_uploadPrimary, _uploadPrimaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x340D530E),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          // Back / close row
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => navigator.maybePop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  tooltip: 'Back',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _closeUploadFlow(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 22,
                  ),
                  tooltip: 'Close',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Content area
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Orchid Database',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.7),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    if (entryId.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              'Entry ID',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.7),
                                letterSpacing: 0.6,
                              ),
                            ),
                            Text(
                              entryId.trim(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFamily: 'monospace',
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Icon(stepIcon, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sectionTitle.isNotEmpty ? sectionTitle : title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (step > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$step / $totalSteps',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                if (step > 0) ...<Widget>[
                  const SizedBox(height: 12),
                  Row(
                    children: List<Widget>.generate(totalSteps, (int i) {
                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: EdgeInsets.only(
                            right: i < totalSteps - 1 ? 4 : 0,
                          ),
                          decoration: BoxDecoration(
                            color: i < step
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementBullet extends StatelessWidget {
  const _RequirementBullet({required this.text, this.level = 0, this.suffix});
  final String text;
  final int level;
  final String? suffix;
  @override
  Widget build(BuildContext context) {
    final double indent = level == 0 ? 8 : 28;
    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 8),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '\u2022  $text',
              style: TextStyle(
                fontSize: 14,
                height: 1.25,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: _textColor,
              ),
            ),
            if (suffix != null)
              TextSpan(
                text: suffix,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.25,
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                  color: _mutedTextColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UploadActionRow extends StatelessWidget {
  const _UploadActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badgeCount;
  String _badgeText(int count) {
    if (count > 99) {
      return '99+';
    }
    return '$count';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surfaceColor,
      elevation: 0,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _lineColor),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 14,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(child: Icon(icon, color: Colors.white, size: 28)),
                    if (badgeCount != null && badgeCount! > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _accentColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _badgeText(badgeCount!),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: _mutedTextColor,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({required this.authController, super.key});
  final AppAuthController authController;
  @override
  State<MapScreen> createState() => _MapScreenState();
}

// ── Trail data (map_trails table)
// Fallback used only if the map_trails fetch fails (e.g. offline) so the map
// still shows something instead of a blank screen.
const List<LatLng> _kBusaTrailFallback = <LatLng>[
  LatLng(6.0705, 124.7412),
  LatLng(6.0758, 124.7350),
  LatLng(6.0821, 124.7284),
  LatLng(6.0903, 124.7201),
  LatLng(6.0987, 124.7128),
  LatLng(6.1055, 124.7049),
  LatLng(6.1092, 124.6858),
];

class MapTrail {
  const MapTrail({
    required this.trailId,
    required this.name,
    required this.color,
    required this.points,
  });
  final int trailId;
  final String name;
  final Color color;
  final List<LatLng> points;
  static Color _parseHexColor(
    dynamic raw, {
    Color fallback = const Color(0xFF86EFAC),
  }) {
    final String s = (raw ?? '').toString().trim();
    if (s.isEmpty) return fallback;
    final String hex = s.startsWith('#') ? s.substring(1) : s;
    final int? value = int.tryParse(
      hex.length == 6 ? 'FF$hex' : hex,
      radix: 16,
    );
    return value != null ? Color(value) : fallback;
  }

  static MapTrail? fromRow(Map<String, dynamic> row) {
    final dynamic coords = row['coordinates'];
    if (coords is! List || coords.isEmpty) return null;
    final List<LatLng> points = coords
        .whereType<List>()
        .where((List p) => p.length >= 2)
        .map(
          (List p) =>
              LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
        )
        .toList();
    if (points.isEmpty) return null;
    return MapTrail(
      trailId: row['trail_id'] is int
          ? row['trail_id'] as int
          : int.tryParse('${row['trail_id']}') ?? 0,
      name: (row['name'] ?? 'Trail').toString(),
      color: _parseHexColor(row['color']),
      points: points,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'trailId': trailId,
    'name': name,
    'color': color.toARGB32(),
    'points': points
        .map((LatLng p) => <double>[p.latitude, p.longitude])
        .toList(),
  };
  static MapTrail? fromJson(Map<String, dynamic> json) {
    final dynamic rawPoints = json['points'];
    if (rawPoints is! List || rawPoints.isEmpty) return null;
    final List<LatLng> points = rawPoints
        .whereType<List>()
        .where((List p) => p.length >= 2)
        .map(
          (List p) =>
              LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
        )
        .toList();
    if (points.isEmpty) return null;
    return MapTrail(
      trailId: (json['trailId'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? 'Trail').toString(),
      color: Color((json['color'] as num?)?.toInt() ?? 0xFF86EFAC),
      points: points,
    );
  }
}

/// Simple in-memory cache so the three map screens (catalog preview,
/// catalog fullscreen, main map) share one fetch instead of each hitting
/// Supabase separately.
class MapTrailsCache {
  static const String _diskCacheKey = 'map_trails';
  static List<MapTrail>? _cached;
  static Future<List<MapTrail>>? _inflight;
  static Future<List<MapTrail>> load({bool forceRefresh = false}) {
    if (!forceRefresh && _cached != null) {
      return Future<List<MapTrail>>.value(_cached);
    }
    if (_inflight != null) return _inflight!;
    _inflight = _fetch()
        .then((List<MapTrail> trails) {
          _cached = trails;
          _inflight = null;
          unawaited(
            OfflineCache.save(
              _diskCacheKey,
              trails.map((MapTrail t) => t.toJson()).toList(),
            ),
          );
          return trails;
        })
        .catchError((Object _) async {
          _inflight = null;
          if (_cached != null) return _cached!;
          final List<MapTrail>? onDisk = await _loadFromDisk();
          if (onDisk != null && onDisk.isNotEmpty) return onDisk;
          return <MapTrail>[
            MapTrail(
              trailId: 0,
              name: 'Mt. Busa Trail',
              color: const Color(0xFF86EFAC),
              points: _kBusaTrailFallback,
            ),
          ];
        });
    return _inflight!;
  }

  static Future<List<MapTrail>?> _loadFromDisk() async {
    final dynamic raw = await OfflineCache.load(_diskCacheKey);
    if (raw is! List) return null;
    return raw
        .whereType<Map>()
        .map((Map m) => MapTrail.fromJson(Map<String, dynamic>.from(m)))
        .whereType<MapTrail>()
        .toList();
  }

  static Future<List<MapTrail>> _fetch() async {
    final List<dynamic> rows = await Supabase.instance.client
        .from('map_trails')
        .select('trail_id, name, color, coordinates, archived')
        .order('trail_id', ascending: true)
        .timeout(_kNetworkTimeout);
    return rows
        .whereType<Map>()
        .where((Map r) => r['archived'] != true)
        .map((Map r) => MapTrail.fromRow(Map<String, dynamic>.from(r)))
        .whereType<MapTrail>()
        .toList();
  }
}

/// Builds web's 3-layer "glow" trail effect (researcher-dashboard.html): a
/// wide, faint halo, a medium mid-layer, and a solid core line, all in the
/// trail's own color.
List<Polyline> buildTrailGlowPolylines(
  List<MapTrail> trails, {
  double scale = 1.0,
}) {
  final List<Polyline> polylines = <Polyline>[];
  for (final MapTrail trail in trails) {
    polylines.add(
      Polyline(
        points: trail.points,
        color: trail.color.withValues(alpha: 0.08),
        strokeWidth: 18 * scale,
      ),
    );
    polylines.add(
      Polyline(
        points: trail.points,
        color: trail.color.withValues(alpha: 0.28),
        strokeWidth: 9 * scale,
      ),
    );
    polylines.add(
      Polyline(
        points: trail.points,
        color: trail.color,
        strokeWidth: 2.5 * scale,
      ),
    );
  }
  return polylines;
}

enum _MapLayer { street, topo, satellite }

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  bool _cardExpanded = true;
  bool _mapReady = false;
  Position? _currentPosition;
  List<MapTrail> _trails = const <MapTrail>[];
  // Which trails are currently hidden — mirrors web's toggleTrail: every
  // trail starts visible, tapping its pill removes/re-adds it from the map.
  final Set<int> _hiddenTrailIds = <int>{};
  final ValueNotifier<_MapLayer> _activeLayerNotifier = ValueNotifier(
    _MapLayer.satellite,
  );
  final ValueNotifier<double> _mapRotationNotifier = ValueNotifier(0.0);
  static const LatLng _kCenter = LatLng(6.090, 124.713);
  static const double _kInitialZoom = 13;
  List<MapTrail> get _displayTrails => _trails.isNotEmpty
      ? _trails
      : <MapTrail>[
          MapTrail(
            trailId: 0,
            name: 'Mt. Busa Trail',
            color: const Color(0xFF86EFAC),
            points: _kBusaTrailFallback,
          ),
        ];
  List<MapTrail> get _visibleTrails => _displayTrails
      .where((MapTrail t) => !_hiddenTrailIds.contains(t.trailId))
      .toList(growable: false);
  void _toggleTrail(int trailId) {
    setState(() {
      if (_hiddenTrailIds.contains(trailId)) {
        _hiddenTrailIds.remove(trailId);
      } else {
        _hiddenTrailIds.add(trailId);
      }
    });
  }

  List<LatLng> get _primaryTrailPoints =>
      _trails.isNotEmpty ? _trails.first.points : _kBusaTrailFallback;
  String get _primaryTrailName =>
      _trails.isNotEmpty ? _trails.first.name : 'Mt. Busa Trail';
  String _tileUrlFor(_MapLayer layer) {
    switch (layer) {
      case _MapLayer.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/'
            'World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case _MapLayer.topo:
        return 'https://a.tile.opentopomap.org/{z}/{x}/{y}.png';
      case _MapLayer.street:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  @override
  void initState() {
    super.initState();
    _getLocation();
    MapTrailsCache.load().then((List<MapTrail> trails) {
      if (mounted) setState(() => _trails = trails);
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    _activeLayerNotifier.dispose();
    _mapRotationNotifier.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;
      final double lat = pos.latitude;
      final double lng = pos.longitude;
      if (!lat.isFinite || !lng.isFinite) return;
      setState(() => _currentPosition = pos);
      if (_mapReady) {
        _mapController.move(LatLng(lat, lng), 15);
      }
    } catch (_) {}
  }

  void _zoomIn() => _mapController.move(
    _mapController.camera.center,
    _mapController.camera.zoom + 1,
  );
  void _zoomOut() => _mapController.move(
    _mapController.camera.center,
    _mapController.camera.zoom - 1,
  );
  void _flyToCurrentLocation() {
    if (_currentPosition == null) return;
    _mapController.move(
      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      15,
    );
  }

  void _resetNorth() {
    _mapController.rotate(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // ── Full-screen flutter_map
          Positioned.fill(
            child: RepaintBoundary(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _kCenter,
                  initialZoom: _kInitialZoom,
                  minZoom: 8,
                  maxZoom: 19,
                  onMapReady: () => setState(() => _mapReady = true),
                  onMapEvent: (MapEvent event) {
                    final double r = event.camera.rotation;
                    if ((r - _mapRotationNotifier.value).abs() >= 1.0) {
                      _mapRotationNotifier.value = r;
                    }
                  },
                ),
                children: <Widget>[
                  ValueListenableBuilder<_MapLayer>(
                    valueListenable: _activeLayerNotifier,
                    builder: (_, layer, _) => TileLayer(
                      key: ValueKey(layer),
                      urlTemplate: _tileUrlFor(layer),
                      userAgentPackageName: 'com.example.flutter_application_1',
                      maxNativeZoom: 18,
                      keepBuffer: 4,
                      evictErrorTileStrategy: EvictErrorTileStrategy.notVisible,
                    ),
                  ),
                  PolylineLayer(
                    polylines: buildTrailGlowPolylines(_visibleTrails),
                  ),
                  if (_currentPosition != null)
                    MarkerLayer(
                      markers: <Marker>[
                        Marker(
                          point: LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                          width: 24,
                          height: 24,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFF306D29),
                              shape: BoxShape.circle,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Color(0x66306D29),
                                  blurRadius: 8,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.circle,
                              color: Colors.white,
                              size: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          // ── Trail show/hide pills (top)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _displayTrails.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final MapTrail trail = _displayTrails[index];
                      final bool isVisible = !_hiddenTrailIds.contains(
                        trail.trailId,
                      );
                      return GestureDetector(
                        onTap: () => _toggleTrail(trail.trailId),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isVisible
                                ? const Color(0xFF4DB86A)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF4DB86A),
                              width: 1.5,
                            ),
                            boxShadow: isVisible
                                ? const <BoxShadow>[
                                    BoxShadow(
                                      color: Color(0x594DB86A),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ]
                                : const <BoxShadow>[
                                    BoxShadow(
                                      color: Color(0x26000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.route_rounded,
                                size: 14,
                                color: isVisible
                                    ? const Color(0xFF0A2710)
                                    : const Color(0xFF4DB86A),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                trail.name,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isVisible
                                      ? const Color(0xFF0A2710)
                                      : const Color(0xFF4DB86A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          // ── Zoom + locate + compass buttons (right side)
          Positioned(
            right: 12,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 52),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Compass — rotates with the map, tap to reset north
                    GestureDetector(
                      onTap: _resetNorth,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Color(0x26000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: ValueListenableBuilder<double>(
                          valueListenable: _mapRotationNotifier,
                          builder: (_, rotation, child) => Transform.rotate(
                            angle: -rotation * (3.141592653589793 / 180),
                            child: child,
                          ),
                          child: CustomPaint(
                            size: const Size(22, 28),
                            painter: _CompassNeedlePainter(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _mapIconButton(Icons.add, _zoomIn),
                    const SizedBox(height: 4),
                    _mapIconButton(Icons.remove, _zoomOut),
                    const SizedBox(height: 12),
                    _mapIconButton(
                      Icons.my_location_rounded,
                      _flyToCurrentLocation,
                      color: const Color(0xFF306D29),
                    ),
                    const SizedBox(height: 12),
                    _mapIconButton(Icons.layers_rounded, () {
                      final int idx = _MapLayer.values.indexOf(
                        _activeLayerNotifier.value,
                      );
                      _activeLayerNotifier.value =
                          _MapLayer.values[(idx + 1) % _MapLayer.values.length];
                    }),
                  ],
                ),
              ),
            ),
          ),
          // ── Bottom info card (draggable)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onVerticalDragEnd: (DragEndDetails details) {
                final double v = details.primaryVelocity ?? 0;
                if (v > 150) setState(() => _cardExpanded = false);
                if (v < -150) setState(() => _cardExpanded = true);
              },
              onTap: () {
                if (!_cardExpanded) setState(() => _cardExpanded = true);
              },
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 20,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Drag handle — always visible
                    const SizedBox(height: 10),
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDADCE0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Title row — always visible
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              _primaryTrailName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF306D29),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              if (!_mapReady) return;
                              _mapController.fitCamera(
                                CameraFit.bounds(
                                  bounds: LatLngBounds.fromPoints(
                                    _primaryTrailPoints,
                                  ),
                                  padding: const EdgeInsets.all(48),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF306D29),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.route_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Trail',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (!_cardExpanded) ...<Widget>[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.keyboard_arrow_up_rounded,
                              color: Color(0xFF80868B),
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Expandable content
                    AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeInOut,
                      child: _cardExpanded
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const SizedBox(height: 2),
                                  const Text(
                                    'South Cotabato / Sarangani Province',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF80868B),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            )
                          : const SizedBox(height: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapIconButton(IconData icon, VoidCallback onTap, {Color? color}) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 20, color: color ?? const Color(0xFF5F6368)),
        ),
      ),
    );
  }
}

class _CompassNeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    // North half — red, points up
    final ui.Path north = ui.Path()
      ..moveTo(cx, 0)
      ..lineTo(cx + cx * 0.55, cy)
      ..lineTo(cx, cy - cy * 0.15)
      ..lineTo(cx - cx * 0.55, cy)
      ..close();
    canvas.drawPath(north, Paint()..color = const Color(0xFFE53935));
    // South half — grey, points down
    final ui.Path south = ui.Path()
      ..moveTo(cx, size.height)
      ..lineTo(cx + cx * 0.55, cy)
      ..lineTo(cx, cy + cy * 0.15)
      ..lineTo(cx - cx * 0.55, cy)
      ..close();
    canvas.drawPath(south, Paint()..color = const Color(0xFF9E9E9E));
    // Centre dot
    canvas.drawCircle(
      Offset(cx, cy),
      2.5,
      Paint()..color = const Color(0xFF212121),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class NotificationController extends ChangeNotifier {
  static const String _prefsKey = 'notif_read_ids_v1';
  static const String _deletedPrefsKey = 'notif_deleted_ids_v1';
  List<AppNotification> _raw = <AppNotification>[];
  Set<String> _readIds = <String>{};
  Set<String> _deletedIds = <String>{};
  bool _isLoading = false;
  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  List<AppNotification> get notifications => _raw;
  int get unreadCount => _raw.where((AppNotification n) => !n.read).length;
  bool get isLoading => _isLoading;
  Future<void> load() async {
    _isLoading = true;
    _notify();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _readIds = (prefs.getStringList(_prefsKey) ?? <String>[]).toSet();
    _deletedIds = (prefs.getStringList(_deletedPrefsKey) ?? <String>[]).toSet();
    try {
      final SupabaseClient supabase = Supabase.instance.client;
      final String userEmail = supabase.auth.currentUser?.email ?? '';
      final List<dynamic> data = await supabase
          .from('species_sightings')
          .select(
            'sighting_id, scientific_name, review_status, created_at, updated_at',
          )
          .eq('researcher_email', userEmail)
          .order('created_at', ascending: false);
      final List<AppNotification> notifs = <AppNotification>[];
      final String? accountStatus = supabase
          .auth
          .currentUser
          ?.userMetadata?['account_status']
          ?.toString();
      if (accountStatus == 'pending_verification') {
        notifs.add(
          AppNotification(
            id: 'account_pending_0',
            type: 'verification',
            message:
                'Your account is under verification. Awaiting superadmin approval.',
            timestamp: 'Today',
            dateLabel: _formatDateLabel(DateTime.now()),
            read: _readIds.contains('account_pending_0'),
          ),
        );
      }
      for (int i = 0; i < data.length; i++) {
        final Map<String, dynamic> item = Map<String, dynamic>.from(
          data[i] as Map,
        );
        final String status = (item['review_status'] ?? '').toString().trim();
        // Drafts haven't been submitted yet, so they aren't a review event.
        if (status.toLowerCase() == 'draft') continue;
        final String scientificName = (item['scientific_name'] ?? '')
            .toString()
            .trim();
        // Prefer updated_at (bumped whenever the review status actually
        // changes) over created_at (frozen at original draft creation) so
        // the notification's date reflects the event it's about, not when
        // the underlying row was first drafted.
        final DateTime eventAt =
            DateTime.tryParse((item['updated_at'] ?? '').toString()) ??
            DateTime.tryParse((item['created_at'] ?? '').toString()) ??
            DateTime.now();
        final String sightingId = (item['sighting_id'] ?? i + 1).toString();
        // Include status in the id so a later status change (e.g. pending ->
        // approved) is treated as a new, unread notification instead of
        // inheriting the read state of the earlier status's notification.
        final String id = '${sightingId}_${status.toLowerCase()}';
        notifs.add(
          AppNotification(
            id: id,
            type: status.isEmpty ? 'pending' : status,
            message: _messageForSubmission(status, scientificName),
            timestamp: _bucketForDate(eventAt),
            dateLabel: _formatDateLabel(eventAt),
            read: _readIds.contains(id),
          ),
        );
      }
      _raw = notifs
          .where((AppNotification n) => !_deletedIds.contains(n.id))
          .toList(growable: false);
    } catch (_) {
      _raw = const <AppNotification>[];
    }
    _isLoading = false;
    _notify();
  }

  Future<void> delete(String id) async {
    _raw = _raw
        .where((AppNotification n) => n.id != id)
        .toList(growable: false);
    _deletedIds.add(id);
    _notify();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_deletedPrefsKey, _deletedIds.toList());
  }

  Future<void> markAsRead(String id) async {
    if (_readIds.contains(id)) return;
    _readIds.add(id);
    _raw = _raw
        .map(
          (AppNotification n) => n.id == id
              ? AppNotification(
                  id: n.id,
                  type: n.type,
                  message: n.message,
                  timestamp: n.timestamp,
                  dateLabel: n.dateLabel,
                  read: true,
                )
              : n,
        )
        .toList(growable: false);
    _notify();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _readIds.toList());
  }

  Future<void> markAllAsRead() async {
    for (final AppNotification n in _raw) {
      _readIds.add(n.id);
    }
    _raw = _raw
        .map(
          (AppNotification n) => AppNotification(
            id: n.id,
            type: n.type,
            message: n.message,
            timestamp: n.timestamp,
            dateLabel: n.dateLabel,
            read: true,
          ),
        )
        .toList(growable: false);
    _notify();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _readIds.toList());
  }

  String _bucketForDate(DateTime value) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime date = DateTime(value.year, value.month, value.day);
    final int diff = today.difference(date).inDays;
    if (diff <= 0) return 'Today';
    if (diff <= 7) return 'Past 7 days';
    return 'Earlier';
  }

  static const List<String> _monthNames = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Formats a real date/time for display, e.g. "Jul 23, 2026 · 3:45 PM"
  /// the actual timestamp was already being fetched (`created_at`) but
  /// previously only fed into the coarse Today/Past 7 days/Earlier bucket.
  String _formatDateLabel(DateTime value) {
    final DateTime local = value.toLocal();
    final int hour24 = local.hour;
    final int hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final String period = hour24 < 12 ? 'AM' : 'PM';
    final String minute = local.minute.toString().padLeft(2, '0');
    return '${_monthNames[local.month - 1]} ${local.day}, ${local.year} · $hour12:$minute $period';
  }

  String _messageForSubmission(String status, String scientificName) {
    final String safeName = scientificName.isEmpty
        ? 'Unnamed species'
        : scientificName;
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Submission approved: $safeName';
      case 'rejected':
        return 'Submission rejected: $safeName';
      case 'revision':
        return 'Submission needs revision: $safeName';
      default:
        return 'Submission pending review: $safeName';
    }
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({required this.controller, super.key});
  final NotificationController controller;
  Widget _buildSection(
    BuildContext context,
    String title,
    List<AppNotification> items,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            color: _mutedTextColor,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        ...items.map(
          (AppNotification item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () {
                controller.markAsRead(item.id);
                showDialog<void>(
                  context: context,
                  builder: (_) => _NotificationDetailDialog(notification: item),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: item.read
                      ? _surfaceColor
                      : _kIsDark
                      ? const Color(0xFF0F2210)
                      : const Color(0xFFF0FAF0),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: item.read ? _lineColor : _primarySoftColor,
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x0E000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: item.read
                              ? const Color(0xFFF1F5F8)
                              : _accentSoftColor,
                          shape: BoxShape.circle,
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: <Widget>[
                            const Positioned.fill(
                              child: Icon(
                                Icons.mail_outline_rounded,
                                color: _primaryColor,
                                size: 24,
                              ),
                            ),
                            if (!item.read)
                              const Positioned(
                                right: 4,
                                top: 4,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: _accentColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: SizedBox(width: 8, height: 8),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.message,
                              style: TextStyle(
                                color: item.read ? _mutedTextColor : _textColor,
                                fontSize: 15,
                                height: 1.25,
                                fontStyle: FontStyle.italic,
                                fontWeight: item.read
                                    ? FontWeight.w400
                                    : FontWeight.w600,
                              ),
                            ),
                            if (item.dateLabel.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 4),
                              Text(
                                item.dateLabel,
                                style: TextStyle(
                                  color: _mutedTextColor,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          if (!item.read)
                            const Text(
                              'Tap to read',
                              style: TextStyle(
                                fontSize: 10,
                                color: _primarySoftColor,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          GestureDetector(
                            onTap: () async {
                              final bool? confirmed = await showDialog<bool>(
                                context: context,
                                builder: (BuildContext ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  title: const Text(
                                    'Delete Notification',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  content: const Text(
                                    'Are you sure you want to delete this notification?',
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                controller.delete(item.id);
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: Color(0xFFB33A2D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _appBackgroundColor,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (BuildContext context, _) {
            final List<AppNotification> notifications =
                controller.notifications;
            final int unreadCount = controller.unreadCount;
            final List<AppNotification> today = notifications
                .where((AppNotification n) => n.timestamp == 'Today')
                .toList(growable: false);
            final List<AppNotification> recent = notifications
                .where((AppNotification n) => n.timestamp == 'Past 7 days')
                .toList(growable: false);
            final List<AppNotification> older = notifications
                .where((AppNotification n) => n.timestamp == 'Earlier')
                .toList(growable: false);
            return RefreshIndicator(
              onRefresh: controller.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Spacer(),
                      Material(
                        color: Colors.transparent,
                        child: InkResponse(
                          onTap: () => Navigator.of(context).pop(),
                          radius: 24,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _surfaceColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: _lineColor),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: _primaryColor,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Notifications',
                              style: TextStyle(
                                color: _textColor,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              unreadCount == 0
                                  ? 'All caught up!'
                                  : '$unreadCount unread notification${unreadCount == 1 ? '' : 's'}',
                              style: TextStyle(
                                color: _mutedTextColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (unreadCount > 0)
                        TextButton(
                          onPressed: controller.markAllAsRead,
                          child: const Text(
                            'Mark all read',
                            style: TextStyle(
                              fontSize: 13,
                              color: _primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Divider(height: 1, color: _lineColor),
                  if (controller.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  const SizedBox(height: 16),
                  _buildSection(context, 'Today', today),
                  if (today.isNotEmpty) const SizedBox(height: 6),
                  _buildSection(context, 'Past 7 days', recent),
                  if (recent.isNotEmpty) const SizedBox(height: 6),
                  _buildSection(context, 'Earlier', older),
                  if (notifications.isEmpty && !controller.isLoading)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Text(
                          'No notifications yet.',
                          style: TextStyle(
                            color: _mutedTextColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationDetailDialog extends StatelessWidget {
  const _NotificationDetailDialog({required this.notification});
  final AppNotification notification;
  IconData get _icon {
    switch (notification.type.toLowerCase()) {
      case 'approved':
        return Icons.check_circle_outline_rounded;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'revision':
        return Icons.edit_note_rounded;
      case 'verification':
        return Icons.verified_user_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color get _iconColor {
    switch (notification.type.toLowerCase()) {
      case 'approved':
        return const Color(0xFF2E7D32);
      case 'rejected':
        return const Color(0xFFC62828);
      case 'revision':
        return const Color(0xFFF57F17);
      case 'verification':
        return const Color(0xFFF57F17);
      default:
        return _primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color ic = _iconColor;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: _surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: ic.withAlpha(26),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon, color: ic, size: 24),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _lineColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: _primaryColor,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              notification.message,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textColor,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              notification.dateLabel.isNotEmpty
                  ? notification.dateLabel
                  : notification.timestamp,
              style: TextStyle(
                fontSize: 12,
                color: _mutedTextColor,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class AuthApiException implements Exception {
  AuthApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AppAuthController extends ChangeNotifier {
  AppAuthController();
  AppUser? _user;
  bool _isInitializing = true;
  bool _isDarkMode = false;
  AppUser? get user => _user;
  bool get isInitializing => _isInitializing;
  bool get isDarkMode => _isDarkMode;
  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', _isDarkMode);
    notifyListeners();
  }

  Future<void> initialize() async {
    // Initialize Supabase here (not in main) so runApp() isn't blocked by the
    // network handshake, which caused the 10-13 s native white screen.
    // SharedPreferences can start in parallel while Supabase connects.
    final results = await Future.wait(<Future<Object?>>[
      Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey)
          .then<Object?>((v) => v)
          .timeout(const Duration(seconds: 12), onTimeout: () => null),
      SharedPreferences.getInstance()
          .then<Object?>((v) => v)
          .timeout(const Duration(seconds: 5), onTimeout: () => null),
    ]);
    final SharedPreferences prefs = results[1] as SharedPreferences;
    _isDarkMode = prefs.getBool('darkMode') ?? false;
    final User? currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      _user = AppUser.fromSupabaseUser(currentUser);
    }
    _isInitializing = false;
    notifyListeners();
    if (currentUser != null) {
      await _syncProfileStatus(currentUser.id);
    }
  }

  /// Fetches `user_profiles.status` for the signed-in user and mirrors web's
  /// gating (researcher-dashboard.html ~2185-2206): 'disabled' forces
  /// sign-out, 'pending' is surfaced via AppUser.isPendingApproval so the
  /// shell can restrict navigation to Home only.
  Future<void> _syncProfileStatus(String authUserId) async {
    try {
      final Map<String, dynamic>? row = await Supabase.instance.client
          .from('user_profiles')
          .select('status, first_name, last_name, full_name, avatar_url')
          .eq('id', authUserId)
          .maybeSingle()
          .timeout(_kNetworkTimeout);
      final String status = (row?['status'] ?? 'approved').toString().trim();
      if (_user == null) return;
      if (status == 'disabled') {
        await logout();
        return;
      }
      // user_profiles is the cross-platform source of truth for name/photo
      // (shared with the web dashboard, which writes different auth
      // user_metadata keys than this app does) — prefer it when present,
      // fall back to whatever AppUser.fromSupabaseUser already read from
      // auth user_metadata for accounts that haven't synced here yet.
      final String? profFirst = (row?['first_name'] as String?)?.trim();
      final String? profLast = (row?['last_name'] as String?)?.trim();
      final String? profFull = (row?['full_name'] as String?)?.trim();
      final String? profAvatar = (row?['avatar_url'] as String?)?.trim();
      _user = _user!.copyWith(
        profileStatus: status.isEmpty ? 'approved' : status,
        firstName: (profFirst != null && profFirst.isNotEmpty)
            ? profFirst
            : null,
        lastName: (profLast != null && profLast.isNotEmpty) ? profLast : null,
        name: (profFull != null && profFull.isNotEmpty) ? profFull : null,
        profilePhotoUrl: (profAvatar != null && profAvatar.isNotEmpty)
            ? profAvatar
            : null,
      );
      notifyListeners();
    } catch (_) {
      // Non-fatal: if user_profiles is unreachable, don't lock the
      // researcher out — default AppUser.profileStatus is 'approved'.
    }
  }

  Future<void> login({
    required String email,
    required String password,
    String? name,
    String? firstName,
    String? lastName,
    String? birthday,
    String? phoneNumber,
    String? affiliation,
  }) async {
    final String normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || password.trim().isEmpty) {
      throw AuthApiException('Email and password are required.');
    }
    final SupabaseClient supabase = Supabase.instance.client;
    final bool isSignup = name != null && name.trim().isNotEmpty;
    try {
      if (isSignup) {
        final String trimmedName = name.trim();
        final AuthResponse response = await supabase.auth.signUp(
          email: normalizedEmail,
          password: password,
          data: <String, dynamic>{
            'name': trimmedName,
            'username': _defaultUsername(
              email: normalizedEmail,
              name: trimmedName,
            ),
            'location': 'Mt. Busa',
            'firstName': firstName?.trim() ?? '',
            'lastName': lastName?.trim() ?? '',
            'birthday': birthday ?? '',
            'phoneNumber': phoneNumber?.trim() ?? '',
            'affiliation': affiliation?.trim() ?? '',
            'account_status': 'pending_verification',
          },
        );
        if (response.user == null) {
          throw AuthApiException('Sign up failed. Please try again.');
        }
        _user = AppUser.fromSupabaseUser(response.user!);
      } else {
        final AuthResponse response = await supabase.auth.signInWithPassword(
          email: normalizedEmail,
          password: password,
        );
        if (response.user == null) {
          throw AuthApiException('Invalid email or password.');
        }
        _user = AppUser.fromSupabaseUser(response.user!);
      }
    } on AuthApiException {
      rethrow;
    } on AuthException catch (e) {
      // ignore: avoid_print
      print('[Auth error] AuthException(${e.statusCode}): ${e.message}');
      final String msg = e.message.toLowerCase();
      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid_credentials') ||
          msg.contains('invalid email or password') ||
          e.statusCode == '400' ||
          e.statusCode == '401') {
        throw AuthApiException('Invalid email or password.');
      }
      if (msg.contains('email not confirmed')) {
        throw AuthApiException(
          'Please confirm your email address before signing in.',
        );
      }
      if (msg.contains('user already registered')) {
        throw AuthApiException(
          'An account with this email already exists. Please sign in.',
        );
      }
      throw AuthApiException('Sign-in error: ${e.message}');
    } catch (e, st) {
      // ignore: avoid_print
      print('[Auth error] ${e.runtimeType}: $e\n$st');
      final String msg = e.toString().toLowerCase();
      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid_credentials') ||
          msg.contains('invalid email or password')) {
        throw AuthApiException('Invalid email or password.');
      }
      if (msg.contains('email not confirmed')) {
        throw AuthApiException(
          'Please confirm your email address before signing in.',
        );
      }
      if (msg.contains('user already registered')) {
        throw AuthApiException(
          'An account with this email already exists. Please sign in.',
        );
      }
      if (msg.contains('network') ||
          msg.contains('socket') ||
          msg.contains('connection') ||
          msg.contains('timeout') ||
          msg.contains('host lookup failed') ||
          msg.contains('failed host lookup')) {
        throw AuthApiException(
          'Network error. Please check your internet connection and try again.',
        );
      }
      throw AuthApiException(
        'Authentication failed: ${e.runtimeType}. Check your connection and try again.',
      );
    }
    notifyListeners();
    final String? authUserId = Supabase.instance.client.auth.currentUser?.id;
    if (authUserId != null) {
      await _syncProfileStatus(authUserId);
    }
  }

  Future<void> updateProfile({
    required String name,
    required String username,
    required String location,
    String? affiliation,
    String? profilePhotoUrl,
  }) async {
    final AppUser? current = _user;
    if (current == null) throw AuthApiException('No active user session.');
    final String resolvedName = name.trim();
    final String resolvedUsername = username.trim().replaceFirst(
      RegExp(r'^@+'),
      '',
    );
    final String resolvedLocation = location.trim();
    final String resolvedAffiliation = affiliation ?? current.affiliation;
    final String resolvedPhotoUrl = profilePhotoUrl ?? current.profilePhotoUrl;
    if (resolvedName.isEmpty || resolvedUsername.isEmpty) {
      throw AuthApiException('Name and username are required.');
    }
    final UserResponse response = await Supabase.instance.client.auth
        .updateUser(
          UserAttributes(
            data: <String, dynamic>{
              'name': resolvedName,
              'username': resolvedUsername,
              'location': resolvedLocation,
              'affiliation': resolvedAffiliation,
              'profilePhotoUrl': resolvedPhotoUrl,
            },
          ),
        );
    final User? updatedUser = response.user;
    _user = updatedUser != null
        ? AppUser.fromSupabaseUser(updatedUser)
        : current.copyWith(
            name: resolvedName,
            username: resolvedUsername,
            location: resolvedLocation,
            affiliation: resolvedAffiliation,
            profilePhotoUrl: resolvedPhotoUrl,
          );
    // Mirror into user_profiles too — the canonical cross-platform store
    // the web dashboard reads, since it writes/reads a different auth
    // user_metadata key set than this app does.
    final String? authUserId =
        updatedUser?.id ?? Supabase.instance.client.auth.currentUser?.id;
    if (authUserId != null) {
      final List<String> nameParts = resolvedName.split(RegExp(r'\s+'));
      final String splitFirst = nameParts.isNotEmpty ? nameParts.first : '';
      final String splitLast = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : '';
      try {
        await Supabase.instance.client
            .from('user_profiles')
            .update(<String, dynamic>{
              'first_name': splitFirst.isNotEmpty ? splitFirst : null,
              'last_name': splitLast.isNotEmpty ? splitLast : null,
              'full_name': resolvedName.isNotEmpty ? resolvedName : null,
              'avatar_url': resolvedPhotoUrl.isNotEmpty
                  ? resolvedPhotoUrl
                  : null,
              'affiliation': resolvedAffiliation.isNotEmpty
                  ? resolvedAffiliation
                  : null,
            })
            .eq('id', authUserId);
      } catch (_) {
        // Non-fatal: auth user_metadata above already saved successfully.
      }
    }
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // signOut can fail when the server returns a non-JSON response (e.g.
      // HTML error page on network issues). Clear the local session anyway.
    }
    _user = null;
    notifyListeners();
  }

  String _defaultUsername({required String email, required String name}) {
    final String source = email.contains('@')
        ? email.split('@').first
        : name.trim();
    final String normalized = source.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return normalized.isNotEmpty ? normalized : 'researcher1';
  }
}

class AppUser {
  const AppUser({
    required this.name,
    required this.email,
    this.accountId,
    this.userId,
    this.username = '',
    this.location = '',
    this.profilePhotoBase64 = '',
    this.profilePhotoUrl = '',
    this.firstName = '',
    this.lastName = '',
    this.birthday = '',
    this.phoneNumber = '',
    this.affiliation = '',
    this.accountStatus = 'verified',
    this.profileStatus = 'approved',
  });
  final int? accountId;
  final int? userId;
  final String name;
  final String email;
  final String username;
  final String location;
  final String profilePhotoBase64;
  final String profilePhotoUrl;
  final String firstName;
  final String lastName;
  final String birthday;
  final String phoneNumber;
  final String affiliation;
  final String accountStatus;
  // user_profiles.status — the DENR/superadmin-managed researcher approval
  // workflow (approved/pending/disabled), separate from accountStatus
  // (Supabase Auth's own email-verification metadata). Mirrors web's
  // researcher-dashboard.html status gating.
  final String profileStatus;
  bool get isPendingVerification => accountStatus == 'pending_verification';
  bool get isPendingApproval => profileStatus == 'pending';
  bool get isDisabled => profileStatus == 'disabled';
  factory AppUser.fromSupabaseUser(User user) {
    final Map<String, dynamic> meta = Map<String, dynamic>.from(
      user.userMetadata ?? <String, dynamic>{},
    );
    final String name = (meta['name'] ?? user.email?.split('@').first ?? '')
        .toString();
    return AppUser(
      name: name,
      email: user.email ?? '',
      username: (meta['username'] ?? '').toString(),
      location: (meta['location'] ?? 'Mt. Busa').toString(),
      profilePhotoBase64: (meta['profilePhotoBase64'] ?? '').toString(),
      profilePhotoUrl: (meta['profilePhotoUrl'] ?? '').toString(),
      firstName: (meta['firstName'] ?? '').toString(),
      lastName: (meta['lastName'] ?? '').toString(),
      birthday: (meta['birthday'] ?? '').toString(),
      phoneNumber: (meta['phoneNumber'] ?? '').toString(),
      affiliation: (meta['affiliation'] ?? '').toString(),
      accountStatus: (meta['account_status'] ?? 'verified').toString(),
    );
  }
  factory AppUser.fromJson(Map<String, dynamic> json) {
    final int? parsedAccountId = int.tryParse(
      (json['accountId'] ?? '').toString(),
    );
    final int? parsedUserId = int.tryParse((json['userId'] ?? '').toString());
    return AppUser(
      accountId: parsedAccountId,
      userId: parsedUserId,
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      profilePhotoBase64: (json['profilePhotoBase64'] ?? '').toString(),
      profilePhotoUrl: (json['profilePhotoUrl'] ?? '').toString(),
      firstName: (json['firstName'] ?? '').toString(),
      lastName: (json['lastName'] ?? '').toString(),
      birthday: (json['birthday'] ?? '').toString(),
      phoneNumber: (json['phoneNumber'] ?? '').toString(),
      affiliation: (json['affiliation'] ?? '').toString(),
      accountStatus: (json['account_status'] ?? 'verified').toString(),
    );
  }
  AppUser copyWith({
    int? accountId,
    int? userId,
    String? name,
    String? email,
    String? username,
    String? location,
    String? profilePhotoBase64,
    String? profilePhotoUrl,
    String? firstName,
    String? lastName,
    String? birthday,
    String? phoneNumber,
    String? affiliation,
    String? accountStatus,
    String? profileStatus,
  }) {
    return AppUser(
      accountId: accountId ?? this.accountId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      username: username ?? this.username,
      location: location ?? this.location,
      profilePhotoBase64: profilePhotoBase64 ?? this.profilePhotoBase64,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      birthday: birthday ?? this.birthday,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      affiliation: affiliation ?? this.affiliation,
      accountStatus: accountStatus ?? this.accountStatus,
      profileStatus: profileStatus ?? this.profileStatus,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'accountId': accountId,
    'userId': userId,
    'name': name,
    'email': email,
    'username': username,
    'location': location,
    'profilePhotoBase64': profilePhotoBase64,
    'profilePhotoUrl': profilePhotoUrl,
    'firstName': firstName,
    'lastName': lastName,
    'birthday': birthday,
    'phoneNumber': phoneNumber,
    'affiliation': affiliation,
    'account_status': accountStatus,
  };
}

class Orchid {
  const Orchid({
    required this.id,
    required this.scientificName,
    required this.commonName,
    required this.image,
    required this.latitude,
    required this.longitude,
    required this.endemicStatus,
    required this.description,
  });
  final String id;
  final String scientificName;
  final String commonName;
  final String image;
  final double latitude;
  final double longitude;
  final String endemicStatus;
  final String description;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.timestamp,
    required this.read,
    this.dateLabel = '',
  });
  final String id;
  final String type;
  final String message;
  final String timestamp;
  final bool read;
  // Formatted actual date/time (e.g. "Jul 23, 2026 · 3:45 PM"), distinct
  // from `timestamp` which only ever holds a coarse bucket label
  // ("Today"/"Past 7 days"/"Earlier") used for section grouping.
  final String dateLabel;
}

class AppStats {
  const AppStats({
    required this.totalSpecies,
    required this.pendingSubmissions,
    required this.totalSightings,
    this.myPendingCount = 0,
    this.myApprovedCount = 0,
  });
  final int totalSpecies;
  final int pendingSubmissions;
  final int totalSightings;
  // Scoped to the signed-in researcher (mirrors web's per-researcher stat
  // chips), unlike the catalog-wide totals above.
  final int myPendingCount;
  final int myApprovedCount;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'totalSpecies': totalSpecies,
    'pendingSubmissions': pendingSubmissions,
    'totalSightings': totalSightings,
    'myPendingCount': myPendingCount,
    'myApprovedCount': myApprovedCount,
  };
  static AppStats fromJson(Map<String, dynamic> json) => AppStats(
    totalSpecies: (json['totalSpecies'] as num?)?.toInt() ?? 0,
    pendingSubmissions: (json['pendingSubmissions'] as num?)?.toInt() ?? 0,
    totalSightings: (json['totalSightings'] as num?)?.toInt() ?? 0,
    myPendingCount: (json['myPendingCount'] as num?)?.toInt() ?? 0,
    myApprovedCount: (json['myApprovedCount'] as num?)?.toInt() ?? 0,
  );
}

class SpeciesHighlight {
  const SpeciesHighlight({
    required this.scientificName,
    required this.imageUrl,
    this.commonName = 'Common Name',
  });
  final String scientificName;
  final String imageUrl;
  final String commonName;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'scientificName': scientificName,
    'imageUrl': imageUrl,
    'commonName': commonName,
  };
  static SpeciesHighlight fromJson(Map<String, dynamic> json) =>
      SpeciesHighlight(
        scientificName: (json['scientificName'] ?? '').toString(),
        imageUrl: (json['imageUrl'] ?? '').toString(),
        commonName: (json['commonName'] ?? 'Common Name').toString(),
      );
}

class CatalogSpecies {
  const CatalogSpecies({
    required this.scientificName,
    required this.commonName,
    this.id,
    this.genus = '',
    this.imageUrl,
    this.latitude,
    this.longitude,
    this.localName,
    this.model3dUrl,
  });
  final int? id;
  final String scientificName;
  final String commonName;
  final String genus;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  final String? localName;
  final String? model3dUrl;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'scientificName': scientificName,
    'commonName': commonName,
    'genus': genus,
    'imageUrl': imageUrl,
    'latitude': latitude,
    'longitude': longitude,
    'localName': localName,
    'model3dUrl': model3dUrl,
  };
  static CatalogSpecies fromJson(Map<String, dynamic> json) => CatalogSpecies(
    id: json['id'] as int?,
    scientificName: (json['scientificName'] ?? '').toString(),
    commonName: (json['commonName'] ?? '').toString(),
    genus: (json['genus'] ?? '').toString(),
    imageUrl: json['imageUrl'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    localName: json['localName'] as String?,
    model3dUrl: json['model3dUrl'] as String?,
  );
}

class CatalogGroup {
  const CatalogGroup({required this.title, required this.species});
  final String title;
  final List<CatalogSpecies> species;
}
