#!/usr/bin/env bash
# Pipeline 3: comprueba que la aplicación quedó operativa a través del ALB.
# Uso: smoke-test.sh <url-base> <version-esperada>
set -euo pipefail

URL="${1:?Indica la URL base, ej. http://mi-alb.us-east-1.elb.amazonaws.com}"
VERSION="${2:?Indica la versión esperada}"
INTENTOS=20

for i in $(seq 1 "$INTENTOS"); do
  BACK="$(curl -fsS --max-time 5 "${URL}/api/health" 2>/dev/null || true)"
  FRONT="$(curl -fsS --max-time 5 "${URL}/" 2>/dev/null || true)"

  if echo "$BACK" | grep -q "\"version\":\"${VERSION}\"" && echo "$FRONT" | grep -q "${VERSION}"; then
    echo "✅ Backend responde: $BACK"
    echo "✅ Frontend sirve la versión ${VERSION}"
    # Prueba funcional de la API: crear una tarea
    curl -fsS --max-time 5 -X POST -H 'Content-Type: application/json' \
      -d "{\"titulo\":\"Smoke test ${VERSION}\"}" "${URL}/api/tareas"
    echo
    echo "Aplicación operativa en ${URL}"
    echo "## ✅ Aplicación operativa: ${URL} (versión \`${VERSION}\`)" >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
    exit 0
  fi
  echo "Intento ${i}/${INTENTOS}: aún no responde la versión ${VERSION}. Reintentando en 15 s..."
  sleep 15
done

echo "::error::La aplicación no respondió con la versión ${VERSION} en ${URL}"
exit 1
