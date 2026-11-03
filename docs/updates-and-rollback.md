# Updates and rollback

Updated: 2026-10-17

How a Steel OS machine stays up to date, and how to go back if an update causes
a problem.

---

## How updates reach a machine

```
Fedora and Bazzite publish fixes
        │
Steel OS image rebuilt automatically every day from Bazzite stable,
and after every merged change (GitHub Actions; signed)
        │
Each machine downloads the newest image in the background on Tuesday just after midnight
        │
The new image takes effect at the next restart
        │
The previous image stays in the boot menu
```

- **One image, not hundreds of packages.** The whole operating system is one
  tested image. An update replaces it as a unit, so a machine is never left
  half-updated.
- **When:** every **Tuesday just after midnight** local time. If the machine was off, the
  update runs at the next boot. A random delay of up to 15 minutes spreads the
  load. Set in `system_files/etc/systemd/system/uupd.timer.d/steel-os-tuesday.conf`.
- **What:** the system image, Flatpak apps and firmware, in one run of
  Bazzite's `uupd` updater.
- **Applying it:** the new image takes effect at the next restart. Nothing
  changes under a running session.
- **Signed:** every published image is signed with the Steel OS key. The
  public half is in the image at `/etc/pki/containers/steel-os.pub`.

## Updating now instead of waiting

- In the **Steel OS Portal**, Welcome tab, click **Update now**.
- Or in the terminal: `sudo bootc upgrade`, then restart.
- `sudo bootc status` shows the running image, the backup image and whether an
  update is waiting.

## Going back

- **At the boot menu,** pick the previous entry. It is the image from before
  the last update.
- **From the terminal:** `sudo bootc rollback`, then restart.
- **From the Portal:** Troubleshoot tab, **Roll back to the previous Steel OS
  version**.

Rolling back changes only the system. Files, settings and apps in the home
folder are kept.

## Apps, notices, signatures and emergencies

- **Apps update every day,** quietly, on mains power. The system still updates
  only on Tuesday. Apps don't need a restart, so their fixes, above all
  Firefox's, don't wait a week.
- **"Restart to finish updating".** When an update has been downloaded, a
  notification offers **Restart now** or **Later**. It appears at most once a
  day for the same update and never interrupts.
- **Only signed updates.** PCs accept Steel OS images only when they are signed
  with the Steel OS key, as `/etc/containers/policy.json` requires. PCs that
  were switched to Steel OS by hand are moved to signed updates automatically.
- **Emergencies.** A critical fix can reach PCs the same day: see
  [security-policy.md](security-policy.md).

## How to test (in a VM)

1. `systemctl list-timers uupd.timer` shows the next run on a Tuesday at about
   midnight.
2. Run `sudo bootc upgrade` and restart. `sudo bootc status` shows the new
   image booted and the old one as the rollback image.
3. Restart and pick the previous entry in the boot menu. The older image starts,
   and home-folder files are unchanged.
4. Run `sudo bootc rollback` and restart to return to the newer image.
