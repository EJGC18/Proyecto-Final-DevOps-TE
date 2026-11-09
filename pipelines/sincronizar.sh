#!/usr/bin/env bash
# Copia los workflows que ejecuta GitHub (.github/workflows) a pipelines/workflows
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p pipelines/workflows
cp .github/workflows/*.yml pipelines/workflows/
echo "Workflows sincronizados en pipelines/workflows/"
