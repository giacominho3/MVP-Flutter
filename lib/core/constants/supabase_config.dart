// lib/core/constants/supabase_config.dart
class SupabaseConfig {
  // SOSTITUISCI questi valori con quelli del TUO progetto Supabase
  static const String url = 'https://scjptlxittvbhcibmbiv.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNjanB0bHhpdHR2YmhjaWJtYml2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgzNzU1NzMsImV4cCI6MjA3Mzk1MTU3M30.v33FvZDPA5zzSKLe2I1e--QEmemoPUrWOv315zTmp0o';
  
  // Per sviluppo locale - cambia se usi tunnel locale
  static const String localUrl = 'http://localhost:54321';
  
  // Configurazione per produzione
  static bool get isProduction => const bool.fromEnvironment('dart.vm.product');
  
  static String get currentUrl => isProduction ? url : url; // Usa sempre Supabase cloud per MVP
  static String get currentAnonKey => anonKey;
}