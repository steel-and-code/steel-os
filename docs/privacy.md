# Privacy

The same text as [steel-os.org/privacy](https://steel-os.org/privacy), kept
here so a change to what Steel OS sends is reviewed together with the words
that describe it. Updated 20 October 2026.

**The short version.** Steel OS has no account, no advertising and no
tracking. It never sells anything about you; there is nothing to sell. A few
things do leave the PC: updates and virus definitions coming in, anonymous
counts going out, and, with Steel Shield, a caught program shared with
malware researchers unless the person turns that off.

## What Steel OS sends by itself

| What | Where | What goes |
|---|---|---|
| Updates | GitHub (ghcr.io), Flathub, Fedora's mirrors | Ordinary downloads: the servers see the internet address, as every website does, and the version asked for. No account, no identifier. |
| Weekly count | Fedora's mirrors | Fedora's standard anonymous count (DNF Count Me), once a week with the update check: the Steel OS version and the age of the install in weeks, nothing else. It adds to the weekly check-in below. |
| Weekly check-in | downloads.steel-os.org | Once a week, and once ever on a PC's first start, a fetch of a tiny file (`ping/pc-active`, `ping/pc-new`) so the homepage can show how many PCs are active. No account, no identifier, nothing about the computer. Turn off with `sudo systemctl disable --now steel-os-checkin.timer`. |
| Virus definitions | ClamAV (Cisco Talos), downloads.steel-os.org | Downloads of the threat lists. Nothing about the person goes up. |
| Counts | downloads.steel-os.org | When Steel Shield quarantines a threat, shares a file or the person reports a scam, it fetches a tiny file (`ping/<name>`) so the numbers on steel-os.org/steel-shield go up by one. Steel Shield installed on its own, on another Linux system, does the same once on its first start (the "installs" number); on Steel OS it doesn't, because Fedora's weekly count already covers that. No file name, no email, nothing else. |
| Time | Fedora's time servers | Clock synchronization. |

## What Steel Shield sends

- Nothing about files or scans, with one automatic exception and two things
  the person does by hand.
- **Sharing caught programs with researchers (automatic, can be turned
  off):** when Steel Shield quarantines a program, installer or script from
  the person's own folders, it sends that one file to abuse.ch's
  MalwareBazaar so everyone's protection improves. It first asks whether they
  already have the file; if so nothing is sent. The upload is anonymous and
  goes through steel-os.org (`/api/sample-share`), which holds the abuse.ch
  key; the file becomes public there. Documents, pictures, music, videos and
  archives are never shared; nothing from the system quarantine is shared.
  Steel Shield tells the person each time. Off: Steel Shield, Status,
  **Sharing with researchers**, Turn off (`steel-shield set share off`).
  Sharing by hand: Quarantine, **Share with researchers**.
- **Scam checker:** checked on the PC. Online, it asks Quad9 whether a link's
  website is a known scam site, sending only the website name. **Report this
  scam** (one click) sends the message, as received, to steel-os.org, which
  passes it straight on to Netcraft's reporting service and keeps nothing. The
  message is what they get: its sender, links and text, and the address it
  was sent to. Nothing about the person's PC goes with it, and the report is
  made in Steel Shield's name, not theirs. An email to the Anti-Phishing
  Working Group (APWG) opens as well, from the person's own mail app, and
  Google's report page with the scam link filled in, in their browser; nothing
  goes to APWG or Google unless they press Send or Submit.
- **Dangerous-website blocking (optional, off by default):** every app looks
  up website names through Quad9, which does not keep the address.

## Reports

**Report a problem** sends what was typed and, if the ticks stay on, the
screenshot or picture and the computer details shown in the window. It lands
in the team's private tracker; pictures are never made public. The person
gets a reference and a private link (My reports) to follow and reply.

## The website

steel-os.org runs on Cloudflare: aggregate statistics only, no tracking
cookies, no advertising. Fonts from Google Fonts. The Discord server is under
Discord's policy.

## Never

No account, no advertising, no tracking beyond the counts above, nothing
sold or passed on. Installed apps have their own policies.

## Keeping this true

Any change that makes Steel OS or Steel Shield send something new must
change this file and steel-os.org/privacy in the same pull request, and the
offline Help where the feature is explained.
