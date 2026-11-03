"""Write release-notes.json: what changed in each Steel OS version.

Every merge to master is one version (see docs/versions.md): the n-th merge
since VERSION last changed is MAJOR.(MINOR + n // 1000).(n % 1000), or n // 10
and n % 10 for the series before 1.3. The title of
each version is its pull request's title (the second paragraph of GitHub's
merge commit message), which is written in plain English. A daily rebuild (a
plain commit on master) keeps the version: it is listed as a "rebuilt" date
under the version it rebuilt. A daily rebuild with something important
underneath is a merge made by the bot (daily-rebuild.yml): a version of its
own, titled by its first line, with no pull request.

usage: release-notes.py OUTPUT [CURRENT_VERSION]
"""
import datetime
import json
import re
import subprocess
import sys


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout


out = sys.argv[1]
current = sys.argv[2] if len(sys.argv) > 2 else None


def version_of(major, minor, n):
    """The n-th merge since VERSION was set to major.minor. From 1.3 on the last
    number rolls over after 999 (1.3.999 -> 1.4.0, T 2026-11-03); the series
    before it rolled over after 9, and keep their numbers. The middle number
    always rolls into the first after 9 (1.9.999 -> 2.0.0)."""
    step = 1000 if (major, minor) >= (1, 3) else 10
    mt = minor + n // step
    return f"{major + mt // 10}.{mt % 10}.{n % step}"


def merges(rng):
    """[(sha, date, subject, body, is_merge)] oldest first for a git range."""
    log = git("log", "--first-parent", "--reverse", "--format=%H%x1f%cI%x1f%s%x1f%b%x1f%P%x1e", rng)
    out = []
    for rec in log.split("\x1e"):
        rec = rec.strip("\n")
        if rec:
            sha, date, subject, body, parents = rec.split("\x1f")
            out.append((sha, date, subject, body, len(parents.split()) > 1))
    return out


def title_of(subject, body):
    m = re.match(r"Merge pull request #(\d+)", subject)
    lines = [l for l in body.strip().splitlines() if l.strip() and not l.startswith("Co-Authored-By")]
    return (int(m.group(1)) if m else None), (lines[0] if m and lines else subject)


# Every commit that set VERSION, oldest first: each starts a series. The
# commit itself is that series' x.y.0 (the build at that commit counts zero
# merges), and the merges after it count up until the next VERSION change.
# The whole history stays in the list across version changes (T, 2026-10-20:
# the list was empty right after 1.0).
version_commits = [c for c in git("log", "--first-parent", "--reverse", "--format=%H", "--", "VERSION").split() if c]
entries = []
for i, vc in enumerate(version_commits):
    major, minor = (int(x) for x in git("show", f"{vc}:VERSION").strip().split(".")[:2])
    sha, date, subject, body, _ = merges(f"{vc}~1..{vc}")[0] if git("rev-list", "--count", vc).strip() != "1" else merges(vc)[0]
    pr, title = title_of(subject, body)
    entries.append({"version": version_of(major, minor, 0), "date": date[:10], "pr": pr, "title": title, "commit": sha[:7]})
    end = version_commits[i + 1] if i + 1 < len(version_commits) else "HEAD"
    n = 0
    for sha, date, subject, body, is_merge in merges(f"{vc}..{end}"):
        if sha == end:
            break
        pr, title = title_of(subject, body)
        # Every merge counts, as in the Justfile (git rev-list --merges).
        if not is_merge:
            # A rebuild (or any plain commit): same version, newer build.
            entries[-1].setdefault("rebuilt", []).append(date[:10])
            continue
        n += 1
        entries.append({"version": version_of(major, minor, n), "date": date[:10], "pr": pr, "title": title, "commit": sha[:7]})

entries.reverse()
with open(out, "w") as f:
    json.dump({
        "generated": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%MZ"),
        "current": current,
        "repo": "https://github.com/steel-and-code/steel-os",
        "versions": entries[:80],
    }, f, indent=1)
    f.write("\n")
print(f"release notes: {len(entries)} versions, newest {entries[0]['version'] if entries else '-'}")
