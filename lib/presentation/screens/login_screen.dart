// lib/presentation/screens/login_screen.dart - VERSIONE CORRETTA
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/constants/supabase_config.dart';
import '../../data/datasources/remote/supabase_service.dart';
import '../providers/chat_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSignUp = false;
  bool _isTestingConnection = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo/Title
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.smart_toy_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  Text(
                    'AI Assistant MVP',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    _isSignUp ? 'Crea il tuo account' : 'Accedi al tuo account',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  // DEBUG: Test connessione button
                  if (kDebugMode) ...[
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _isTestingConnection ? null : _testConnection,
                      icon: _isTestingConnection 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_find),
                      label: Text(_isTestingConnection 
                          ? 'Testing...' 
                          : 'Test Connessione'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warning,
                        side: const BorderSide(color: AppColors.warning),
                      ),
                    ),
                    _buildDebugConfigInfo(),
                  ],
                  
                  const SizedBox(height: 48),
                  
                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Inserisci la tua email';
                      }
                      if (!value.contains('@')) {
                        return 'Inserisci una email valida';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Inserisci la password';
                      }
                      if (value.length < 6) {
                        return 'La password deve essere di almeno 6 caratteri';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Submit Button
                  ElevatedButton(
                    onPressed: authState is AppAuthStateLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: authState is AppAuthStateLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(_isSignUp ? 'Registrati' : 'Accedi'),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Toggle Sign Up/Sign In
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                      });
                    },
                    child: Text(_isSignUp 
                        ? 'Hai già un account? Accedi'
                        : 'Non hai un account? Registrati'),
                  ),
                  
                  // Debug: Modalità offline - CORRETTO
                  if (kDebugMode) ...[
                    const SizedBox(height: 16),
                  ],
                  
                  // Error Message
                  if (authState is AppAuthStateError) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: AppColors.error, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              authState.message,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
    });

    try {
      final isConnected = await SupabaseService.testConnection();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isConnected 
              ? '✅ Connessione Supabase OK!'
              : '❌ Connessione Supabase fallita'
            ),
            backgroundColor: isConnected ? AppColors.success : AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Errore: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_isSignUp) {
      ref.read(authStateProvider.notifier).signUp(email, password);
    } else {
      ref.read(authStateProvider.notifier).signIn(email, password);
    }
  }

  // DEBUG WIDGET
  Widget _buildDebugConfigInfo() {
    if (!kDebugMode) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info, color: AppColors.warning, size: 16),
              SizedBox(width: 8),
              Text(
                'DEBUG: Configurazione Supabase',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'URL: ${SupabaseConfig.currentUrl}',
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
          Text(
            'Key: ${SupabaseConfig.currentAnonKey.substring(0, 20)}...',
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 4),
          Text(
            'Produzione: ${SupabaseConfig.isProduction}',
            style: const TextStyle(fontSize: 11),
          ),
          Text(
            'Desktop: ${SupabaseConfig.isDesktop}',
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}