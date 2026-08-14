#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
CONTAINER_NAME="${POSTGRES_CONTAINER_NAME:-shared_postgres}"
BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/backups/postgres}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
TIMESTAMP="$(date +%Y-%m-%d-%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/postgres-all-$TIMESTAMP.sql.gz"
PARTIAL_FILE="$BACKUP_FILE.partial"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

POSTGRES_USER="${POSTGRES_USER:-}"

cleanup_partial() {
  rm -f "$PARTIAL_FILE"
}
trap cleanup_partial EXIT

fail() {
  echo "Error: $*" >&2
  exit 1
}

[[ -n "$POSTGRES_USER" ]] || fail "POSTGRES_USER is required. Set it in .env or environment."
[[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] || fail "RETENTION_DAYS must be a non-negative integer."

command -v docker >/dev/null 2>&1 || fail "docker command not found."
docker inspect "$CONTAINER_NAME" >/dev/null 2>&1 || fail "PostgreSQL container '$CONTAINER_NAME' not found."

mkdir -p "$BACKUP_DIR"

echo "Creating PostgreSQL backup from container '$CONTAINER_NAME'..."
echo "Output: $BACKUP_FILE"

if docker exec "$CONTAINER_NAME" pg_dumpall -U "$POSTGRES_USER" | gzip -c > "$PARTIAL_FILE"; then
  mv "$PARTIAL_FILE" "$BACKUP_FILE"
else
  fail "Backup failed. Partial file removed."
fi

find "$BACKUP_DIR" -type f -name 'postgres-all-*.sql.gz' -mtime +"$RETENTION_DAYS" -delete

SIZE="$(du -h "$BACKUP_FILE" | awk '{print $1}')"

echo "Backup completed successfully."
echo "File: $BACKUP_FILE"
echo "Size: $SIZE"
echo "Retention: deleted backups older than $RETENTION_DAYS day(s)."
