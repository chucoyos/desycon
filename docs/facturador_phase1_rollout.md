# Facturador - Implementación por etapas (reversible)

## Objetivo de Fase 1
Introducir la base de facturación sin alterar comportamiento operativo actual.

### Incluye
- Tablas nuevas: `invoices`, `invoice_events`.
- Campos SAT en `service_catalogs` para mapeo de conceptos CFDI.
- Cliente API aislado en `app/services/facturador`.
- Feature flag `FACTURADOR_ENABLED` (apagado por defecto).

### No incluye
- Timbrado automático en callbacks.
- Botones de emisión/cancelación en UI.
- Jobs de emisión en background.

## Activación segura
1. Desplegar código con `FACTURADOR_ENABLED=false`.
2. Ejecutar migraciones en ventana controlada.
3. Verificar arranque, logs y consultas básicas.
4. Mantener operación normal (sin timbrado PAC activo).

## Rollback (si falla implementación)
### Rollback funcional inmediato
- Mantener o forzar `FACTURADOR_ENABLED=false`.
- Resultado: la integración PAC queda desactivada sin afectar operación actual.

### Rollback estructural (DB)
Si se requiere volver al estado previo de esquema:

```bash
bin/rails db:rollback STEP=2
```

Esto revierte:
1. `AddSatFieldsToServiceCatalogs`
2. `CreateInvoicesAndInvoiceEvents`

## Criterio de salida de Fase 1
- Aplicación estable con migraciones aplicadas.
- Sin cambios de flujo en contenedores/partidas.
- Listo para Fase 2: jobs de emisión y wiring controlado.

## Fase 2 (implementada, apagada por flag)

### Incluye
- Cache y refresh de token Facturador en servicios internos.
- Resolución de `emisor_id` desde `userinfo` con cache.
- Builder de payload CFDI base desde `Invoice` + `ServiceCatalog` + perfiles fiscales.
- Job de emisión idempotente con lock por factura y reintentos (`IssueInvoiceJob`).

### Seguridad operativa
- La emisión solo corre si `FACTURADOR_ENABLED=true`.
- Si está en `false`, no se dispara timbrado (comportamiento actual preservado).

### Rollback Fase 2
1. **Inmediato (recomendado):** poner `FACTURADOR_ENABLED=false`.
2. Limpiar estado temporal de autenticación (cache):

```ruby
Facturador::TokenStore.clear!
Facturador::EmisorService.clear!
```

3. Si además deseas revertir esquema, usar rollback DB de la fase 1.

## Fase 3 (implementada, apagada por flag)

### Incluye
- Auto-emisión al crear servicios (`ContainerService` y `BlHouseLineService`) mediante callback `after_commit`.
- Construcción/encolado idempotente de factura con `AutoIssueService`.
- Trazabilidad visual del estado CFDI por servicio en pantallas de detalle.
- Preload de facturas en `show` para evitar N+1.

### Seguridad operativa
- La auto-emisión requiere ambos flags en `true`:
	- `FACTURADOR_ENABLED`
	- `FACTURADOR_AUTO_ISSUE_ENABLED`
- Requiere `FACTURADOR_ISSUER_ENTITY_ID` con entidad emisora válida y perfil fiscal completo.

### Rollback Fase 3
1. **Inmediato (recomendado):** `FACTURADOR_AUTO_ISSUE_ENABLED=false`.
2. Si deseas cortar toda integración: `FACTURADOR_ENABLED=false`.
3. Limpiar cache de PAC:

```ruby
Facturador::TokenStore.clear!
Facturador::EmisorService.clear!
```

## Fase 4 (implementada, apagada por flag)

### Incluye
- Endpoints manuales para emisión y cancelación (`InvoicesController`).
- Policy dedicada (`InvoicePolicy`) restringida a admin/ejecutivo.
- Botones UI en tarjetas de servicios para emitir, reintentar y cancelar CFDI.
- Servicio de cancelación contra PAC (`CancelInvoiceService`) con estatus `cancel_pending`/`cancelled`.
- Cancelación acotada temporalmente a motivo `02` (sin relación/sustitución).

### Seguridad operativa
- Requiere flags en `true`:
	- `FACTURADOR_ENABLED`
	- `FACTURADOR_MANUAL_ACTIONS_ENABLED`

### Rollback Fase 4
1. **Inmediato (recomendado):** `FACTURADOR_MANUAL_ACTIONS_ENABLED=false`.
2. Si deseas cortar toda integración: `FACTURADOR_ENABLED=false`.
3. Mantener rutas/código sin uso activo (sin riesgo operativo).

## Fase 5 (implementada, apagada por flag)

### Incluye
- Sincronización XML/PDF de facturas emitidas y almacenamiento en ActiveStorage.
- Bitácora de eventos PAC para solicitud/almacenamiento de XML y PDF.
- Endpoint manual `sync_documents` por factura y botones en UI de servicios.

### Seguridad operativa
- Requiere flags en `true`:
	- `FACTURADOR_ENABLED`
	- `FACTURADOR_MANUAL_ACTIONS_ENABLED`

### Rollback Fase 5
1. **Inmediato (recomendado):** `FACTURADOR_MANUAL_ACTIONS_ENABLED=false`.
2. Si deseas cortar toda integración: `FACTURADOR_ENABLED=false`.
3. Los archivos ya descargados permanecen en ActiveStorage (histórico auditable).

## Fase 6 (implementada, apagada por flag)

### Incluye
- Servicio de conciliación de estatus locales contra listado PAC por UUID.
- Job programable (`ReconcileInvoicesJob`) y tarea manual (`rake facturador:reconcile_invoices`).
- Mapeo de estatus PAC a estados locales: `issued`, `cancel_pending`, `cancelled`.
- Bitácora de conciliación por evento (`reconcile_requested`, `reconcile_synced`, etc.).

### Seguridad operativa
- Requiere flags en `true`:
	- `FACTURADOR_ENABLED`
	- `FACTURADOR_RECONCILIATION_ENABLED`

### Rollback Fase 6
1. **Inmediato (recomendado):** `FACTURADOR_RECONCILIATION_ENABLED=false`.
2. Si deseas cortar toda integración: `FACTURADOR_ENABLED=false`.
3. El histórico de eventos de conciliación se conserva para auditoría.

## Fase 7 (implementada, apagada por flag)

### Incluye
- Registro de cobranza interna por factura (`invoice_payments`).
- Disparo automático de complemento de pago al registrar cobro.
- Endpoint/UI para capturar pagos desde tarjetas de servicio.
- Construcción de payload tipo `P` para complemento de pago.

### Seguridad operativa
- Requiere flags en `true`:
	- `FACTURADOR_ENABLED`
	- `FACTURADOR_PAYMENT_COMPLEMENTS_ENABLED`
- La captura manual usa `FACTURADOR_MANUAL_ACTIONS_ENABLED`.

### Rollback Fase 7
1. **Inmediato (recomendado):** `FACTURADOR_PAYMENT_COMPLEMENTS_ENABLED=false`.
2. Si deseas ocultar captura manual: `FACTURADOR_MANUAL_ACTIONS_ENABLED=false`.
3. Si deseas cortar todo PAC: `FACTURADOR_ENABLED=false`.
