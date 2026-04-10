# Worker Post-Deploy Health Checklist (Production)

Aplicacion: desycon
Objetivo: confirmar estabilidad del worker despues de migrar a Solid Queue y tuning de memoria.

## Linea base (ya observada)
- Dynos web/worker en estado up.
- Adapter efectivo: solid_queue.
- Worker arrancando con:
  - thread_pool_size: 1
  - dispatcher batch_size: 100
  - worker polling_interval: 0.5
- Memoria observada reciente: ~305 MB a ~413 MB (cuota 512 MB).
- Sin nuevos eventos R14 en la ventana mas reciente posterior al deploy/restart.

## Revisar a las +2 horas
1. Estado de dynos
   heroku ps --app desycon

2. Verificar adapter en runtime
   heroku run --app desycon 'bin/rails runner "puts Rails.application.config.active_job.queue_adapter"'

3. Revisar logs worker (ultimos 300)
   heroku logs --dyno worker -n 300 --app desycon

4. Criterios de salud (+2h)
- OK: worker up, sin crashes repetidos.
- OK: sin R14 nuevos.
- OK: memoria total worker < 460 MB de forma sostenida.
- ALERTA: memoria > 480 MB sostenida o R14 reaparece.

## Revisar a las +24 horas
1. Estado de dynos
   heroku ps --app desycon

2. Logs extendidos worker (ultimos 1500)
   heroku logs --dyno worker -n 1500 --app desycon

3. Criterios de salud (+24h)
- OK: sin R14 en toda la ventana revisada.
- OK: sin reinicios por crash.
- OK: memoria estable sin acercarse al limite de 512 MB.
- ALERTA: R14 en picos operativos o reinicios por OOM.

## Accion de contingencia (si reaparece R14)
1. Aumentar tamano del dyno worker (recomendado si hay carga real sostenida).
2. Mantener JOB_CONCURRENCY=1 y JOB_THREADS=1.
3. Separar colas pesadas en un worker dedicado.
4. Revisar jobs de mayor costo (PDF/adjuntos/consultas amplias) para procesar en lotes.

## Comandos utiles
- Variables activas relevantes:
  heroku config --app desycon | grep -E 'ACTIVE_JOB_QUEUE_ADAPTER|JOB_|RAILS_MAX_THREADS|MALLOC_ARENA_MAX'

- Reinicio controlado de worker:
  heroku ps:restart worker --app desycon
