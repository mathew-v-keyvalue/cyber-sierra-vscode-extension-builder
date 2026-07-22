# Releasing

How to cut a new Morpheus CLI release via GitHub Releases, and how the
`curl | bash` install path (`bootstrap.sh`) consumes it.

## One-time setup: the `binaries-staging` release

`.github/workflows/release.yml` runs on a hosted GitHub Actions runner with a
clean checkout on every tag push — it has no access to files that only ever
existed on someone's laptop. So manually-built SEA binaries are staged ahead
of time in a permanent, unlisted **prerelease** that the workflow downloads
from before packaging the real release.

Create it once, per repo:

```bash
gh release create binaries-staging --prerelease \
  --notes "Internal storage for manually-built platform binaries. Not for end users."
```

It's marked `--prerelease` specifically so it never shows up as "latest" —
`bootstrap.sh`'s default install path resolves against `releases/latest`,
which skips prereleases entirely.

## Staging a new binary

Whenever a new SEA build arrives from the separate `morpheus/` CLI source
project, upload it to `binaries-staging` under the exact expected filename
(see `release-input/README.md` for the full list):

```bash
gh release upload binaries-staging release-input/morpheus-linux-x64 --clobber
```

`--clobber` lets you re-upload to replace a stale binary for a platform.
This can be done independently of cutting a release — staged binaries just
sit there until the next tag push picks them up.

## Cutting a release

1. Bump the `VERSION` file at repo root to the new version (no leading `v`,
   e.g. `1.2.0`). `scripts/release.sh` fails loudly if this doesn't match
   the tag being released — this is intentional, to force the bump to
   happen on the commit you actually tag.
2. Commit the `VERSION` bump.
3. Tag and push:
   ```bash
   git tag v1.2.0
   git push origin v1.2.0
   ```
4. The `Release` workflow fires automatically: it downloads whatever
   platform binaries are currently in `binaries-staging`, packages them
   with `scripts/release.sh` (missing platforms are skipped, not
   failures — a release with only `linux-x64` staged is a valid release),
   and publishes `morpheus-<platform>.tar.gz` + `SHA256SUMS` as assets on
   the new `v1.2.0` release.

## Testing the packaging step locally

You don't need CI to dry-run this. Drop one or more binaries into
`release-input/` (see its `README.md` for filenames), make sure `VERSION`
matches what you're about to pass, then:

```bash
./scripts/release.sh 1.2.0
ls -la dist/
```

## Rollback

End users pin or roll back with the `MORPHEUS_VERSION` environment variable,
which `bootstrap.sh` maps directly onto a `vX.Y.Z` release tag:

```bash
MORPHEUS_VERSION=1.1.0 curl -fsSL https://raw.githubusercontent.com/mathew-v-keyvalue/cyber-sierra-vscode-extension-builder/main/bootstrap.sh | bash
```

There's nothing extra to do on the release side for this to work — every
past release's assets remain downloadable at their own tag forever.
