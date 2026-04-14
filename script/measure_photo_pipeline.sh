#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${1:-}"
LINES="${2:-8000}"

if [[ -z "$APP_NAME" ]]; then
  echo "Uso: script/measure_photo_pipeline.sh <heroku_app> [lineas_logs]"
  echo "Ejemplo: script/measure_photo_pipeline.sh desycon 12000"
  exit 1
fi

if ! command -v heroku >/dev/null 2>&1; then
  echo "Error: Heroku CLI no esta instalado."
  exit 1
fi

echo "Descargando ultimas $LINES lineas de logs para app=$APP_NAME..."
LOG_DATA="$(heroku logs -a "$APP_NAME" -n "$LINES" || true)"

extract_stats() {
  local label="$1"
  local pattern="$2"

  local durations
  durations="$(printf '%s\n' "$LOG_DATA" | grep "$pattern" | sed -n 's/.*duration_ms=\([0-9][0-9]*\).*/\1/p' || true)"

  local count
  count="$(printf '%s\n' "$durations" | sed '/^$/d' | wc -l | tr -d ' ')"

  echo ""
  echo "[$label]"
  echo "Eventos: $count"

  if [[ "$count" == "0" ]]; then
    echo "Sin datos en el rango solicitado."
    return
  fi

  printf '%s\n' "$durations" | awk '
    BEGIN { min = -1; max = 0; sum = 0; n = 0 }
    {
      v = $1 + 0
      if (min < 0 || v < min) min = v
      if (v > max) max = v
      sum += v
      n += 1
    }
    END {
      avg = (n > 0 ? sum / n : 0)
      printf("min_ms=%d avg_ms=%.2f max_ms=%d\n", min, avg, max)
    }
  '
}

echo ""
echo "===== REPORTE PIPELINE FOTOS ====="
extract_stats "Upload request web" "[Photos::Upload]"
extract_stats "Preprocess variant worker" "[Photos::PreprocessVariantJob]"
extract_stats "Build ZIP worker" "[Photos::BuildArchiveJob]"

echo ""
echo "Sugerencia de prueba controlada:"
echo "1) Ejecuta este script antes de la prueba para baseline."
echo "2) Sube 50 fotos en una sola seccion."
echo "3) Espera 2-5 minutos y vuelve a ejecutar el script."
