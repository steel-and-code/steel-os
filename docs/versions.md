# Steel OS version numbers

Every Steel OS build has a version like **1.3.12**, and every merge to
`master` counts one up. The last number rolls over after 999:

1.3.0, 1.3.1 ... 1.3.999, **1.4.0**, 1.4.1 ... 1.9.999, **2.0.0**

The middle number rolls over after 9 into the first: 1.9.999 is followed by
2.0.0, never 1.10.0. Until 1.3 the last number rolled over after 9 (1.2.9 was
followed by 1.3.0); those earlier versions keep their numbers.

- The `VERSION` file at the top of this repository holds the starting point
  (now `1.3`). Counting starts from it: the first build after `VERSION`
  changes is that number with `.0` (for example 1.3.0).
- `VERSION` can also be raised by hand (a one-line pull request) to start a
  new series at once, as was done for 1.0 on 20 October 2026 and 1.3 on
  3 November 2026.

The version shows in **About this System** ("Steel OS 1.3.12"), on the
installer's information panel, in `/usr/share/steel-os/version`, in the
installer's file name (`steel-os-1.3.12-x86_64.iso`) and `.image.txt` record,
and in the list of builds on steel-os.org/download.

A daily rebuild on Bazzite's newest base (Fedora's updates) **keeps the
version**: when the base images have changed, the **Daily rebuild** workflow
records it on `master` (`packages/base-images.txt`, a plain commit, not a
merge), the image and installer are rebuilt with the same version number and a
newer build date (`/usr/share/steel-os/build`, `YYYYMMDD-commit`), and the
installer replaces the one with the same name. A year of rebuilds with no
changes is still the same version. When nothing changed upstream, nothing is
built. Rebuilds are not announced on Discord; new versions are.

An **important** change underneath is the exception: a new Fedora version, a
new Linux kernel series, a new KDE Plasma series, a new Mesa (graphics driver)
series, a new NVIDIA driver series, or an urgent Fedora security fix for a
package in the image. Then the Daily rebuild records it as a merge (made by the
bot, no pull request) titled in plain English, for example "Under the hood:
Fedora 45 and Linux kernel 7.3". That counts the version up like any merge, so
it shows in "What's new" on steel-os.org and is announced on Discord.
`.github/scripts/upstream-notes.py` decides, from the base's own release notes
and Fedora's update system; `packages/upstream.json` remembers what was
underneath at the last check.

Every installer is built from the exact image of the merge that triggered it.
When several merges land while an installer is building, only the newest one
gets an installer, so the list on steel-os.org/download can skip a number.

## The road to 1.0

| Version | When |
|---|---|
| 0.4.x to 0.9.x | Counts up by itself with every merge: tester fixes and features |
| **1.0** | The release checklist passes, a stranger installs from the guide alone, and the main Download button goes live. Change `VERSION` to `1.0` |

## Release notes

Every installer build also publishes `release-notes.json` on
downloads.steel-os.org (made by `.github/scripts/release-notes.py`): one entry
per version with its date and pull request title, plus the dates it was
rebuilt on. steel-os.org/preview shows it as **What's new**. So a pull request's title is its release note: write it
in plain English, for people using Steel OS.
