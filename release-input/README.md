# release-input/

Manual drop-in location for pre-built, platform-specific `morpheus` SEA
binaries, produced by the separate `morpheus/` CLI project (out of this
repo's scope). Everything in this directory except this file is gitignored.

Expected filenames (exact):

```
morpheus-linux-x64
morpheus-linux-arm64
morpheus-darwin-arm64
morpheus-darwin-x64
```

Any subset may be present. `scripts/release.sh` packages only what's here —
missing platforms are skipped, not treated as errors, as long as at least
one binary is present.

## Publishing a binary so CI can pick it up for a tagged release

`.github/workflows/release.yml` runs on a hosted runner with a clean
checkout — it has no access to files that only ever existed on your
machine. So instead of committing binaries here, upload them to the
`binaries-staging` GitHub Release, which the release workflow downloads
from before packaging:

```bash
gh release upload binaries-staging release-input/morpheus-linux-x64 --clobber
```

See [RELEASING.md](../RELEASING.md) for the full release runbook.
