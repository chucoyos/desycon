# Facturador Env Vars and Flags Checklist

Checklist operativo para no olvidar variables de entorno y feature flags de Facturador.

Runbook relacionado:

- `docs/solid_queue_worker_production_checklist.md`

## 1. Variables requeridas (base)

- `FACTURADOR_ENABLED`
- `FACTURADOR_ENVIRONMENT`
- `FACTURADOR_AUTO_ISSUE_ENABLED`
- `FACTURADOR_MANUAL_ACTIONS_ENABLED`
- `FACTURADOR_RECONCILIATION_ENABLED`
- `FACTURADOR_AUTO_SYNC_DOCUMENTS_ON_RECONCILE_ENABLED`
- `FACTURADOR_PAYMENT_COMPLEMENTS_ENABLED`
- `FACTURADOR_EMAIL_ENABLED`
- `FACTURADOR_ISSUER_ENTITY_ID`
- `FACTURADOR_AUTH_BASE_URL`
- `FACTURADOR_BUSINESS_BASE_URL`
- `FACTURADOR_USERNAME`
- `FACTURADOR_PASSWORD_MD5`
- `FACTURADOR_CLIENT_ID`
- `FACTURADOR_CLIENT_SECRET`
- `FACTURADOR_SERIE`
- `FACTURADOR_EMAIL_SUBJECT`
- `FACTURADOR_EMAIL_MESSAGE`

## 2. Valores sugeridos por entorno

### Staging

- `FACTURADOR_ENABLED=true`
- `FACTURADOR_ENVIRONMENT=sandbox`
- `FACTURADOR_AUTO_ISSUE_ENABLED=true`
- `FACTURADOR_MANUAL_ACTIONS_ENABLED=true`
- `FACTURADOR_RECONCILIATION_ENABLED=true`
- `FACTURADOR_AUTO_SYNC_DOCUMENTS_ON_RECONCILE_ENABLED=true`
- `FACTURADOR_PAYMENT_COMPLEMENTS_ENABLED=false`
- `FACTURADOR_EMAIL_ENABLED=true`

### Production (antes del release de nueva funcionalidad)

- `FACTURADOR_ENABLED=true`
- `FACTURADOR_ENVIRONMENT=production` (o el valor operativo definido por PAC)
- `FACTURADOR_AUTO_ISSUE_ENABLED=true`
- `FACTURADOR_MANUAL_ACTIONS_ENABLED=true`
- `FACTURADOR_RECONCILIATION_ENABLED=true`
- `FACTURADOR_AUTO_SYNC_DOCUMENTS_ON_RECONCILE_ENABLED=false` (activar al validar comportamiento)
- `FACTURADOR_PAYMENT_COMPLEMENTS_ENABLED=false`
- `FACTURADOR_EMAIL_ENABLED=false` (activar en release)

### Production (el dia del release de email)

- Cambiar solo:
- `FACTURADOR_EMAIL_ENABLED=true`

## 3. Comandos de ejemplo (Heroku)

### Staging

```bash
heroku config:set -a desycon-staging \
FACTURADOR_EMAIL_SUBJECT="Tu comprobante fiscal digital" \
FACTURADOR_EMAIL_MESSAGE="Adjuntamos tu CFDI en XML y PDF." \
FACTURADOR_EMAIL_ENABLED=true
```

### Production (preparacion segura)

```bash
heroku config:set -a desycon \
FACTURADOR_EMAIL_SUBJECT="Tu comprobante fiscal digital" \
FACTURADOR_EMAIL_MESSAGE="Adjuntamos tu CFDI en XML y PDF." \
FACTURADOR_EMAIL_ENABLED=false
```

### Production (activacion)

```bash
heroku config:set -a desycon FACTURADOR_EMAIL_ENABLED=true
```

## 4. Verificacion rapida

```bash
heroku config:get FACTURADOR_EMAIL_SUBJECT -a desycon-staging
heroku config:get FACTURADOR_EMAIL_MESSAGE -a desycon-staging
heroku config:get FACTURADOR_EMAIL_ENABLED -a desycon-staging

heroku config:get FACTURADOR_EMAIL_SUBJECT -a desycon
heroku config:get FACTURADOR_EMAIL_MESSAGE -a desycon
heroku config:get FACTURADOR_EMAIL_ENABLED -a desycon
```

## 5. Smoke test despues de activar email

1. Emitir o abrir una factura `issued` con `sat_uuid` presente.
2. Ejecutar envio manual desde UI (`Enviar CFDI por correo`).
3. Validar `flash` de exito.
4. Validar eventos en factura:
- `email_requested`
- `email_sent` o `email_failed`
5. Si hay `email_failed`, revisar `provider_error_message` y `response_payload` del evento.

## 6. Notas operativas

- Si PAC responde `true` literal al endpoint de correo, se considera envio aceptado.
- Si email esta deshabilitado y trigger es manual, la app muestra alerta clara y no intenta envio.
- Los hooks automaticos de email (issue/cancel/reconcile) son no bloqueantes para el estado fiscal.
