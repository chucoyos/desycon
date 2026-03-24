# Checklist de Cumplimiento PAC - REP Pago Multiple

Este checklist documenta el estado actual para emision de REP con multiples facturas en un solo comprobante.

## Implementado

- Un solo complemento de pago para varios pagos/facturas compatibles.
- Construccion de `complementoPago20` con `doctoRelacionado` multiple.
- Validacion de consistencia por lote: mismo emisor, mismo receptor, mismo metodo de pago y misma fecha.
- Validacion de consistencia de moneda: misma moneda en pagos y en facturas origen.
- `usoCFDI` para REP en `CP01`.
- Comprobante tipo `P` con `moneda` `XXX`, `formaPago` `99`, `metodoPago` `PUE`.
- `totales.montoTotalPagos` calculado con suma del lote.

## No soportado (bloqueado explicitamente)

- Lotes con tasas de impuesto mixtas en el mismo REP agrupado.
  - Resultado esperado: se rechaza con error de validacion antes de timbrar.

## Riesgos a validar con PAC en ambiente integrado

- Confirmar aceptacion PAC para todos los campos de REP agrupado segun su version de contrato/API.
- Validar XML timbrado final cuando existan escenarios frontera (folios sin serie, montos con redondeos, parcialidades altas).

## Recomendacion operativa

- Mantener el flujo agrupado para casos homogeneos.
- Si hay heterogeneidad fiscal (por ejemplo tasas distintas), separar en lotes compatibles antes de emitir REP.
