#!/bin/bash
set -e

echo "🚀 Virgo AI - Building per Netlify..."

# Verifica directory corrente
echo "📍 Directory corrente: $(pwd)"
echo "📁 Contenuto directory:"
ls -la

# Verifica che siamo nella directory del progetto Flutter
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ pubspec.yaml non trovato!"
    echo "❌ Assicurati di essere nella root del progetto Flutter"
    exit 1
fi

echo "✅ pubspec.yaml trovato"

# Directory di lavoro per Flutter
WORK_DIR="/opt/buildhome"
FLUTTER_DIR="$WORK_DIR/flutter"
FLUTTER_VERSION="3.19.0"

# Funzione per installare Flutter
install_flutter() {
    echo "📦 Installando Flutter $FLUTTER_VERSION..."
    cd "$WORK_DIR"
    
    # Rimuovi installazione precedente se esiste
    rm -rf flutter flutter_linux_*.tar.xz
    
    # Scarica Flutter
    wget -q "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
    
    # Estrai
    tar xf "flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
    
    echo "✅ Flutter installato in $FLUTTER_DIR"
    
    # Torna alla directory del progetto
    cd "$BUILD_DIR"
}

# Controlla se Flutter esiste e funziona
if [ -x "$FLUTTER_DIR/bin/flutter" ]; then
    echo "✅ Flutter trovato, verificando versione..."
    cd "$BUILD_DIR"  # Assicurati di essere nella directory giusta
    CURRENT_VERSION=$("$FLUTTER_DIR/bin/flutter" --version 2>/dev/null | head -n1 | cut -d' ' -f2 || echo "unknown")
    echo "Versione attuale: $CURRENT_VERSION"
    
    if [[ "$CURRENT_VERSION" != "$FLUTTER_VERSION"* ]]; then
        echo "⚠️ Versione diversa, reinstallo..."
        install_flutter
    fi
else
    echo "❌ Flutter non trovato"
    install_flutter
fi

# Configura PATH
export PATH="$FLUTTER_DIR/bin:$PATH"

# Assicurati di essere nella directory del progetto
cd "$BUILD_DIR"

# Verifica che Flutter funzioni
echo "🔍 Verificando installazione Flutter..."
flutter --version

# IMPORTANTE: Disabilita analytics PRIMA di altri comandi
echo "🔧 Disabilitando analytics..."
flutter config --no-analytics 2>/dev/null || true

# Disabilita anche crash reporting
flutter config --no-enable-analytics 2>/dev/null || true

# Ora esegui doctor senza flag analytics
echo "🔍 Flutter doctor..."
flutter doctor -v || echo "⚠️ Flutter doctor ha segnalato alcuni problemi, ma continuo..."

# Configura Flutter per web
echo "🔧 Configurando Flutter Web..."
flutter config --enable-web

# Verifica che web sia supportato
flutter devices || echo "⚠️ Nessun device trovato, ma continuo..."

# Pulisci progetto
echo "🧹 Pulendo progetto..."
flutter clean

# Installa dipendenze
echo "📦 Installando dipendenze..."
flutter pub get

# IMPORTANTE: Crea i file necessari che potrebbero mancare
echo "📝 Creando file mancanti..."

# Crea le directory per gli assets se non esistono
mkdir -p assets/images
mkdir -p assets/icons

# Crea placeholder per le immagini se non esistono
if [ ! -f "assets/images/logo_virgo.png" ]; then
    echo "⚠️ Logo mancante, creo placeholder..."
    # Crea un file PNG 1x1 pixel trasparente come placeholder
    printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05|(\xcf\x16\x00\x00\x00\x00IEND\xaeB`\x82' > assets/images/logo_virgo.png
fi

if [ ! -f "assets/images/logo_virgo_extended.png" ]; then
    echo "⚠️ Logo extended mancante, creo placeholder..."
    printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05|(\xcf\x16\x00\x00\x00\x00IEND\xaeB`\x82' > assets/images/logo_virgo_extended.png
fi

# Crea un SVG placeholder per Google logo se non esiste
if [ ! -f "assets/icons/google_logo.svg" ]; then
    echo "⚠️ Google logo SVG mancante, creo placeholder..."
    cat > assets/icons/google_logo.svg << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
  <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
  <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
  <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
  <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
</svg>
EOF
fi

# Analizza codice (non bloccante)
echo "🔍 Analizzando codice..."
flutter analyze --no-fatal-infos --no-fatal-warnings || echo "⚠️ Alcuni warning trovati, ma continuo..."

# Build per produzione con environment variables
echo "🏗️ Building per web..."

# Definisci le variabili d'ambiente per il build
export SUPABASE_URL="${SUPABASE_URL:-https://scjptlxittvbhcibmbiv.supabase.co}"
export SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNjanB0bHhpdHR2YmhjaWJtYml2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgzNzU1NzMsImV4cCI6MjA3Mzk1MTU3M30.v33FvZDPA5zzSKLe2I1e--QEmemoPUrWOv315zTmp0o}"
export GOOGLE_CLIENT_ID_WEB="${GOOGLE_CLIENT_ID_WEB:-1015899649183-6qsdcijpdpskf2sn65ujfmhdt1j1eko1.apps.googleusercontent.com}"

# Build con le variabili d'ambiente
flutter build web \
    --release \
    --web-renderer canvaskit \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
    --dart-define=GOOGLE_CLIENT_ID_WEB="$GOOGLE_CLIENT_ID_WEB" \
    --dart-define=FLUTTER_WEB_USE_SKIA=true \
    --dart-define=FLUTTER_WEB_AUTO_DETECT=false \
    --no-tree-shake-icons

# Verifica risultato
if [ -d "build/web" ] && [ -f "build/web/index.html" ]; then
    echo "✅ Build completata!"
    echo "📁 File generati:"
    ls -la build/web/
    
    # Post-processing: Aggiungi meta tags per migliorare il caricamento
    if [ -f "build/web/index.html" ]; then
        echo "🔧 Ottimizzando index.html..."
        # Aggiungi preload per fonts se necessario
        sed -i 's|</head>|<link rel="preconnect" href="https://fonts.googleapis.com">\n  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n  </head>|' build/web/index.html || true
    fi
    
    # Mostra dimensioni
    echo "📊 Dimensioni file principali:"
    du -sh build/web/*.js build/web/*.html 2>/dev/null || true
    
    # Crea un file _redirects per Netlify SPA routing
    echo "/* /index.html 200" > build/web/_redirects
    echo "✅ File _redirects creato per SPA routing"
    
else
    echo "❌ Build fallita: file mancanti"
    echo "Contenuto della directory build:"
    ls -la build/ || echo "Directory build non trovata"
    exit 1
fi

echo "🎉 Deploy pronto per Netlify!"