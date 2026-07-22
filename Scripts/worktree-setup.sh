#!/usr/bin/env bash
# Seed only gitignored, per-machine configuration. This script is idempotent:
# existing worktree-local files win, and provisioning failures are non-fatal.
set -u

worktree="$(git rev-parse --show-toplevel)"
main="$(dirname "$(git rev-parse --git-common-dir)")"
[ "$worktree" = "$main" ] && exit 0

log() { printf 'worktree-setup: %s\n' "$1"; }

for rel in .claude/settings.local.json Development.xcconfig; do
  src="$main/$rel"
  dst="$worktree/$rel"
  if [ -e "$src" ] && [ ! -e "$dst" ]; then
    mkdir -p "$(dirname "$dst")"
    if cp -R "$src" "$dst"; then
      log "seeded $rel"
    else
      log "WARN: failed to seed $rel"
    fi
  fi
done

if [ "${WORKTREE_SKIP_INSTALL:-0}" != "1" ]; then
  if (cd "$worktree/APITypes" && swift package resolve) >/dev/null 2>&1; then
    log 'resolved APITypes'
  else
    log 'WARN: APITypes resolution failed — run swift package resolve manually'
  fi
fi

log 'done'
