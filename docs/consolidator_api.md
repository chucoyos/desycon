# API del Consolidador

Guía de referencia para que un consolidador integre su sistema con Global DYC y consulte sus contenedores, partidas (BL House Lines) y fotografías mediante una API REST de solo lectura.

## 1. Resumen

- **Base URL:** `https://www.globaldyc.com/api/v1/consolidator`
- **Formato:** JSON (`Accept: application/json`)
- **Autenticación:** API Key tipo `Bearer`
- **Alcance:** Solo lectura (`GET`). No se puede crear, modificar ni eliminar información mediante esta API.
- **Multi-tenant:** Cada API Key pertenece a un único consolidador. Solo se devuelven datos de ese consolidador; nunca se acepta un identificador de consolidador enviado por el cliente.
- **Sincronización incremental:** Los listados de contenedores y partidas aceptan `updated_since` para devolver registros modificados desde una marca de tiempo UTC.

## 2. Obtener tu API Key

La API Key la genera un usuario interno (`admin` o `executive`) desde la ficha de tu entidad en la plataforma. La clave se muestra **una sola vez** en pantalla al momento de generarla; después solo se conserva su hash en el servidor y no puede recuperarse.

Formato de la clave:

```text
dsc_live_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX   # producción
dsc_test_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX   # pruebas/staging
```

Si pierdes la clave o sospechas que fue expuesta, solicita al equipo de Global DYC que la revoque y genere una nueva. Una clave revocada deja de funcionar de inmediato.

## 3. Autenticación

Cada solicitud debe incluir la clave en el header `Authorization`, usando el esquema `Bearer`:

```http
GET /api/v1/consolidator/containers HTTP/1.1
Host: globaldyc.com
Authorization: Bearer dsc_live_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Accept: application/json
```

Ejemplo con `curl`:

```bash
curl -s \
  -H "Authorization: Bearer dsc_live_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" \
  -H "Accept: application/json" \
  "https://www.globaldyc.com/api/v1/consolidator/containers"
```

Si el header falta, la clave es inválida, fue revocada o expiró, la API responde `401 Unauthorized`:

```json
{
  "error": {
    "code": "invalid_api_key",
    "message": "API key is invalid or inactive.",
    "details": {}
  }
}
```

No es necesario enviar tu identificador de consolidador en la URL ni en el cuerpo de la solicitud: el servidor lo determina a partir de la API Key.

## 4. Convenciones generales

### 4.1 Paginación

Los listados históricos usan `page` y `per_page`. Las consultas incrementales con `updated_since` usan `per_page` y el cursor descrito en [Fechas](#44-fechas), no `page`.

| Parámetro  | Tipo    | Default | Límite      | Descripción                          |
|------------|---------|---------|-------------|---------------------------------------|
| `page`     | integer | `1`     | mayor a 0   | Número de página solicitada.          |
| `per_page` | integer | `25`    | 1 a 100     | Cantidad de resultados por página.    |

### 4.2 Formato de respuesta (colecciones)

```json
{
  "data": [ /* array de recursos */ ],
  "meta": {
    "page": 1,
    "per_page": 25,
    "total_count": 42,
    "total_pages": 2
  }
}
```

### 4.3 Formato de errores

```json
{
  "error": {
    "code": "invalid_parameter",
    "message": "date_field is invalid",
    "details": {}
  }
}
```

| Código HTTP | `code`              | Cuándo ocurre                                                                 |
|-------------|---------------------|--------------------------------------------------------------------------------|
| 401         | `invalid_api_key`   | Falta el header, la clave es incorrecta, fue revocada o expiró.               |
| 404         | `not_found`         | El contenedor o la partida no existe, o pertenece a otro consolidador.        |
| 422         | `invalid_parameter` | Falta o es inválido un parámetro, incluyendo un rango incompleto o filtros de fecha incompatibles. |

Por seguridad, un recurso que pertenece a otro consolidador **siempre responde `404`**, nunca `403`, para no revelar su existencia.

### 4.4 Fechas

Los campos de fecha y hora se devuelven en ISO 8601 UTC, por ejemplo `2026-09-05T20:15:40Z`; los campos de tipo fecha se devuelven como `YYYY-MM-DD`. Los filtros de fecha (`date_from`, `date_to`) también usan `YYYY-MM-DD`. `updated_since` requiere un timestamp ISO 8601 UTC con zona explícita `Z` o `+00:00`; el límite es inclusivo (`updated_at >= updated_since`).

`updated_since` es mutuamente excluyente con `date_from` y `date_to`. En los listados globales de contenedores y partidas debe enviarse `updated_since` o un rango completo. Con `updated_since`, los resultados se ordenan por `updated_at ASC, id ASC`; con un rango se conserva el orden histórico descendente.

La sincronización con `updated_since` usa cursor: la primera respuesta incluye `sync_until` y `next_cursor`; para continuar, envía el cursor y conserva los mismos filtros. El cursor mantiene una ventana fija y avanza después del último par `(updated_at, id)`. No envíes `page` ni `updated_since` junto con `cursor`. Las consultas históricas siguen usando `page` y `per_page`.

Cuando una partida cambia, su contenedor actualiza `updated_at`. Lo mismo ocurre al agregar o actualizar una fotografía del contenedor o de una partida. Así, el siguiente delta de contenedores detecta también esos cambios asociados.

## 5. Endpoints

### 5.1 Listar contenedores

```http
GET /api/v1/consolidator/containers
```

**Parámetros de consulta:**

| Parámetro     | Tipo   | Descripción                                                                 |
|---------------|--------|-------------------------------------------------------------------------------|
| `status`      | string | Estatus exacto del contenedor (ej. `activo`, `desconsolidado`).               |
| `number`      | string | Búsqueda parcial por número de contenedor.                                    |
| `reference`   | string | Búsqueda parcial por referencia interna (`archivo_nr`).                       |
| `bl_master`   | string | Búsqueda parcial por BL Master.                                               |
| `date_field`  | string | `created_at` (default) o `fecha_desconsolidacion`. Define sobre qué campo se aplica el rango de fechas. |
| `date_from`   | date   | Fecha inicial del rango (`YYYY-MM-DD`); debe enviarse junto con `date_to` y no puede combinarse con `updated_since`. |
| `date_to`     | date   | Fecha final del rango (`YYYY-MM-DD`), igual o posterior a `date_from`. No puede combinarse con `updated_since`. |
| `updated_since` | datetime | Timestamp ISO 8601 UTC inclusivo; alternativo al rango de fechas. Ordena por `updated_at ASC, id ASC`. |
| `cursor`      | string | Cursor opaco de continuación devuelto por la API; se usa en lugar de `updated_since` para las siguientes páginas delta. |
| `page`        | int    | Ver [Paginación](#41-paginación); no se admite junto con `updated_since`/`cursor`. |
| `per_page`    | int    | Ver [Paginación](#41-paginación).                                             |

**Ejemplo de solicitud:**

```bash
curl -s \
  -H "Authorization: Bearer dsc_live_XXXX..." \
  -H "Accept: application/json" \
  "https://www.globaldyc.com/api/v1/consolidator/containers?status=activo&date_field=fecha_desconsolidacion&date_from=2026-08-01&date_to=2026-08-31&page=1&per_page=25"
```

**Ejemplo de respuesta `200 OK`:**

```json
{
  "data": [
    {
      "id": 481,
      "number": "MSCU1234567",
      "bl_master": "BL-2026-0091",
      "reference": "REF-2026-0091",
      "status": "desconsolidado",
      "tipo_maniobra": "importacion",
      "type_size": "40HC",
      "recinto": "SSA",
      "almacen": "OCUPA",
      "fecha_desconsolidacion": "2026-08-15",
      "fecha_descarga": "2026-08-10T14:32:00Z",
      "created_at": "2026-08-01T09:00:00Z",
      "updated_at": "2026-08-15T18:20:00Z",
      "consolidator": { "id": 12, "name": "Consolidadora Ejemplo S.A." },
      "shipping_line": { "id": 3, "name": "Maersk" },
      "vessel": { "id": 7, "name": "MSC Fantasia" },
      "voyage": { "id": 45, "code": "V-2026-33" },
      "origin_port": { "id": 2, "name": "Shanghai (CNSHA)" },
      "bl_house_lines_count": 6
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 25,
    "total_count": 1,
    "total_pages": 1
  }
}
```

**Ejemplo de sincronización incremental:**

```bash
curl -s \
  -H "Authorization: Bearer dsc_live_XXXX..." \
  -H "Accept: application/json" \
  "https://www.globaldyc.com/api/v1/consolidator/containers?updated_since=2026-09-01T12%3A00%3A00Z&per_page=100"
```

La respuesta delta incluye un cursor y el límite superior fijo de la ventana:

```json
{
  "data": [
    {
      "id": 481,
      "number": "MSCU1234567",
      "created_at": "2026-08-01T09:00:00Z",
      "updated_at": "2026-09-05T20:15:40Z",
      "bl_house_lines_count": 6
    }
  ],
  "meta": {
    "per_page": 100,
    "next_cursor": "eyJf...firma...",
    "sync_until": "2026-09-05T20:20:00.000000Z"
  }
}
```

Para continuar, envía `cursor` y `per_page`, sin `updated_since` ni `page`:

```bash
curl -s \
  -H "Authorization: Bearer dsc_live_XXXX..." \
  -H "Accept: application/json" \
  "https://www.globaldyc.com/api/v1/consolidator/containers?cursor=eyJf...firma...&per_page=100"
```

Repite mientras `meta.next_cursor` no sea `null`. Al terminar todas las páginas, avanza el watermark a `meta.sync_until`; aplica upsert para tolerar registros repetidos. Los cambios posteriores a `sync_until` quedan para la siguiente sincronización.

### 5.2 Listar partidas (BL House Lines) del consolidador

```http
GET /api/v1/consolidator/bl_house_lines
```

El endpoint devuelve partidas de todos los contenedores asignados al consolidador de la API Key. No acepta un identificador de consolidador proporcionado por el cliente.

**Parámetros de consulta:**

| Parámetro | Tipo | Descripción |
|-----------|------|-------------|
| `status` | string | Estatus exacto de la partida. |
| `updated_since` | datetime | Timestamp ISO 8601 UTC inclusivo; no combinar con `date_from`/`date_to`. Ordena por `updated_at ASC, id ASC`. |
| `date_from` | date | Inicio del rango histórico (`YYYY-MM-DD`), junto con `date_to`; filtra por `created_at`. |
| `date_to` | date | Fin del rango histórico (`YYYY-MM-DD`), igual o posterior a `date_from`. |
| `cursor` | string | Cursor opaco de continuación para una sincronización delta. |
| `page` | int | Ver [Paginación](#41-paginación); no se admite junto con `updated_since`/`cursor`. |
| `per_page` | int | Ver [Paginación](#41-paginación). |

Debe enviarse `updated_since` o el rango completo `date_from`/`date_to`. Los objetos de `data` conservan la serialización del endpoint de partidas por contenedor; cuando se usa delta, `meta` contiene `per_page`, `sync_until` y `next_cursor`.

**Ejemplo incremental:**

```bash
curl -s \
  -H "Authorization: Bearer dsc_live_XXXX..." \
  -H "Accept: application/json" \
  "https://www.globaldyc.com/api/v1/consolidator/bl_house_lines?updated_since=2026-09-01T12%3A00%3A00Z&per_page=100"
```

### 5.3 Listar partidas (BL House Lines) de un contenedor

```http
GET /api/v1/consolidator/containers/:container_id/bl_house_lines
```

El `:container_id` debe pertenecer al consolidador autenticado; en caso contrario, la respuesta es `404`.

**Parámetros de consulta:**

| Parámetro  | Tipo   | Descripción                              |
|------------|--------|--------------------------------------------|
| `status`   | string | Estatus exacto de la partida.               |
| `updated_since` | datetime | Timestamp ISO 8601 UTC inclusivo; no combinar con un rango. Ordena por `updated_at ASC, id ASC`. |
| `date_from` | date | Inicio del rango (`YYYY-MM-DD`), junto con `date_to`; filtra por `created_at`. |
| `date_to` | date | Fin del rango (`YYYY-MM-DD`), igual o posterior a `date_from`. |
| `cursor` | string | Cursor de continuación de una consulta incremental. |
| `page`     | int    | Ver [Paginación](#41-paginación); no se admite con `updated_since`/`cursor`. |
| `per_page` | int    | Ver [Paginación](#41-paginación).           |

**Ejemplo de solicitud:**

```bash
curl -s \
  -H "Authorization: Bearer dsc_live_XXXX..." \
  -H "Accept: application/json" \
  "https://www.globaldyc.com/api/v1/consolidator/containers/481/bl_house_lines?status=documentos_ok"
```

**Ejemplo de respuesta `200 OK`:**

```json
{
  "data": [
    {
      "id": 9021,
      "container_id": 481,
      "partida": 3,
      "blhouse": "HBL-0034521",
      "cantidad": 120,
      "packaging": { "id": 4, "name": "Caja" },
      "contiene": "Refacciones automotrices",
      "marcas": "ACME / SIN MARCAS",
      "peso": 850.5,
      "volumen": 3.2,
      "clase_imo": "0",
      "tipo_imo": "0",
      "telex": false,
      "status": "documentos_ok",
      "fecha_despacho": null,
      "created_at": "2026-08-02T10:15:00Z",
      "updated_at": "2026-08-16T08:00:00Z",
      "client": { "id": 55, "name": "Importadora ABC" },
      "customs_agent": { "id": 8, "name": "Agencia Aduanal del Pacífico" },
      "customs_broker": { "id": 21, "name": "Juan Pérez" }
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 25,
    "total_count": 1,
    "total_pages": 1
  }
}
```

**Respuesta cuando el contenedor no existe o pertenece a otro consolidador (`404`):**

```json
{
  "error": {
    "code": "not_found",
    "message": "Container not found.",
    "details": {}
  }
}
```

### 5.4 Metadatos de fotografías

Las fotografías de contenedor y de partida usan la misma estructura de respuesta, pero rutas distintas.

```http
GET /api/v1/consolidator/containers/:container_id/photos
GET /api/v1/consolidator/containers/:container_id/bl_house_lines/:bl_house_line_id/photos
```

**Secciones válidas (`section`):**

| Recurso    | Secciones permitidas                    | Sección por defecto |
|------------|------------------------------------------|----------------------|
| Contenedor | `apertura`, `desconsolidacion`, `vacio`   | `apertura`           |
| Partida    | `etiquetado`                              | `etiquetado`         |

**Parámetros de consulta:**

| Parámetro  | Tipo   | Descripción                                       |
|------------|--------|------------------------------------------------------|
| `section`  | string | Sección de fotos a consultar (ver tabla anterior).    |
| `page`     | int    | Ver [Paginación](#41-paginación).                     |
| `per_page` | int    | Ver [Paginación](#41-paginación).                     |

**Ejemplo de solicitud (fotos de contenedor):**

```bash
curl -s \
  -H "Authorization: Bearer dsc_live_XXXX..." \
  -H "Accept: application/json" \
  "https://www.globaldyc.com/api/v1/consolidator/containers/481/photos?section=apertura"
```

**Ejemplo de solicitud (fotos de partida):**

```bash
curl -s \
  -H "Authorization: Bearer dsc_live_XXXX..." \
  -H "Accept: application/json" \
  "https://www.globaldyc.com/api/v1/consolidator/containers/481/bl_house_lines/9021/photos?section=etiquetado"
```

**Ejemplo de respuesta `200 OK` (producción, almacenamiento S3):**

```json
{
  "data": [
    {
      "id": 30442,
      "section": "apertura",
      "filename": "apertura-01.jpg",
      "content_type": "image/jpeg",
      "byte_size": 245678,
      "created_at": "2026-08-10T13:05:00Z",
      "download_url": "https://desycon-bucket.s3.amazonaws.com/...&X-Amz-Expires=300&X-Amz-Signature=...",
      "expires_at": "2026-09-05T20:20:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 25,
    "total_count": 1,
    "total_pages": 1
  }
}
```

**Notas importantes sobre `download_url`:**

- Es una **URL presignada de S3** válida solo por el tiempo indicado en `expires_at` (5 minutos desde que se generó la respuesta).
- Debe descargarse **inmediatamente**; si expira, hay que volver a llamar al endpoint para obtener una URL nueva.
- No contiene ni requiere tu API Key: es de un solo uso temporal y cualquiera con el enlace puede descargar el archivo mientras esté vigente, así que no debe compartirse ni registrarse en logs públicos.
- La API nunca devuelve el binario ni una versión en base64 de la imagen: siempre se debe descargar desde `download_url`.

En entornos de prueba (Active Storage con almacenamiento local), `download_url` es una ruta relativa de la aplicación y `expires_at` es `null`.

## 6. Flujo típico de consumo

1. **Sincronizar contenedores modificados:**
  `GET /containers?updated_since=2026-09-01T12:00:00Z&per_page=100`, luego continuar con `cursor` hasta que `next_cursor` sea `null`.
2. **Sincronizar partidas modificadas:**
  `GET /bl_house_lines?updated_since=2026-09-01T12:00:00Z&per_page=100`, luego continuar con `cursor` hasta que `next_cursor` sea `null`.
3. **Para consultar las partidas de un contenedor específico, usar la ruta anidada:**
  `GET /containers/{container_id}/bl_house_lines`
4. **Para cada contenedor o partida, obtener metadatos de fotografías y descargarlas antes de que expire la URL:**
   `GET /containers/{container_id}/photos`
   `GET /containers/{container_id}/bl_house_lines/{bl_house_line_id}/photos`
5. **Avanzar el watermark delta** a `sync_until` solo después de terminar las páginas cursor de esa ventana.

Ejemplo de paginación completa en pseudocódigo:

```text
page = 1
loop:
  response = GET /containers?page={page}&per_page=100
  process(response.data)
  break if page >= response.meta.total_pages
  page += 1
```

## 7. Buenas prácticas de integración

- Cachea el resultado de `containers` y `bl_house_lines` por un periodo corto (por ejemplo, unos minutos) para reducir llamadas repetidas. Para sincronización delta, persiste el último `updated_at` procesado y tolera duplicados mediante upsert o una ventana de solapamiento.
- No hagas polling agresivo; el estado de contenedores y partidas no cambia con frecuencia menor a minutos.
- Descarga las fotografías apenas obtengas la URL; no almacenes `download_url` para uso posterior, ya que expira.
- Maneja explícitamente los códigos `401`, `404` y `422` en tu integración, en vez de asumir siempre `200`.
- Si tu integración deja de usarse, solicita al equipo de Desycon la revocación de la API Key correspondiente.

## 8. Límites y alcance

- La API es de **solo lectura**: no existen endpoints `POST`, `PATCH` ni `DELETE` para el consolidador.
- No es posible generar, listar ni revocar API Keys desde la API; esa gestión la realiza únicamente el equipo interno de Desycon.
- El límite máximo de `per_page` es 100 registros por página en todos los endpoints.
