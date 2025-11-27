# Labs Data & Tarballs

This repository includes runnable lab exercises. Some labs require small datasets or compressed archives (tarballs). To keep examples reproducible while avoiding bloat, follow these rules:

- Scope: Only include lab-specific archives under `labs/`.
- Size cap: Keep individual files under ~10 MB. Larger assets should be hosted externally and downloaded via a script.
- Format: Prefer `.tar.gz` for portability; avoid proprietary formats.
- Structure:
  - `labs/<domain>/<lab-id>/data/` for raw inputs
  - `labs/<domain>/<lab-id>/artifacts/` for outputs generated during the lab
  - `labs/<domain>/<lab-id>/scripts/` for fetch/build helpers

## Referencing External Data

When datasets exceed the size cap, provide a fetch script:

```sh
#!/usr/bin/env sh
set -euo pipefail
# Example: labs/embedded-linux/lab01-toolchain/scripts/fetch.sh
mkdir -p "$(dirname "$0")/../data"
cd "$(dirname "$0")/../data"
curl -LO https://example.com/toolchain-sample.tar.gz
sha256sum -c <<'EOF'
<sha256sum>  toolchain-sample.tar.gz
EOF
```

## Versioning Policy

- Small, static samples should be committed to the repo (now allowed by `.gitignore`).
- Generated artifacts should not be committed; they belong in `artifacts/` and are regenerated.
- Include a short `README.md` in each lab directory describing inputs, expected outputs, and steps.
