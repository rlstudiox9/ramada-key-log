import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/auth_session.dart';
import 'models/key_issuance.dart';
import 'models/staff_roster_member.dart';
import 'services/api_service.dart';
import 'utils/file_download.dart';
import 'utils/key_log_export.dart';
import 'widgets/staff_performance_chart.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  runApp(const RamadaKeyLogApp());
}

/// Ramada by Wyndham Brand Theme Colors
class RamadaColors {
  static const Color burgundy = Color(0xFF7A1426);
  static const Color burgundyDark = Color(0xFF520B18);
  static const Color burgundyLight = Color(0xFF9E1F35);
  static const Color gold = Color(0xFFC5A059);
  static const Color goldLight = Color(0xFFDFBA76);
  static const Color goldContainer = Color(0xFFF9F3E8);
  static const Color charcoalDark = Color(0xFF0B1020);
  static const Color charcoalSurface = Color(0xFF111827);
  static const Color charcoalRaised = Color(0xFF1A2436);
  static const Color charcoalBorder = Color(0xFF28354A);
  static const Color charcoalMuted = Color(0xFF9AA9BD);
  static const Color creamBg = Color(0xFFFBF9F5);
  static const Color white = Colors.white;

  // Status Colors
  static const Color success = Color(0xFF1B8755);
  static const Color successText = Color(0xFF166534);
  static const Color successBg = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFD97706);
  static const Color warningText = Color(0xFF92400E);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerText = Color(0xFFB91C1C);
  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color carried = Color(0xFF7C3AED);
  static const Color carriedBg = Color(0xFFF3E8FF);
}

class RamadaLoadingView extends StatelessWidget {
  final String message;

  const RamadaLoadingView({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: RamadaColors.creamBg,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          RamadaColors.burgundyDark,
                          RamadaColors.burgundy,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: RamadaColors.gold.withValues(alpha: 0.75),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.vpn_key_rounded,
                      color: RamadaColors.goldLight,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'RAMADA KEYS',
                    style: TextStyle(
                      color: RamadaColors.burgundyDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: RamadaColors.gold,
                      backgroundColor: RamadaColors.goldContainer,
                      semanticsLabel: 'Loading',
                    ),
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: const LinearProgressIndicator(
                      minHeight: 5,
                      color: RamadaColors.burgundy,
                      backgroundColor: RamadaColors.goldContainer,
                      semanticsLabel: 'Loading progress',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class RamadaKeyLogApp extends StatefulWidget {
  final ApiService? apiService;

  const RamadaKeyLogApp({super.key, this.apiService});

  @override
  State<RamadaKeyLogApp> createState() => _RamadaKeyLogAppState();
}

class _RamadaKeyLogAppState extends State<RamadaKeyLogApp>
    with WidgetsBindingObserver {
  static const _idleLogoutDuration = Duration(minutes: 10);

  ThemeMode _themeMode = ThemeMode.dark;
  late final ApiService _apiService;
  AuthSession? _session;
  bool _isRestoringSession = true;
  String? _authError;
  Timer? _idleLogoutTimer;
  DateTime? _lastActivityAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _apiService = widget.apiService ?? ApiService();
    _restoreSession();
  }

  @override
  void dispose() {
    _idleLogoutTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _session != null) {
      _scheduleIdleLogout();
    }
  }

  void _recordUserActivity() {
    if (_session == null) return;
    _lastActivityAt = DateTime.now();
    _scheduleIdleLogout();
  }

  void _scheduleIdleLogout() {
    _idleLogoutTimer?.cancel();
    if (_session == null) return;

    final lastActivity = _lastActivityAt ?? DateTime.now();
    _lastActivityAt = lastActivity;
    final remaining =
        _idleLogoutDuration - DateTime.now().difference(lastActivity);
    if (remaining <= Duration.zero) {
      unawaited(_logoutForInactivity());
      return;
    }
    _idleLogoutTimer =
        Timer(remaining, () => unawaited(_logoutForInactivity()));
  }

  Future<void> _logoutForInactivity() async {
    final session = _session;
    if (session == null) return;

    _idleLogoutTimer?.cancel();
    _idleLogoutTimer = null;
    _lastActivityAt = null;
    _apiService.accessToken = null;
    if (mounted) {
      setState(() {
        _session = null;
        _authError =
            'Signed out after 10 minutes of inactivity. Please sign in again.';
      });
    }

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove('auth_access_token');
    } catch (error, stackTrace) {
      debugPrint('Could not clear the idle session token: $error\n$stackTrace');
    }
    unawaited(() async {
      try {
        await _apiService.logout(token: session.accessToken);
      } catch (error, stackTrace) {
        debugPrint('Server idle sign-out failed: $error\n$stackTrace');
      }
    }());
  }

  Future<void> _restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString('auth_access_token');
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _isRestoringSession = false);
      return;
    }

    try {
      final user = await _apiService.getCurrentUser(token: token);
      _apiService.accessToken = token;
      if (mounted) {
        setState(() {
          _session = AuthSession(accessToken: token, user: user);
          _isRestoringSession = false;
        });
        _lastActivityAt = DateTime.now();
        _scheduleIdleLogout();
      }
    } catch (error, stackTrace) {
      debugPrint('Could not restore sign-in session: $error\n$stackTrace');
      await preferences.remove('auth_access_token');
      _apiService.accessToken = null;
      if (mounted) {
        setState(() {
          _authError = error is ApiException && error.statusCode != 401
              ? 'Could not verify the saved session. Check the server and try again.'
              : null;
          _isRestoringSession = false;
        });
      }
    }
  }

  Future<void> _acceptSession(AuthSession session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('auth_access_token', session.accessToken);
    _apiService.accessToken = session.accessToken;
    if (!mounted) return;
    setState(() {
      _authError = null;
      _session = session;
    });
    _lastActivityAt = DateTime.now();
    _scheduleIdleLogout();
  }

  Future<void> _signOut() async {
    final session = _session;
    if (session == null) return;
    _idleLogoutTimer?.cancel();
    _idleLogoutTimer = null;
    _lastActivityAt = null;
    try {
      await _apiService.logout(token: session.accessToken);
    } catch (error, stackTrace) {
      debugPrint(
          'Server sign-out failed; clearing local session: $error\n$stackTrace');
    } finally {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove('auth_access_token');
      _apiService.accessToken = null;
      if (mounted) setState(() => _session = null);
    }
  }

  Future<void> _expireSession() async {
    _idleLogoutTimer?.cancel();
    _idleLogoutTimer = null;
    _lastActivityAt = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('auth_access_token');
    _apiService.accessToken = null;
    if (mounted) setState(() => _session = null);
  }

  void toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ramada Keys - Doha Old Town',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      builder: (context, child) {
        if (_session == null) return child ?? const SizedBox.shrink();
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _recordUserActivity(),
          onPointerMove: (_) => _recordUserActivity(),
          onPointerHover: (_) => _recordUserActivity(),
          onPointerSignal: (_) => _recordUserActivity(),
          child: Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent || event is KeyRepeatEvent) {
                _recordUserActivity();
              }
              return KeyEventResult.ignored;
            },
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: RamadaColors.creamBg,
        dividerColor: const Color(0xFFE2E8F0),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Color(0xFF1F2937)),
          displayMedium: TextStyle(color: Color(0xFF1F2937)),
          displaySmall: TextStyle(color: Color(0xFF1F2937)),
          headlineLarge: TextStyle(color: Color(0xFF1F2937)),
          headlineMedium: TextStyle(color: Color(0xFF1F2937)),
          headlineSmall: TextStyle(color: Color(0xFF1F2937)),
          titleLarge: TextStyle(color: Color(0xFF1F2937)),
          titleMedium: TextStyle(color: Color(0xFF1F2937)),
          titleSmall: TextStyle(color: Color(0xFF1F2937)),
          bodyLarge: TextStyle(color: Color(0xFF1F2937)),
          bodyMedium: TextStyle(color: Color(0xFF1F2937)),
          bodySmall: TextStyle(color: Color(0xFF475569)),
          labelLarge: TextStyle(color: Color(0xFF1F2937)),
          labelMedium: TextStyle(color: Color(0xFF334155)),
          labelSmall: TextStyle(color: Color(0xFF475569)),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: RamadaColors.burgundy,
          primary: RamadaColors.burgundy,
          secondary: RamadaColors.gold,
          surface: Colors.white,
        ),
        dataTableTheme: const DataTableThemeData(
          headingTextStyle: TextStyle(
            color: RamadaColors.burgundyDark,
            fontWeight: FontWeight.bold,
          ),
          dataTextStyle: TextStyle(color: Color(0xFF1F2937)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: RamadaColors.charcoalDark,
        dividerColor: RamadaColors.charcoalBorder,
        cardTheme: const CardThemeData(
          color: RamadaColors.charcoalSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: RamadaColors.charcoalRaised,
          hintStyle: const TextStyle(color: RamadaColors.charcoalMuted),
          labelStyle: const TextStyle(color: RamadaColors.charcoalMuted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: RamadaColors.charcoalBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: RamadaColors.charcoalBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: RamadaColors.gold, width: 1.4),
          ),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: RamadaColors.burgundy,
          brightness: Brightness.dark,
          primary: RamadaColors.goldLight,
          secondary: RamadaColors.gold,
          surface: RamadaColors.charcoalSurface,
        ),
        dataTableTheme: const DataTableThemeData(
          headingRowColor: WidgetStatePropertyAll(RamadaColors.charcoalRaised),
          headingTextStyle: TextStyle(
            color: RamadaColors.goldLight,
            fontWeight: FontWeight.bold,
          ),
          dataRowColor: WidgetStatePropertyAll(RamadaColors.charcoalSurface),
          dataTextStyle: TextStyle(color: Color(0xFFF1F1F1)),
          dividerThickness: 0.8,
        ),
      ),
      home: _isRestoringSession
          ? const RamadaLoadingView(
              message: 'Restoring your secure session...',
            )
          : _session == null
              ? AuthScreen(
                  apiService: _apiService,
                  initialError: _authError,
                  onAuthenticated: _acceptSession,
                )
              : HotelDashboardScreen(
                  key: ValueKey(_session!.user.id),
                  session: _session!,
                  onLogout: _signOut,
                  onSessionExpired: _expireSession,
                  onToggleTheme: toggleTheme,
                  isDark: _themeMode == ThemeMode.dark,
                  apiService: _apiService,
                ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  final ApiService apiService;
  final Future<void> Function(AuthSession session) onAuthenticated;
  final String? initialError;

  const AuthScreen({
    super.key,
    required this.apiService,
    required this.onAuthenticated,
    this.initialError,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  bool _rememberUsername = false;
  bool _isWarmingBackend = true;
  bool _backendWarmupFailed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _errorMessage = widget.initialError;
    unawaited(_restoreRememberedUsername());
    unawaited(_warmBackend());
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    final username = value?.trim() ?? '';
    if (username.length < 3 || username.length > 64) {
      return 'Use 3 to 64 characters.';
    }
    if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(username)) {
      return 'Use letters, numbers, dots, underscores or hyphens.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 8) return 'Use at least 8 characters.';
    if ((value ?? '').length > 128) return 'Password is too long.';
    return null;
  }

  Future<void> _warmBackend() async {
    final isAvailable = await widget.apiService.wakeBackend();
    if (!mounted) return;
    setState(() {
      _isWarmingBackend = false;
      _backendWarmupFailed = !isAvailable;
    });
  }

  Future<void> _restoreRememberedUsername() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final remember = preferences.getBool('remember_username') ?? false;
      if (!mounted) return;
      setState(() {
        _rememberUsername = remember;
        if (remember) {
          _usernameController.text =
              preferences.getString('remembered_username') ?? '';
        }
      });
    } catch (error, stackTrace) {
      debugPrint('Could not restore remembered username: $error\n$stackTrace');
    }
  }

  Future<void> _setRememberUsername(bool remember) async {
    setState(() => _rememberUsername = remember);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('remember_username', remember);
      if (!remember) await preferences.remove('remembered_username');
    } catch (error, stackTrace) {
      debugPrint('Could not update remembered username: $error\n$stackTrace');
    }
  }

  Future<void> _saveRememberedUsername() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (_rememberUsername) {
        await preferences.setString(
          'remembered_username',
          _usernameController.text.trim(),
        );
      } else {
        await preferences.remove('remembered_username');
      }
    } catch (error, stackTrace) {
      debugPrint('Could not save remembered username: $error\n$stackTrace');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final session = _isSignUp
          ? await widget.apiService.signUp(
              username: _usernameController.text.trim(),
              displayName: _displayNameController.text.trim(),
              password: _passwordController.text,
            )
          : await widget.apiService.login(
              username: _usernameController.text.trim(),
              password: _passwordController.text,
            );
      if (!_isSignUp) await _saveRememberedUsername();
      await widget.onAuthenticated(session);
    } catch (error, stackTrace) {
      debugPrint('Authentication request failed: $error\n$stackTrace');
      if (mounted) setState(() => _errorMessage = _userFriendlyError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _userFriendlyError(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 401) return 'Username or password is incorrect.';
      if (error.statusCode == 409) {
        return 'That username is already registered. Please sign in.';
      }
      if (error.statusCode == 429) {
        return 'Too many attempts. Please wait 15 minutes and try again.';
      }
      if (error.statusCode >= 500) {
        return 'The sign-in service is temporarily unavailable.';
      }
      return error.message;
    }
    return 'Could not reach the sign-in service. Check your connection.';
  }

  Future<void> _showForgotPassword() async {
    var requestedUsername = '';
    var isSubmitting = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Forgot password?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your username. A reset request will be sent to a hotel administrator.',
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('forgot-username'),
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onChanged: (value) => requestedUsername = value,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (requestedUsername.trim().isEmpty) return;
                      setDialogState(() => isSubmitting = true);
                      try {
                        await widget.apiService.requestPasswordReset(
                          username: requestedUsername.trim(),
                        );
                        if (dialogContext.mounted) {
                          FocusScope.of(dialogContext).unfocus();
                          Navigator.pop(dialogContext);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'If the account exists, an administrator will receive the reset request.',
                              ),
                            ),
                          );
                        }
                      } catch (error, stackTrace) {
                        debugPrint(
                          'Password reset request failed: $error\n$stackTrace',
                        );
                        if (dialogContext.mounted) {
                          setDialogState(() => isSubmitting = false);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not submit the request. Please contact the hotel administrator.',
                              ),
                            ),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Request reset'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/ramada_hotel_bg.jpg'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFF081326).withValues(alpha: 0.79),
                    const Color(0xFF101F3D).withValues(alpha: 0.55),
                    const Color(0xFF081326).withValues(alpha: 0.48),
                  ],
                  stops: const [0, 0.52, 1],
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  return Column(
                    children: [
                      Expanded(
                        child: isWide
                            ? Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal:
                                      constraints.maxWidth >= 1280 ? 72 : 32,
                                  vertical: 24,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 11,
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(right: 40),
                                        child: _buildBrandPanel(),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 9,
                                      child: Center(
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              maxWidth: 480),
                                          child: _buildLoginPanel(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : SingleChildScrollView(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 20, 20, 24),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 480),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildBrandPanel(compact: true),
                                        const SizedBox(height: 22),
                                        _buildLoginPanel(compact: true),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      _buildLoginFooter(
                        isWide: isWide && constraints.maxWidth >= 1200,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPanel({bool compact = false}) => _buildFormCard(
        compact: compact,
      );

  Widget _buildLoginFooter({required bool isWide}) {
    const brand = Text(
      '◈  Ramada by Wyndham  ·  Doha Old Town',
      key: ValueKey('login-footer-brand'),
      style: TextStyle(color: Color(0xFFD4DCE9), fontSize: 11),
    );
    final privacyButton = TextButton(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFD4DCE9),
        minimumSize: const Size(44, 40),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 11),
      ),
      onPressed: () => _showLegalDialog(
        title: 'Privacy Policy',
        sections: _privacySections,
      ),
      child: const Text('Privacy Policy'),
    );
    final termsButton = TextButton(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFD4DCE9),
        minimumSize: const Size(44, 40),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 11),
      ),
      onPressed: () => _showLegalDialog(
        title: 'Terms & Conditions',
        sections: _termsSections,
      ),
      child: const Text('Terms & Conditions'),
    );
    const poweredBy = Text(
      'Powered by R & L Studio',
      style: TextStyle(color: Color(0xFF9EABC0), fontSize: 10),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF071123).withValues(alpha: 0.82),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 48 : 16,
        vertical: isWide ? 6 : 8,
      ),
      child: isWide
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                brand,
                Row(
                  key: const ValueKey('login-footer-links'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    privacyButton,
                    const SizedBox(width: 8),
                    termsButton,
                    const SizedBox(width: 16),
                    poweredBy,
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                brand,
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 0,
                  children: [
                    privacyButton,
                    termsButton,
                    poweredBy,
                  ],
                ),
              ],
            ),
    );
  }

  static const _privacySections = <(String, String)>[
    (
      'Hotel operational data',
      'This application records key-card and system-access activity for hotel operations, including room references, staff actions and handover details. Only enter information required to manage access.',
    ),
    (
      'Access and confidentiality',
      'Use your own authorized account, keep credentials private, and sign out when your shift ends or you leave a shared workstation. Do not disclose guest or operational information to people who are not authorized to receive it.',
    ),
    (
      'Data security and retention',
      'Access is limited by account permissions and activity is handled by the hotel-managed service. Hotel management is responsible for account provisioning, retention schedules and responding to data access or correction requests.',
    ),
    (
      'Security concerns',
      'Report a lost device, suspected account compromise or incorrect access record promptly to hotel management. Do not use this application as an emergency communication channel.',
    ),
  ];

  static const _termsSections = <(String, String)>[
    (
      'Permitted use',
      'The hotel grants authorized staff a limited, non-exclusive, non-transferable permission to use this key-management log for Ramada by Wyndham Doha Old Town operations, subject to their assigned account role.',
    ),
    (
      'Account responsibility',
      'You are responsible for activity performed through your account. Do not share credentials, attempt to bypass role restrictions, or enter false or unnecessary records. Admin access is provisioned by hotel management.',
    ),
    (
      'Restrictions and ownership',
      'The application and its branding remain the property of their respective owners. You may not copy, redistribute, resell, reverse engineer or modify the software except as permitted by applicable law or with written authorization.',
    ),
    (
      'Availability and changes',
      'Hotel management may update, suspend or revoke access when operationally necessary. The service is provided for internal record keeping and does not replace physical key-control procedures, hotel policies or emergency protocols.',
    ),
  ];

  Future<void> _showLegalDialog({
    required String title,
    required List<(String, String)> sections,
  }) =>
      showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.82,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: Theme.of(dialogContext)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          color: RamadaColors.burgundyDark,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final (heading, body) in sections) ...[
                            Text(
                              heading,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: RamadaColors.burgundy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(body),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildBrandPanel({bool compact = false}) {
    final headlineFontSize =
        MediaQuery.sizeOf(context).width < 1180 ? 34.0 : 42.0;
    return Column(
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 48 : 68,
              height: compact ? 48 : 68,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFFD8A84E).withValues(alpha: 0.8),
                  width: 1.4,
                ),
                borderRadius: BorderRadius.circular(18),
                color: Colors.white.withValues(alpha: 0.045),
              ),
              child: Center(
                child: Text(
                  'R',
                  style: TextStyle(
                    color: const Color(0xFFE9B755),
                    fontSize: compact ? 34 : 48,
                    height: 1,
                    fontFamily: 'serif',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RAMADA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 22 : 32,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: compact ? 3 : 4.5,
                    fontFamily: 'serif',
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'BY WYNDHAM',
                  style: TextStyle(
                    color: const Color(0xFFE1E7F0),
                    fontSize: compact ? 9 : 11,
                    letterSpacing: compact ? 3.2 : 4.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 22),
        Container(
          width: compact ? 170 : 230,
          height: 1,
          color: const Color(0xFFD8A84E).withValues(alpha: 0.72),
        ),
        const SizedBox(height: 10),
        Text(
          'DOHA OLD TOWN   ·   KEY & ACCESS LOG',
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: const Color(0xFFE7B658),
            fontSize: compact ? 9 : 11,
            fontWeight: FontWeight.w700,
            letterSpacing: compact ? 1 : 1.8,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 38),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 570),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: const Color(0xFFF7F8FA),
                  fontSize: headlineFontSize,
                  height: 1.16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'serif',
                ),
                children: const [
                  TextSpan(text: 'A secure handover starts\n'),
                  TextSpan(
                    text: 'with a clear record.',
                    style: TextStyle(color: Color(0xFFEAB653)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SizedBox(
            width: 430,
            child: Text(
              'Sign in to manage key cards, guest access and shift handovers.',
              style: TextStyle(
                color: Color(0xFFD8E0ED),
                height: 1.5,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 30),
          Wrap(
            spacing: 14,
            runSpacing: 12,
            children: [
              _roleBadge(
                Icons.room_service_outlined,
                'Reception / Front Desk',
                'Manage guest access &\nfront desk operations',
              ),
              _roleBadge(
                Icons.verified_user_outlined,
                'Admin Controls',
                'Access management &\ncorrections',
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _roleBadge(IconData icon, String label, String detail) => Container(
        width: 224,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFFD8A84E).withValues(alpha: 0.65),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: const Color(0xFFE5B351)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: Color(0xFFBAC6D8),
                      height: 1.3,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildFormCard({bool compact = false}) {
    return Card(
      elevation: 28,
      shadowColor: Colors.black.withValues(alpha: 0.38),
      color: const Color(0xFFFCFCFD),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(compact ? 22 : 26),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.85)),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 23 : 34),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F0E3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.lock_person_outlined,
                      color: Color(0xFFC7963D),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isSignUp ? 'Create your account' : 'Welcome Back',
                          style: TextStyle(
                            color: const Color(0xFF0D1D3A),
                            fontSize: compact ? 23 : 27,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'serif',
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _isSignUp
                              ? 'New accounts are created with Reception access.'
                              : 'Sign in to continue to the hotel key log.',
                          style: const TextStyle(
                            color: Color(0xFF71809A),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 21 : 26),
              if (_isSignUp) ...[
                TextFormField(
                  key: const ValueKey('auth:Full name'),
                  controller: _displayNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _authDecoration(
                    'Full name',
                    Icons.badge_outlined,
                  ),
                  validator: (value) => (value?.trim().length ?? 0) < 2
                      ? 'Enter your name.'
                      : null,
                ),
                const SizedBox(height: 15),
              ],
              TextFormField(
                key: const ValueKey('auth:Username'),
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: _authDecoration('Username', Icons.person_outline),
                validator: _validateUsername,
              ),
              const SizedBox(height: 15),
              TextFormField(
                key: const ValueKey('auth:Password'),
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction:
                    _isSignUp ? TextInputAction.next : TextInputAction.done,
                onFieldSubmitted: (_) => _isSignUp ? null : _submit(),
                decoration: _authDecoration(
                  'Password',
                  Icons.lock_outline,
                  suffix: IconButton(
                    tooltip:
                        _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: _isSignUp ? _validatePassword : null,
              ),
              if (!_isSignUp)
                CheckboxListTile(
                  key: const ValueKey('auth:remember-username'),
                  value: _rememberUsername,
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value != null) {
                            unawaited(_setRememberUsername(value));
                          }
                        },
                  title: const Text('Remember username on this device'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                ),
              if (_isSignUp) ...[
                const SizedBox(height: 14),
                TextFormField(
                  key: const ValueKey('auth:Re-type password'),
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: _authDecoration(
                    'Re-type password',
                    Icons.lock_reset_outlined,
                    suffix: IconButton(
                      tooltip: _obscureConfirmPassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => value != _passwordController.text
                      ? 'Passwords do not match.'
                      : null,
                ),
              ],
              if (!_isSignUp)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isSubmitting ? null : _showForgotPassword,
                    child: const Text('Forgot password?'),
                  ),
                ),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCECEF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF3CDD4)),
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFB4233C),
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFF9D1C33),
                              height: 1.45,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.disabled)) {
                        return const Color(0xFF9B6670);
                      }
                      if (states.contains(WidgetState.pressed)) {
                        return const Color(0xFF780E22);
                      }
                      if (states.contains(WidgetState.hovered)) {
                        return const Color(0xFFBE1D3D);
                      }
                      return const Color(0xFFA9142F);
                    }),
                    foregroundColor: const WidgetStatePropertyAll(Colors.white),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    elevation: WidgetStateProperty.resolveWith((states) =>
                        states.contains(WidgetState.hovered) ? 7 : 3),
                    shadowColor: const WidgetStatePropertyAll(
                      Color(0x55A9142F),
                    ),
                    minimumSize: const WidgetStatePropertyAll(
                      Size(double.infinity, 52),
                    ),
                    overlayColor: const WidgetStatePropertyAll(
                      Color(0x22FFFFFF),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isSignUp ? 'Sign Up' : 'Login',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.arrow_forward_rounded, size: 19),
                          ],
                        ),
                ),
              ),
              if (_isWarmingBackend || _isSubmitting) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _isSubmitting
                            ? 'Connecting securely…'
                            : 'Connecting to sign-in service…',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF71809A),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (_backendWarmupFailed) ...[
                const SizedBox(height: 8),
                const Text(
                  'Service may be starting. Sign-in retries automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF71809A),
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () => setState(() {
                          _isSignUp = !_isSignUp;
                          _errorMessage = null;
                          _formKey.currentState?.reset();
                          _passwordController.clear();
                          _confirmPasswordController.clear();
                        }),
                child: Text(
                  _isSignUp
                      ? 'Already registered? Sign in'
                      : 'New staff member? Create account',
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Admin access is provisioned by hotel management.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _authDecoration(
    String label,
    IconData icon, {
    Widget? suffix,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: 'Enter your ${label.toLowerCase()}',
        hintStyle: const TextStyle(
          color: Color(0xFF98A5B9),
          fontSize: 13,
        ),
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD8E0EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD8E0EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF274A78), width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFB4233C)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFB4233C), width: 1.6),
        ),
      );
}

class HotelDashboardScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;
  final ApiService apiService;
  final AuthSession session;
  final Future<void> Function() onLogout;
  final Future<void> Function() onSessionExpired;

  const HotelDashboardScreen(
      {super.key,
      required this.onToggleTheme,
      required this.isDark,
      required this.apiService,
      required this.session,
      required this.onLogout,
      required this.onSessionExpired});

  @override
  State<HotelDashboardScreen> createState() => _HotelDashboardScreenState();
}

class _HotelDashboardScreenState extends State<HotelDashboardScreen> {
  static const Duration _inventoryRefreshInterval = Duration(seconds: 5);

  int totalInventory = 70;
  String dutyStaffName = "";
  String selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String selectedShift = "Morning (07:00 - 15:00)";
  String searchQuery = "";
  String activeFilter = "ALL"; // ALL, PENDING, RETURNED, MISSING, CARRIED
  final GlobalKey _overviewSectionKey = GlobalKey();
  final GlobalKey _logsSectionKey = GlobalKey();
  int _selectedDashboardSection = 0;
  bool _isLoading = true;
  String? _storageError;
  String? _inventorySyncError;
  bool _isRefreshingInventory = false;
  bool _isCheckingDailyReport = false;
  String? _dailyReportError;
  String? _lastActiveDate;
  String? _lastActiveShift;
  Timer? _inventoryRefreshTimer;
  Timer? _activeShiftTimer;
  Timer? _dailyReportTimer;

  final List<String> shifts = [
    "Morning (07:00 - 15:00)",
    "Afternoon (15:00 - 23:00)",
    "Night (23:00 - 07:00)",
    "All Shifts"
  ];

  List<KeyIssuanceItem> issuances = [];
  List<StaffRosterMember> staffRoster = [];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _inventoryRefreshTimer = Timer.periodic(
      _inventoryRefreshInterval,
      (_) => _refreshSharedInventory(),
    );
    _activeShiftTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshActiveShift(),
    );
    _dailyReportTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkForDailyReport(),
    );
  }

  @override
  void dispose() {
    _inventoryRefreshTimer?.cancel();
    _activeShiftTimer?.cancel();
    _dailyReportTimer?.cancel();
    super.dispose();
  }

  String _shiftFor(DateTime dateTime) =>
      dateTime.hour < 7 || dateTime.hour >= 23
          ? shifts[2]
          : dateTime.hour < 15
              ? shifts[0]
              : shifts[1];

  Future<void> _refreshActiveShift() async {
    if (_isLoading) return;
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final currentShift = _shiftFor(now);
    if (_lastActiveDate == today && _lastActiveShift == currentShift) return;
    _lastActiveDate = today;
    _lastActiveShift = currentShift;

    try {
      var shiftForToday = currentShift;
      if (!widget.session.user.isAdmin) {
        final assignedShift = await widget.apiService.getStaffShiftAssignment(
          shiftDate: today,
          token: widget.session.accessToken,
        );
        if (assignedShift != null && shifts.take(3).contains(assignedShift)) {
          shiftForToday = assignedShift;
        }
      }
      if (!mounted) return;
      setState(() {
        selectedDate = today;
        selectedShift = shiftForToday;
      });
      issuances = await widget.apiService.getLogs();
      await _syncCarryForward();
      if (mounted) setState(() => _storageError = null);
    } catch (error, stackTrace) {
      _reportApiError(error, stackTrace);
    }
  }

  Future<void> _loadSavedData() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final now = DateTime.now();
      selectedDate = DateFormat('yyyy-MM-dd').format(now);
      selectedShift = _shiftFor(now);
      _lastActiveDate = selectedDate;
      _lastActiveShift = _shiftFor(now);
      dutyStaffName = preferences.getString('duty_staff_name') ?? dutyStaffName;
      staffRoster = await widget.apiService.getStaffRoster(
        token: widget.session.accessToken,
      );
      totalInventory = await widget.apiService.getInventoryLimit(
        token: widget.session.accessToken,
      );
      issuances = await widget.apiService.getLogs();
      if (!widget.session.user.isAdmin) {
        try {
          final assignedShift = await widget.apiService.getStaffShiftAssignment(
            shiftDate: selectedDate,
            token: widget.session.accessToken,
          );
          if (assignedShift != null && shifts.take(3).contains(assignedShift)) {
            selectedShift = assignedShift;
          }
        } catch (error, stackTrace) {
          debugPrint('Could not restore assigned shift: $error\n$stackTrace');
        }
      }
      await _syncCarryForward();
    } catch (error, stackTrace) {
      debugPrint('Failed to load key logs from API: $error\n$stackTrace');
      _storageError = 'Key logs could not be loaded from the API: $error';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    if (mounted) unawaited(_checkForDailyReport());
  }

  Future<void> _checkForDailyReport() async {
    if (_isLoading || _isCheckingDailyReport) return;
    _isCheckingDailyReport = true;
    try {
      final report = await widget.apiService.getLatestDailyReport();
      if (report == null || !mounted) return;

      final preferences = await SharedPreferences.getInstance();
      final lastDownloaded =
          preferences.getString('last_daily_report_downloaded') ?? '';
      if (report.reportDate.compareTo(lastDownloaded) <= 0) {
        if (_dailyReportError != null) {
          setState(() => _dailyReportError = null);
        }
        return;
      }

      downloadTextFile(
        report.csvContent,
        'ramada-key-log-daily-${report.reportDate}.csv',
        'text/csv;charset=utf-8',
      );
      await preferences.setString(
        'last_daily_report_downloaded',
        report.reportDate,
      );
      if (!mounted) return;
      setState(() => _dailyReportError = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Daily key log report downloaded (${report.reportDate}).'),
          action: SnackBarAction(
            label: 'Download again',
            onPressed: () => downloadTextFile(
              report.csvContent,
              'ramada-key-log-daily-${report.reportDate}.csv',
              'text/csv;charset=utf-8',
            ),
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
          'Failed to retrieve daily key log report: $error\n$stackTrace');
      if (!mounted) return;
      final message = 'Daily report unavailable: $error';
      if (_dailyReportError != message) {
        setState(() => _dailyReportError = message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      if (error is ApiException && error.statusCode == 401) {
        unawaited(widget.onSessionExpired());
      }
    } finally {
      _isCheckingDailyReport = false;
    }
  }

  Future<void> _refreshLogs() async {
    final loadedLogs = await widget.apiService.getLogs();
    if (!mounted) return;
    setState(() {
      issuances = loadedLogs;
      _storageError = null;
    });
  }

  Future<void> _refreshSharedInventory() async {
    if (_isLoading || _isRefreshingInventory) return;
    _isRefreshingInventory = true;
    try {
      final refreshedInventory = await widget.apiService.getInventoryLimit(
        token: widget.session.accessToken,
      );
      if (!mounted) return;
      if (refreshedInventory != totalInventory || _inventorySyncError != null) {
        setState(() {
          totalInventory = refreshedInventory;
          _inventorySyncError = null;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to sync shared key inventory: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _inventorySyncError = 'Shared inventory could not be refreshed: $error';
      });
      if (error is ApiException && error.statusCode == 401) {
        unawaited(widget.onSessionExpired());
      }
    } finally {
      _isRefreshingInventory = false;
    }
  }

  int get _minimumInventoryLimit {
    final carriedEntryIds =
        issuances.map((item) => item.carriedFromId).whereType<String>().toSet();
    return issuances
        .where((item) => !carriedEntryIds.contains(item.id))
        .fold(0, (total, item) => total + item.remainingUnreturnedQty);
  }

  Future<void> _openInventoryLimitDialog() async {
    if (!widget.session.user.isAdmin) return;
    final updatedInventory = await showDialog<int>(
      context: context,
      builder: (context) => AdminInventoryLimitDialog(
        currentInventory: totalInventory,
        minimumInventory: _minimumInventoryLimit,
      ),
    );
    if (updatedInventory == null || !mounted) return;

    try {
      await widget.apiService.updateInventoryLimit(
        totalInventory: updatedInventory,
        token: widget.session.accessToken,
      );
      if (!mounted) return;
      setState(() => totalInventory = updatedInventory);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Key stock limit updated.')),
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to update key stock limit: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException
                  ? error.message
                  : 'Key stock limit could not be saved. Try again.',
            ),
          ),
        );
      }
    }
  }

  Future<int> _syncCarryForward() async {
    if (selectedShift == 'All Shifts' || selectedDate == 'ALL') return 0;
    final carriedCount = await widget.apiService.carryForwardLogs(
      shiftDate: selectedDate,
      shiftPeriod: selectedShift,
      issuedDateTime: DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now()),
      staffName: dutyStaffName.isEmpty
          ? widget.session.user.displayName
          : dutyStaffName,
      token: widget.session.accessToken,
    );
    await _refreshLogs();
    return carriedCount;
  }

  Future<void> _selectShift(String shift) async {
    final previousShift = selectedShift;
    setState(() => selectedShift = shift);
    if (widget.session.user.isAdmin) return;
    if (shift == 'All Shifts' || selectedDate == 'ALL') return;
    try {
      await widget.apiService.setStaffShiftAssignment(
        shiftDate: selectedDate,
        shiftPeriod: shift,
        token: widget.session.accessToken,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to save selected duty shift: $error\n$stackTrace');
      if (mounted) {
        setState(() => selectedShift = previousShift);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Duty shift selection could not be saved: $error')),
        );
      }
    }
  }

  Future<void> _openManageStaffRoster() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AdminStaffRosterDialog(
        apiService: widget.apiService,
        accessToken: widget.session.accessToken,
        readOnly: !widget.session.user.isAdmin,
      ),
    );
    if (!mounted) return;
    try {
      final refreshedRoster = await widget.apiService.getStaffRoster(
        token: widget.session.accessToken,
      );
      setState(() => staffRoster = refreshedRoster);
    } catch (error, stackTrace) {
      _reportApiError(error, stackTrace);
    }
  }

  void _reportApiError(Object error, StackTrace stackTrace) {
    debugPrint('Key log API request failed: $error\n$stackTrace');
    if (!mounted) return;
    setState(() {
      _storageError = 'API request failed: $error';
      if (error is ApiException && error.statusCode == 401) {
        unawaited(widget.onSessionExpired());
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_storageError!)),
    );
  }

  // Real-time calculation metrics
  KeyLogMetrics get _metrics => KeyLogMetrics.calculate(
        issuances,
        totalInventory: totalInventory,
        shiftDate: selectedDate == 'ALL' ? null : selectedDate,
        shiftPeriod: selectedShift,
      );

  int get handoverToGuest => _metrics.handoverToGuest;
  int get returnFromGuest => _metrics.returnFromGuest;
  int get missingKeys => _metrics.missingKeys;
  int get currentlyWithGuest => _metrics.currentlyWithGuest;
  int get remainingInFd => _metrics.remainingInFd;
  List<StaffIssueMetric> get _staffPerformanceMetrics =>
      StaffPerformanceChart.calculateMetrics(
        entries: issuances,
        staffRoster: staffRoster,
      );

  List<KeyIssuanceItem> get filteredList {
    return issuances.where((item) {
      final matchesDate =
          selectedDate == "ALL" || item.shiftDate == selectedDate;
      final matchesShift =
          selectedShift == "All Shifts" || item.shiftPeriod == selectedShift;
      final matchesQuery = searchQuery.isEmpty ||
          item.roomOrAccess.toLowerCase().contains(searchQuery.toLowerCase()) ||
          item.guestOrHolderName
              .toLowerCase()
              .contains(searchQuery.toLowerCase()) ||
          item.issuingStaff.toLowerCase().contains(searchQuery.toLowerCase());
      final matchesFilter = switch (activeFilter) {
        "PENDING" => item.isPending,
        "RETURNED" => item.isFullyReturned,
        "MISSING" => item.isMissing,
        "CARRIED" => item.isCarriedForward,
        _ => true,
      };
      return matchesDate && matchesShift && matchesQuery && matchesFilter;
    }).toList();
  }

  Future<void> _triggerAutoCarryForward() async {
    if (selectedShift == 'All Shifts' || selectedDate == 'ALL') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a specific date and shift before syncing.'),
        ),
      );
      return;
    }
    try {
      final carriedCount = await _syncCarryForward();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Auto Carry-Forward Engine: $carriedCount unreturned keys synchronized into active shift.'),
          backgroundColor: RamadaColors.carried,
        ),
      );
    } catch (error, stackTrace) {
      _reportApiError(error, stackTrace);
    }
  }

  void _openAddDialog() {
    if (remainingInFd <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No keys are currently available at FD.')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AddIssuanceDialog(
        initialStaffName: dutyStaffName,
        staffRoster: staffRoster.where((staff) => staff.isActive).toList(),
        availableQuantity: remainingInFd,
        onAdd: (room, guest, qty, cat, remarks, staff, checkOutDate) async {
          final nowFmt =
              DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now());
          final item = KeyIssuanceItem(
            id: '',
            sNo: issuances.length + 1,
            shiftDate: selectedDate,
            shiftPeriod: selectedShift,
            issuedDateTime: nowFmt,
            checkOutDate: checkOutDate,
            issuingStaff: staff,
            roomOrAccess: room,
            guestOrHolderName: guest,
            qtyIssued: qty,
            category: cat,
            remarks: remarks,
          );
          try {
            await widget.apiService.createLog(item);
            dutyStaffName = staff;
            final preferences = await SharedPreferences.getInstance();
            await preferences.setString('duty_staff_name', staff);
            await _refreshLogs();
          } catch (error, stackTrace) {
            _reportApiError(error, stackTrace);
            rethrow;
          }
        },
      ),
    );
  }

  void _openReturnDialog(KeyIssuanceItem item) {
    int pending = item.qtyIssued - item.qtyReturned;
    int returnQty = pending;
    final activeRoster = staffRoster.where((staff) => staff.isActive).toList();
    String? receiver = activeRoster.any((staff) => staff.name == dutyStaffName)
        ? dutyStaffName
        : null;
    String notes = "";
    var isSubmitting = false;
    final receiverFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Mark Key as Returned',
              style: TextStyle(
                  color: RamadaColors.success, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Room / Access: ${item.roomOrAccess}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Pending Return: $pending pcs',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Qty Returning:'),
                    Row(
                      children: [
                        IconButton(
                          onPressed: returnQty > 1
                              ? () => setDialogState(() => returnQty--)
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        Text('$returnQty',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        IconButton(
                          onPressed: returnQty < pending
                              ? () => setDialogState(() => returnQty++)
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                ),
                Form(
                  key: receiverFormKey,
                  child: DropdownButtonFormField<String>(
                    key: const ValueKey('return:staff-name'),
                    initialValue: receiver,
                    decoration: const InputDecoration(
                      labelText: 'Key Received By *',
                    ),
                    items: activeRoster
                        .map(
                          (staff) => DropdownMenuItem(
                            value: staff.name,
                            child: Text('${staff.name} (${staff.hours})'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => receiver = value),
                    validator: (value) =>
                        value == null ? 'Select a staff member.' : null,
                  ),
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Return Notes'),
                  onChanged: (v) => notes = v,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: RamadaColors.success),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!receiverFormKey.currentState!.validate()) return;
                      final selectedReceiver = receiver;
                      if (selectedReceiver == null) return;
                      final updatedItem = KeyIssuanceItem.fromMap(item.toMap())
                        ..qtyReturned = item.qtyReturned + returnQty
                        ..returnedDateTime = DateFormat('dd-MMM-yyyy hh:mm a')
                            .format(DateTime.now())
                        ..keyReceivedBy = selectedReceiver
                        ..remarks = notes.isEmpty
                            ? item.remarks
                            : "${item.remarks} | $notes";
                      setDialogState(() => isSubmitting = true);
                      try {
                        await widget.apiService.updateLog(updatedItem);
                        dutyStaffName = selectedReceiver;
                        final preferences =
                            await SharedPreferences.getInstance();
                        await preferences.setString(
                            'duty_staff_name', dutyStaffName);
                        await _refreshLogs();
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (error, stackTrace) {
                        _reportApiError(error, stackTrace);
                      } finally {
                        if (ctx.mounted) {
                          setDialogState(() => isSubmitting = false);
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm Return',
                      style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteLog(KeyIssuanceItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          widget.session.user.isAdmin
              ? 'Delete key log?'
              : 'Delete key log with audit record?',
        ),
        content: Text(
          widget.session.user.isAdmin
              ? 'Delete the entry for ${item.roomOrAccess}? This cannot be undone.'
              : 'Delete the entry for ${item.roomOrAccess}? The before-image and your account will be recorded in the audit log.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: RamadaColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      if (widget.session.user.isAdmin) {
        await widget.apiService.adminDeleteLog(
          item.id,
          accessToken: widget.session.accessToken,
        );
      } else {
        await widget.apiService.deleteLog(
          item.id,
          accessToken: widget.session.accessToken,
        );
      }
      await _refreshLogs();
    } catch (error, stackTrace) {
      _reportApiError(error, stackTrace);
    }
  }

  Future<void> _openEditDialog(KeyIssuanceItem item) async {
    final isAdmin = widget.session.user.isAdmin;
    final updatedItem = await showDialog<KeyIssuanceItem>(
      context: context,
      builder: (dialogContext) => isAdmin
          ? AdminEditDialog(item: item)
          : StaffCorrectionDialog(item: item),
    );
    if (updatedItem == null) return;
    try {
      if (isAdmin) {
        await widget.apiService.adminUpdateLog(
          updatedItem,
          accessToken: widget.session.accessToken,
        );
      } else {
        await widget.apiService.correctLog(
          updatedItem,
          accessToken: widget.session.accessToken,
        );
      }
      await _refreshLogs();
    } catch (error, stackTrace) {
      _reportApiError(error, stackTrace);
    }
  }

  void _openPasswordResetRequests() {
    if (!widget.session.user.isAdmin) return;
    showDialog<void>(
      context: context,
      builder: (context) => AdminPasswordResetRequestsDialog(
        apiService: widget.apiService,
        accessToken: widget.session.accessToken,
      ),
    );
  }

  Future<void> _openChangePasswordDialog() async {
    if (!widget.session.user.isAdmin) return;
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => AdminChangePasswordDialog(
        apiService: widget.apiService,
        accessToken: widget.session.accessToken,
      ),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your password has been updated.')),
      );
    }
  }

  void _openExportDialog() {
    final sb = StringBuffer();
    sb.writeln("RAMADA BY WYNDHAM DOHA OLD TOWN - KEY LOG");
    sb.writeln("Date: $selectedDate | Shift: $selectedShift");
    sb.writeln(
        "Inventory: Total=$totalInventory, Issued=$handoverToGuest, Returned=$returnFromGuest, Missing=$missingKeys, At FD=$remainingInFd");
    sb.writeln("-" * 40);
    for (var it in filteredList) {
      sb.writeln(
          "${it.sNo}. ${it.roomOrAccess} | Issued: ${it.qtyIssued} | Ret: ${it.qtyReturned} | Status: ${it.isMissing ? 'MISSING' : (it.isFullyReturned ? 'RETURNED' : 'PENDING')} | Staff: ${it.issuingStaff}");
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export & Backup Log'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 200,
                padding: const EdgeInsets.all(8),
                color: Colors.grey.withOpacity(0.1),
                child: SingleChildScrollView(
                  child: Text(sb.toString(),
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12)),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      final content = sb.toString();
                      Clipboard.setData(ClipboardData(text: content));
                      downloadTextFile(
                        content,
                        'key-log-$selectedDate.txt',
                        'text/plain;charset=utf-8',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Text log downloaded and copied.')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Text'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      final jsonStr =
                          jsonEncode(issuances.map((e) => e.toMap()).toList());
                      Clipboard.setData(ClipboardData(text: jsonStr));
                      downloadTextFile(
                        jsonStr,
                        'key-log-$selectedDate.json',
                        'application/json;charset=utf-8',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('JSON backup downloaded and copied.')),
                      );
                    },
                    icon: const Icon(Icons.data_object),
                    label: const Text('JSON'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      final csv = KeyLogExport.toCsv(filteredList);
                      Clipboard.setData(ClipboardData(text: csv));
                      downloadTextFile(
                        csv,
                        'key-log-$selectedDate.csv',
                        'text/csv;charset=utf-8',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('CSV downloaded and copied.')),
                      );
                    },
                    icon: const Icon(Icons.table_chart),
                    label: const Text('CSV'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _navigateToDashboardSection(int section) {
    setState(() => _selectedDashboardSection = section);
    final targetContext =
        (section == 0 ? _overviewSectionKey : _logsSectionKey).currentContext;
    if (targetContext != null) {
      unawaited(
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 220),
          alignment: 0.06,
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  Widget _buildOperationsRail({required bool extended}) => Container(
        width: extended ? 232 : 76,
        decoration: const BoxDecoration(
          color: RamadaColors.charcoalSurface,
          border: Border(
            right: BorderSide(color: RamadaColors.charcoalBorder),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  extended ? 18 : 10,
                  20,
                  extended ? 18 : 10,
                  20,
                ),
                child: Row(
                  mainAxisAlignment: extended
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            RamadaColors.burgundy,
                            RamadaColors.burgundyDark,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: RamadaColors.gold.withValues(alpha: 0.55),
                        ),
                      ),
                      child: const Icon(
                        Icons.vpn_key_rounded,
                        color: RamadaColors.goldLight,
                        size: 20,
                      ),
                    ),
                    if (extended) ...[
                      const SizedBox(width: 11),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RAMADA',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'KEY OPERATIONS',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: RamadaColors.charcoalMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (extended)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 16, 10),
                  child: Row(
                    children: [
                      Text(
                        'WORKSPACE',
                        style: TextStyle(
                          color: RamadaColors.charcoalMuted.withValues(
                            alpha: 0.72,
                          ),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.15,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(child: Divider(height: 1)),
                    ],
                  ),
                ),
              Expanded(
                child: NavigationRail(
                  backgroundColor: Colors.transparent,
                  extended: extended,
                  minWidth: 76,
                  minExtendedWidth: 232,
                  groupAlignment: -1,
                  labelType: extended
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  selectedIndex: _selectedDashboardSection,
                  onDestinationSelected: _navigateToDashboardSection,
                  indicatorColor: RamadaColors.burgundy.withValues(alpha: 0.35),
                  selectedIconTheme: const IconThemeData(
                    color: RamadaColors.goldLight,
                    size: 20,
                  ),
                  unselectedIconTheme: const IconThemeData(
                    color: RamadaColors.charcoalMuted,
                    size: 19,
                  ),
                  indicatorShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  selectedLabelTextStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelTextStyle: const TextStyle(
                    color: RamadaColors.charcoalMuted,
                    fontSize: 11,
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.space_dashboard_outlined),
                      selectedIcon: Icon(Icons.space_dashboard_rounded),
                      label: Text('Overview'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.vpn_key_outlined),
                      selectedIcon: Icon(Icons.vpn_key_rounded),
                      label: Text('Key log'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  extended ? 14 : 8,
                  10,
                  extended ? 14 : 8,
                  14,
                ),
                child: extended
                    ? Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: RamadaColors.charcoalRaised,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: RamadaColors.charcoalBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 17,
                              backgroundColor:
                                  RamadaColors.burgundy.withValues(alpha: 0.32),
                              child: Text(
                                widget.session.user.displayName.isEmpty
                                    ? '?'
                                    : widget.session.user.displayName[0]
                                        .toUpperCase(),
                                style: const TextStyle(
                                  color: RamadaColors.goldLight,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.session.user.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    widget.session.user.roleLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: RamadaColors.charcoalMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : Tooltip(
                        message: widget.session.user.displayName,
                        child: const Icon(
                          Icons.account_circle_outlined,
                          color: RamadaColors.charcoalMuted,
                        ),
                      ),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const RamadaLoadingView(message: 'Loading key log...');
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Container(
          decoration: BoxDecoration(
            color:
                isDark ? RamadaColors.charcoalSurface : RamadaColors.burgundy,
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? RamadaColors.charcoalBorder
                    : RamadaColors.burgundyLight,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 1000;
                  return Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color:
                                    RamadaColors.gold.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                  color:
                                      RamadaColors.gold.withValues(alpha: 0.2),
                                ),
                              ),
                              child: const Icon(
                                Icons.vpn_key_rounded,
                                color: RamadaColors.goldLight,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'RAMADA BY WYNDHAM',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.6,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    compact
                                        ? '${widget.session.user.displayName} • ${widget.session.user.roleLabel}'
                                        : 'DOHA OLD TOWN • KEY CARD & ACCESS LOG',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: RamadaColors.goldLight,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!compact)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                widget.session.user.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                widget.session.user.roleLabel,
                                style: const TextStyle(
                                  color: RamadaColors.goldLight,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      IconButton(
                        tooltip: 'Logout',
                        onPressed: () => widget.onLogout(),
                        icon: const Icon(Icons.logout, color: Colors.white),
                      ),
                      IconButton(
                        tooltip: widget.session.user.isAdmin
                            ? 'Manage staff roster'
                            : 'View staff roster',
                        onPressed: _openManageStaffRoster,
                        icon: const Icon(
                          Icons.groups_outlined,
                          color: RamadaColors.goldLight,
                        ),
                      ),
                      if (widget.session.user.isAdmin)
                        IconButton(
                          tooltip: 'Change password',
                          onPressed: _openChangePasswordDialog,
                          icon: const Icon(
                            Icons.key_rounded,
                            color: RamadaColors.goldLight,
                          ),
                        ),
                      if (widget.session.user.isAdmin)
                        IconButton(
                          tooltip: 'Password reset requests',
                          onPressed: _openPasswordResetRequests,
                          icon: const Icon(
                            Icons.password_outlined,
                            color: RamadaColors.goldLight,
                          ),
                        ),
                      const SizedBox(width: 4),
                      if (compact)
                        IconButton(
                          tooltip: 'Export / Share',
                          onPressed: _openExportDialog,
                          icon:
                              const Icon(Icons.ios_share, color: Colors.white),
                        )
                      else
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RamadaColors.gold,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: _openExportDialog,
                          icon: const Icon(Icons.ios_share, size: 16),
                          label: const Text(
                            'Export / Share',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      IconButton(
                        tooltip: widget.isDark ? 'Light theme' : 'Dark theme',
                        onPressed: widget.onToggleTheme,
                        icon: Icon(
                          widget.isDark ? Icons.light_mode : Icons.dark_mode,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
      body: Row(
        children: [
          if (MediaQuery.sizeOf(context).width >= 1080)
            _buildOperationsRail(
              extended: MediaQuery.sizeOf(context).width >= 1320,
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                MediaQuery.sizeOf(context).width < 700 ? 12 : 26,
                MediaQuery.sizeOf(context).width < 700 ? 12 : 26,
                MediaQuery.sizeOf(context).width < 700 ? 12 : 26,
                160,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Operations overview',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : RamadaColors.charcoalDark,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Front desk key inventory and shift activity',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? RamadaColors.charcoalMuted
                                      : const Color(0xFF526174),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? RamadaColors.charcoalSurface
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? RamadaColors.charcoalBorder
                                  : const Color(0xFFD8DEE8),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: isDark
                                    ? RamadaColors.goldLight
                                    : RamadaColors.burgundy,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('EEE, d MMM').format(DateTime.now()),
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : RamadaColors.charcoalDark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_storageError != null || _inventorySyncError != null)
                    MaterialBanner(
                      content: Text(_storageError ?? _inventorySyncError!),
                      leading: const Icon(Icons.warning_amber),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            try {
                              await _refreshLogs();
                              await _refreshSharedInventory();
                            } catch (error, stackTrace) {
                              _reportApiError(error, stackTrace);
                            }
                          },
                          child: const Text('Retry Connection'),
                        ),
                      ],
                    ),
                  // Metrics Dashboard Box
                  KeyedSubtree(
                    key: _overviewSectionKey,
                    child: _buildInventoryMetricsBox(),
                  ),
                  const SizedBox(height: 16),
                  StaffPerformanceChart(metrics: _staffPerformanceMetrics),
                  const SizedBox(height: 16),

                  // Shift Engine Banner
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? RamadaColors.charcoalSurface
                          : RamadaColors.goldContainer,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: isDark
                            ? RamadaColors.charcoalBorder
                            : RamadaColors.gold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.sync,
                          color: isDark
                              ? RamadaColors.goldLight
                              : RamadaColors.burgundy,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Shift automation',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : RamadaColors.burgundyDark,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Unreturned keys carry forward at shift handover.',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? RamadaColors.charcoalMuted
                                      : Colors.blueGrey,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            backgroundColor: RamadaColors.burgundy.withValues(
                              alpha: isDark ? 0.25 : 0.1,
                            ),
                            foregroundColor: isDark
                                ? RamadaColors.goldLight
                                : RamadaColors.burgundy,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: _triggerAutoCarryForward,
                          child: const Text('Sync'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  KeyedSubtree(
                    key: _logsSectionKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 4,
                            bottom: 14,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Key log',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : RamadaColors.charcoalDark,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Search and manage issued key cards',
                                      style: TextStyle(
                                        color: isDark
                                            ? RamadaColors.charcoalMuted
                                            : const Color(0xFF526174),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? RamadaColors.charcoalRaised
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark
                                        ? RamadaColors.charcoalBorder
                                        : const Color(0xFFD8DEE8),
                                  ),
                                ),
                                child: Text(
                                  '${filteredList.length} entries',
                                  style: TextStyle(
                                    color: isDark
                                        ? RamadaColors.charcoalMuted
                                        : const Color(0xFF526174),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Filters & Search
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final searchField = TextField(
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark
                                    ? RamadaColors.charcoalRaised
                                    : Colors.white,
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: isDark
                                      ? RamadaColors.charcoalMuted
                                      : const Color(0xFF526174),
                                ),
                                hintText: 'Search room, guest or staff',
                                hintStyle: TextStyle(
                                  color: isDark
                                      ? RamadaColors.charcoalMuted
                                      : const Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(11),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? RamadaColors.charcoalBorder
                                        : RamadaColors.burgundy
                                            .withValues(alpha: 0.18),
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                              onChanged: (v) => setState(() => searchQuery = v),
                            );
                            final shiftSelector = SizedBox(
                              width: constraints.maxWidth < 680
                                  ? double.infinity
                                  : 270,
                              child: Tooltip(
                                message: 'Select your duty shift',
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Duty Shift',
                                    labelStyle: TextStyle(
                                      color: isDark
                                          ? RamadaColors.charcoalMuted
                                          : const Color(0xFF526174),
                                      fontSize: 11,
                                    ),
                                    filled: true,
                                    fillColor: isDark
                                        ? RamadaColors.charcoalRaised
                                        : Colors.white,
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(11),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? RamadaColors.charcoalBorder
                                            : const Color(0xFFD8DEE8),
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(11),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? RamadaColors.charcoalBorder
                                            : RamadaColors.burgundy
                                                .withValues(alpha: 0.18),
                                      ),
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      key: const ValueKey(
                                          'dashboard:duty-shift'),
                                      value: selectedShift,
                                      isExpanded: true,
                                      items: shifts
                                          .where((shift) =>
                                              widget.session.user.isAdmin ||
                                              shift != 'All Shifts')
                                          .map((s) => DropdownMenuItem(
                                              value: s, child: Text(s)))
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          unawaited(_selectShift(value));
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );
                            if (constraints.maxWidth < 680) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  searchField,
                                  const SizedBox(height: 12),
                                  shiftSelector,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: searchField),
                                const SizedBox(width: 12),
                                shiftSelector,
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        // Table of records
                        _buildIssuanceTable(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 1080
          ? NavigationBar(
              height: 64,
              backgroundColor: RamadaColors.charcoalSurface,
              indicatorColor: RamadaColors.burgundy.withValues(alpha: 0.35),
              selectedIndex: _selectedDashboardSection,
              onDestinationSelected: _navigateToDashboardSection,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  selectedIcon: Icon(Icons.space_dashboard_rounded),
                  label: 'Overview',
                ),
                NavigationDestination(
                  icon: Icon(Icons.vpn_key_outlined),
                  selectedIcon: Icon(Icons.vpn_key_rounded),
                  label: 'Key log',
                ),
              ],
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: RamadaColors.gold,
        foregroundColor: RamadaColors.charcoalDark,
        elevation: 1,
        hoverElevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onPressed: _openAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Issue Key Card',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildInventoryMetricsBox() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final healthyColor =
        isDark ? const Color(0xFF7BE0A6) : RamadaColors.successText;
    final criticalColor =
        isDark ? const Color(0xFFFF9A9A) : RamadaColors.dangerText;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? RamadaColors.charcoalBorder
              : RamadaColors.burgundy.withValues(alpha: 0.12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'KEY INVENTORY',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark
                          ? RamadaColors.charcoalMuted
                          : const Color(0xFF475569),
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 1.15,
                    ),
                  ),
                ),
                if (widget.session.user.isAdmin)
                  IconButton(
                    tooltip: 'Manage key stock',
                    onPressed: _openInventoryLimitDialog,
                    icon: const Icon(
                      Icons.add_box_outlined,
                      color: RamadaColors.gold,
                    ),
                  ),
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: remainingInFd >= 20
                        ? (isDark
                            ? const Color(0xFF173E2C)
                            : RamadaColors.successBg)
                        : (isDark
                            ? const Color(0xFF4A2528)
                            : RamadaColors.dangerBg),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: remainingInFd >= 20
                          ? healthyColor.withValues(alpha: 0.28)
                          : criticalColor.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    remainingInFd >= 20 ? 'Stock Healthy' : 'Stock Critical',
                    style: TextStyle(
                      color: remainingInFd >= 20 ? healthyColor : criticalColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1120
                    ? 5
                    : constraints.maxWidth >= 740
                        ? 3
                        : constraints.maxWidth >= 440
                            ? 2
                            : 1;
                const spacing = 10.0;
                final width =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                final tiles = <Widget Function(double)>[
                  (width) => _buildMetricTile(
                        'Total Keys',
                        '$totalInventory Pcs',
                        Icons.inventory_2_outlined,
                        const Color(0xFFD57972),
                        const Color(0xFF302426),
                        width: width,
                        onTap: () => _openMetricSummary('Total Keys'),
                      ),
                  (width) => _buildMetricTile(
                        'Handover Issued',
                        '$handoverToGuest Keys',
                        Icons.north_east_rounded,
                        const Color(0xFF6FB0D2),
                        const Color(0xFF202C34),
                        width: width,
                        onTap: () => _openMetricSummary('Handover Issued'),
                      ),
                  (width) => _buildMetricTile(
                        'Return from Guest',
                        '$returnFromGuest Returned',
                        Icons.keyboard_return_rounded,
                        const Color(0xFF6DC69A),
                        const Color(0xFF202E29),
                        width: width,
                        onTap: () => _openMetricSummary('Return from Guest'),
                      ),
                  (width) => _buildMetricTile(
                        'Missing',
                        '$missingKeys Pcs',
                        Icons.warning_amber_rounded,
                        const Color(0xFFE58179),
                        const Color(0xFF322523),
                        width: width,
                        onTap: () => _openMetricSummary('Missing Keys'),
                      ),
                  (width) => _buildMetricTile(
                        'Available at Desk',
                        '$remainingInFd Available',
                        Icons.desk_outlined,
                        RamadaColors.goldLight,
                        const Color(0xFF302C22),
                        isHighlighted: true,
                        width: width,
                        onTap: () => _openMetricSummary('Remaining in FD'),
                      ),
                ];
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [for (final tile in tiles) tile(width)],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
      String title, String val, IconData icon, Color color, Color bg,
      {bool isHighlighted = false, double width = 170, VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileColor =
        isDark ? color : Color.lerp(color, RamadaColors.charcoalDark, 0.42)!;
    final tileBackground = isDark ? bg : Color.lerp(bg, Colors.white, 0.72)!;
    return SizedBox(
      width: width,
      height: 116,
      child: Material(
        color: tileBackground,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: isHighlighted
                    ? RamadaColors.gold.withValues(alpha: 0.42)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.055)
                        : color.withValues(alpha: 0.14)),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark
                              ? RamadaColors.charcoalMuted
                              : const Color(0xFF475569),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: tileColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(icon, color: tileColor, size: 17),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  val,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : RamadaColors.charcoalDark,
                    fontSize: 22,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'View details  ›',
                  style: TextStyle(
                    color: isHighlighted
                        ? (isDark
                            ? RamadaColors.goldLight
                            : RamadaColors.burgundy)
                        : (isDark
                            ? RamadaColors.charcoalMuted
                            : const Color(0xFF526174)),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<KeyIssuanceItem> get _metricScopeEntries => issuances.where((item) {
        final matchesDate =
            selectedDate == 'ALL' || item.shiftDate == selectedDate;
        final matchesShift =
            selectedShift == 'All Shifts' || item.shiftPeriod == selectedShift;
        return matchesDate && matchesShift;
      }).toList();

  void _openMetricSummary(String title) {
    final scopedEntries = _metricScopeEntries;
    final matchingEntries = switch (title) {
      'Handover Issued' => scopedEntries.where((item) {
          return item.remainingUnreturnedQty - item.missingQuantity > 0;
        }).toList(),
      'Return from Guest' =>
        scopedEntries.where((item) => item.qtyReturned > 0).toList(),
      'Missing Keys' =>
        scopedEntries.where((item) => item.missingQuantity > 0).toList(),
      _ => scopedEntries,
    };
    final metricCount = switch (title) {
      'Total Keys' => totalInventory,
      'Handover Issued' => handoverToGuest,
      'Return from Guest' => returnFromGuest,
      'Missing Keys' => missingKeys,
      'Remaining in FD' => remainingInFd,
      _ => 0,
    };
    final unit = switch (title) {
      'Total Keys' || 'Missing Keys' => 'pcs',
      'Handover Issued' => 'keys currently with guests',
      'Return from Guest' => 'keys returned',
      'Remaining in FD' => 'keys available at the front desk',
      _ => 'items',
    };
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$metricCount $unit'),
                const SizedBox(height: 6),
                Text(
                  'Scope: ${selectedDate == 'ALL' ? 'All dates' : selectedDate} • $selectedShift',
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
                const Divider(height: 24),
                if (matchingEntries.isEmpty)
                  const Text('No key log records in this summary.')
                else
                  for (final item in matchingEntries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.roomOrAccess),
                      subtitle: Text(
                        '${item.guestOrHolderName.isEmpty ? item.issuingStaff : item.guestOrHolderName} • Issued ${item.qtyIssued}, returned ${item.qtyReturned}${item.missingQuantity > 0 ? ' • Missing ${item.missingQuantity}' : ''}',
                      ),
                    ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildIssuanceTable() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark
              ? RamadaColors.charcoalBorder
              : RamadaColors.burgundy.withValues(alpha: 0.12),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1080;
          final horizontalMargin = compact ? 6.0 : 8.0;
          final columnSpacing = compact ? 4.0 : 7.0;
          final availableColumnWidth = (constraints.maxWidth -
                  horizontalMargin * 2 -
                  columnSpacing * 10 -
                  24)
              .clamp(0.0, double.infinity);
          const columnWeights = [
            0.040,
            0.098,
            0.078,
            0.088,
            0.053,
            0.053,
            0.103,
            0.098,
            0.088,
            0.107,
            0.194,
          ];
          final columnWidths = columnWeights
              .map((weight) => availableColumnWidth * weight)
              .toList(growable: false);

          Widget heading(int column, String label) => SizedBox(
                width: columnWidths[column],
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );

          Widget cellText(
            int column,
            String value, {
            TextStyle? style,
            int maxLines = 2,
          }) =>
              SizedBox(
                width: columnWidths[column],
                child: Text(
                  value,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: style,
                ),
              );

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: compact ? 52 : 48,
              dataRowMinHeight: compact ? 56 : 52,
              dataRowMaxHeight: compact ? 76 : 64,
              horizontalMargin: horizontalMargin,
              columnSpacing: columnSpacing,
              dividerThickness: 0.6,
              dataRowColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.hovered)
                      ? (isDark
                          ? RamadaColors.charcoalRaised.withValues(alpha: 0.72)
                          : RamadaColors.goldContainer)
                      : null),
              headingRowColor: WidgetStateProperty.all(
                isDark
                    ? RamadaColors.charcoalRaised
                    : RamadaColors.burgundy.withValues(alpha: 0.08),
              ),
              columns: [
                DataColumn(label: heading(0, 'S.No')),
                DataColumn(label: heading(1, 'Issued Time')),
                DataColumn(label: heading(2, 'Staff')),
                DataColumn(label: heading(3, 'Room / Access')),
                DataColumn(label: heading(4, 'Qty Issue')),
                DataColumn(label: heading(5, 'Qty Ret')),
                DataColumn(label: heading(6, 'Status')),
                DataColumn(label: heading(7, 'Returned Time')),
                DataColumn(label: heading(8, 'Key Received By')),
                DataColumn(label: heading(9, 'Remarks')),
                DataColumn(label: heading(10, 'Actions')),
              ],
              rows: filteredList.asMap().entries.map((entry) {
                final item = entry.value;
                final rowNumber = entry.key + 1;
                final hasScheduledCheckout =
                    item.isPending && item.checkOutDate != null;
                final parsedCheckoutDate = item.checkOutDate == null
                    ? null
                    : DateTime.tryParse(item.checkOutDate!);
                final checkoutLabel = parsedCheckoutDate == null
                    ? item.checkOutDate
                    : DateFormat('d MMM yyyy').format(parsedCheckoutDate);
                final statusColor = item.isMissing
                    ? (isDark
                        ? const Color(0xFFFF9A9A)
                        : RamadaColors.dangerText)
                    : (item.isFullyReturned
                        ? (isDark
                            ? const Color(0xFF7BE0A6)
                            : RamadaColors.successText)
                        : (isDark
                            ? const Color(0xFFFFD180)
                            : RamadaColors.warningText));
                final statusBackground = item.isMissing
                    ? (isDark ? const Color(0xFF4A2528) : RamadaColors.dangerBg)
                    : (item.isFullyReturned
                        ? (isDark
                            ? const Color(0xFF173E2C)
                            : RamadaColors.successBg)
                        : (isDark
                            ? const Color(0xFF4A3518)
                            : RamadaColors.warningBg));

                return DataRow(
                  cells: [
                    DataCell(Text('$rowNumber')),
                    DataCell(cellText(1, item.issuedDateTime)),
                    DataCell(cellText(2, item.issuingStaff)),
                    DataCell(
                      cellText(
                        3,
                        item.roomOrAccess,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? RamadaColors.goldLight
                              : RamadaColors.burgundy,
                        ),
                      ),
                    ),
                    DataCell(cellText(4, '${item.qtyIssued} pcs', maxLines: 1)),
                    DataCell(
                        cellText(5, '${item.qtyReturned} pcs', maxLines: 1)),
                    DataCell(
                      SizedBox(
                        width: columnWidths[6],
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusBackground,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.isMissing
                                    ? 'MISSING'
                                    : (item.isFullyReturned
                                        ? 'RETURNED'
                                        : 'PENDING'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                              if (hasScheduledCheckout)
                                Text(
                                  'Check-out $checkoutLabel',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: statusColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    DataCell(cellText(7, item.returnedDateTime ?? '—')),
                    DataCell(cellText(8, item.keyReceivedBy ?? '—')),
                    DataCell(
                        cellText(9, item.remarks.isEmpty ? '—' : item.remarks)),
                    DataCell(
                      SizedBox(
                        width: columnWidths[10],
                        child: Wrap(
                          spacing: compact ? 0 : 2,
                          alignment: WrapAlignment.start,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            IconButton(
                              tooltip: widget.session.user.isAdmin
                                  ? 'Edit log'
                                  : 'Correct log (audited)',
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                  width: 34, height: 34),
                              padding: EdgeInsets.zero,
                              onPressed: () => _openEditDialog(item),
                            ),
                            if (item.isPending)
                              compact
                                  ? IconButton(
                                      tooltip: 'Return key',
                                      icon: const Icon(
                                        Icons.keyboard_return_rounded,
                                        size: 18,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                              width: 34, height: 34),
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _openReturnDialog(item),
                                    )
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDark
                                            ? RamadaColors.success
                                            : RamadaColors.successText,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                      ),
                                      onPressed: () => _openReturnDialog(item),
                                      child: const Text(
                                        'Return',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                            IconButton(
                              tooltip: widget.session.user.isAdmin
                                  ? 'Delete log'
                                  : 'Delete log (audited)',
                              icon: const Icon(Icons.delete_outline, size: 18),
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                  width: 34, height: 34),
                              padding: EdgeInsets.zero,
                              onPressed: () => _confirmDeleteLog(item),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

class AddIssuanceDialog extends StatefulWidget {
  final Future<void> Function(
    String room,
    String guest,
    int qty,
    String cat,
    String remarks,
    String staff,
    String? checkOutDate,
  ) onAdd;
  final String initialStaffName;
  final int availableQuantity;
  final List<StaffRosterMember> staffRoster;

  const AddIssuanceDialog({
    super.key,
    required this.onAdd,
    required this.initialStaffName,
    required this.availableQuantity,
    required this.staffRoster,
  });

  @override
  State<AddIssuanceDialog> createState() => _AddIssuanceDialogState();
}

class AdminChangePasswordDialog extends StatefulWidget {
  final ApiService apiService;
  final String accessToken;

  const AdminChangePasswordDialog({
    super.key,
    required this.apiService,
    required this.accessToken,
  });

  @override
  State<AdminChangePasswordDialog> createState() =>
      _AdminChangePasswordDialogState();
}

class AdminInventoryLimitDialog extends StatefulWidget {
  final int currentInventory;
  final int minimumInventory;

  const AdminInventoryLimitDialog({
    super.key,
    required this.currentInventory,
    required this.minimumInventory,
  });

  @override
  State<AdminInventoryLimitDialog> createState() =>
      _AdminInventoryLimitDialogState();
}

class AdminStaffRosterDialog extends StatefulWidget {
  final ApiService apiService;
  final String accessToken;
  final bool readOnly;

  const AdminStaffRosterDialog({
    super.key,
    required this.apiService,
    required this.accessToken,
    this.readOnly = false,
  });

  @override
  State<AdminStaffRosterDialog> createState() => _AdminStaffRosterDialogState();
}

class _AdminStaffRosterDialogState extends State<AdminStaffRosterDialog> {
  final _nameController = TextEditingController();
  final _hoursController = TextEditingController();
  List<StaffRosterMember> _members = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _loadRoster() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final members = await widget.apiService.getStaffRoster(
        token: widget.accessToken,
        includeInactive: !widget.readOnly,
      );
      if (mounted) setState(() => _members = members);
    } catch (error, stackTrace) {
      debugPrint('Failed to load staff roster: $error\n$stackTrace');
      if (mounted) {
        setState(() => _errorMessage = _staffErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _staffErrorMessage(Object error) => error is ApiException
      ? error.message
      : 'Staff roster could not be saved. Check the server and try again.';

  Future<void> _addMember() async {
    final name = _nameController.text.trim();
    final hours = _hoursController.text.trim();
    if (name.isEmpty || hours.isEmpty) {
      setState(() => _errorMessage = 'Enter a staff name and shift hours.');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final member = await widget.apiService.addStaffRosterMember(
        name: name,
        hours: hours,
        token: widget.accessToken,
      );
      if (!mounted) return;
      setState(() {
        _members = [
          ..._members,
          member
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _nameController.clear();
        _hoursController.clear();
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to add staff member: $error\n$stackTrace');
      if (mounted) setState(() => _errorMessage = _staffErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _editMember(StaffRosterMember member) async {
    final nameController = TextEditingController(text: member.name);
    final hoursController = TextEditingController(text: member.hours);
    try {
      final values = await showDialog<(String, String)>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Edit ${member.name}'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Staff name'),
                ),
                TextField(
                  controller: hoursController,
                  decoration: const InputDecoration(
                    labelText: 'Shift hours',
                    hintText: '08:00 - 17:00',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                (nameController.text.trim(), hoursController.text.trim()),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (values == null || values.$1.isEmpty || values.$2.isEmpty) return;
      final updated = await widget.apiService.updateStaffRosterMember(
        member: member,
        name: values.$1,
        hours: values.$2,
        isActive: member.isActive,
        token: widget.accessToken,
      );
      if (mounted) {
        setState(() {
          _members = _members
              .map((current) => current.id == updated.id ? updated : current)
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to edit staff member: $error\n$stackTrace');
      if (mounted) setState(() => _errorMessage = _staffErrorMessage(error));
    } finally {
      nameController.dispose();
      hoursController.dispose();
    }
  }

  Future<void> _setMemberActive(
    StaffRosterMember member,
    bool isActive,
  ) async {
    try {
      final updated = await widget.apiService.updateStaffRosterMember(
        member: member,
        name: member.name,
        hours: member.hours,
        isActive: isActive,
        token: widget.accessToken,
      );
      if (mounted) {
        setState(() {
          _members = _members
              .map((current) => current.id == updated.id ? updated : current)
              .toList();
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to update staff status: $error\n$stackTrace');
      if (mounted) setState(() => _errorMessage = _staffErrorMessage(error));
    }
  }

  Future<void> _removeMember(StaffRosterMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove staff member?'),
        content: Text(
          'Remove ${member.name} from the active staff roster? Historical key logs will remain unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.apiService.deleteStaffRosterMember(
        staffId: member.id,
        token: widget.accessToken,
      );
      if (mounted) {
        setState(() => _members.removeWhere((item) => item.id == member.id));
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to remove staff member: $error\n$stackTrace');
      if (mounted) setState(() => _errorMessage = _staffErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.readOnly ? 'Staff Roster' : 'Manage Staff Roster'),
        content: SizedBox(
          width: 520,
          child: _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.readOnly) ...[
                      TextField(
                        key: const ValueKey('roster:add-name'),
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'New staff name',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const ValueKey('roster:add-hours'),
                              controller: _hoursController,
                              decoration: const InputDecoration(
                                labelText: 'Shift hours',
                                hintText: '08:00 - 17:00',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _isSaving ? null : _addMember,
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                    ],
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: RamadaColors.danger),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: _members.isEmpty
                          ? const Center(child: Text('No roster members yet.'))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: _members.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final member = _members[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(member.name),
                                  subtitle: Text(
                                    '${member.hours} · ${member.isActive ? 'Active' : 'Inactive'}',
                                  ),
                                  leading: widget.readOnly
                                      ? Icon(
                                          member.isActive
                                              ? Icons.check_circle_outline
                                              : Icons.pause_circle_outline,
                                          color: member.isActive
                                              ? RamadaColors.success
                                              : Colors.blueGrey,
                                        )
                                      : Switch(
                                          value: member.isActive,
                                          onChanged: (value) =>
                                              _setMemberActive(member, value),
                                        ),
                                  trailing: widget.readOnly
                                      ? null
                                      : Wrap(
                                          children: [
                                            IconButton(
                                              tooltip: 'Edit staff member',
                                              onPressed: () =>
                                                  _editMember(member),
                                              icon: const Icon(
                                                  Icons.edit_outlined),
                                            ),
                                            IconButton(
                                              tooltip: 'Remove staff member',
                                              onPressed: () =>
                                                  _removeMember(member),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: RamadaColors.danger,
                                              ),
                                            ),
                                          ],
                                        ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _loadRoster,
            child: const Text('Refresh'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
}

class _AdminInventoryLimitDialogState extends State<AdminInventoryLimitDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _inventoryController;

  @override
  void initState() {
    super.initState();
    _inventoryController = TextEditingController(
      text: widget.currentInventory.toString(),
    );
  }

  @override
  void dispose() {
    _inventoryController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, int.parse(_inventoryController.text));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Manage key stock'),
        content: SizedBox(
          width: 360,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Only Admin can update the hotel key inventory. At least ${widget.minimumInventory} keys are currently checked out.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('inventory-limit-field'),
                  controller: _inventoryController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(7),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Total key stock',
                    suffixText: 'keys',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final inventory = int.tryParse(value ?? '');
                    if (inventory == null) {
                      return 'Enter a valid whole number.';
                    }
                    if (inventory < widget.minimumInventory) {
                      return 'At least ${widget.minimumInventory} keys are checked out.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _save(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _save,
            child: const Text('Save stock limit'),
          ),
        ],
      );
}

class _AdminChangePasswordDialogState extends State<AdminChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await widget.apiService.changeOwnPassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
        token: widget.accessToken,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('Failed to change admin password: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = error is ApiException
            ? error.message
            : 'Could not update your password. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Change your password'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    key: const ValueKey('change-password:current'),
                    controller: _currentPasswordController,
                    obscureText: true,
                    enabled: !_isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'Current password',
                    ),
                    validator: (value) => (value ?? '').isEmpty
                        ? 'Enter your current password.'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const ValueKey('change-password:new'),
                    controller: _newPasswordController,
                    obscureText: true,
                    enabled: !_isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                      helperText: 'Use 8 to 128 characters.',
                    ),
                    validator: (value) {
                      final password = value ?? '';
                      if (password.length < 8) {
                        return 'Use at least 8 characters.';
                      }
                      if (password.length > 128) {
                        return 'Password must be 128 characters or fewer.';
                      }
                      if (password == _currentPasswordController.text) {
                        return 'Choose a password different from the current one.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const ValueKey('change-password:confirm'),
                    controller: _confirmPasswordController,
                    obscureText: true,
                    enabled: !_isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                    ),
                    validator: (value) => value != _newPasswordController.text
                        ? 'Passwords do not match.'
                        : null,
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: RamadaColors.danger),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed:
                _isSubmitting ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Change password'),
          ),
        ],
      );
}

class AdminPasswordResetRequestsDialog extends StatefulWidget {
  final ApiService apiService;
  final String accessToken;

  const AdminPasswordResetRequestsDialog({
    super.key,
    required this.apiService,
    required this.accessToken,
  });

  @override
  State<AdminPasswordResetRequestsDialog> createState() =>
      _AdminPasswordResetRequestsDialogState();
}

class _AdminPasswordResetRequestsDialogState
    extends State<AdminPasswordResetRequestsDialog> {
  List<PasswordResetRequestItem> _requests = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final requests = await widget.apiService.getPasswordResetRequests(
        token: widget.accessToken,
      );
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _error = null;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to load password reset requests: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _error = 'Password reset requests could not be loaded.';
        _isLoading = false;
      });
    }
  }

  Future<String?> _askForNewPassword() async {
    var passwordValue = '';
    var confirmValue = '';
    String? error;
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set new password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  obscureText: true,
                  onChanged: (value) => passwordValue = value,
                  decoration: const InputDecoration(
                    labelText: 'New password',
                    helperText: 'Use at least 8 characters.',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  obscureText: true,
                  onChanged: (value) => confirmValue = value,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: const TextStyle(color: RamadaColors.danger),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (passwordValue.length < 8) {
                  setDialogState(() => error = 'Use at least 8 characters.');
                } else if (passwordValue != confirmValue) {
                  setDialogState(() => error = 'Passwords do not match.');
                } else {
                  Navigator.pop(dialogContext, passwordValue);
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
    return password;
  }

  Future<void> _resetPassword(PasswordResetRequestItem request) async {
    final userId = request.userId;
    if (userId == null) return;
    final password = await _askForNewPassword();
    if (password == null) return;
    try {
      await widget.apiService.resetReceptionPassword(
        userId: userId,
        password: password,
        token: widget.accessToken,
      );
      await _loadRequests();
    } catch (error, stackTrace) {
      debugPrint('Failed to reset reception password: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset could not be saved.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Password reset requests'),
      content: SizedBox(
        width: 440,
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            : _error != null
                ? Text(_error!)
                : _requests.isEmpty
                    ? const Text('No pending password reset requests.')
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _requests.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final request = _requests[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(request.username),
                            subtitle: Text(
                              'Requested ${DateFormat('dd MMM, HH:mm').format(request.createdAt.toLocal())}',
                            ),
                            trailing: IconButton(
                              tooltip: 'Reset password',
                              onPressed: request.userId == null
                                  ? null
                                  : () => _resetPassword(request),
                              icon: const Icon(Icons.lock_reset),
                            ),
                          );
                        },
                      ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : _loadRequests,
          child: const Text('Refresh'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _AddIssuanceDialogState extends State<AddIssuanceDialog> {
  final _formKey = GlobalKey<FormState>();
  String room = "";
  String guest = "";
  int qty = 1;
  String category = "Guest Key Card";
  String remarks = "";
  String? staffName;
  DateTime? checkOutDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    staffName = widget.staffRoster.any(
      (staff) => staff.name == widget.initialStaffName,
    )
        ? widget.initialStaffName
        : null;
  }

  Future<void> _selectCheckOutDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final lastDate = DateTime(today.year + 10, today.month, today.day);
    final initialDate = checkOutDate ?? today.add(const Duration(days: 1));
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(today) ? today : initialDate,
      firstDate: today,
      lastDate: lastDate,
    );
    if (selectedDate != null && mounted) {
      setState(() => checkOutDate = DateUtils.dateOnly(selectedDate));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Issue New Key / Card',
          style: TextStyle(
              color: RamadaColors.burgundy, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Room No / Access *',
                  hintText: 'e.g. Room 405',
                ),
                onChanged: (value) => setState(() => room = value),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter a room or access point.'
                    : null,
              ),
              TextFormField(
                decoration:
                    const InputDecoration(labelText: 'Guest / Holder Name'),
                onChanged: (value) => guest = value,
              ),
              const SizedBox(height: 8),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Expected check-out date (optional)',
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        checkOutDate == null
                            ? 'No check-out date'
                            : DateFormat('d MMM yyyy').format(checkOutDate!),
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('issue:check-out-date'),
                      onPressed: _selectCheckOutDate,
                      child: Text(checkOutDate == null ? 'Set date' : 'Change'),
                    ),
                    if (checkOutDate != null)
                      IconButton(
                        tooltip: 'Clear check-out date',
                        onPressed: () => setState(() => checkOutDate = null),
                        icon: const Icon(Icons.clear),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Keys stay active through the check-out date. Without one, unreturned keys are marked missing after 24 hours.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              DropdownButtonFormField<String>(
                key: const ValueKey('issue:staff-name'),
                decoration: const InputDecoration(
                  labelText: 'Staff Name *',
                ),
                initialValue: staffName,
                items: widget.staffRoster
                    .map(
                      (staff) => DropdownMenuItem(
                        value: staff.name,
                        child: Text('${staff.name} (${staff.hours})'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => staffName = value),
                validator: (value) =>
                    value == null ? 'Select a staff member.' : null,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Qty Issued:'),
                  Row(
                    children: [
                      IconButton(
                          onPressed:
                              qty > 1 ? () => setState(() => qty--) : null,
                          icon: const Icon(Icons.remove)),
                      Text('$qty',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(
                          onPressed: qty < widget.availableQuantity
                              ? () => setState(() => qty++)
                              : null,
                          icon: const Icon(Icons.add)),
                    ],
                  ),
                ],
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Remarks'),
                onChanged: (value) => remarks = value,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: RamadaColors.burgundy,
              foregroundColor: Colors.white),
          onPressed: _isSubmitting || qty > widget.availableQuantity
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  final selectedStaff = staffName;
                  if (selectedStaff == null) return;
                  final dialogContext = context;
                  setState(() => _isSubmitting = true);
                  try {
                    await widget.onAdd(
                      room.trim(),
                      guest.trim(),
                      qty,
                      category,
                      remarks,
                      selectedStaff,
                      checkOutDate == null
                          ? null
                          : DateFormat('yyyy-MM-dd').format(checkOutDate!),
                    );
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  } catch (_) {
                    // The dashboard reports API errors; keep the dialog open.
                  } finally {
                    if (mounted) setState(() => _isSubmitting = false);
                  }
                },
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Issue'),
        ),
      ],
    );
  }
}

class StaffCorrectionDialog extends StatefulWidget {
  final KeyIssuanceItem item;

  const StaffCorrectionDialog({
    super.key,
    required this.item,
  });

  @override
  State<StaffCorrectionDialog> createState() => _StaffCorrectionDialogState();
}

class _StaffCorrectionDialogState extends State<StaffCorrectionDialog> {
  late final TextEditingController _roomController;
  late final TextEditingController _guestController;
  late final TextEditingController _staffController;
  late final TextEditingController _issuedQtyController;
  late final TextEditingController _remarksController;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _roomController = TextEditingController(text: item.roomOrAccess);
    _guestController = TextEditingController(text: item.guestOrHolderName);
    _staffController = TextEditingController(text: item.issuingStaff);
    _issuedQtyController =
        TextEditingController(text: item.qtyIssued.toString());
    _remarksController = TextEditingController(text: item.remarks);
  }

  @override
  void dispose() {
    _roomController.dispose();
    _guestController.dispose();
    _staffController.dispose();
    _issuedQtyController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _save() {
    final item = widget.item;
    final qtyIssued = int.tryParse(_issuedQtyController.text);
    if (_roomController.text.trim().isEmpty ||
        _staffController.text.trim().isEmpty ||
        qtyIssued == null ||
        qtyIssued < item.qtyReturned) {
      setState(() {
        _validationError =
            'Enter a room and staff name; issued quantity cannot be below keys already returned.';
      });
      return;
    }

    final correctedItem = KeyIssuanceItem.fromMap(item.toMap())
      ..roomOrAccess = _roomController.text.trim()
      ..guestOrHolderName = _guestController.text.trim()
      ..issuingStaff = _staffController.text.trim()
      ..qtyIssued = qtyIssued
      ..remarks = _remarksController.text.trim();
    Navigator.pop(context, correctedItem);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Correct Key Log'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your correction will be recorded in the audit log.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextField(
                controller: _roomController,
                decoration: const InputDecoration(labelText: 'Room / Access'),
              ),
              TextField(
                controller: _guestController,
                decoration:
                    const InputDecoration(labelText: 'Guest / Holder Name'),
              ),
              TextField(
                controller: _staffController,
                decoration: const InputDecoration(labelText: 'Staff Name'),
              ),
              TextField(
                controller: _issuedQtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Qty Issued'),
              ),
              TextField(
                controller: _remarksController,
                decoration: const InputDecoration(labelText: 'Remarks'),
              ),
              if (_validationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _validationError!,
                    style: const TextStyle(color: RamadaColors.danger),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save Correction'),
        ),
      ],
    );
  }
}

class AdminEditDialog extends StatefulWidget {
  final KeyIssuanceItem item;

  const AdminEditDialog({
    super.key,
    required this.item,
  });

  @override
  State<AdminEditDialog> createState() => _AdminEditDialogState();
}

class _AdminEditDialogState extends State<AdminEditDialog> {
  late final TextEditingController _roomController;
  late final TextEditingController _guestController;
  late final TextEditingController _issuedQtyController;
  late final TextEditingController _returnedQtyController;
  late final TextEditingController _missingQtyController;
  late final TextEditingController _remarksController;
  late final TextEditingController _staffNameController;
  late final TextEditingController _receivedByController;
  late String _status;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _roomController = TextEditingController(text: item.roomOrAccess);
    _guestController = TextEditingController(text: item.guestOrHolderName);
    _issuedQtyController =
        TextEditingController(text: item.qtyIssued.toString());
    _returnedQtyController =
        TextEditingController(text: item.qtyReturned.toString());
    _missingQtyController =
        TextEditingController(text: item.missingQty.toString());
    _remarksController = TextEditingController(text: item.remarks);
    _staffNameController = TextEditingController(text: item.issuingStaff);
    _receivedByController =
        TextEditingController(text: item.keyReceivedBy ?? '');
    _status = item.isMissing
        ? 'MISSING'
        : item.isFullyReturned
            ? 'RETURNED'
            : 'PENDING';
  }

  @override
  void dispose() {
    _roomController.dispose();
    _guestController.dispose();
    _issuedQtyController.dispose();
    _returnedQtyController.dispose();
    _missingQtyController.dispose();
    _remarksController.dispose();
    _staffNameController.dispose();
    _receivedByController.dispose();
    super.dispose();
  }

  void _save() {
    final item = widget.item;
    final qtyIssued = int.tryParse(_issuedQtyController.text);
    final qtyReturned = int.tryParse(_returnedQtyController.text);
    final missingQty = int.tryParse(_missingQtyController.text);
    if (_roomController.text.trim().isEmpty ||
        _staffNameController.text.trim().isEmpty ||
        qtyIssued == null ||
        qtyIssued < 1 ||
        qtyReturned == null ||
        qtyReturned < 0 ||
        missingQty == null ||
        missingQty < 0 ||
        qtyReturned > qtyIssued ||
        (_status == 'PENDING' && qtyReturned == qtyIssued) ||
        (_status == 'MISSING' && missingQty > qtyIssued - qtyReturned)) {
      setState(() {
        _validationError =
            'Enter both staff names and check room and quantity values.';
      });
      return;
    }

    final isMissing = _status == 'MISSING';
    final finalReturnedQty = _status == 'RETURNED' ? qtyIssued : qtyReturned;
    final updatedItem = KeyIssuanceItem.fromMap(item.toMap())
      ..roomOrAccess = _roomController.text.trim()
      ..guestOrHolderName = _guestController.text.trim()
      ..qtyIssued = qtyIssued
      ..qtyReturned = finalReturnedQty
      ..isMissing = isMissing
      ..missingQty = isMissing ? missingQty : 0
      ..issuingStaff = _staffNameController.text.trim()
      ..keyReceivedBy = _receivedByController.text.trim().isEmpty
          ? null
          : _receivedByController.text.trim()
      ..remarks = _remarksController.text.trim();
    if (isMissing && updatedItem.missingQty == 0) {
      updatedItem.missingQty = qtyIssued - finalReturnedQty;
    }
    if (_status == 'RETURNED' && updatedItem.returnedDateTime == null) {
      updatedItem.returnedDateTime =
          DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now());
    }
    Navigator.pop(context, updatedItem);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Key Log'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _roomController,
                decoration: const InputDecoration(labelText: 'Room / Access'),
              ),
              TextField(
                controller: _guestController,
                decoration:
                    const InputDecoration(labelText: 'Guest / Holder Name'),
              ),
              TextField(
                controller: _staffNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Staff Name *'),
              ),
              TextField(
                controller: _issuedQtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Qty Issued'),
              ),
              TextField(
                controller: _returnedQtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Qty Returned'),
              ),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'PENDING', child: Text('PENDING')),
                  DropdownMenuItem(value: 'RETURNED', child: Text('RETURNED')),
                  DropdownMenuItem(
                    value: 'MISSING',
                    child: Text('MISSING / LOST'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _status = value);
                },
              ),
              if (_status == 'MISSING')
                TextField(
                  controller: _missingQtyController,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Missing Quantity'),
                ),
              TextField(
                controller: _receivedByController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Key Received By'),
              ),
              TextField(
                controller: _remarksController,
                decoration: const InputDecoration(labelText: 'Remarks'),
                maxLines: 2,
              ),
              if (_validationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _validationError!,
                    style: const TextStyle(color: RamadaColors.danger),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save Changes'),
        ),
      ],
    );
  }
}
