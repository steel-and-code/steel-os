# Security patch policy

Updated: 2026-10-17. Proposed by Blackbox Entertainment (BBE). Steel & Code
(S&C) approves it by merging the pull request that adds this file.

How fast a security fix from Fedora or Bazzite reaches a Steel OS PC, and what
happens when a fix can't wait.

---

## The normal path

| Step | When |
|---|---|
| Fedora publishes a fix | Usually within days of the upstream fix |
| Bazzite rebuilds its `stable` image with it | Bazzite's regular schedule |
| Steel OS rebuilds all three editions from the newest Bazzite `stable` | Every day at 10:05 UTC, and after every merged change. Every image is signed |
| PCs download the new system | **Every Tuesday just after midnight**, or at the next start if the PC was off |
| The new system takes effect | At the next restart. Steel OS shows "Restart to finish updating" |
| Apps (Flatpaks), including Firefox | **Every day**, in the background, with no restart |

**Worst case for a system fix:** about a week after Bazzite ships it. System
fixes almost always need a restart anyway, and one predictable restart a week
is the Tuesday promise. Apps, where most urgent browser fixes land, update
daily.

**No holding period.** Steel OS does not hold Bazzite's images for its own
extra test. Bazzite already tests `stable`, and Steel OS's layer is thin. If a
bad image ever ships, the previous version is always in the boot menu, and the
next fix ships the same way.

## Only signed updates

Every image is signed with the Steel OS key. PCs check each update against the
public key in `/etc/pki/containers/steel-os.pub`, as `/etc/containers/policy.json`
requires, and refuse anything unsigned or signed by anyone else. The build
checks every new signature with that same public key before PCs can see it.

## Emergency: a fix that can't wait for Tuesday

Use it when a flaw is being actively exploited and affects Steel OS users, and
only then.

1. **Rebuild.** On GitHub, open Actions, then **Build container image**, then
   **Run workflow** on `master`. Wait for all three editions to be green and
   signed, about 15 minutes. If the fix needs a change in Steel OS itself,
   merge that pull request instead; the merge rebuilds.
2. **Announce.** In the website repo, add `releases/urgent.json`:
   ```json
   {"id": "2026-11-03-short-name", "message": "One plain-English sentence about the fix."}
   ```
   Use a new `id` every time, then merge it.
3. **What PCs do.** Every six hours each PC reads that file. A new `id` makes
   it download the update straight away, signed like any other, and show
   **Important update: please restart soon** with **Restart now** and
   **Later**.
4. **Afterwards.** Leave the file in place, because PCs act on each `id` only
   once. Post a short note on steel-os.org.

**Who can do it:** S&C or BBE. Both have to agree, unless one of them can't be
reached within a few hours.

## Not covered here

- Firmware updates arrive with the Tuesday update, through Bazzite's updater.
- Antivirus definitions update hourly, once Steel Shield ships.
