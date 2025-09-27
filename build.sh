#!/bin/bash
set -e

echo "🚀 Virgo AI - Building per Netlify..."

# Directory di lavoro
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
}

# Controlla se Flutter esiste e funziona
if [ -x "$FLUTTER_DIR/bin/flutter" ]; then
    echo "✅ Flutter trovato, verificando versione..."
    CURRENT_VERSION=$("$FLUTTER_DIR/bin/flutter" --version | head -n1 | cut -d' ' -f2)
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

# Torna alla directory del progetto
cd "$BUILD_DIR"

# Verifica che Flutter funzioni
echo "🔍 Verificando installazione Flutter..."
flutter --version
flutter doctor -v

# Configura Flutter per web
echo "🔧 Configurando Flutter Web..."
flutter config --enable-web --no-analytics

# Verifica che web sia supportato
flutter devices

# Pulisci progetto
echo "🧹 Pulendo progetto..."
flutter clean

# Installa dipendenze
echo "📦 Installando dipendenze..."
flutter pub get

# Verifica dipendenze
echo "🔍 Verificando dipendenze..."
flutter pub deps

# Analizza codice (non bloccante)
echo "🔍 Analizzando codice..."
flutter analyze --no-fatal-infos || echo "⚠️ Alcuni warning trovati, ma continuo..."

# Build per produzione
echo "🏗️ Building per web..."
flutter build web \
    --release \
    --web-renderer canvaskit \
    --dart-define=FLUTTER_WEB_USE_SKIA=true \
    --dart-define=FLUTTER_WEB_AUTO_DETECT=false \
    --source-maps

# Verifica risultato
if [ -d "build/web" ] && [ -f "build/web/index.html" ]; then
    echo "✅ Build completata!"
    echo "📁 File generati:"
    ls -la build/web/
    
    # Mostra dimensioni
    echo "📊 Dimensioni file principali:"
    du -sh build/web/*.js build/web/*.html 2>/dev/null || true
    
else
    echo "❌ Build fallita: file mancanti"
    exit 1
fi

echo "🎉 Deploy pronto per Netlify!"