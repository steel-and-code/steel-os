#!/bin/bash
# Steel OS image build script (STEEL-16).
#
# Runs once, inside the container build, on top of Bazzite. Everything Steel
# OS changes about Bazzite happens here or in system_files/. Never patch
# Bazzite's own files; add ours next to them.
#
# The Universal Blue template uses `set -ouex pipefail` here; we keep it so
# the build stops on the first error and prints every command it runs.

set -ouex pipefail

### 1. Settings files
# Everything under system_files/ is copied to / in the image. Today that is
# the Plasma defaults (STEEL-29): keyboard shortcuts, cascading windows,
# Konsole as the terminal. Later stories add the wallpaper, the update
# schedule and the Steel Apps list the same way.
cp -avf /ctx/system_files/. /

### 2. Extra rpm packages
# packages/image.txt lists Fedora package names, one per line. Lines that
# start with # and blank lines are ignored. Only system pieces belong there;
# apps are Flatpaks and are installed at first boot (STEEL-17).
mapfile -t IMAGE_PACKAGES < <(grep -Ev '^\s*(#|$)' /ctx/packages/image.txt)
if [[ ${#IMAGE_PACKAGES[@]} -gt 0 ]]; then
    dnf5 install -y "${IMAGE_PACKAGES[@]}"
fi

### 3. Image signing key
# The public half of the Steel OS signing key goes into the image so an
# installed machine can check that updates really come from us. The matching
# registries.d file in system_files/ tells the container tools where our
# signatures live. Enforcing the check in /etc/containers/policy.json is a
# follow-up story; today the key is only made available.
install -D -m 0644 /ctx/cosign.pub /etc/pki/containers/steel-os.pub

### 4. Services
# Nothing enabled yet. wsdd (Windows network discovery) is installed above
# but is switched on by STEEL-39 together with the firewall rule it needs.

### 5. Branding (STEEL-31)
# Wallpapers as Plasma wallpaper packages, so both appear in the wallpaper
# chooser with a name. metadata.json for each lives in system_files/.
install -D -m 0644 /ctx/branding/wallpaper/steel-os-wallpaper-waves-3840x2160.png \
    /usr/share/wallpapers/steel-os-waves/contents/images/3840x2160.png
install -D -m 0644 /ctx/branding/wallpaper/steel-os-wallpaper-room-3840x2160.png \
    /usr/share/wallpapers/steel-os-room/contents/images/3840x2160.png

# Default desktop wallpaper, the way Bazzite does it: Fedora's Plasma reads
# /usr/share/backgrounds/default.jxl and default-dark.jxl, and Bazzite points
# those at its own image. We point them at the waves wallpaper. The file is a
# PNG behind a .jxl name; the image loader checks the content, not the name.
# If the VM test shows a blank desktop, convert the wallpapers to JXL.
ln -sf /usr/share/wallpapers/steel-os-waves/contents/images/3840x2160.png /usr/share/backgrounds/default.jxl
ln -sf /usr/share/wallpapers/steel-os-waves/contents/images/3840x2160.png /usr/share/backgrounds/default-dark.jxl
rm -f /usr/share/backgrounds/default.xml

# Plasma's own fallback (T, 2026-10-18: a 0.4.7 install showed Fedora's
# picture). A new desktop takes the wallpaper named "Default", and the
# look-and-feel themes name one too (Fedora's say "Fedora", Breeze's "Next").
# All of them now mean the Steel OS waves, so it is the first wallpaper
# however the desktop gets created. The other wallpapers stay in the chooser.
rm -rf /usr/share/wallpapers/Default
ln -s steel-os-waves /usr/share/wallpapers/Default
python3 - <<'PYEOF'
import glob, re
for path in glob.glob("/usr/share/plasma/look-and-feel/*/contents/defaults"):
    text = open(path).read()
    if re.search(r"^\[Wallpaper\]", text, re.M):
        text = re.sub(r"(^\[Wallpaper\]\n(?:(?!\[).*\n)*?)Image=.*", r"\1Image=steel-os-waves", text, count=1, flags=re.M)
    else:
        text = text.rstrip("\n") + "\n\n[Wallpaper]\nImage=steel-os-waves\n"
    open(path, "w").write(text)
    print("Steel OS wallpaper default:", path)
PYEOF
grep -h -A1 '^\[Wallpaper\]' /usr/share/plasma/look-and-feel/*/contents/defaults | grep Image= | sort | uniq -c
readlink /usr/share/wallpapers/Default

# Logo for System Settings > About (see system_files/etc/xdg/kcm-about-distrorc)
install -D -m 0644 /ctx/branding/icon/png/steel-os-icon-dark-256.png /usr/share/pixmaps/steel-os.png

### 5b. No Bazzite name on the desktop (STEEL-31, STEEL-40)
# Bazzite Portal opens at every first login and says "Bazzite" throughout.
# Bazzite's version does not start, is hidden and is taken off the taskbar;
# section 16 puts the Steel OS Portal in its place. Bazzite's announcement
# pop-up is switched off too.
rm -f /etc/skel/.config/autostart/bazzite-portal.desktop
rm -f /etc/xdg/autostart/bazzite-announcement.desktop
for f in /usr/share/applications/*yafti*.desktop; do
    [[ -f "$f" ]] || continue
    grep -q '^NoDisplay=' "$f" && sed -i 's/^NoDisplay=.*/NoDisplay=true/' "$f" \
        || sed -i '/^\[Desktop Entry\]/a NoDisplay=true' "$f"
done
for f in /usr/share/plasma/shells/org.kde.plasma.desktop/contents/updates/bazzite-pins.js \
         /usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js; do
    [[ -f "$f" ]] && sed -i '/yafti_gtk\.desktop/d' "$f"
done

# New users get Plasma's default layout and Plasma marks every update script
# as already done for them, so the wallpaper script also has to run inside
# the default layout (the same way Bazzite adds its taskbar pins).
LAYOUT=/usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js
sed -i '$r /usr/share/plasma/shells/org.kde.plasma.desktop/contents/updates/steel-os-wallpaper.js' "$LAYOUT"

### 6. Default apps at first boot (STEEL-17)
# The Flatpak list ships inside the image; a small service installs it from
# Flathub after the first boot with a network. See
# system_files/usr/libexec/steel-os-flatpak-install.
install -D -m 0644 /ctx/packages/flatpaks-default.txt /usr/share/steel-os/flatpaks-default.txt
chmod 0755 /usr/libexec/steel-os-flatpak-install
systemctl enable steel-os-flatpak-install.service

# The Steel Apps list also feeds the first-login setup's app checklist.
install -D -m 0644 /ctx/packages/steel-apps.txt /usr/share/steel-os/steel-apps.txt

### 7. The OS calls itself Steel OS (STEEL-48)
# Build number (STEEL-57): date and commit of this image, from the Containerfile.
mkdir -p /usr/share/steel-os
echo "${STEEL_OS_BUILD:-local}" > /usr/share/steel-os/build
echo "${STEEL_OS_VERSION:-0.0.0}" > /usr/share/steel-os/version
echo "Steel OS version $(cat /usr/share/steel-os/version), build $(cat /usr/share/steel-os/build)"
# steel-os-version: the version in plain English, for people (bootc status
# shows image digests). It also prints under the terminal's welcome message.
chmod 0755 /usr/bin/steel-os-version
/usr/bin/steel-os-version --short
# Bazzite rewrites Fedora's /usr/lib/os-release in its build (see Bazzite's
# build_files/image-info). We do the same on top, changing only the fields
# that name the OS. ID stays "bazzite" and image-info.json stays untouched,
# because Bazzite's own tools read those; checked 2026-10-16, nothing in
# Bazzite reads VARIANT_ID or NAME at run time.
# Fedora's anonymous Count Me statistic reports NAME and VARIANT_ID, which is
# how Steel OS machines are counted (STEEL-33).
OS_RELEASE="/usr/lib/os-release"
sed -i 's/^NAME=.*/NAME="Steel OS"/' "$OS_RELEASE"
# The version shows in About this System and in the boot menu: "Steel OS 0.5.3".
# The NVIDIA images say so, because the boot menu lists every installed
# version and nothing else told them apart (S&C, 2026-10-19). The base image
# records its flavour in /usr/share/ublue-os/image-info.json.
flavour="$(jq -r '."image-flavor" // ."image-name" // ""' /usr/share/ublue-os/image-info.json 2>/dev/null || true)"
case "$flavour" in
    *nvidia-open*) variant=" NVIDIA" ;;
    *nvidia*)      variant=" NVIDIA legacy" ;;
    *)             variant="" ;;
esac
echo "Steel OS edition from image flavour '${flavour}': 'Steel OS ${STEEL_OS_VERSION:-}${variant}'"
sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"Steel OS ${STEEL_OS_VERSION:-}${variant}\"/" "$OS_RELEASE"
grep -q '^STEEL_OS_VERSION=' "$OS_RELEASE" || echo "STEEL_OS_VERSION=${STEEL_OS_VERSION:-0.0.0}" >> "$OS_RELEASE"
sed -i 's/^VARIANT_ID=.*/VARIANT_ID=steel-os/' "$OS_RELEASE"
sed -i 's|^HOME_URL=.*|HOME_URL="https://steel-os.org"|' "$OS_RELEASE"
sed -i 's|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL="https://steel-os.org"|' "$OS_RELEASE"
sed -i 's|^SUPPORT_URL=.*|SUPPORT_URL="https://steel-os.org"|' "$OS_RELEASE"
sed -i 's|^BUG_REPORT_URL=.*|BUG_REPORT_URL="https://steel-os.org"|' "$OS_RELEASE"
sed -i 's/^LOGO=.*/LOGO=steel-os/' "$OS_RELEASE"
sed -i 's/^DEFAULT_HOSTNAME=.*/DEFAULT_HOSTNAME="steel-os"/' "$OS_RELEASE"
# Orange, the brand color, for the terminal banner that reads ANSI_COLOR
sed -i 's/^ANSI_COLOR=.*/ANSI_COLOR="0;38;2;242;100;30"/' "$OS_RELEASE"
# The boot menu entry name
sed -i 's/^BOOTLOADER_NAME=.*/BOOTLOADER_NAME="Steel OS"/' "$OS_RELEASE"
# Bazzite writes this for GRUB; keep the pattern, change the name
echo "Steel OS release $(rpm -E %fedora) (Kinoite)" > /etc/system-release
grep -E '^(NAME|PRETTY_NAME|ID|VARIANT_ID|LOGO|HOME_URL)=' "$OS_RELEASE"

# The icon that LOGO=steel-os points at, in every standard size
for size in 16 32 48 64 128 256 512; do
    install -D -m 0644 "/ctx/branding/icon/png/steel-os-icon-dark-${size}.png" \
        "/usr/share/icons/hicolor/${size}x${size}/apps/steel-os.png"
done
install -D -m 0644 /ctx/branding/icon/steel-os-icon-dark.svg /usr/share/icons/hicolor/scalable/apps/steel-os.svg

### 8. Keep the package repos usable for the ISO builder (STEEL-50)
# bootc-image-builder copies the enabled dnf repos out of the image and runs
# dnf in its own container to assemble the installer. A repo whose signing
# key is a local file (gpgkey=file://...) only works there if that file also
# exists in the builder's container. Fedora's own keys do; Bazzite's extra
# repos (terra, rpmfusion and friends) point at keys that do not, and the ISO
# build stops with "Failed to retrieve GPG key". Repos are not used on an
# installed machine (updates arrive as whole images), so every repo that is
# not Fedora's own and keys from a local file is switched off in the image.
for repo in /etc/yum.repos.d/*.repo; do
    [[ -f "$repo" ]] || continue
    if grep -qE '^gpgkey=file://' "$repo" && ! grep -qE '^gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora' "$repo"; then
        echo "Disabling $repo: its signing key is a local file the ISO builder cannot read"
        sed -i -e 's/^enabled=1/enabled=0/' -e 's/^enabled=true/enabled=false/' "$repo"
    fi
done
grep -l '^enabled=1' /etc/yum.repos.d/*.repo || true

### 10. Desktop polish (STEEL-7, STEEL-20, STEEL-37, STEEL-48)
# Start button icon and plain-English start menu, for new and existing users.
LAYOUT=/usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js
sed -i '$r /usr/share/plasma/shells/org.kde.plasma.desktop/contents/updates/steel-os-panel.js' "$LAYOUT"

# No "Bazzite" in any start-menu name. Desktop files keep their file names
# (other tools refer to them); only the text people read changes.
for f in /usr/share/applications/*.desktop; do
    [[ -f "$f" ]] || continue
    if grep -qE '^(Name|GenericName|Comment)(\[[^]]*\])?=.*Bazzite' "$f"; then
        sed -i -E '/^(Name|GenericName|Comment)(\[[^]]*\])?=/ s/Bazzites?/Steel OS/g' "$f"
    fi
done

# The app store is Bazzite's "Bazaar". Call it what it is.
BAZAAR=/usr/share/applications/io.github.kolunmi.Bazaar.desktop
if [[ -f "$BAZAAR" ]]; then
    sed -i -E 's/^Name=.*/Name=App Store/; s/^GenericName=.*/GenericName=App Store/' "$BAZAAR"
    grep -q '^Keywords=' "$BAZAAR" && sed -i 's/^Keywords=/Keywords=Bazaar;store;apps;install;/' "$BAZAAR" \
        || echo 'Keywords=Bazaar;store;apps;install;' >> "$BAZAAR"
fi

# Things Steel OS does not ship (STEEL-20): rpm packages listed in
# packages/remove.txt are removed, and launchers listed in
# packages/hide.txt stay installed but out of the start menu.
mapfile -t REMOVE_PACKAGES < <(grep -Ev '^\s*(#|$)' /ctx/packages/remove.txt || true)
if [[ ${#REMOVE_PACKAGES[@]} -gt 0 ]]; then
    dnf5 remove -y "${REMOVE_PACKAGES[@]}"
fi
while IFS= read -r launcher; do
    f="/usr/share/applications/${launcher}"
    [[ -f "$f" ]] || { echo "hide.txt: $launcher not found, skipping"; continue; }
    grep -q '^NoDisplay=' "$f" && sed -i 's/^NoDisplay=.*/NoDisplay=true/' "$f" \
        || sed -i '/^\[Desktop Entry\]/a NoDisplay=true' "$f"
done < <(grep -Ev '^\s*(#|$)' /ctx/packages/hide.txt || true)

### 11. Keyboard shortcuts actually applied (STEEL-29)
# Plasma 6 does not read shortcut defaults from /etc/xdg/kglobalshortcutsrc
# (found in VM testing, 2026-10-17: Super+Enter did nothing). The same file
# is now (a) copied into /etc/skel so every new user starts with it, and
# (b) applied once to existing users at login by steel-os-shortcuts.
# Plasma 6 stores app-launch shortcuts as the plain key list, so the
# "[services]" entries are rewritten from the old "active,default,name" form.
SHORTCUTS=/usr/share/steel-os/kglobalshortcutsrc
install -D -m 0644 /etc/xdg/kglobalshortcutsrc "$SHORTCUTS"
awk '
    /^\[services\]/ { svc = 1; print; next }
    /^\[/           { svc = 0; print; next }
    svc && /^[^#=]+=/ {
        key = substr($0, 1, index($0, "=") - 1)
        val = substr($0, index($0, "=") + 1)
        n = split(val, parts, ",")
        print key "=" parts[1]
        next
    }
    { print }
' "$SHORTCUTS" > "$SHORTCUTS.new" && mv "$SHORTCUTS.new" "$SHORTCUTS"
install -D -m 0644 "$SHORTCUTS" /etc/skel/.config/kglobalshortcutsrc
chmod 0755 /usr/libexec/steel-os-shortcuts /usr/libexec/steel-os-taskbar /usr/libexec/steel-os-desktops
grep -A1 'org.kde.konsole.desktop' "$SHORTCUTS"

### 12. No Fedora logo presented as ours (STEEL-51)
# Fedora's trademark guidelines: a system built on Fedora must not use the
# Fedora logo as its own. Bazzite keeps Fedora's logo files, which Plasma and
# other tools show as "the system logo". Replace those files with the
# Steel OS icon. Saying "built on Fedora" stays, in About and the docs.
for f in $(find /usr/share/icons/hicolor -path '*/apps/*' \( -name 'fedora-logo-icon.*' -o -name 'start-here*.*' -o -name 'distributor-logo*.*' \) 2>/dev/null); do
    case "$f" in
        *.svg) install -m 0644 /ctx/branding/icon/steel-os-icon-dark.svg "$f" ;;
        *.png)
            size="$(basename "$(dirname "$(dirname "$f")")")"   # e.g. 48x48
            px="${size%%x*}"
            src="/ctx/branding/icon/png/steel-os-icon-dark-${px}.png"
            [[ -f "$src" ]] || src=/ctx/branding/icon/png/steel-os-icon-dark-256.png
            install -m 0644 "$src" "$f"
            ;;
    esac
done
for f in /usr/share/pixmaps/fedora-logo*.png /usr/share/pixmaps/system-logo*.png /usr/share/pixmaps/fedora-gdm-logo.png; do
    [[ -f "$f" ]] && install -m 0644 /ctx/branding/icon/png/steel-os-icon-dark-256.png "$f"
done
for f in /usr/share/pixmaps/fedora-logo*.svg /usr/share/pixmaps/system-logo*.svg; do
    [[ -f "$f" ]] && install -m 0644 /ctx/branding/icon/steel-os-icon-dark.svg "$f"
done
gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true

### 13. No Bazzite left in the terminal or for older users (STEEL-48, STEEL-31)
# Terminal welcome message: Steel OS text and tips instead of Bazzite's
# (template in system_files/usr/share/ublue-os/motd/). Bazzite's own tips
# and Swedish template link to Bazzite's docs and Discord; remove them.
rm -f /usr/share/ublue-os/motd/tips/10-ublue.md /usr/share/ublue-os/motd/tips/20-bazzite.md
rm -rf /usr/share/ublue-os/motd/tips/sv
cp -f /usr/share/ublue-os/motd/template.md /usr/share/ublue-os/motd/template.sv.md
# Computers named "bazzite" by an early image get renamed at boot.
chmod 0755 /usr/libexec/steel-os-hostname
systemctl enable steel-os-hostname.service

### 14. Shortcuts as built-in defaults; Bazzite's portal removed (STEEL-29, STEEL-18, STEEL-31)
# Konsole's own launcher file sets its default shortcut (Ctrl+Alt+T), and
# Plasma uses that for every user who has not changed it. Put Super+Enter and
# Alt+Enter there too, so they work with no per-user step at all.
KONSOLE_DESKTOP=/usr/share/applications/org.kde.konsole.desktop
if [[ -f "$KONSOLE_DESKTOP" ]]; then
    if grep -q '^X-KDE-Shortcuts=' "$KONSOLE_DESKTOP"; then
        sed -i 's/^X-KDE-Shortcuts=.*/X-KDE-Shortcuts=Meta+Return,Alt+Return,Ctrl+Alt+T/' "$KONSOLE_DESKTOP"
    else
        sed -i '/^\[Desktop Entry\]/a X-KDE-Shortcuts=Meta+Return,Alt+Return,Ctrl+Alt+T' "$KONSOLE_DESKTOP"
    fi
    grep '^X-KDE-Shortcuts=' "$KONSOLE_DESKTOP"
fi

# Apply the per-user shortcuts BEFORE the desktop starts (Plasma 6 reads them
# only when KWin starts), as a user service, instead of an autostart entry
# that ran too late.
rm -f /etc/xdg/autostart/steel-os-shortcuts.desktop
systemctl --global enable steel-os-shortcuts.service

# Bazzite Portal: Bazzite's version goes entirely. Its engine stays, and
# section 16 turns it into the Steel OS Portal. The search plugins read
# Bazzite's list and are removed.
PORTAL_PKGS=()
for p in krunner-yafti gnome-search-yafti; do
    rpm -q "$p" >/dev/null 2>&1 && PORTAL_PKGS+=("$p")
done
if [[ ${#PORTAL_PKGS[@]} -gt 0 ]]; then
    dnf5 remove -y "${PORTAL_PKGS[@]}" || echo "Portal search plugins could not be removed: ${PORTAL_PKGS[*]}"
fi
rm -rf /usr/share/yafti
rm -f /usr/share/applications/*yafti*.desktop /etc/skel/.config/autostart/bazzite-portal.desktop
rm -f /usr/share/metainfo/*yafti*.xml

### 15. Virtual machines work out of the box (STEEL-40)
# Bazzite does not ship the libvirt virtual machine service; its
# "ujust setup-virtualization" assumes it is there. Steel OS includes it
# (packages/image.txt) and switches it on, so Virtual Machine Manager from
# Steel Apps works right after install with no extra setup and no restart.
# libvirt's services start on demand when an app connects (socket activation).
for unit in virtqemud.socket virtnetworkd.socket virtstoraged.socket \
            virtnodedevd.socket virtsecretd.socket virtinterfaced.socket \
            virtproxyd.socket virtlogd.socket virtlockd.socket; do
    if systemctl list-unit-files "$unit" >/dev/null 2>&1; then
        systemctl enable "$unit"
    fi
done
# The default NAT network starts with the first VM.
if [[ -f /etc/libvirt/qemu/networks/default.xml ]]; then
    mkdir -p /etc/libvirt/qemu/networks/autostart
    ln -sf ../default.xml /etc/libvirt/qemu/networks/autostart/default.xml
fi

### 16. Steel OS Portal: welcome, one-click Steel Apps, system tools (STEEL-40)
# Bazzite Portal's engine (yafti-gtk, GPL-3.0, github.com/ublue-os/yafti-gtk)
# shows whatever its settings file lists. Steel OS gives it its own file,
# built from packages/steel-apps.txt, and its own name, color and icon.
PORTAL_ENGINE=/usr/bin/yafti_gtk.py
if [[ ! -f "$PORTAL_ENGINE" ]]; then
    echo "Steel OS Portal: the portal engine is missing from the base image" >&2
    exit 1
fi
sed -i \
    -e 's/Bazzite Portal/Steel OS Portal/g' \
    -e "s|^AUTOSTART_FILE = .*|AUTOSTART_FILE = os.path.join(AUTOSTART_DIR, 'steel-os-portal.desktop')|" \
    -e 's|^Comment=Helps you setup Bazzite$|Comment=Set up Steel OS and install apps in one click|' \
    -e 's|^Exec=yafti_gtk.py /usr/share/yafti/yafti.yml$|Exec=yafti_gtk.py /usr/share/steel-os/portal.yml|' \
    -e 's|^Icon=io.github.ublue_os.yafti_gtk$|Icon=steel-os-portal|' \
    -e 's|^DEFAULT_ACCENT = .*|DEFAULT_ACCENT = "#F2641E"|' \
    "$PORTAL_ENGINE"
# Buttons that only open an app or a web page ("terminal: false" in the
# Portal's list, from make-portal.py) start it directly instead of in a
# terminal window (T, 2026-10-18: Steel Shield opened Konsole too). If the
# engine's code has changed, they keep opening a terminal, with a warning.
python3 - "$PORTAL_ENGINE" <<'PYEOF2'
import sys
p = sys.argv[1]
s = open(p).read()
call = "error_message = self.launch_terminal(script)"
method = "    def launch_terminal(self, script):"
if s.count(call) == 1 and s.count(method) == 1:
    s = s.replace(call, "error_message = self.launch_detached(script) if action.get('terminal') is False else self.launch_terminal(script)")
    s = s.replace(method, """    def launch_detached(self, script):
        \"\"\"Steel OS: run a button that only opens an app, without a terminal window.\"\"\"
        try:
            return subprocess.Popen(['bash', '-c', script], start_new_session=True,
                                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception as e:
            return f"Could not start it: {e}"

""" + method)
    # The choices in a row's pop-up (Install, Open, Uninstall) run through a
    # second call; the ones that start a window (steel-os-app) skip the
    # terminal too (T, 2026-10-19).
    option_call = "result = self.launch_terminal(script)"
    if s.count(option_call) == 1:
        s = s.replace(option_call, "result = self.launch_detached(script) if script.startswith(('nohup setsid ', 'xdg-open ')) else self.launch_terminal(script)")
        print("Steel OS Portal: Install / Open / Uninstall choices open their own window, no terminal")
    else:
        print("Steel OS Portal: WARNING the choice pop-up changed; app installs still open a terminal")
    # After a one-click row's window closes, re-check that row's Installed /
    # Not installed; and re-check every row on screen whenever the Portal
    # window comes back into focus, in case an app was added or removed in
    # the App Store (T, 2026-10-19).
    plain_return = "            if isinstance(error_message, subprocess.Popen):\n                return"
    focus = "            GLib.idle_add(self.refresh_active_dialog_if_needed)"
    if s.count(plain_return) == 1 and s.count(focus) == 1:
        s = s.replace(plain_return, """            if isinstance(error_message, subprocess.Popen):
                status_script = (action.get('status_script') or "").strip()
                if status_script:
                    def _steel_wait(p=error_message, aid=action.get('id'), ss=status_script):
                        p.wait()
                        _STEEL_FLATPAKS["at"] = 0.0
                        GLib.idle_add(self.fetch_and_update_single_status, aid, ss)
                    threading.Thread(target=_steel_wait, daemon=True).start()
                return""")
        s = s.replace(focus, focus + "\n            GLib.idle_add(self.steel_refresh_rows)")
        s = s.replace(method, """    def steel_refresh_rows(self):
        \"\"\"Steel OS: re-check the rows on screen when the window comes back (one flatpak list).\"\"\"
        now = time.monotonic()
        if now - getattr(self, '_steel_rows_checked', 0.0) < 5:
            return False
        self._steel_rows_checked = now
        _STEEL_FLATPAKS["at"] = 0.0
        try:
            actions = self.page_actions_map.get(self.current_page_name, []) if self.current_page_name else []
            for a in actions:
                ss = (a.get('status_script') or "").strip()
                if ss and a.get('id') in self.action_status_widgets:
                    self.executor.submit(self.fetch_and_update_single_status, a.get('id'), ss)
        except Exception:
            pass
        return False

""" + method)
        print("Steel OS Portal: rows re-check Installed / Not installed after a click and on focus")
    else:
        print("Steel OS Portal: WARNING engine changed; rows refresh only when the Portal is reopened")
    # Every Steel Apps row used to run its own shell (bash -l, then flatpak info)
    # through a 4-thread pool with a 3-second limit, so a page of 30 apps sat on
    # "Checking..." for ages (T, 2026-10-19). Now one "flatpak list", kept for
    # two seconds, answers every row at once; anything else still runs its own
    # script.
    fetch = "    def fetch_and_update_single_status(self, action_id, status_script):\n        \"\"\"Executes a single script and schedules a UI update.\"\"\"\n        status_token = \"unknown\"\n"
    helper_anchor = "def escape_markup(text):"
    popup_wait = "                def wait_and_refresh():\n                    result.wait()\n"
    if s.count(fetch) == 1 and s.count(helper_anchor) == 1 and s.count(popup_wait) == 1:
        s = s.replace(fetch, fetch + """        m = re.match(r'^flatpak info (\\S+) >/dev/null 2>&1 && echo install \\|\\| echo uninstall$', (status_script or '').strip())
        if m:
            ids = steel_installed_flatpaks()
            if ids is not None:
                GLib.idle_add(self._update_status_ui, action_id, 'install' if m.group(1) in ids else 'uninstall')
                return
""")
        s = s.replace(helper_anchor, """_STEEL_FLATPAKS = {"at": 0.0, "ids": None}
_STEEL_FLATPAKS_LOCK = threading.Lock()


def steel_installed_flatpaks(max_age=2.0):
    \"\"\"Steel OS: the ids of every installed app from one flatpak list, kept for a
    couple of seconds so a page of rows is answered at once. None if flatpak failed.\"\"\"
    with _STEEL_FLATPAKS_LOCK:
        if time.monotonic() - _STEEL_FLATPAKS["at"] > max_age:
            try:
                r = subprocess.run(["flatpak", "list", "--app", "--columns=application"],
                                   capture_output=True, text=True, timeout=30, check=False)
                _STEEL_FLATPAKS["ids"] = set(r.stdout.split()) if r.returncode == 0 else None
            except Exception:
                _STEEL_FLATPAKS["ids"] = None
            _STEEL_FLATPAKS["at"] = time.monotonic()
        return _STEEL_FLATPAKS["ids"]


""" + helper_anchor)
        s = s.replace(popup_wait, popup_wait + "                    _STEEL_FLATPAKS[\"at\"] = 0.0\n")
        if "\nimport re\n" not in s:
            s = s.replace("import os\n", "import os\nimport re\n", 1)
        print("Steel OS Portal: Steel Apps rows answered from one flatpak list")
    else:
        print("Steel OS Portal: WARNING engine changed; each row still runs its own check")
    # Category chips (T, 2026-10-20): a tab whose rows carry a "category"
    # (Steel Apps: Everyday, Work, Creative, Games and Streaming) gets a row
    # of buttons at the top, All / Everyday / Work / ..., that show only that
    # category's rows. No extra tabs.
    page = """        scrolled.controller_targets = []
        for action in screen.get('actions', []):
            item = self.create_action_item(action)
            page_box.append(item)
            scrolled.controller_targets.append(item.get_child())
"""
    if s.count(page) == 1:
        s = s.replace(page, """        actions = screen.get('actions', [])
        cats = []
        for a in actions:
            c = a.get('category')
            if c and c not in cats:
                cats.append(c)
        items = []
        if len(cats) > 1:
            chips = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
            chips.set_margin_bottom(4)
            first = None
            def steel_pick(btn, cat):
                if not btn.get_active():
                    return
                for it in items:
                    it.set_visible(cat is None or getattr(it, 'steel_category', None) == cat)
            for label, cat in [("All", None)] + [(c, c) for c in cats]:
                b = Gtk.ToggleButton(label=label)
                b.add_css_class('pill')
                if first is None:
                    first = b
                    b.set_active(True)
                else:
                    b.set_group(first)
                b.connect('toggled', steel_pick, cat)
                chips.append(b)
            page_box.append(chips)
        scrolled.controller_targets = []
        for action in actions:
            item = self.create_action_item(action)
            item.steel_category = action.get('category')
            items.append(item)
            page_box.append(item)
            scrolled.controller_targets.append(item.get_child())
""")
        print("Steel OS Portal: category chips on tabs with categories")
    else:
        print("Steel OS Portal: WARNING engine changed; no category chips")
    # One click means one click (T, 2026-10-21): the engine opens its choices
    # window for any row that has a status check, so the Steel Apps rows
    # (Installed / Not installed pill, plus one script) showed a window with
    # only Close and never installed anything. A row with its own script and
    # no choices runs the script straight away; the pill stays.
    modal = """    def action_uses_modal(self, action):
        \"\"\"Return True when the action should open the management modal.\"\"\"
        if self.get_action_options(action):
            return True
        return bool((action.get('status_script') or "").strip())
"""
    if s.count(modal) == 1:
        s = s.replace(modal, """    def action_uses_modal(self, action):
        \"\"\"Return True when the action should open the management modal.\"\"\"
        if self.get_action_options(action):
            return True
        if (action.get('script') or "").strip():
            return False   # Steel OS: a row with its own script runs on one click
        return bool((action.get('status_script') or "").strip())
""")
        print("Steel OS Portal: one-click rows run their script instead of opening a choices window")
    else:
        sys.exit("Steel OS Portal: the engine's action_uses_modal changed; one-click rows would open a choices window")
    open(p, "w").write(s)
    compile(s, p, "exec")
    print("Steel OS Portal: buttons that open an app start it without a terminal")
else:
    print("Steel OS Portal: WARNING engine changed; every button still opens a terminal")
PYEOF2
# The one-click install window the Steel Apps rows use.
chmod 0755 /usr/libexec/steel-os-app
if grep -qi bazzite "$PORTAL_ENGINE"; then
    echo "Steel OS Portal: the engine still mentions Bazzite:" >&2
    grep -ni bazzite "$PORTAL_ENGINE" >&2
    exit 1
fi
# The Portal's own icon (branding/portal), used by its launcher and, under
# the engine's name, for its window.
install -D -m 0644 /ctx/branding/portal/steel-os-portal.svg \
    /usr/share/icons/hicolor/scalable/apps/steel-os-portal.svg
install -D -m 0644 /ctx/branding/portal/steel-os-portal.svg \
    /usr/share/icons/hicolor/scalable/apps/io.github.ublue_os.yafti_gtk.svg
mkdir -p /usr/share/steel-os
STEEL_OS_NVIDIA="$([[ -n "$variant" ]] && echo 1 || echo 0)" python3 /ctx/portal/make-portal.py /ctx/packages/steel-apps.txt /ctx/portal/base.yml \
    /usr/share/steel-os/portal.yml
# At a new user's first login the Steel OS Setup steps run first
# (/usr/libexec/steel-os-setup, STEEL-35) and end by offering to open the
# Portal. The Portal is in the start menu, the favorites and on the taskbar;
# its "Launch at startup" switch makes it open at every login.
# Steel & Code Forge one-click install (STEEL-25): the installer script, the
# package address it uses, and a check that what it needs is in the image.
install -D -m 0644 /ctx/packages/forge-source.txt /usr/share/steel-os/forge-source
chmod 0755 /usr/libexec/steel-os-forge
python3 -c 'import sys, venv, ensurepip; sys.exit(0 if sys.version_info >= (3, 11) else 1)'     || { echo "Steel OS: Python 3.11+ with venv is needed for Forge" >&2; exit 1; }
echo "Steel OS: Forge prerequisites present ($(python3 --version), curl, tar)"
chmod 0755 /usr/libexec/steel-os-setup /usr/libexec/steel-os-help /usr/libexec/steel-os-help-server

# One installer for every PC (STEEL-30): at boot, move the PC to the Steel OS
# edition that matches its graphics card, then ask for a restart at login.
chmod 0755 /usr/libexec/steel-os-graphics-check /usr/libexec/steel-os-graphics-notice
systemctl enable steel-os-graphics-check.service
rm -f /etc/skel/.config/autostart/steel-os-portal.desktop
for f in /usr/share/plasma/shells/org.kde.plasma.desktop/contents/updates/bazzite-pins.js \
         /usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js; do
    [[ -f "$f" ]] || continue
    if grep -q 'steel-os-portal\.desktop' "$f"; then continue; fi
    sed -i 's|"applications:org.kde.konsole.desktop",|"applications:org.kde.konsole.desktop",\n                    "applications:steel-os-portal.desktop",|' "$f"
    grep -q 'steel-os-portal.desktop' "$f" && echo "Steel OS Portal pinned in $f" || echo "Steel OS Portal: no Konsole pin found in $f"
done
# Taskbar for new users (T, 2026-10-17): Firefox, Steel OS Portal, file
# manager, App Store, Steel Shield, Steam, Lutris and the terminal, in that
# order, next to the start button. Anyone can pin or unpin more.
# The four desktop boxes (Super+1 to 4) move from beside the start button to
# beside the clock, numbered, so they don't look like empty taskbar spots.
# Steam stays installed and on the taskbar, but no longer starts by itself at
# login (T, 2026-10-17): the base image launched it silently at every login,
# and its first-run download got in the way while people set up their PC.
rm -f /etc/skel/.config/autostart/steam.desktop /etc/xdg/autostart/steam.desktop
STEEL_PINS='"preferred://browser", "applications:steel-os-portal.desktop", "preferred://filemanager", "applications:io.github.kolunmi.Bazaar.desktop", "applications:steel-shield.desktop", "applications:steam.desktop", "applications:net.lutris.Lutris.desktop", "applications:org.kde.konsole.desktop"'
for f in /usr/share/plasma/shells/org.kde.plasma.desktop/contents/updates/bazzite-pins.js \
         /usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js; do
    [[ -f "$f" ]] || continue
    STEEL_PINS="$STEEL_PINS" python3 - "$f" <<'PYEOF'
import os, re, sys
p = sys.argv[1]
s = open(p).read()
new, n = re.subn(r'writeConfig\("launchers",\s*\[[^\]]*\]\)',
                 'writeConfig("launchers", [' + os.environ["STEEL_PINS"] + '])', s)
open(p, "w").write(new)
print(f"Steel OS taskbar pins set in {p}: {n}")
PYEOF
done
LAYOUT=/usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js
if grep -q '^panel.addWidget("org.kde.plasma.pager")' "$LAYOUT" && grep -q '^panel.addWidget("org.kde.plasma.systemtray")' "$LAYOUT"; then
    sed -i '/^panel.addWidget("org.kde.plasma.pager")$/d' "$LAYOUT"
    sed -i 's|^panel.addWidget("org.kde.plasma.systemtray")$|var steelPager = panel.addWidget("org.kde.plasma.pager")\nsteelPager.currentConfigGroup = ["General"]\nsteelPager.writeConfig("displayedText", "Number")\npanel.addWidget("org.kde.plasma.systemtray")|' "$LAYOUT"
    echo "Steel OS: desktop switcher moved next to the clock"
else
    echo "Steel OS: WARNING default panel layout changed; desktop switcher left where it is"
fi
grep -n 'addWidget' "$LAYOUT" | head -12

# Start menu favorites for new users: the Steel OS Portal replaces
# Bazzite Portal in the list Bazzite ships.
FAVS=/usr/share/kde-settings/kde-profile/default/xdg/kicker-extra-favoritesrc
if [[ -f "$FAVS" ]]; then
    sed -i 's/io\.github\.ublue_os\.yafti_gtk\.desktop/steel-os-portal.desktop/' "$FAVS"
    grep -q 'steel-os-portal\.desktop' "$FAVS" \
        || sed -i 's/^Prepend=\(.*\)$/Prepend=\1steel-os-portal.desktop;/' "$FAVS"
    grep '^Prepend=' "$FAVS"
fi

# The App Store's Curated page: Steel Apps by category first, then the
# picks the base image already had (build_files/portal/make-bazaar.py).
BAZAAR_CONTENT=/usr/share/ublue-os/bazaar/content.yaml
mkdir -p "$(dirname "$BAZAAR_CONTENT")"
python3 /ctx/portal/make-bazaar.py /ctx/packages/steel-apps.txt "$BAZAAR_CONTENT" "$BAZAAR_CONTENT.new"
mv "$BAZAAR_CONTENT.new" "$BAZAAR_CONTENT"

# Bazzite's offline "Documentation" app shows Bazzite's manual. Hidden until
# Steel OS has its own help pages.
for f in /usr/share/applications/bazzite-documentation.desktop; do
    [[ -f "$f" ]] || continue
    grep -q '^NoDisplay=' "$f" && sed -i 's/^NoDisplay=.*/NoDisplay=true/' "$f" \
        || sed -i '/^\[Desktop Entry\]/a NoDisplay=true' "$f"
done

# Notifications from the system tools (for example after adding a media app)
# carry the Steel OS name, not Bazzite's.
grep -rl -- '--app-name=Bazzite' /usr/share/ublue-os/just 2>/dev/null \
    | xargs -r sed -i 's/--app-name=Bazzite/--app-name="Steel OS"/g'

gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true

### 17. Forgotten password: security questions and a reset from the login screen (STEEL-36)
# Design: docs/password-recovery-design.md. Optional security questions (set
# up in Steel OS Setup or the Portal) let a user reset a forgotten password:
# "Forgot your password?" on the login screen restarts the PC into a reset
# window that checks the answers and sets a new password.
# "Report a problem or idea": a window that sends a report, with an optional
# screenshot and computer details, to steel-os.org/api/report.
chmod 0755 /usr/libexec/steel-os-report /usr/libexec/steel-os-my-reports /usr/libexec/steel-os-share-printers

chmod 0755 /usr/libexec/steel-os-recovery-crypt /usr/libexec/steel-os-recovery-enrol \
    /usr/libexec/steel-os-recovery-setup /usr/libexec/steel-os-recovery-reset \
    /usr/libexec/steel-os-recovery-reset-ui

# Self-test: answers hash with yescrypt and check correctly, or the build stops.
selftest_hash="$(printf ' New  York ' | /usr/libexec/steel-os-recovery-crypt hash)"
[[ "$selftest_hash" == '$y$'* ]] || { echo "Steel OS recovery: yescrypt hashing failed" >&2; exit 1; }
printf 'new york' | /usr/libexec/steel-os-recovery-crypt verify "$selftest_hash" \
    || { echo "Steel OS recovery: a correct answer was rejected" >&2; exit 1; }
if printf 'boston' | /usr/libexec/steel-os-recovery-crypt verify "$selftest_hash"; then
    echo "Steel OS recovery: a wrong answer was accepted" >&2
    exit 1
fi
echo "Steel OS recovery: answer hashing self-test passed"

# Login manager. Fedora 44's KDE uses Plasma Login Manager, whose login screen
# is compiled into the program, so it can't carry the "Forgot your password?"
# button. Steel OS uses SDDM with the Breeze theme instead (both still part of
# Fedora; packages/image.txt), and Plasma Login Manager is switched off.
if [[ -f /usr/lib/systemd/system/sddm.service ]]; then
    systemctl disable plasmalogin.service 2>/dev/null || true
    ln -sf /usr/lib/systemd/system/sddm.service /etc/systemd/system/display-manager.service
    echo "Steel OS: login manager is SDDM"
else
    echo "Steel OS: WARNING sddm is not installed; keeping the base image's login manager"
    rpm -q sddm sddm-breeze plasma-login-manager 2>&1 || true
fi

# The login screen: Breeze plus "Forgot your password?". If Breeze's layout
# ever changes so the button can't be added, the plain theme stays and the
# reset service is not switched on.
if python3 /ctx/sddm/make-login-theme.py | tee /dev/stderr | grep -qx OK; then
    # Keep whatever greeter environment the base image sets; add file writes
    # for the reset note.
    GREETER_ENV="$(grep -h '^GreeterEnvironment=' /usr/lib/sddm/sddm.conf.d/*.conf \
        /etc/sddm.conf.d/*.conf /etc/sddm.conf 2>/dev/null | tail -1 | cut -d= -f2- || true)"
    mkdir -p /etc/sddm.conf.d
    printf '%s\n' \
        "# Steel OS (STEEL-36): Steel OS login theme with \"Forgot your password?\"." \
        "[Theme]" \
        "Current=steel-os" \
        "" \
        "[General]" \
        "GreeterEnvironment=${GREETER_ENV:+${GREETER_ENV},}QML_XHR_ALLOW_FILE_WRITE=1" \
        > /etc/sddm.conf.d/zz-steel-os.conf
    if [[ -f /etc/sddm.conf ]] && grep -q '^Current=' /etc/sddm.conf; then
        sed -i 's/^Current=.*/Current=steel-os/' /etc/sddm.conf
    fi
    cat /etc/sddm.conf.d/zz-steel-os.conf
    systemctl enable steel-os-recovery-reset.service
else
    echo "Steel OS recovery: WARNING login theme not changed; reset service not enabled"
    rpm -q sddm sddm-breeze plasma-login-manager 2>&1 || true
    ls -la /usr/share/sddm/themes 2>&1 || true
    readlink -f /etc/systemd/system/display-manager.service || true
fi

### 18. Updates and security (STEEL-27, STEEL-49, STEEL-47, STEEL-23)
# Policy in docs/security-policy.md. The system updates on Tuesday (uupd.timer,
# see section 4 / system_files); apps update every day; an update that is
# waiting shows "Restart to finish updating"; only signed Steel OS images are
# accepted; and an urgent fix can reach PCs the same day.
chmod 0755 /usr/libexec/steel-os-update-notice /usr/libexec/steel-os-signed-updates \
    /usr/libexec/steel-os-urgent-update /usr/libexec/steel-os-night-restart /usr/libexec/steel-os-update-now \
    /usr/libexec/steel-os-update-retry
systemctl enable steel-os-app-updates.timer steel-os-signed-updates.service \
    steel-os-urgent-update.timer steel-os-night-restart.timer
systemctl --global enable steel-os-app-updates.timer steel-os-update-notice.timer steel-os-night-restart.timer
# Restart at night to finish an update (T, 2026-10-18), and "Update now" in
# the Portal without a password or terminal: polkit lets an administrator at
# the computer start uupd.service (system_files/usr/share/polkit-1/rules.d).
systemctl cat uupd.service >/dev/null || { echo "Steel OS: uupd.service is missing" >&2; exit 1; }

# Only images signed with the Steel OS key are accepted from
# ghcr.io/steel-and-code (all three editions). Bazzite's own entries stay.
POLICY=/etc/containers/policy.json
[[ -f "$POLICY" ]] || echo '{"default":[{"type":"reject"}],"transports":{"docker":{}}}' > "$POLICY"
jq '.transports.docker["ghcr.io/steel-and-code"] = [{
        "type": "sigstoreSigned",
        "keyPath": "/etc/pki/containers/steel-os.pub",
        "signedIdentity": {"type": "matchRepository"}
    }]' "$POLICY" > "$POLICY.new"
mv "$POLICY.new" "$POLICY"
jq -e '.transports.docker["ghcr.io/steel-and-code"][0].type == "sigstoreSigned"' "$POLICY" >/dev/null
test -s /etc/pki/containers/steel-os.pub
jq -c '.transports.docker | keys' "$POLICY"

### 19. Printers, scanners and Windows networking (STEEL-38, STEEL-39)
# Packages in packages/image.txt. Here: switch the services on.
# - Network printers that support driverless printing are added by themselves.
# - Steel OS shows up in Windows Explorer's Network (wsdd).
# - Windows file sharing starts only when a folder is shared (path unit), and
#   the firewall lets file sharing through so Windows PCs can reach it.
chmod 0755 /usr/libexec/steel-os-sharing-users
for unit in cups.socket cups-browsed.service wsdd.service steel-os-file-sharing.path steel-os-sharing-users.service; do
    if systemctl list-unit-files "$unit" >/dev/null 2>&1; then
        systemctl enable "$unit"
    else
        echo "Steel OS: $unit not found"
    fi
done
if command -v firewall-offline-cmd >/dev/null 2>&1; then
    zone="$(firewall-offline-cmd --get-default-zone)"
    for svc in samba samba-client mdns ipp-client ws-discovery ws-discovery-client; do
        firewall-offline-cmd --zone="$zone" --add-service="$svc" >/dev/null 2>&1 \
            && echo "Steel OS firewall: $svc allowed in $zone" \
            || echo "Steel OS firewall: $svc not available in this firewalld"
    done
fi
rpm -q hplip gutenprint-cups printer-driver-brlaser ipp-usb sane-airscan skanpage samba-usershares kdenetwork-filesharing wsdd || true
# A USB printer plugged in again is found again (udev rule + service).
test -f /usr/lib/udev/rules.d/90-steel-os-usb-printer.rules
systemctl cat steel-os-usb-printer-rediscover.service >/dev/null
# A removed printer (USB or network) is found again within two minutes.
chmod 0755 /usr/libexec/steel-os-printer-rediscover
systemctl enable steel-os-printer-rediscover.timer

### 20. Gaming devices and game fixes (STEEL-32, STEEL-45, STEEL-46)
# Drivers for the Xbox wireless adapter, Razer devices and racing wheels come
# with Bazzite. Steel OS adds the tools (packages/image.txt, Steel Apps), the
# flight-stick access rules (system_files/usr/lib/udev/rules.d), the Portal's
# Gaming tab, and one-click repairs for Star Citizen and Battle.net.
# Star Citizen's memory setting (vm.max_map_count) is already set higher than
# it needs by Bazzite (70-gaming.conf), so nothing is added for it.
chmod 0755 /usr/libexec/steel-os-lug-helper /usr/libexec/steel-os-repair-game

# Input Remapper (macros for keyboards, mice, keypads and controllers): Bazzite
# installs it but hides it and leaves it off. Steel OS shows it and turns it on,
# so saved macros load at every login.
for f in /usr/share/applications/input-remapper-gtk.desktop /etc/xdg/autostart/input-remapper-autoload.desktop; do
    [[ -f "$f" ]] || continue
    sed -i '/^NoDisplay=true$/d; /^Hidden=true$/d' "$f"
done
if [[ -f /usr/share/applications/input-remapper-gtk.desktop ]]; then
    sed -i 's/^GenericName=.*$//' /usr/share/applications/input-remapper-gtk.desktop
    sed -i '/^\[Desktop Entry\]/a GenericName=Keyboard, mouse and controller macros' /usr/share/applications/input-remapper-gtk.desktop
fi
systemctl enable input-remapper.service 2>/dev/null || echo "Steel OS: input-remapper.service not found"

# Plain-English names in the start menu.
for pair in "jstest-gtk.desktop|Controller and flight stick tester" \
            "io.github.antimicrox.antimicrox.desktop|Use a controller as keyboard and mouse" \
            "solaar.desktop|Logitech wireless devices"; do
    f="/usr/share/applications/${pair%%|*}"
    [[ -f "$f" ]] || continue
    sed -i '/^GenericName=/d' "$f"
    sed -i "/^\[Desktop Entry\]/a GenericName=${pair#*|}" "$f"
done
rpm -q input-remapper solaar libratbag-ratbagd antimicrox jstest-gtk steam-devices zenity || true
ls /usr/share/applications | grep -i -E "jstest|antimicro|solaar|input-remapper" || true

### 21. Steel Shield: built-in virus protection (STEEL-53)
# ClamAV with definitions from Cisco Talos, updated hourly. Steel Shield
# (/usr/bin/steel-shield) scans new downloads automatically, offers to scan
# USB drives, scans the home folder weekly, keeps a recoverable quarantine and
# explains findings in plain English. The scanner runs only while scanning.
chmod 0755 /usr/bin/steel-shield
install -D -m 0644 /ctx/branding/shield/steel-shield.svg /usr/share/icons/hicolor/scalable/apps/steel-shield.svg
gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true

# Definitions: hourly, from the official mirror. Fedora's sample line
# "Example" must not be active or freshclam refuses to run.
FRESHCLAM=/etc/freshclam.conf
if [[ -f "$FRESHCLAM" ]]; then
    sed -i -e 's/^Example/#Example/' -e '/^Checks /d' -e '/^DatabaseMirror /d' "$FRESHCLAM"
    printf '%s\n' "# Steel Shield (STEEL-53): check for new definitions every hour." \
        "Checks 24" "DatabaseMirror database.clamav.net" >> "$FRESHCLAM"
fi
systemctl enable clamav-freshclam.service

# Built-in definitions (T, 2026-10-18): today's definitions ship inside the
# image, so a new install is protected from the first boot, even offline,
# and the first online update only fetches what changed. The
# steel-shield-definitions service puts them in /var/lib/clamav at boot when
# nothing newer is there; the updater then keeps them current hourly. If the
# download fails here the build goes on (installs then download them at
# first boot, as before), with a warning in the log.
chmod 0755 /usr/libexec/steel-shield-system /usr/libexec/steel-shield-quarantine /usr/libexec/steel-shield-app
# The app window needs Qt for Python; check it loads, so a missing package
# shows up here instead of as the plain menus on a user's PC.
python3 -c 'import PySide6.QtSvgWidgets, PySide6.QtWidgets'     || { echo "Steel Shield: the app window can't load Qt for Python" >&2; exit 1; }
python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" /usr/libexec/steel-shield-app
# The scam checker (opt-in add-on, T 2026-10-19): rules only, tested against
# sample scams and ordinary mail; the build stops if a scam slips through or
# an ordinary message raises a false alarm.
chmod 0755 /usr/libexec/steel-shield-scamcheck
bash /ctx/tests/scamcheck/run.sh /usr/libexec/steel-shield-scamcheck
# The "Is this a scam?" button for Thunderbird: the same rules, packaged as
# an add-on. Steel Shield's "Add the button to Thunderbird" copies it into
# Thunderbird's profile. Versioned like Steel OS.
TB=/usr/share/steel-shield/thunderbird
sed -i "s/\"version\": \"[0-9.]*\"/\"version\": \"$(cat /usr/share/steel-os/version)\"/" "$TB/manifest.json"
python3 - "$TB" <<'PYEOF'
import sys, zipfile, os
d = sys.argv[1]
with zipfile.ZipFile("/usr/share/steel-shield/steel-shield-scamcheck.xpi", "w", zipfile.ZIP_DEFLATED) as z:
    for f in ["manifest.json", "scamcheck.js", "popup.html", "popup.js", "icon.svg"]:
        z.write(os.path.join(d, f), f)
PYEOF
rm -f "$TB/test-run.js"
ls -la /usr/share/steel-shield/steel-shield-scamcheck.xpi
SEED=/usr/share/steel-shield/definitions
mkdir -p "$SEED"
chown clamupdate:clamupdate "$SEED" 2>/dev/null || true
if timeout 900 freshclam --foreground --show-progress=no --datadir="$SEED" --config-file=/etc/freshclam.conf; then
    chown -R root:root "$SEED"
    chmod 0644 "$SEED"/*
    rm -f "$SEED"/freshclam.dat "$SEED"/*.tmp
    ls -la "$SEED"
    # Prove the built-in definitions load: the scanner must report millions of
    # known threats from them (the build stops otherwise). Detection and
    # quarantine are proved by the self-test below.
    known="$(clamscan -d "$SEED" /dev/null 2>&1 | sed -n 's/^Known viruses: *//p' || true)"
    echo "Steel Shield: built-in definitions hold ${known:-0} known threats"
    if (( ${known:-0} < 1000000 )); then
        echo "Steel Shield: the built-in definitions did not load" >&2
        clamscan -d "$SEED" /dev/null >&2 || true
        exit 1
    fi
else
    echo "Steel OS: WARNING could not download the built-in virus definitions; installs will download them at first boot"
    rm -rf "$SEED"
fi
systemctl enable steel-shield-definitions.service
systemctl --global enable steel-shield-downloads.service steel-shield-usb.path steel-shield-weekly.timer

# Behavior watching (STEEL-60): startup changes, file scrambling, hidden
# miners and newly runnable downloads, for every user; the extra threat list
# from abuse.ch, daily; and the optional "block dangerous websites" switch.
chmod 0755 /usr/libexec/steel-shield-guard /usr/libexec/steel-shield-dns /usr/libexec/steel-shield-extra
systemctl --global enable steel-shield-guard.service
systemctl enable steel-shield-extra.timer
/usr/libexec/steel-shield-guard selftest

# Self-test with the EICAR test file and a one-line definition, so the build
# proves scanning, detection and quarantine work without downloading the
# real definitions. Fails the build if anything is off.
st="$(mktemp -d)"
mkdir -p "$st/home/Downloads"
printf '%s' 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > "$st/home/Downloads/eicar.com"
printf '%s:%s:Win.Test.EICAR_HDB-1\n' "$(md5sum "$st/home/Downloads/eicar.com" | cut -d' ' -f1)" \
    "$(stat -c %s "$st/home/Downloads/eicar.com")" > "$st/test.hdb"
HOME="$st/home" XDG_DATA_HOME="$st/home/.local/share" XDG_STATE_HOME="$st/home/.local/state" \
    XDG_CONFIG_HOME="$st/home/.config" STEEL_SHIELD_DB="$st/test.hdb" \
    /usr/bin/steel-shield selftest-scan "$st/home/Downloads/eicar.com"
if [[ -e "$st/home/Downloads/eicar.com" ]] || ! ls "$st"/home/.local/share/steel-shield/quarantine/*/file >/dev/null 2>&1; then
    echo "Steel Shield self-test FAILED: the test file was not quarantined" >&2
    exit 1
fi
/usr/bin/steel-shield explain Win.Test.EICAR_HDB-1
/usr/bin/steel-shield explain Win.Trojan.Agent-12345
rm -rf "$st"
echo "Steel Shield self-test passed: test file detected and quarantined"

### Developer tools (Katana test): nvim from the image, zeditor opens the Zed
# Flatpak installed at first boot. The build fails if either command is missing.
chmod 0755 /usr/bin/zeditor
for c in nvim zeditor; do
    command -v "$c" >/dev/null || { echo "Steel OS: developer command $c is missing" >&2; exit 1; }
done
echo "Steel OS developer commands: $(command -v nvim) $(command -v zeditor)"

### 9. Rebuild the boot image so the boot splash shows Steel OS (STEEL-31)
# The logo shown while the machine starts is read from the initramfs, a small
# boot image Bazzite generated before our files were added. Our logo frames in
# /usr/share/plymouth/themes/spinner/ only appear once the initramfs is
# rebuilt. Same command Bazzite uses (its build_files/build-initramfs).
# Keep this the LAST section: anything copied in after it would not reach
# the boot screen.
# Steel OS boot screen (T, 2026-10-18): no spinning circle. The Steel OS logo
# sits at the bottom; the hexagon around the S turns slowly and the blue
# underscore blinks, like a text cursor. The theme's "throbber" (its spinner)
# becomes 90 frames of the logo: the hexagon turns a sixth of a turn per loop
# (it looks the same after 60 degrees, so the loop is seamless) and the
# underscore is on for 15 frames and off for 15, placed where the logo used
# to be. The separate logo (watermark) is removed so it isn't drawn
# twice, and messages such as "Preparing System" appear above the logo.
SPINNER=/usr/share/plymouth/themes/spinner
if [[ -f "$SPINNER/spinner.plymouth" ]]; then
    rm -f "$SPINNER"/throbber-*.png "$SPINNER/watermark.png"
    cp /usr/share/steel-os/plymouth/throbber-*.png "$SPINNER/"
    python3 - "$SPINNER/spinner.plymouth" <<'PYEOF'
import sys
path = sys.argv[1]
want = {"HorizontalAlignment": ".5", "VerticalAlignment": ".96", "MessageBelowAnimation": "false"}
lines = open(path).read().splitlines()
out, section, seen = [], "", set()
for line in lines:
    stripped = line.strip()
    if stripped.startswith("["):
        if section == "two-step":
            out.extend(f"{k}={v}" for k, v in want.items() if k not in seen)
        section = stripped.strip("[]")
    key = stripped.split("=", 1)[0]
    if section == "two-step" and key in want:
        line = f"{key}={want[key]}"
        seen.add(key)
    out.append(line)
if section == "two-step":
    out.extend(f"{k}={v}" for k, v in want.items() if k not in seen)
open(path, "w").write("\n".join(out) + "\n")
PYEOF
    echo "Steel OS boot screen: blinking logo"
    grep -E '^(ImageDir|HorizontalAlignment|VerticalAlignment|Watermark|MessageBelowAnimation)' "$SPINNER/spinner.plymouth"
    ls "$SPINNER" | grep -c '^throbber-'
else
    echo "Steel OS: WARNING the spinner boot theme is missing; boot screen unchanged"
fi

QUALIFIED_KERNEL="$(rpm -q --queryformat='%{evr}.%{arch}' kernel-core | tail -n 1)"
export DRACUT_NO_XATTR=1
/usr/bin/dracut --no-hostonly --kver "$QUALIFIED_KERNEL" --reproducible --zstd -v \
    --add ostree --add fido2 -f "/usr/lib/modules/$QUALIFIED_KERNEL/initramfs.img"
chmod 0600 "/usr/lib/modules/$QUALIFIED_KERNEL/initramfs.img"
