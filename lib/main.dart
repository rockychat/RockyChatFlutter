import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'services/api_client.dart';
import 'services/mqtt_service.dart';
import 'services/deep_link_service.dart';
import 'services/route_observer.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/friend_provider.dart';
import 'providers/moment_provider.dart';
import 'providers/community_provider.dart';
import 'providers/blog_provider.dart';
import 'pages/login_page.dart';
import 'pages/main_shell.dart';

final appRouteObserver = AppRouteObserver();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = ApiClient();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(apiClient)),
      ],
      child: const RockyChatApp(),
    ),
  );
}

class RockyChatApp extends StatefulWidget {
  const RockyChatApp({super.key});

  @override
  State<RockyChatApp> createState() => _RockyChatAppState();
}

class _RockyChatAppState extends State<RockyChatApp> {
  final DeepLinkService _deepLinkService = DeepLinkService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      _deepLinkService.setAuthProvider(auth);
      _deepLinkService.init();
    });
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.loading) {
          return MaterialApp(
            title: 'Rocky Chat',
            debugShowCheckedModeBanner: false,
            theme: buildAdwaitaDarkTheme(),
            navigatorObservers: [appRouteObserver],
            home: const Scaffold(
              backgroundColor: AdwColors.window,
              body: Center(
                child: CircularProgressIndicator(color: AdwColors.accent),
              ),
            ),
          );
        }
        if (!auth.isAuthenticated) {
          return MaterialApp(
            title: 'Rocky Chat',
            debugShowCheckedModeBanner: false,
            theme: buildAdwaitaDarkTheme(),
            navigatorObservers: [appRouteObserver],
            home: const LoginPage(),
          );
        }
        return _ServicesShell(key: ValueKey(auth.user?.id));
      },
    );
  }
}

class _ServicesShell extends StatefulWidget {
  const _ServicesShell({super.key});
  @override
  State<_ServicesShell> createState() => _ServicesShellState();
}

class _ServicesShellState extends State<_ServicesShell> {
  late final MqttService _mqtt;
  late final ChatProvider _chat;
  late final FriendProvider _friend;
  late final MomentProvider _moment;
  late final CommunityProvider _community;
  late final BlogProvider _blog;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final api = auth.api;
    _mqtt = MqttService(api, () => auth.token ?? '');
    _chat = ChatProvider(api, _mqtt, () => auth.user);
    _friend = FriendProvider(api);
    _moment = MomentProvider(api);
    _community = CommunityProvider(api);
    _blog = BlogProvider(api);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mqtt.connect();
      _chat.init();
      _friend.refreshAll();
    });
  }

  @override
  void dispose() {
    _mqtt.disconnect();
    _mqtt.dispose();
    _chat.dispose();
    _friend.dispose();
    _moment.dispose();
    _community.dispose();
    _blog.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _mqtt),
        ChangeNotifierProvider.value(value: _chat),
        ChangeNotifierProvider.value(value: _friend),
        ChangeNotifierProvider.value(value: _moment),
        ChangeNotifierProvider.value(value: _community),
        ChangeNotifierProvider.value(value: _blog),
      ],
      child: MaterialApp(
        title: 'Rocky Chat',
        debugShowCheckedModeBanner: false,
        theme: buildAdwaitaDarkTheme(),
        navigatorObservers: [appRouteObserver],
        home: const MainShell(),
      ),
    );
  }
}
