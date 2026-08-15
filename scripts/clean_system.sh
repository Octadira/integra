#!/bin/bash
set -e

echo "=== Cleaning Integra Application and System Settings ==="

# Terminate running Integra process if any
pkill -f "Integra" 2>/dev/null || true

# Remove Installed Apps from /Applications
echo "--> Removing app bundles from /Applications..."
rm -rf "/Applications/Integra.app"
rm -rf "/Applications/integra.app"

# Remove User App Support and Preferences
echo "--> Removing configuration, caches, and saved states..."
rm -rf "$HOME/Library/Application Support/Integra"
rm -rf "$HOME/Library/Application Support/integra"
rm -rf "$HOME/Library/Preferences/com.integra.app.plist"
rm -rf "$HOME/Library/Preferences/com.octadira.integra.plist"
rm -rf "$HOME/Library/Caches/com.integra.app"
rm -rf "$HOME/Library/Caches/com.octadira.integra"
rm -rf "$HOME/Library/Saved Application State/com.integra.app.savedState"
rm -rf "$HOME/Library/Saved Application State/com.octadira.integra.savedState"

# Unmount active FUSE-T/SSHFS mounts in ~/Mounts
if [ -d "$HOME/Mounts" ]; then
    echo "--> Cleaning ~/Mounts..."
    for mountpt in "$HOME/Mounts"/*; do
        if [ -d "$mountpt" ]; then
            /usr/sbin/diskutil unmount force "$mountpt" 2>/dev/null || /sbin/umount "$mountpt" 2>/dev/null || true
            rmdir "$mountpt" 2>/dev/null || true
        fi
    done
fi

echo "=== Cleanup Finished! The Mac is ready for a clean installation test. ==="
