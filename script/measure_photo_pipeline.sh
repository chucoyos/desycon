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

UPLOAD_P95=""
UPLOAD_ERRORS=""
PREPROCESS_P95=""
PREPROCESS_ERRORS=""
ZIP_P95=""
ZIP_ERRORS=""

update_stage_state() {
  local label="$1"
  local p95="$2"
  local errors="$3"

  case "$label" in
    "Upload request web")
      UPLOAD_P95="$p95"
      UPLOAD_ERRORS="$errors"
      ;;
    "Preprocess variant worker")
      PREPROCESS_P95="$p95"
      PREPROCESS_ERRORS="$errors"
      ;;
    "Build ZIP worker")
      ZIP_P95="$p95"
      ZIP_ERRORS="$errors"
      ;;
  esac
}

extract_stats() {
  local label="$1"
  local pattern="$2"
  local warn_p95_ms="$3"

  local stage_lines
  stage_lines="$(printf '%s\n' "$LOG_DATA" | grep -F "$pattern" || true)"

  local durations
  durations="$(printf '%s\n' "$stage_lines" | sed -n 's/.*duration_ms=\([0-9][0-9]*\).*/\1/p' || true)"

  local error_count
  error_count="$(printf '%s\n' "$stage_lines" | grep -c 'status=error' || true)"

  local count
  count="$(printf '%s\n' "$durations" | sed '/^$/d' | wc -l | tr -d ' ')"

  echo ""
  echo "[$label]"
  echo "Eventos: $count"
  echo "Errores: $error_count"

  if [[ "$count" == "0" ]]; then
    echo "Sin datos en el rango solicitado."
    update_stage_state "$label" "" "$error_count"
    return
  fi

  local summary
  summary="$(printf '%s\n' "$durations" | sort -n | awk '
    function percentile_index(n, p) {
      idx = int((p * n) + 0.999999)
      if (idx < 1) idx = 1
      if (idx > n) idx = n
      return idx
    }

    {
      n += 1
      values[n] = $1 + 0
      sum += values[n]
    }
    END {
      if (n == 0) {
        print "Sin datos"
        exit
      }

      min = values[1]
      max = values[n]
      avg = sum / n
      p50 = values[percentile_index(n, 0.50)]
      p95 = values[percentile_index(n, 0.95)]
      p99 = values[percentile_index(n, 0.99)]

      printf("min_ms=%d p50_ms=%d p95_ms=%d p99_ms=%d avg_ms=%.2f max_ms=%d\n", min, p50, p95, p99, avg, max)
    }
  ' )"

  echo "$summary"

  local p95_value
  p95_value="$(printf '%s\n' "$summary" | sed -n 's/.*p95_ms=\([0-9][0-9]*\).*/\1/p')"

  local stage_status
  stage_status="OK"
  if [[ "${error_count:-0}" -gt 0 ]]; then
    stage_status="WARN"
  elif [[ -n "$p95_value" && "$p95_value" -gt "$warn_p95_ms" ]]; then
    stage_status="WARN"
  fi

  echo "Estado: $stage_status (umbral_p95_ms=$warn_p95_ms)"

  update_stage_state "$label" "$p95_value" "$error_count"
}

print_diagnosis() {
  echo ""
  echo "===== DIAGNOSTICO AUTOMATICO ====="

  if [[ -z "$UPLOAD_P95" && -z "$PREPROCESS_P95" && -z "$ZIP_P95" ]]; then
    echo "No hay datos suficientes para diagnostico."
    return
  fi

  if [[ "${UPLOAD_ERRORS:-0}" -gt 0 || "${PREPROCESS_ERRORS:-0}" -gt 0 || "${ZIP_ERRORS:-0}" -gt 0 ]]; then
    echo "Hallazgo: se detectaron errores en una o mas etapas."
    echo "Recomendaciones:"
    echo "- Revisar errores en logs por etiqueta [Photos::Upload], [Photos::PreprocessVariantJob] y [Photos::BuildArchiveJob]."
    echo "- Verificar limites de tamano/tipo de imagen y disponibilidad de S3."
    echo "- Si los errores son de timeout, reducir lote por request (5-10) o implementar sub-lotes automaticos."
    return
  fi

  if [[ -n "$UPLOAD_P95" && -n "$PREPROCESS_P95" && -n "$ZIP_P95" ]]; then
    if [[ "$UPLOAD_P95" -le 3000 && ( "$PREPROCESS_P95" -gt 500 || "$ZIP_P95" -gt 10000 ) ]]; then
      echo "Hallazgo: web rapido y post-procesamiento lento."
      echo "Cuello de botella probable: worker_active_storage."
      echo "Recomendaciones:"
      echo "- Escalar worker_active_storage dynos."
      echo "- Revisar backlog de cola active_storage y tiempos de jobs."
      echo "- Mantener upload en lotes pequenos para suavizar picos."
      return
    fi

    if [[ "$UPLOAD_P95" -gt 5000 && "$PREPROCESS_P95" -le 500 && "$ZIP_P95" -le 10000 ]]; then
      echo "Hallazgo: submit web mas lento que workers."
      echo "Cuello de botella probable: request web + persistencia DB."
      echo "Recomendaciones:"
      echo "- Escalar web dynos si hay concurrencia alta."
      echo "- Revisar rendimiento DB (conexiones, waits, locks, outliers)."
      echo "- Reducir lote por request o usar sub-lotes automaticos."
      return
    fi

    if [[ "$UPLOAD_P95" -gt 5000 && "$PREPROCESS_P95" -gt 500 ]]; then
      echo "Hallazgo: lentitud combinada en web y workers."
      echo "Cuello de botella probable: saturacion general (DB/recursos/cola)."
      echo "Recomendaciones:"
      echo "- Escalar web y worker_active_storage de forma temporal."
      echo "- Verificar plan de DB y metricas de waits/locks."
      echo "- Aplicar politica de lotes pequenos (5-10) en cargas masivas."
      return
    fi
  fi

  echo "Hallazgo: pipeline estable dentro de umbrales actuales."
  echo "Recomendaciones:"
  echo "- Mantener monitoreo periodico con este script."
  echo "- Ejecutar prueba concurrente (2 usuarios) para validar margen real."
}

echo ""
echo "===== REPORTE PIPELINE FOTOS ====="
extract_stats "Upload request web" "[Photos::Upload]" 8000
extract_stats "Preprocess variant worker" "[Photos::PreprocessVariantJob]" 500
extract_stats "Build ZIP worker" "[Photos::BuildArchiveJob]" 10000
print_diagnosis

echo ""
echo "Sugerencia de prueba controlada:"
echo "1) Ejecuta este script antes de la prueba para baseline."
echo "2) Sube 50 fotos en una sola seccion."
echo "3) Espera 2-5 minutos y vuelve a ejecutar el script."
