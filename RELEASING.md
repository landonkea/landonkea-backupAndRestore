# Releasing

This is a script, not a hosted service, so there's no server to deploy to and no real "production" in the usual sense. What "dev / staging / prod" means here instead is version tags: which snapshot of `backup.sh` and `restore.sh` is safe to actually run on a Mac you care about.

## Branches

- **`main`** is always the last known-good, stable state. Every commit on `main` should pass CI (`.github/workflows/ci.yml`, ShellCheck plus a syntax check).
- **`dev`** is where day-to-day work happens, small fixes, new backup categories, whatever's next from `FEATURE_IDEAS.md`. It merges into `main` via pull request once it's in a state you'd trust on your own machine.
- **Feature branches** (`feature/docker-config-backup`, `fix/restore-overwrite-prompt`, that kind of name) branch off `dev` for anything bigger than a one-line fix, and merge back into `dev` the same way.

Nothing pushes straight to `main`. Everything lands there through a PR from `dev` (or occasionally a direct hotfix branch, for something urgent like the SSH-key nesting bug fixed in commit `1e68701`).

## Version tags

Two tag shapes, two different workflows react to them.

**Release candidate (staging): `v1.3.0-rc1`**
Push a tag like this from `main` once `dev` has been merged in and you want to try the result on a real machine before calling it done. `.github/workflows/staging-release.yml` picks it up and creates a GitHub **pre-release**, marked as such, with auto-generated notes. Nothing about this tag says "trust this," it says "test this."

```bash
git checkout main
git pull
git tag v1.3.0-rc1
git push origin v1.3.0-rc1
```

**Stable release: `v1.3.0`**
Once an `-rc` build has actually been run and looks right, tag the same commit without the `-rc` suffix. `.github/workflows/release.yml` picks up any `v*` tag that doesn't contain `-rc` and creates a real GitHub Release, changelog notes generated automatically from the commits/PRs since the last tag.

```bash
git tag v1.3.0
git push origin v1.3.0
```

Version numbers follow plain semantic versioning: MAJOR bumps for anything that changes what gets backed up/restored in a way that could surprise someone (a category removed, a file format changed), MINOR for new backup/restore coverage, PATCH for bug fixes like the Homebrew URL fix or the same-day-rerun nesting fix.

## What each workflow actually does

| Trigger | Workflow | Result |
|---|---|---|
| Push/PR to `main` | `ci.yml` | ShellCheck + `bash -n`, no scripts executed |
| Push/PR to `main`, `dev`, `staging` | `ai-attribution-check.yml` | Blocks commits with AI-tool attribution |
| Tag `v*-rc*` | `staging-release.yml` | GitHub pre-release, for testing |
| Tag `v*` (no `-rc`) | `release.yml` | GitHub Release, changelog notes, stable |

Both release workflows re-run the same `bash -n` syntax check CI already does before creating anything, a broken script never gets tagged as a release just because CI happened to pass on an earlier commit.
