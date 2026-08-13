# Build Log

This file has two jobs. First, it's a record of how this repo actually got built, commit by commit, so six months from now nobody has to guess why something is shaped the way it is. Second, it's a rebuild procedure: if this repo, GitHub, and every clone of it vanished tomorrow, these are the exact steps to reconstruct it with no manual guesswork.

Everything below is pulled from real `git log` output, not reconstructed from memory. Thirteen commits, July 26 to August 12, 2026.

## History

**3e01f69 — `feat: macOS backup and restore toolkit with SSH key safety` (Jul 26)**
The starting point. `backup.sh` (163 lines) and `restore.sh` (207 lines) landed in one commit, along with a README and a `.gitignore` built specifically to keep `Mac_Backup_*/` folders and `*.bak` files out of version control. That gitignore rule exists because the backup folders these scripts create contain real SSH private keys, so it had to be right from commit one, not bolted on later.

**2fec84d — `refactor: split backup/restore scripts into single-purpose functions` (Aug 1)**
Both scripts had been flat top-to-bottom procedures. This rewrote them into named functions (`backup_homebrew_packages`, `backup_dotfiles`, `backup_ssh_keys`, and so on) called in sequence from a `main()` at the bottom. No new behavior, just a structure where each concern is readable and testable on its own.

**fc112b9 — `ci: add static analysis (shellcheck + bash -n)` (Aug 1)**
First CI workflow. Runs `bash -n` (syntax check without execution) and ShellCheck on every push and PR to `main`. The workflow comment is explicit that `backup.sh`/`restore.sh` must never actually run in CI, they touch a real filesystem and real SSH keys, so a CI runner has no business executing them.

**20af576 — `Fix broken Homebrew install URL and let Ruby gems round-trip` (Aug 2)**
Two real bugs. The Homebrew install URL in `restore.sh` pointed at a dead host. And Ruby gems were being listed during backup but never actually reinstalled during restore, unlike npm and pip, which round-tripped fine. Both fixed in the same commit.

**aad2072 — `ci: add workflow to block AI attribution in commits` (Aug 7)**
Added `ai-attribution-check.yml`, a workflow that scans commit messages, author/committer fields, and file contents for AI tool names and no-reply addresses, and fails the build if it finds any.

**732e13b — `chore: trigger GitHub re-index` (Aug 7)**
Empty commit, no file changes. Used to force GitHub to re-crawl the repo.

**d0e4f85 — `ci: upgrade AI attribution check to cover author/committer fields` (Aug 7)**
The first version of the attribution check only scanned commit messages. This extended it to also check the author and committer name/email fields, since attribution can show up there instead of in the message body.

**0ac186b — `docs: add design workflow documentation` (Aug 8)**
Added `docs/DESIGN.md` with Mermaid diagrams showing the backup and restore flows end to end.

**9a8d297 — `docs: remove em dashes from README` (Aug 9)**
A prose cleanup pass across the README, both scripts, and DESIGN.md, replacing em dashes with commas or periods. Purely a style fix, no behavior changed.

**21c32b7 — `feat: widen backup coverage to version managers, VS Code, and more secrets` (Aug 11)**
The biggest functional commit after the initial one. Backup/restore coverage grew from "Homebrew + npm/pip/gem + three dotfiles + SSH" to also include nvm/pyenv/rbenv version lists, VS Code extensions and settings, Mac App Store and `/Applications` inventory, crontab and LaunchAgents, and non-SSH secrets (GPG, AWS, gcloud, kube, npm/yarn registry tokens).

**7f39fdf — `feat: run backups automatically on a weekly schedule` (Aug 11)**
Added the `schedule/` folder: a launchd plist template, `install-schedule.sh`, and `uninstall-schedule.sh`. This is what lets `backup.sh` run every Sunday at 10 AM without anyone remembering to type the command. Also added a backup-retention step to `backup.sh` (`prune_old_backups`, keeps the 4 most recent dated folders) since an unattended weekly job would otherwise pile up backup folders, each containing a copy of SSH keys, forever.

**1e68701 — `fix: stop LaunchAgents/SSH/secrets backups from nesting on same-day reruns` (Aug 11)**
A real bug in the copy logic: `cp -R sourceDir destDir` only behaves like a merge the first time. If you run `backup.sh` twice in one day (same dated folder already exists), the second run nests `sourceDir` one level deeper inside itself instead of overwriting it in place. Fixed by pre-creating the destination folder and copying with the `sourceDir/.` form everywhere this pattern was used (LaunchAgents, SSH keys, GPG, AWS, gcloud).

**787164a — `ci: stop AI attribution check from flagging itself and normal GitHub merges` (Aug 12)**
The attribution-check workflow was tripping on its own source file (it contains the blocked keyword list) and on ordinary GitHub-generated merge commit text. Tightened to exclude its own file from the content scan and to stop treating standard merge commits as hits.

## Current structure

```
landonkea-backupAndRestore/
├── .github/workflows/
│   ├── ci.yml                      shellcheck + bash -n on every push/PR
│   └── ai-attribution-check.yml    blocks AI-tool references in commits/files
├── docs/
│   └── DESIGN.md                   Mermaid diagrams of the backup/restore flow
├── schedule/
│   ├── com.landonkea.backupandrestore.plist   launchd job template
│   ├── install-schedule.sh                    installs the weekly job
│   └── uninstall-schedule.sh                  removes it
├── backup.sh                       collects everything into a dated folder
├── restore.sh                      reinstalls/copies everything back
├── .gitignore                      keeps Mac_Backup_*/ and *.bak out of git
└── README.md
```

## Rebuilding from zero

If this repo still exists on GitHub, the real answer is one command:

```bash
git clone git@github.com:landonkea/landonkea-backupAndRestore.git
```

That's the entire "zero manual input" rebuild in the normal case. The steps below are for the worse scenario: GitHub is gone too, and all that's left is a saved copy of the current file contents (for instance, pulled from a personal backup drive, which, no small irony, is exactly the kind of thing this tool exists to protect against needing). Everything here is a literal, ordered command sequence, nothing depends on a human making a judgment call.

```bash
# 1. Create the repo and its ignore rules first, before anything else,
#    so a secret-laden Mac_Backup_ folder can never land in git by accident.
mkdir landonkea-backupAndRestore && cd landonkea-backupAndRestore
git init -b main

cat > .gitignore <<'EOF'
# Ignore all backup snapshot folders. They contain SSH private keys.
Mac_Backup_*/
*.bak
.DS_Store
EOF

# 2. Recreate the directory layout.
mkdir -p .github/workflows docs schedule

# 3. Restore backup.sh and restore.sh with their exact current byte
#    content from the saved copy. These files are long (24KB / 21KB) and
#    change over time, so this log intentionally does not duplicate them
#    inline, that copy would drift out of sync the moment either script
#    is next edited. Copy them verbatim from the saved source.
cp /path/to/saved/backup.sh  ./backup.sh
cp /path/to/saved/restore.sh ./restore.sh
chmod +x backup.sh restore.sh

# 4. Same approach for every other tracked file: copy verbatim from the
#    saved source into its matching path.
#      README.md
#      docs/DESIGN.md
#      schedule/com.landonkea.backupandrestore.plist
#      schedule/install-schedule.sh
#      schedule/uninstall-schedule.sh
#      .github/workflows/ci.yml
#      .github/workflows/ai-attribution-check.yml
#      .github/workflows/staging-release.yml
#      .github/workflows/release.yml
#      RELEASING.md
#      FEATURE_IDEAS.md
#      BUILD_LOG.md (this file)
chmod +x schedule/install-schedule.sh schedule/uninstall-schedule.sh

# 5. Commit everything as a single starting point.
git add -A
git commit -m "rebuild: restore landonkea-backupAndRestore from saved source"

# 6. Recreate the branch/tag conventions documented in RELEASING.md.
git branch dev

# 7. Point the remote at GitHub (create the repo there first via
#    `gh repo create landonkea/landonkea-backupAndRestore --private`
#    if it doesn't exist) and push.
git remote add origin git@github.com:landonkea/landonkea-backupAndRestore.git
git push -u origin main
git push -u origin dev
```

That's the whole procedure. No step above requires a decision that isn't already fully specified, every path, filename, and command is exact.
