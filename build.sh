#!/bin/bash
set -e

echo "🚀 Building Flutter Web per Netlify..."

# Controlla se Flutter è disponibile
if command -v flutter &> /dev/null; then
    echo "✅ Flutter già disponibile"
    flutter --version
else
    echo "❌ Flutter non trovato nel PATH"
    
    # Prova percorsi comuni di Netlify
    POSSIBLE_PATHS=(
        "/opt/buildhome/.flutter/bin"
        "/opt/buildhome/flutter/bin"
        "$HOME/.flutter/bin"
        "$HOME/flutter/bin"
    )
    
    for path in "${POSSIBLE_PATHS[@]}"; do
        if [ -f "$path/flutter" ]; then
            echo "✅ Flutter trovato in: $path"
            export PATH="$PATH:$path"
            break
        fi
    done
    
    # Se ancora non trovato, installa
    if ! command -v flutter &> /dev/null; then
        echo "📦 Installando Flutter..."
        cd /tmp
        wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.19.0-stable.tar.xz
        tar xf flutter_linux_3.19.0-stable.tar.xz
        export PATH="$PATH:/tmp/flutter/bin"
    fi
fi

# Torna alla directory del progetto
cd "$BUILD_DIR"

# Configura Flutter per web
echo "🔧 Configurando Flutter Web..."
flutter config --enable-web --no-analytics

# Pulisci e ottieni dipendenze
echo "🧹 Pulendo cache..."
flutter clean

echo "📦 Ottenendo dipendenze..."
flutter pub get

# Verifica analisi (ma non bloccare se ci sono warning)
echo "🔍 Verificando codice..."
flutter analyze --no-fatal-infos || echo "⚠️ Ci sono alcuni warning, ma continuiamo..."

# Build ottimizzato per produzione
echo "🏗️ Building per web..."
flutter build web \
    --release \
    --web-renderer canvaskit \
    --dart-define=FLUTTER_WEB_USE_SKIA=true \
    --dart-define=FLUTTER_WEB_AUTO_DETECT=false

# Verifica risultato
if [ -d "build/web" ] && [ -f "build/web/index.html" ]; then
    echo "✅ Build completata con successo!"
    echo "📁 Contenuto build/web:"
    ls -la build/web/
else
    echo "❌ Build fallita: file mancanti in build/web"
    exit 1
fi