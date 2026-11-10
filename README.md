# openconnect-autologin

Automatic login for Cisco AnyConnect VPNs on Linux, without typing your password or one-time code. On GNOME, you just click the VPN switch in the quick settings menu. On other desktops, you run one command, e.g. from a keyboard shortcut or an alias (see [Other desktops](#other-desktops)).

Your username, password and TOTP secret are stored in your keyring (e.g. GNOME Keyring or KWallet), which is unlocked when you log in.

Made for the ETH Zurich VPN, but it works with any AnyConnect server that accepts a username, a password and (optionally) a TOTP code. The examples below use ETH; replace the server, group and username with your own.

## Requirements

- `openconnect` 9.10 or newer
- `NetworkManager` with the openconnect plugin
- `GNOME` desktop for the one-click switch (on other desktops, see [Other desktops](#other-desktops))

Install the packages for your distribution:

**Fedora**
```sh
sudo dnf install NetworkManager-openconnect-gnome openconnect libsecret libnotify
```

**Ubuntu 24.04+ / Debian 13+**
```sh
sudo apt install network-manager-openconnect-gnome openconnect libsecret-tools libnotify-bin
```

**Arch Linux**
```sh
sudo pacman -S networkmanager-openconnect openconnect libsecret libnotify
```

## Installation

**1. Install the script.** Download this repository, open a terminal in its
folder and run:

```sh
./install.sh
```

Nothing outside your home directory is changed, so no `sudo` is needed.

**2. Save your login.** Use the VPN address your university gives you,
including the group if there is one:

```sh
~/.local/bin/openconnect-autologin --store https://sslvpn.ethz.ch/staff-net
```

It asks for:

- **Username**, e.g. `jdoe@staff-net.ethz.ch`
- **Password**: your VPN password (ETH: your network password)
- **TOTP secret**: the secret behind the QR code you scanned into your authenticator app, e.g. `JBSWY3DPEHPK3PXP` (spaces are ignored). **Not** the 6-digit code that changes every 30 seconds. Password managers like Bitwarden can show the secret. Leave it empty if your VPN doesn't use one-time codes.
- **Group from the group list**: only if the official client makes you pick a group from a list, e.g. `RWTH-VPN (Split Tunnel)`. Leave it empty for ETH.
- **User agent**: press Enter to keep the default `AnyConnect`.

If there is no VPN connection with this address yet, it creates one for you. Run the command again whenever your password changes, and once for every group you use (e.g. `staff-net` and `student-net`).

You can check that the login was saved in your chosen keyring. By default this is `Seahorse` in the Gnome GUI.

**3. Log out and back in.**

**4. Connect** with the VPN switch in the quick settings menu.

### Example: ETH Zurich

You need:

- your VPN group, e.g. `staff-net`, `student-net` or your department's own group
- your ETH network password, which you set at [password.ethz.ch](https://password.ethz.ch)
- the secret of your VPN one-time password, which you also set up there. When the QR code is shown, save the secret that goes with it (in the `otpauth://` link it's the `secret=` part). If you already scanned it into Bitwarden, the entry's TOTP field contains it.

For the group `staff-net`, saving the login looks like this:

```
$ ~/.local/bin/openconnect-autologin --store https://sslvpn.ethz.ch/staff-net
Username: jdoe@staff-net.ethz.ch
Password:
TOTP secret, not the 6-digit code (e.g. JBSWY3DPEHPK3PXP, leave empty if none):
Group from the group list (leave empty if none):
User agent [AnyConnect]:
Name for the new VPN connection [sslvpn.ethz.ch/staff-net]: ETH VPN
Created the VPN connection.
```

The username is always your ETH username, `@`, the group, and `.ethz.ch`. Leave the group question empty and keep the `AnyConnect` user agent; ETH requires it. After logging out and back in, "ETH VPN" shows up under VPN in the quick settings menu (in the top right usually).

## Does it work with my university?

It works if your university uses Cisco AnyConnect (Cisco Secure Client) and you log in with a username, a password and either no second factor or a TOTP code whose secret you can see.

- **Tested:** ETH Zurich
- **Should work, untested:** University of Münster, Heidelberg University, RWTH Aachen (with the group from the list), University of Michigan, University of British Columbia

If you try it somewhere else, please open an issue and say whether it worked.

## Other desktops

On desktops other than GNOME, e.g. KDE, connect with:

```sh
~/.local/bin/openconnect-autologin --connect "ETH VPN"
```

This logs in with the saved login and starts the VPN through NetworkManager. Bind it to a keyboard shortcut, or add an alias to your `~/.bashrc`:

```sh
alias ethvpn='~/.local/bin/openconnect-autologin --connect "ETH VPN"'
```

Disconnect with `nmcli connection down "ETH VPN"` or from your network menu. You still need `install.sh` (or copy the script anywhere) and `--store` once; logging out isn't needed for `--connect`. KWallet support is untested. Feel free to try it and report whether it works.

On desktops that use nm-applet (Xfce, MATE, ...) the VPN switch may work too. This is untested.

## Troubleshooting

**The normal login window still appears.** GNOME didn't pick up the setup yet. Check with

```sh
grep -z NM_VPN /proc/$(pgrep -xu $USER gnome-shell)/environ
```

If that prints nothing, restart your computer.

**"No answer from the keyring. Is it locked?"** The keyring is only unlocked automatically when you log in with your password. Fingerprint login and automatic login leave it locked. Unlock it in "Passwords and Keys" (Seahorse) or log in with your password.

**Any other "VPN login failed" message** shows openconnect's error. Usually the password or TOTP secret is wrong; save them again with `--store`.

**It stopped working after a system update.** Run `./install.sh` again.

## How it works

The NetworkManager login window always tells the VPN server that it supports browser-based login, and there is no way to turn that off ([issue #116](https://gitlab.gnome.org/GNOME/NetworkManager-openconnect/-/work_items/116)). Some servers, ETH's included, then hand out a session that is rejected as soon as the tunnel starts. `openconnect --no-external-auth` avoids this, but the GUI can't pass that option.

When a VPN connection needs a login, GNOME runs the login program named in `/usr/lib/NetworkManager/VPN/nm-openconnect-service.name`. `install.sh` puts a copy of that file in `~/.local/share/openconnect-autologin/vpn/` that points to this script instead, and tells GNOME to look there first by setting `NM_VPN_PLUGIN_DIR` in `~/.config/environment.d/`.

When you connect, the script (in `login`):

1. reads the connection's address, user agent and protocol with `nmcli`,
2. looks up the saved login for that address in the keyring. If there is none, it opens the normal login window, so your other VPNs work as before,
3. logs in with `openconnect --authenticate --no-external-auth`, which generates the one-time code from the TOTP secret,
4. passes the session cookie to NetworkManager, which starts the VPN. On GNOME this happens in `auth_dialog`, which speaks GNOME Shell's login-program protocol; with `--connect` it happens in `connect`, through `nmcli connection up`. To support another desktop, only this last part needs replacing.

Each login is one keyring entry with the attributes `service=openconnect-autologin` and `gateway=https://sslvpn.ethz.ch/staff-net`. The secret is four lines: username, password, TOTP secret and group (the last two may be empty). To use a different password manager, edit `cred_lookup` and `cred_store` at the top of the script.

## Security

With the TOTP secret on the same computer as the password, the second factor no longer protects you if someone gets into your logged-in session. Use disk encryption (e.g. LUKS) and lock your screen when not in use.

## Uninstall

```sh
./install.sh --uninstall
```

Then log out and back in, and delete the "VPN login for ..." entries in "Passwords and Keys". The VPN connections stay; remove them in GNOME Settings if you don't need them.

## Tested on

Fedora 44 with GNOME 50, NetworkManager 1.56, NetworkManager-openconnect 1.2.10 and openconnect 9.12. Reports from other distributions are welcome.

## License

[GPL-3.0-or-later](LICENSE)
