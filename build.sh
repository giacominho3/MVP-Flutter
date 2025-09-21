#!/bin/bash

# Download Flutter SDK
git clone https://github.com/flutter/flutter.git
export PATH="$PATH:`pwd`/flutter/bin"

# Use stable channel and specific version
flutter channel stable
flutter upgrade

# Enable web support
flutter config --enable-web

# Get dependencies
flutter pub get

# Build for web
flutter build web --release --web-renderer canvaskit

# Copy web files to the right location
cp -r build/web/* .