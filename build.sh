#!/bin/bash

set -e  # Exit on error

echo "🔧 Starting Flutter build..."

# Download Flutter SDK
echo "📥 Downloading Flutter SDK..."
git clone https://github.com/flutter/flutter.git --depth 1 --branch stable
export PATH="$PATH:`pwd`/flutter/bin"

# Configure Flutter
echo "⚙️ Configuring Flutter..."
flutter config --enable-web

# Get Flutter version
flutter --version

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build for web
echo "🏗️ Building web app..."
flutter build web --release --dart-define=FLUTTER_WEB_RENDERER=canvaskit

# Copy web files to the right location
echo "📋 Copying files..."
cp -r build/web/* .

echo "✅ Build completed successfully!"