#!/bin/sh

# ci_post_clone.sh
# Script to set up the environment for Xcode Cloud builds

set -e

echo "===== Setting up Flutter environment ====="

# Navigate to the project root
cd "$CI_PRIMARY_REPOSITORY_PATH"

# Install Flutter using git
if [ ! -d "$HOME/flutter" ]; then
    echo "Cloning Flutter SDK..."
    git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter"
fi

# Add Flutter to PATH
export PATH="$PATH:$HOME/flutter/bin"

# Disable Flutter analytics
flutter config --no-analytics

# Run Flutter doctor
echo "===== Running Flutter doctor ====="
flutter doctor -v

# Get Flutter packages
echo "===== Getting Flutter packages ====="
flutter pub get

# Generate any necessary code (Hive adapters, etc.)
echo "===== Running build_runner ====="
flutter pub run build_runner build --delete-conflicting-outputs || true

# Navigate to iOS directory
cd ios

# Install CocoaPods dependencies
echo "===== Installing CocoaPods dependencies ====="
pod install --repo-update

echo "===== CI post-clone setup complete ====="
