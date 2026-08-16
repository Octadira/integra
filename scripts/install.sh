#!/bin/bash
# ==============================================================================
# Integra Instant Installer for macOS
# One-line automated installation & Gatekeeper quarantine removal
# Usage: curl -fsSL https://raw.githubusercontent.com/Octadira/integra/main/scripts/install.sh | bash
# ==============================================================================
set -e

# Visual colors & styles
BOLD="\033[1m"
GREEN="\033[32m"
BLUE="\033[34m"
CYAN="\033[36m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

echo -e "${CYAN}"
echo "    ___       __                         "
echo "   / (_)___  / /____  ____ __________ _ "
echo "  / / / __ \/ __/ _ \/ __ \`/ ___/ __ \`/ "
echo " / / / / / / /_/  __/ /_/ / /  / /_/ /  "
echo "/_/_/_/ /_/\__/\___/\__, /_/   \__,_/   "
echo "                   /____/               "
echo -e "${RESET}"
echo -e "${BOLD}Integra — Native macOS SSHFS & AI Agent Workspace Manager${RESET}"
echo "=================================================================="

# Check OS
if [ "$(uname)" != "Darwin" ]; then
    echo -e "${RED}❌ Error: Integra is only supported on macOS (Darwin).${RESET}"
    exit 1
fi

# Fetch latest release version from GitHub API
echo -e "${BLUE}--> Checking latest release from GitHub...${RESET}"
LATEST_TAG=$(curl -sSL "https://api.github.com/repos/Octadira/integra/releases/latest" | grep '"tag_name":' | head -n 1 | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')

if [ -z "$LATEST_TAG" ] || [ "$LATEST_TAG" = "null" ]; then
    LATEST_TAG="v0.8.5"
fi

VERSION="${LATEST_TAG#v}"
DMG_URL="https://github.com/Octadira/integra/releases/download/${LATEST_TAG}/Integra-${LATEST_TAG}.dmg"

echo -e "--> Found version: ${GREEN}${LATEST_TAG}${RESET}"
TEMP_DIR=$(mktemp -d /tmp/integra_install_XXXXXX)
DMG_FILE="$TEMP_DIR/Integra.dmg"
MOUNT_POINT="$TEMP_DIR/mount"

cleanup() {
    if [ -d "$MOUNT_POINT" ]; then
        hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    fi
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Download release DMG
echo -e "${BLUE}--> Downloading ${DMG_URL}...${RESET}"
curl -fsSL "$DMG_URL" -o "$DMG_FILE"

# Mount DMG
echo -e "${BLUE}--> Extracting application bundle...${RESET}"
mkdir -p "$MOUNT_POINT"
hdiutil attach "$DMG_FILE" -mountpoint "$MOUNT_POINT" -nobrowse -quiet

# Copy to /Applications
APP_SRC="$MOUNT_POINT/Integra.app"
APP_DEST="/Applications/Integra.app"

if [ ! -d "$APP_SRC" ]; then
    echo -e "${RED}❌ Error: Integra.app not found in downloaded image.${RESET}"
    exit 1
fi

echo -e "${BLUE}--> Installing to ${APP_DEST}...${RESET}"
# Remove existing version if present
if [ -d "$APP_DEST" ]; then
    rm -rf "$APP_DEST"
fi
cp -R "$APP_SRC" "/Applications/"

# Remove Gatekeeper quarantine attribute
echo -e "${BLUE}--> Clearing macOS Gatekeeper quarantine attribute...${RESET}"
xattr -cr "$APP_DEST" 2>/dev/null || true

# Detach DMG
hdiutil detach "$MOUNT_POINT" -quiet

echo ""
echo -e "${GREEN}${BOLD}✅ Integra ${LATEST_TAG} successfully installed to /Applications/Integra.app!${RESET}"
echo ""
echo -e "${CYAN}Quick Start:${RESET}"
echo -e "  1. Open from Spotlight: Press ${BOLD}Cmd + Space${RESET} and type ${BOLD}Integra${RESET}."
echo -e "  2. Or launch from terminal: ${BOLD}open -a Integra${RESET}"
echo -e "  3. Open ${BOLD}Dependency Doctor${RESET} in the sidebar to ensure FUSE-T is active."
echo ""
