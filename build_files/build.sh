#!/bin/bash

set -ouex pipefail

log() {
    echo "=== $* ==="
}

# --- 1. ENABLE REPOSITORIES ---
# We enable Terra via the release RPM, and keep your other necessary Coprs
log "Enabling Repositories (Terra, Ghostty, Niri)..."

# Install Terra-Release to get the repo configs
sudo dnf install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release


COPR_REPOS=(
    avengemedia/dms
	pgdev/ghostty
	ulysg/xwayland-satellite
	yalter/niri
)
for repo in "${COPR_REPOS[@]}"; do
	# Try to enable the repo, but don't fail the build if it doesn't support this Fedora version
	if ! dnf5 -y copr enable "$repo" 2>&1; then
		log "Warning: Failed to enable COPR repo $repo (may not support Fedora $RELEASE)"
	fi
done

# --- 2. DEFINE PACKAGE LISTS ---
# Noctalia specific dependencies verified: swww for walls, playerctl for media,
# bc for math/logic in some scripts, and the essential noctalia-qs fork.
NIRI_PKGS=(
    noctalia-shell
    noctalia-qs
    niri
    playerctl
    brightnessctl
    imagemagick
    cava
    cliphist
    gnome-keyring
    xdg-desktop-portal-gtk
    xwayland-satellite
    libqalculate
    bc
    python3
    python3-pywal
    python3-pip
    evolution-data-server
    wlsunset
)

FONTS=(
    adobe-source-code-pro-fonts
    fontawesome-fonts-all
)

ADDITIONAL_SYSTEM_APPS=(
    ghostty
)

# --- 3. INSTALL ALL PACKAGES ---
log "Installing packages..."
dnf5 install --setopt=install_weak_deps=False -y \
    "${FONTS[@]}" \
    "${NIRI_PKGS[@]}" \
    "${ADDITIONAL_SYSTEM_APPS[@]}"

# --- 4. PYWALFOX SYSTEM-WIDE SETUP ---
log "Setting up Pywalfox..."
# Install the pywalfox daemon into the image's /usr path
pip install --prefix=/usr pywalfox

# Create the manifest for the native messaging host
mkdir -p /usr/lib64/mozilla/native-messaging-hosts/

cat <<EOF > /usr/lib64/mozilla/native-messaging-hosts/pywalfox.json
{
    "name": "pywalfox",
    "description": "Browser daemon for pywalfox",
    "path": "/usr/bin/pywalfox",
    "type": "stdio",
    "allowed_extensions": [
        "pywalfox@fntne.com"
    ]
}
EOF

# --- 5. CLEANUP ---
log "Disabling Copr repos..."
for repo in "${COPR_REPOS[@]}"; do
    dnf5 -y copr disable "$repo"
done

# Enable essential background services
systemctl enable podman.socket
systemctl enable uupd.timer
