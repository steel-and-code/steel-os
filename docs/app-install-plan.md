# Application Installation Plan

Date: 2026-10-15 (rewritten the same day for the Bazzite decision)
Owners: BBE (which apps, what the user sees) and S&C (how each is installed)

**How this was researched.** Every app on BBE's list was checked against Flathub,
the Flatpak app store, on 2026-10-15. The earlier Omarchy-era version of this
plan checked the same apps against the Arch repositories; that work confirmed
the apps exist for Linux and is superseded by this version.

---

## 1. The one way to install apps

Product goal 4 says one install path, not five formats. On Bazzite this is
already true:

- **One format: Flatpak.** Apps come from Flathub, update on their own in the
  background, and run sandboxed. The system image never changes when an app is
  installed, which is why updates cannot break it.
- **One store: Discover.** Bazzite ships KDE's Discover app. It has a search
  box and an Install button. It is the Microsoft Store equivalent.

**What Steel OS adds: the Steel Apps list.** Discover shows thousands of apps.
A Windows user wants the dozen they know. Steel OS ships a short curated list
(`packages/steel-apps.txt`) with one row per approved app and one Install
button each. Installing is a Flatpak install from Flathub; nothing is hosted
by us.

**Found on first boot (BBE, 2026-10-16): Bazzite Portal already is that
screen.** Bazzite ships a "Bazzite Portal" window at first login with tabs for
Install Applications, Get Media Apps, Manage Bazzite, Tweak Systems and
Troubleshoot, each row with a one-line description and an install action, plus
its own store called Bazaar. So Steel OS does not build a Steel Apps screen.
It keeps Bazzite Portal, renames it, and adds a **Steel Apps** section at the
top with the must-haves from `steel-apps.txt`. Bazzite's own catalog (DaVinci
Resolve, Antigravity, CoolerControl, ASUS tools, and the media web apps such as
Prime Video, Apple TV, Disney Plus and HBO Max, which BBE asked to keep) stays
below it. How the Portal's list is defined in the image, and whether a section
can be added without patching Bazzite, is checked when the Steel Apps screen
is built.

No server is needed anywhere in this. Flathub hosts the apps. The list is a
text file inside the image.

### Why not the alternatives

| Option | Verdict |
|---|---|
| **Discover plus Flatpak plus a Steel Apps list** | **Chosen.** Already built, one format, sandboxed, auto-updating. |
| Install rpm packages into the image for every app | Rejected for apps. Bloats the image, every app update means a full image rebuild, and users cannot add their own. Used only for system pieces (WezTerm, printer drivers, wsdd). |
| A Steel OS store app built from scratch | Rejected. Discover does the job; the Steel Apps list is the only custom piece. |
| Omarchy's Install menu (the previous plan) | Gone with the base change. |

---

## 2. Where every app comes from

Three tiers. All Flatpak IDs below were confirmed on Flathub on 2026-10-15.

### Built into the image, or preinstalled on first boot (every machine)

| App | How | ID or package | Note |
|---|---|---|---|
| Konsole (terminal) | Part of Plasma on Bazzite | rpm, already present | Steel OS default terminal (decided 2026-10-16 by S&C and BBE). Alt+C / Alt+V copy and paste set by Steel OS. |
| LibreOffice (office) | Flatpak, first boot | `org.libreoffice.LibreOffice` | BBE's "Open Office". Opens Word, Excel, PowerPoint. |
| Firefox (default browser) | Flatpak, first boot | `org.mozilla.firefox` | Default browser (decided 2026-10-16). Bazzite already ships it. |
| Files (Dolphin), Ark (zip), Kate (editor), Okular (PDF, EPUB), Skanpage (scanner), Spectacle (screenshots), Gwenview (images) | Part of Plasma on Bazzite | rpm, already present | Confirm on first boot which are present; add missing ones to `packages/image.txt`. |
| Steam | Already in Bazzite | native | Bazzite's reason to exist. |
| OBS Studio | Flatpak, one click (Steel Apps) | `com.obsproject.Studio` | Screen capture works on Plasma Wayland. One click since 2026-10-18. |
| Kdenlive (video editor) | Flatpak, one click (Steel Apps) | `org.kde.kdenlive` | The offline video editor. One click since 2026-10-18. |
| Obsidian | Flatpak, first boot | `md.obsidian.Obsidian` | |
| Moonlight (game streaming) | Flatpak, one click (Steel Apps) | `com.moonlight_stream.Moonlight` | One click since 2026-10-18. |
| Zed (editor) | Flatpak, first boot | `dev.zed.Zed` | |
| Discover (store) | Part of Plasma on Bazzite | rpm | The store. |

### One click from the Steel Apps list

| App | ID | Note |
|---|---|---|
| Google Chrome | `com.google.Chrome` | One click; Firefox is the default (decided 2026-10-16). |
| WezTerm | `org.wezfurlong.wezterm` | One click; Konsole is the default (decided 2026-10-16). |
| Slack | `com.slack.Slack` | BBE's must-have |
| Zoom | `us.zoom.Zoom` | BBE's must-have. The full desktop client, no web-app workaround needed. |
| Dropbox | `com.dropbox.Client` | BBE's must-have. Tray icon works on Plasma. |
| Discord | `com.discordapp.Discord` | BBE's must-have |
| Thunderbird (email, the Outlook equivalent) | `org.mozilla.Thunderbird` | BBE's request (2026-10-16). Email, calendar, contacts in one app; connects to Outlook.com, Microsoft 365 and Gmail accounts. Outlook itself has no Linux version; its web version can also be added as a Chrome app. |
| GIMP (Photoshop equivalent) | `org.gimp.GIMP` | |
| Krita (painting; the Artweaver equivalent) | `org.kde.krita` | |
| Inkscape (vector drawing) | `org.inkscape.Inkscape` | |
| KolourPaint (MS Paint equivalent) | `org.kde.kolourpaint` | |
| Audacity (audio) | `org.audacityteam.Audacity` | |
| VS Code | `com.visualstudio.code` | The Flatpak works for most people. Developers who hit sandbox limits can use S&C's Distrobox route instead; note in the dev guide. |
| NotepadNext (Notepad++ remake) | `com.github.dail8859.NotepadNext` | Notepad++ itself is Windows-only. Kate is built in. |
| Shotcut (simple video editor) | `org.shotcut.Shotcut` | |
| Calibre (ebook library) | `com.calibre_ebook.calibre` | |
| Foliate (ebook reader) | `com.github.johnfactotum.Foliate` | Okular, built in, also opens EPUB. |
| Lutris (EA app, Ubisoft, other Windows stores) | `net.lutris.Lutris` | How the EA app and Battle.net are installed. Bazzite documents this path. |
| Heroic (Epic, GOG, Amazon) | `com.heroicgameslauncher.hgl` | |
| GeForce NOW (cloud gaming) | `io.github.hmlendea.geforcenow-electron` | |
| Steel & Code Forge | not packaged yet | S&C's AI development platform, packaged by S&C. Ships with Python runtimes inside; wants a container runtime (Bazzite has Podman) and NVIDIA support (the NVIDIA image). |
| Ollama (local AI models) | to decide: Flatpak, Homebrew, or container | Optional, like Forge. |

### Web apps (no Linux program exists)

| App | How |
|---|---|
| CapCut | capcut.com/editor in Firefox, or Chrome's "install as app" for an app-style window. Kdenlive is the offline editor. |
| Xbox Cloud Gaming | xbox.com/play in Firefox, or Chrome's "install as app". **Cloud streaming only**: PC Game Pass downloads are impossible on Linux. Say so plainly. |

### Things with no Linux version, and their stand-ins

| Asked for | Stand-in |
|---|---|
| Outlook | Thunderbird (one click), or Outlook on the web as a Chrome app |
| Notepad++ | NotepadNext (one click) or Kate (built in) |
| Artweaver | Krita |
| CapCut | Web editor, or Kdenlive |
| NAPS2 | No Flatpak exists. Skanpage is built in and covers scanning. NAPS2 publishes an rpm that could be layered into the image if BBE insists; not recommended. |
| Local Xbox Game Pass | Cloud streaming only |

---

### Blackbox Entertainment's own apps: Crew and Voxlore

BBE plans to ship Crew and Voxlore as Electron apps with a local AI stack, sold
on Steam. They will run on Steel OS if two things are true, and both are in
Blackbox's hands, not Steel OS's:

1. **Ship a Linux build on Steam.** Electron builds for Linux the same way it
   builds for Windows. Steam delivers it natively, and it also runs on Steam
   Deck, whose users are the largest Linux gaming audience. Without a Linux
   build, Steam will try the Windows build through Proton, which works for
   many Electron apps but is not something to rely on for a local AI stack.
2. **Make the AI stack GPU-portable.** On Linux, NVIDIA cards can use CUDA
   (Steel OS's NVIDIA image carries the driver), but AMD and Intel cannot. A
   stack built on Vulkan (for example llama.cpp's Vulkan backend) runs on all
   three. A CUDA-only stack would work only on NVIDIA machines.

Steel OS adds nothing special for them; they are Steam games as far as the OS
is concerned. The VM BBE is setting up is a good first test bed for the Linux
builds, and the physical test machine for GPU acceleration.

## 3. Developer tools

Bazzite's system image is read-only, so developer tools do not go in the
image either. Bazzite ships Homebrew and Distrobox for this, which is how
S&C would work:

- `packages/brew.txt`: tools installed through Homebrew on request (jq, fd,
  lazygit, lazydocker, github-cli, mise for Python and Node versions,
  docker-compose). git and ripgrep are in the image itself (`image.txt`).
- Docker: Bazzite ships Podman, which runs Docker-style containers and can
  provide a `docker` command. Docker Engine itself can be added to the image
  if Forge needs it.
- The "Developer setup" entry at the top of the Portal's Developer tab runs the
  Homebrew installs in one go (built 2026-10-24, `build_files/portal/make-portal.py`).

---

## 4. The package list files

The Omarchy-era lists (`core.txt`, `development.txt`, `optional.txt`,
`excluded.txt`, `review.txt`) are replaced by lists that match how a Bazzite
image is built:

| File | Read by | Contents |
|---|---|---|
| `packages/image.txt` | `build.sh` at image build | rpm packages added to the system image: printer drivers, wsdd, anything Plasma lacks |
| `packages/flatpaks-default.txt` | first-boot script | Flatpaks installed on every machine |
| `packages/steel-apps.txt` | the Steel Apps screen | One-click catalog: Flatpak ID, display name, one-line description |
| `packages/brew.txt` | the developer setup entry | Homebrew tools |
| `packages/remove.txt` | `build.sh` | Things Bazzite ships that Steel OS removes; filled in after the first boot |

Every line is a real, verified identifier, with a `#` comment above anything
unusual.

---

## 5. Decisions carried over from the Omarchy plan

- Browser and terminal defaults reversed on 2026-10-16: Firefox and Konsole are the defaults; Chrome and WezTerm are one click. LibreOffice kept.
- The old chromium, xournalpp, foot, HEY, Basecamp removals no longer apply;
  those were Omarchy packages. `remove.txt` starts empty and is filled after BBE
  boots the first image and lists what Bazzite preinstalls that we do not want.
- Zoom: the desktop client is a proper Flatpak now, so no web-app workaround.
- Slack, Dropbox, Firefox, office suite, NAPS2 (as Skanpage), zip, Notepad++
  (as Kate and NotepadNext), Discord, Steam with EA and Xbox cloud, Audacity,
  GIMP, Krita, Inkscape, KolourPaint, VS Code, CapCut, ebook readers: all
  covered above.

---

## 6. Verification

- Flathub check: done 2026-10-15 for every ID in section 2 (HTTP 200 from
  Flathub's app database). NAPS2 and the first guess at NotepadNext's ID came
  back missing; NotepadNext was found under `com.github.dail8859.NotepadNext`,
  NAPS2 has no Flatpak.
- **Not done at the time:** booting a Steel OS image.
- **Not done at the time:** confirming which KDE apps Bazzite already includes.

---

## 7. Follow-up tickets

1. **First-boot Flatpak install and default browser**:
   install `flatpaks-default.txt` on first login, confirm Firefox is default,
   idempotent.
2. **Steel Apps section in Bazzite Portal** (new, phase 4): add the
   `steel-apps.txt` entries as a section at the top of Bazzite Portal's
   Install Applications tab, rename the window to Steel OS, keep the rest.
3. **Developer setup entry** (phase 4, done 2026-10-24): Homebrew installs from `brew.txt`.
4. **remove.txt after first boot**: list and remove what
   we do not want.
5. **Forge packaging**.
