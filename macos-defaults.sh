#!/usr/bin/env bash
# dotfiles-version: 1.0.0
# macos-defaults.sh — a curated set of macOS preferences.
# Idempotent. Run once after install.sh. Some changes require log-out / restart.

set -euo pipefail

if [[ "$(uname)" != "Darwin" ]]; then
  echo "Not macOS, skipping." >&2
  exit 0
fi

echo "Applying macOS defaults..."

# -- Keyboard ----------------------------------------------------------------
# Fast key repeat (lower = faster). Default is 6. Apple's "Fast" slider = 2.
defaults write NSGlobalDomain KeyRepeat -int 2
# Delay before repeat starts. Default is 25. Apple's "Short" slider = 15.
defaults write NSGlobalDomain InitialKeyRepeat -int 15
# Disable press-and-hold for special characters (so holding a key repeats it)
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# -- Finder ------------------------------------------------------------------
# Show hidden files by default (Cmd+Shift+. also toggles)
defaults write com.apple.Finder AppleShowAllFiles -bool true
# Show all file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# Show path bar at bottom of Finder windows
defaults write com.apple.finder ShowPathbar -bool true
# Show status bar
defaults write com.apple.finder ShowStatusBar -bool true
# Default new Finder windows to $HOME
defaults write com.apple.finder NewWindowTarget -string "PfHm"
# Disable the "are you sure you want to open this app" dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false
# Don't create .DS_Store on network volumes or USB sticks
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# -- Dock --------------------------------------------------------------------
# Auto-hide with no delay
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.4
# Minimize windows into their app icon (less clutter)
defaults write com.apple.dock minimize-to-application -bool true
# Don't rearrange Spaces based on most recent use
defaults write com.apple.dock mru-spaces -bool false

# -- Screenshots --------------------------------------------------------------
# Save screenshots to ~/Screenshots instead of Desktop (less clutter)
mkdir -p "$HOME/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Screenshots"
# Save as PNG (already the default but make explicit)
defaults write com.apple.screencapture type -string "png"
# Don't include the drop shadow in window screenshots
defaults write com.apple.screencapture disable-shadow -bool true

# -- Trackpad / mouse ---------------------------------------------------------
# Tap to click
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# -- Misc UI ------------------------------------------------------------------
# Save to disk (not iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
# Expand Save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Apply changes
killall Finder >/dev/null 2>&1 || true
killall Dock >/dev/null 2>&1 || true
killall SystemUIServer >/dev/null 2>&1 || true

echo ""
echo "Done. Some changes (keyboard repeat) require a logout / restart to take effect."
