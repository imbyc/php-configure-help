# Repository Guidelines

## Project Structure & Module Organization
This repository stores generated PHP `./configure --help` outputs by version.

- `docs/`: generated Markdown files, one per PHP version (for example `docs/8.5.6.md`).
- `gen.sh`: main generator script; fetches PHP release metadata, downloads source tarballs, runs `configure --help`, and writes docs.
- `public.sh`: shared shell logging helpers.
- `version-id.jq`: jq helpers for PHP version sorting and URL selection.
- `.github/workflows/gen.yml`: scheduled automation that runs `./gen.sh 8`.

Keep generated artifacts in `docs/`. Do not commit temporary extraction directories like `src/` or downloaded tarballs.

## Build, Test, and Development Commands
- `chmod u+x ./gen.sh && ./gen.sh`: generate docs for default major version (`8`).
- `./gen.sh 8.4`: generate all available `8.4.x` (including RC when available).
- `./gen.sh 8.5.7RC2`: generate one specific version.
- `bash -n gen.sh public.sh`: shell syntax check before committing.

The script requires `bash`, `curl`, `jq`, `wget`, and `tar` on your machine.

## Coding Style & Naming Conventions
- Shell scripts use `bash` with `set -Eeuo pipefail`.
- Prefer 2-space indentation in shell/jq blocks; keep existing style consistent in edited files.
- Function names use `PascalCase` in `gen.sh` (existing convention) and `_snake_case` for log helpers in `public.sh`.
- Generated docs must be named exactly `docs/<PHP_VERSION>.md`.

## Testing Guidelines
There is no unit-test framework in this repo. Validation is command-based:

1. Run `bash -n gen.sh public.sh`.
2. Run `./gen.sh <target-version>` for at least one version.
3. Verify generated Markdown includes header, fenced `bash` block, and metadata lines (version/date/url/hash).

When changing generation logic, test one stable version and one RC version if possible.

## Commit & Pull Request Guidelines
- Auto-generated commits in history follow: `🤖 Add <version...>`.
- Manual commit messages must use Chinese (仓库约定), preferably imperative and scoped, e.g. `修复: 处理 RC 版本下载地址`.
- PRs should include:
  - what changed and why,
  - sample command(s) run locally,
  - affected version files under `docs/`,
  - workflow impact if `.github/workflows/` or `gen.sh` changed.
