import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';

/// Login page matching the GNOME lock-screen style from web/pages/Login.jsx.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // view: 'selection' | 'login' | 'register'
  String _view = 'selection';
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _loading = false;

  void _resetForm() {
    _emailController.clear();
    _passwordController.clear();
    setState(() => _error = null);
  }

  void _changeView(String newView) {
    _resetForm();
    setState(() => _view = newView);
  }

  Future<void> _handleLogin() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final auth = context.read<AuthProvider>();
      final result = await auth.login(
          _emailController.text.trim(), _passwordController.text);
      if (!result['success']!) {
        setState(() => _error = result['message'] as String?);
      }
    } catch (_) {
      setState(() => _error = '发生错误，请重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleOidcLogin() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final auth = context.read<AuthProvider>();
      final result = await auth.loginWithOidc();
      // 'pending' means the browser was opened and we're waiting for the deep
      // link callback — this is normal on mobile, not an error.
      if (result['success'] != true && result['pending'] != true) {
        setState(() => _error = result['message'] as String?);
      }
    } catch (_) {
      setState(() => _error = 'OIDC 登录失败');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdwColors.loginBg,
      body: Stack(
        children: [
          // ─── Top Status Bar ─────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('cofe.allons-y.uk',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  Text(_formattedTime(),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  Row(
                    children: [
                      Icon(Icons.wifi, size: 14, color: Colors.white.withValues(alpha: 0.9)),
                      const SizedBox(width: 12),
                      Icon(Icons.volume_up, size: 14, color: Colors.white.withValues(alpha: 0.9)),
                      const SizedBox(width: 12),
                      Icon(Icons.battery_full, size: 14, color: Colors.white.withValues(alpha: 0.9)),
                      const SizedBox(width: 12),
                      Icon(Icons.power_settings_new, size: 14, color: Colors.white.withValues(alpha: 0.9)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ─── Main Content ──────────────────────────────────
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildView(),
            ),
          ),

          // ─── Bottom Logo ───────────────────────────────────
          if (_view == 'selection')
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.key, size: 20, color: Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(width: 8),
                  Text('FlowerMaple',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1.2,
                          color: Colors.white.withValues(alpha: 0.5))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formattedTime() {
    final now = DateTime.now();
    return '${now.month}月${now.day}日 ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildView() {
    switch (_view) {
      case 'login':
        return _buildLoginForm();
      case 'register':
        return _buildRegisterView();
      default:
        return _buildSelectionView();
    }
  }

  // ─── Selection View ────────────────────────────────────────────
  Widget _buildSelectionView() {
    return Column(
      key: const ValueKey('selection'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSelectionItem(
          icon: Icons.person,
          label: '登录',
          color: AdwColors.accent,
          onTap: () => _changeView('login'),
        ),
        const SizedBox(height: 16),
        _buildSelectionItem(
          icon: Icons.person_add,
          label: '注册',
          color: AdwColors.green,
          onTap: () => _changeView('register'),
        ),
        const SizedBox(height: 40),
        TextButton(
          onPressed: () => _changeView('register'),
          child: Text('未列出？',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildSelectionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 320,
      child: Material(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          hoverColor: AdwColors.accent,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Icon(icon, size: 24, color: Colors.white.withValues(alpha: 0.9)),
                ),
                const SizedBox(width: 20),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Login Form ────────────────────────────────────────────────
  Widget _buildLoginForm() {
    return SizedBox(
      key: const ValueKey('login'),
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Back + Avatar
          Row(
            children: [
              IconButton(
                onPressed: () => _changeView('selection'),
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  shape: const CircleBorder(),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          CircleAvatar(
            radius: 40,
            backgroundColor: AdwColors.accent.withValues(alpha: 0.8),
            child: const Icon(Icons.person, size: 32, color: Colors.white),
          ),
          const SizedBox(height: 12),
          const Text('账号登录',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5)),
          const SizedBox(height: 24),

          if (_error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdwColors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdwColors.red.withValues(alpha: 0.3)),
              ),
              child: Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.red.shade200,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 20),
          ],

          // Email
          TextField(
            controller: _emailController,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '邮箱',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
              ),
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),

          // Password
          TextField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '密码',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
              ),
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
            onSubmitted: (_) => _handleLogin(),
          ),
          const SizedBox(height: 16),

          // Submit
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('确定', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Register View (OIDC only) ─────────────────────────────────
  Widget _buildRegisterView() {
    return SizedBox(
      key: const ValueKey('register'),
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _changeView('selection'),
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  shape: const CircleBorder(),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          CircleAvatar(
            radius: 40,
            backgroundColor: AdwColors.green.withValues(alpha: 0.8),
            child: const Icon(Icons.person_add, size: 32, color: Colors.white),
          ),
          const SizedBox(height: 12),
          const Text('注册账号',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5)),
          const SizedBox(height: 24),

          if (_error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdwColors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdwColors.red.withValues(alpha: 0.3)),
              ),
              child: Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.red.shade200,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 20),
          ],

          Text('请使用统一认证中心（假全币）进行账号关联注册。',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _handleOidcLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('使用假全币账号进行注册',
                      style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
