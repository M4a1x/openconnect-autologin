#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Usage: ./install.sh [--uninstall]
set -euo pipefail

name=openconnect-autologin
bin=$HOME/.local/bin/$name
data_dir=$HOME/.local/share/$name
plugin_dir=$data_dir/vpn
env_file=$HOME/.config/environment.d/90-$name.conf
system_file=/usr/lib/NetworkManager/VPN/nm-openconnect-service.name

if [[ ${1:-} == --uninstall ]]; then
    rm -rfv "$bin" "$data_dir" "$env_file"
    systemctl --user unset-environment NM_VPN_PLUGIN_DIR || true
    echo "Log out and back in to get the stock dialog back."
    exit
fi

missing=()
for cmd in openconnect nmcli secret-tool notify-send; do
    command -v "$cmd" >/dev/null || missing+=("$cmd")
done
[[ -f $system_file ]] || missing+=(NetworkManager-openconnect)
if command -v openconnect >/dev/null && [[ $(openconnect --help 2>&1) != *--no-external-auth* ]]; then
    missing+=("openconnect 9.10 or newer")
fi
if ((${#missing[@]})); then
    echo "Missing: ${missing[*]}" >&2
    exit 1
fi

install -Dm755 "$(dirname "$0")/$name" "$bin"

# libnm ignores plugin files that are writable by group or others
mkdir -p "$plugin_dir"
sed "s|^auth-dialog=.*|auth-dialog=$bin|" "$system_file" >"$plugin_dir/nm-openconnect-service.name"
chmod 644 "$plugin_dir/nm-openconnect-service.name"

mkdir -p "$(dirname "$env_file")"
echo "NM_VPN_PLUGIN_DIR=$plugin_dir" >"$env_file"
# environment.d is only read when the systemd user instance starts, and logging out doesn't always restart it
systemctl --user set-environment "NM_VPN_PLUGIN_DIR=$plugin_dir" || true

cat <<EOF
Installed. Next:
  1. Save your login, e.g.: $bin --store https://sslvpn.ethz.ch/staff-net
  2. Log out and back in.
EOF
