#!/bin/bash

set -ouex pipefail

log() {
    echo "=== $* ==="
}

# --- 1. ENABLE REPOSITORIES ---
log "Enabling Repositories (Terra, Ghostty, Niri)..."

# Ensure the terra repo file exists
if [ ! -f /etc/yum.repos.d/terra.repo ]; then
    dnf5 install -y https://repos.fyralabs.com/terra41/terra-release-41-2.noarch.rpm
fi

# FORCE Terra to use Fedora 41 paths (Fedora 43 is too new for their mirrors)
sed -i 's/\$releasever/41/g' /etc/yum.repos.d/terra.repo
# Flip the enabled switch
sed -i '0,/enabled=0/s//enabled=1/' /etc/yum.repos.d/terra.repo

COPR_REPOS=(
    pgdev/ghostty
    ulysg/xwayland-satellite
    yalter/niri
)
for repo in "${COPR_REPOS[@]}"; do
    if ! dnf5 -y copr enable "$repo" 2>&1; then
        log "Warning: Failed to enable COPR repo $repo"
    fi
done

dnf5 makecache

# --- 2. DEFINE PACKAGE LISTS ---
NIRI_PKGS=(
    noctalia-shell
    noctalia-qs
    niri
    playerctl
    brightnessctl
    ImageMagick
    cava
    cliphist
    gnome-keyring
    xdg-desktop-portal-gtk
    xwayland-satellite
    libqalculate
    bc
    python3
    python3-pip
    evolution-data-server
    wlsunset
    python3-pywal  # Added here so DNF handles it from Terra
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
# Using --skip-unavailable as a safety net for the bleeding-edge fc43
dnf5 install --setopt=install_weak_deps=False -y \
    "${FONTS[@]}" \
    "${NIRI_PKGS[@]}" \
    "${ADDITIONAL_SYSTEM_APPS[@]}" \
    --skip-unavailable

# --- 4. PYWALFOX SYSTEM-WIDE SETUP ---
log "Setting up Pywalfox..."

# DO NOT try to mkdir /usr/local. 
# Instead, ensure the native-messaging-hosts path exists (it is in /usr/lib64)
mkdir -p /usr/lib64/mozilla/native-messaging-hosts/

# Install pywalfox to /usr/bin to avoid /usr/local/bin issues
# Use --break-system-packages for Fedora 43+ compatibility
pip install --prefix=/usr --break-system-packages pywalfox

# Create the manifest
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

systemctl enable podman.socket
systemctl enable uupd.timer
