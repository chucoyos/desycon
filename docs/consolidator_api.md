# API del Consolidador

Guía de referencia para que un consolidador integre su sistema con Global DYC y consulte sus contenedores, partidas (BL House Lines) y fotografías mediante una API REST de solo lectura.

## 1. Resumen

- **Base URL:** `https://www.globaldyc.com/api/v1/consolidator`
- **Formato:** JSON (`Accept: application/json`)
- **Autenticación:** API Key tipo `Bearer`
- **Alcance:** Solo lectura (`GET`). No se puede crear, modificar ni eliminar información mediante esta API.
- **Multi-tenant:** Cada API Key pertenece a un único consolidador. Solo se devuelven datos de ese consolidador; nunca se acepta un identificador de consolidador enviado por el cliente.
- **Consulta de contenedores:** Debe indicar un rango completo mediante `date_from` y `date_to` para evitar consultas masivas.

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

Todos los listados aceptan:

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
| 422         | `invalid_parameter` | Falta o es inválido un parámetro, incluyendo el rango obligatorio de fechas.  |

Por seguridad, un recurso que pertenece a otro consolidador **siempre responde `404`**, nunca `403`, para no revelar su existencia.

### 4.4 Fechas

Todas las fechas se devuelven en formato ISO 8601 UTC, por ejemplo `2026-09-05T20:15:40Z`. Los filtros de fecha (`date_from`, `date_to`) deben enviarse como `YYYY-MM-DD`.

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
| `date_from`   | date   | **Obligatorio.** Fecha inicial del rango (`YYYY-MM-DD`).                       |
| `date_to`     | date   | **Obligatorio.** Fecha final del rango (`YYYY-MM-DD`) y debe ser igual o posterior a `date_from`. |
| `page`        | int    | Ver [Paginación](#41-paginación).                                             |
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

### 5.2 Listar partidas (BL House Lines) de un contenedor

```http
GET /api/v1/consolidator/containers/:container_id/bl_house_lines
```

El `:container_id` debe pertenecer al consolidador autenticado; en caso contrario, la respuesta es `404`.

**Parámetros de consulta:**

| Parámetro  | Tipo   | Descripción                              |
|------------|--------|--------------------------------------------|
| `status`   | string | Estatus exacto de la partida.               |
| `page`     | int    | Ver [Paginación](#41-paginación).           |
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

### 5.3 Metadatos de fotografías

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

1. **Listar contenedores recientes o filtrados por fecha de desconsolidación:**
   `GET /containers?date_field=fecha_desconsolidacion&date_from=...&date_to=...`
2. **Para cada contenedor de interés, obtener sus partidas:**
   `GET /containers/{container_id}/bl_house_lines`
3. **Para cada contenedor o partida, obtener metadatos de fotografías y descargarlas antes de que expire la URL:**
   `GET /containers/{container_id}/photos`
   `GET /containers/{container_id}/bl_house_lines/{bl_house_line_id}/photos`
4. **Repetir paginando** con `page` mientras `meta.page < meta.total_pages`.

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

- Cachea el resultado de `containers` y `bl_house_lines` por un periodo corto (por ejemplo, unos minutos) para reducir llamadas repetidas.
- No hagas polling agresivo; el estado de contenedores y partidas no cambia con frecuencia menor a minutos.
- Descarga las fotografías apenas obtengas la URL; no almacenes `download_url` para uso posterior, ya que expira.
- Maneja explícitamente los códigos `401`, `404` y `422` en tu integración, en vez de asumir siempre `200`.
- Si tu integración deja de usarse, solicita al equipo de Desycon la revocación de la API Key correspondiente.

## 8. Límites y alcance

- La API es de **solo lectura**: no existen endpoints `POST`, `PATCH` ni `DELETE` para el consolidador.
- No es posible generar, listar ni revocar API Keys desde la API; esa gestión la realiza únicamente el equipo interno de Desycon.
- El límite máximo de `per_page` es 100 registros por página en todos los endpoints.
