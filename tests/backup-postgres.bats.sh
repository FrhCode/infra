#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/backup-postgres.sh"

if [[ ! -f "$SCRIPT" ]]; then
  echo "missing script: $SCRIPT" >&2
  exit 1
fi

grep -q 'shared_postgres' "$SCRIPT"
grep -q 'pg_dumpall' "$SCRIPT"
grep -q 'RETENTION_DAYS' "$SCRIPT"
grep -q 'backups/postgres' "$SCRIPT"
grep -q 'postgres-all-' "$SCRIPT"
grep -q 'gzip' "$SCRIPT"
grep -q 'trap' "$SCRIPT"

bash -n "$SCRIPT"
