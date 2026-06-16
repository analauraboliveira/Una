#!/bin/bash
# ============================================================
# Aplica as migrations do banco em ordem numérica.
# Executado pelo entrypoint do container PostgreSQL na
# primeira inicialização (quando o volume está vazio).
#
# Os arquivos em /docker-entrypoint-initdb.d/ são executados
# em ordem alfabética — este script roda após 00_auth_mock.sql.
# ============================================================

set -e

DB="${POSTGRES_DB:-una_dev}"
USER="${POSTGRES_USER:-postgres}"
MIGRATIONS_DIR="/migrations"

echo "==> Una: aplicando migrations em $MIGRATIONS_DIR..."

for migration in "$MIGRATIONS_DIR"/*.sql; do
    filename=$(basename "$migration")
    echo "    --> $filename"
    psql -v ON_ERROR_STOP=1 -U "$USER" -d "$DB" -f "$migration"
done

echo "==> Una: migrations aplicadas com sucesso."

# Aplica seed apenas se a variável SEED_DB estiver definida como 'true'
# Uso: SEED_DB=true docker compose up
if [ "${SEED_DB:-false}" = "true" ]; then
    SEED_FILE="/migrations/../seed.sql"
    if [ -f "$SEED_FILE" ]; then
        echo "==> Una: aplicando seed data..."
        psql -v ON_ERROR_STOP=1 -U "$USER" -d "$DB" -f "$SEED_FILE"
        echo "==> Una: seed aplicado com sucesso."
    fi
fi
