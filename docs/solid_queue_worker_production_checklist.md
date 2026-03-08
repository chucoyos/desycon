# Solid Queue + Worker (Produccion) - Checklist de Implementacion

Checklist operativo para habilitar `solid_queue + worker` en produccion de forma segura, reversible y con control de costos.

## 1. Objetivo

- Tener cola persistente para jobs de Active Job.
- Evitar perdida de jobs por reinicios de dynos.
- Habilitar reintentos con `wait` de manera confiable.

## 2. Requisitos previos

- Codigo desplegado con soporte de `worker` en `Procfile`.
- Entorno `production` preparado para usar `solid_queue`.
- Backup reciente de base de datos en Heroku.
- Ventana de cambio definida (aunque sea corta).

## 3. Backup y estado actual

```bash
heroku pg:backups:capture -a desycon
heroku pg:backups -a desycon
heroku ps -a desycon
```

## 4. Configuracion recomendada (coste minimo inicial)

- `worker=1`.
- `JOB_CONCURRENCY=1`.
- Mantener `web` sin cambios al inicio.

```bash
heroku config:set -a desycon JOB_CONCURRENCY=1
```

## 5. Preparar esquema de cola

Primero intenta con flujo normal:

```bash
heroku run -a desycon bin/rails db:prepare
```

Si el worker cae por tablas faltantes (`solid_queue_*`), cargar esquema de cola explicitamente:

```bash
heroku run -a desycon bin/rails runner "SolidQueue::Job.connection; load Rails.root.join('db/queue_schema.rb')"
```

## 6. Habilitar worker

```bash
heroku ps:scale worker=1 -a desycon
heroku ps -a desycon
```

## 7. Verificacion tecnica inmediata

```bash
heroku logs --tail -a desycon --dyno worker
```

Esperado en logs:

- `Started Supervisor`
- `Started Dispatcher`
- `Started Worker`

Verificar tablas de cola:

```bash
heroku run -a desycon bin/rails runner "p SolidQueue::Job.connection.tables.grep(/solid_queue/)"
```

## 8. Smoke test funcional (Facturador)

1. Emitir una factura de prueba.
2. Verificar eventos:
- `issue_succeeded`
- `email_requested`
- `email_sent` (o retry y luego `email_sent`)
3. Validar que no se rompa el flujo fiscal si el email falla.

## 9. Rollback rapido

Si hay problema operativo:

```bash
heroku ps:scale worker=0 -a desycon
```

Si se dejo habilitado toggle de adapter por env:

```bash
heroku config:set ACTIVE_JOB_QUEUE_ADAPTER=async -a desycon
```

Luego reiniciar web:

```bash
heroku ps:restart web -a desycon
```

## 10. Monitoreo y costos

Monitoreo diario inicial:

- Estado de dynos (`heroku ps`).
- Crashes de `worker`.
- Latencia de procesamiento de jobs criticos.

Estrategia de costo minimo:

- Empezar con `worker=1` y `JOB_CONCURRENCY=1`.
- Escalar solo si hay backlog real.
- Revisar consumo en dashboard de Heroku durante 1-2 semanas antes de aumentar recursos.

## 11. Criterio de exito

- Worker estable sin crashes.
- Jobs de emision/email ejecutandose en tiempos esperados.
- Sin perdida de jobs tras deploy/restart.
- Sin regresiones en flujo funcional de facturacion.
