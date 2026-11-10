# Desycon

Sistema de gestión de cargas LCL y revalidaciones electrónicas (asignación de mercancía electrónica) para agentes aduanales.

## Características

- 🔐 **Autenticación** - Sistema de usuarios con Devise
- 👥 **Autorización basada en roles** - Administrador, Operador, Agente Aduanal
- 🚢 **Gestión de Líneas Navieras** - CRUD completo con políticas de acceso
- 🎨 **UI Moderna** - Tailwind CSS con diseño responsive
- 🌐 **Internacionalización** - Interfaz completamente en español
- ⚡ **Hotwire** - Turbo y Stimulus para interactividad sin JavaScript pesado
- ✅ **Tests** - Suite completa con RSpec

## Stack Tecnológico

- **Ruby** 3.4.1
- **Rails** 8.1.1
- **PostgreSQL** - Base de datos
- **Tailwind CSS** 4.1.16 - Estilos
- **Hotwire** (Turbo + Stimulus) - Frontend interactivo
- **Devise** 4.9 - Autenticación
- **Pundit** 2.4 - Autorización
- **RSpec** - Testing
- **GitHub Actions** - CI/CD
- **Heroku** - Deployment

## Requisitos Previos

- Ruby 3.4.1
- PostgreSQL 14+
- Node.js (para importmap)

## Instalación

1. **Clonar el repositorio**
   ```bash
   git clone https://github.com/chucoyos/desycon.git
   cd desycon
   ```

2. **Instalar dependencias**
   ```bash
   bundle install
   ```

3. **Configurar base de datos**
   ```bash
   bin/rails db:create
   bin/rails db:migrate
   bin/rails db:seed
   ```

4. **Iniciar el servidor**
   ```bash
   bin/dev
   ```

5. **Acceder a la aplicación**
   - URL: http://localhost:3000

## Ejecutar Tests

```bash
# Todos los tests
bundle exec rspec

# Tests específicos
bundle exec rspec spec/models/
bundle exec rspec spec/requests/
bundle exec rspec spec/policies/

# Con cobertura
bundle exec rspec --format documentation
```

## Solicitudes de servicios en Lázaro Cárdenas

Las agencias pueden solicitar servicios de partida para MXLZC desde su listado
o el detalle de la partida. Se requiere que la partida pertenezca a la agencia,
esté revalidada, la factura de asignación esté pagada y la agencia no esté
restringida por facturas vencidas. La partida debe tener un cliente facturable
sin una asociación incompatible con la agencia.

Para solicitar la entrega (`BL-ENT-LZC`) es obligatorio adjuntar un único PDF
que contenga DODA, pedimento completo y simple pagado, tarja desconsol, MBL
revalidado y carta revalidado. Los demás servicios no lo requieren. El archivo
se abre en una pestaña nueva desde el detalle de la partida o el listado del
personal. El seguimiento de solicitudes en el detalle está disponible para la
agencia propietaria y para administradores y ejecutivos.

Al revalidar una partida MXLZC, se usa el catálogo activo `BL-ASIG-LZC` para
la asignación electrónica; las asignaciones históricas se conservan sin crear
un cargo duplicado. Al reasignar se crea una nueva asignación `BL-ASIG-LZC`.
Para solicitar servicios debe estar pagada la asignación más reciente, incluida
una factura directa o agrupada. Si falta el catálogo activo `BL-ASIG-LZC`, la
revalidación registra un error y la reasignación no se completa. Los demás
puertos conservan su catálogo de asignación existente.

El catálogo ofrece servicios de BL House activos con código terminado en `LZC`,
excepto las variantes automáticas de asignación, almacenaje, entrega, control
documental y custodia. La agencia indica la fecha requerida; administración
o un ejecutivo autoriza y asigna la hora, y puede reprogramar conservando la
fecha original. La ejecución se confirma en la solicitud y no cambia el estado
de despacho de la partida. El servicio autorizado se puede facturar; al
reprogramar no se modifican los servicios ya facturados.

Para importaciones MXLZC, el despacho genera el control documental `BL-CODIE-LZC`
y el almacenaje `BL-ALM-LZC` cuando se supera la gracia. El almacenaje usa el
monto diario de su catálogo, días cobrables, unidades y multiplicador IMO; para
`BL-ALM-LZC` se cobran como mínimo 10 unidades. El cálculo usa
fecha de desconsolidación y `fecha_despacho`, sin tramos. Los servicios históricos
`BL-ALMA` se conservan y no se genera otro almacenaje para la misma partida.
Ambos catálogos LZC deben estar activos; si alguno falta, el despacho continúa y
se registra un error. Los demás puertos conservan sus reglas.

El servicio solicitable `BL-PRV-LZC` (coordinación previo de carga en almacén
LZC) se calcula como `BL-PREVIO`: tarifa del catálogo por tonelada o m³, lo que
sea mayor, con un mínimo de 10 unidades y el multiplicador IMO existente. `BL-REAC-LZC` (coordinación reacomodo de carga) usa
la misma fórmula con un mínimo de 7 unidades, y `BL-POSC-LZC` (coordinación
posicionamiento de carga), `BL-MF-LZC` (maniobra en falso) y `BL-ENT-LZC` (entrega de almacén a camión, $626) con un mínimo de 10 unidades.

`BL-PA-LZC` (personal adicional) es tarifa fija por unidad: monto del catálogo ($1,300 + IVA) por la cantidad capturada, sin fórmula de peso o volumen.

`BL-ETQ-LZC` (colocación de etiqueta) es tarifa por etiqueta ($10 + IVA c/u): monto del catálogo por la cantidad capturada, sin mínimo.

`BL-PER-LZC` (pernoctaje en recinto) es tarifa por día ($2,500 + IVA): monto del catálogo por la cantidad de días capturada.

`BL-PMD-LZC` (programación mismo día) es tarifa fija por HBL ($3,447 + IVA): monto del catálogo con cantidad 1.

`BL-EMP-LZC` (emplaye) es tarifa por pallet ($500 + IVA): se calcula automáticamente con la `cantidad` de la partida; si no la tiene, usa la cantidad capturada.

`BL-FLJ-LZC` (fleje) es tarifa por metro ($300 + IVA): monto del catálogo por los metros capturados en la cantidad del servicio.

`BL-GRP-LZC` (sello metálico/grapas) es tarifa por pieza ($20 + IVA c/u): monto del catálogo por la cantidad capturada.

`BL-CLVS-LZC` (clavos) es tarifa por pieza ($15 + IVA c/u): monto del catálogo por la cantidad capturada.

`BL-REF-LZC` (refacturación) es tarifa fija ($1,200 + IVA): monto del catálogo con cantidad 1.

Para crear o actualizar los catálogos de estos servicios LZC (clave SAT 80151600, unidad E48) ejecuta únicamente `bin/rails runner db/seeds/lzc_services.rb`; es idempotente.

El listado de solicitudes muestra de inicio las de los últimos tres meses (por fecha de solicitud); se amplía cambiando o vaciando el filtro «Desde». Al autorizar `BL-PRV-LZC` se crea también automáticamente el servicio `BL-REAC-LZC` con la misma fecha programada; si su catálogo no existe o está inactivo, la autorización se rechaza.

## Runbooks Operativos

- Diagnostico rapido de colas Solid Queue: [docs/solid_queue_quick_diagnosis_runbook.md](docs/solid_queue_quick_diagnosis_runbook.md)
- Verificacion post-deploy de worker: [docs/worker_post_deploy_health_checklist.md](docs/worker_post_deploy_health_checklist.md)
- Configuracion de New Relic en Heroku: [docs/new_relic_addon_setup.md](docs/new_relic_addon_setup.md)

## Medicion de rendimiento de carga de fotos

Se incluye un script para medir tiempos del pipeline de fotos (request web, preprocesado de variantes y generacion de ZIP) usando logs de Heroku.

Archivo:

- script/measure_photo_pipeline.sh

Uso:

1. Activar logs de medicion temporalmente en la app objetivo:

   heroku config:set PHOTO_TIMING_LOGS=true -a desycon-staging

2. Ejecutar medicion (staging):

   script/measure_photo_pipeline.sh desycon-staging 12000

3. Ejecutar medicion (produccion):

   script/measure_photo_pipeline.sh desycon 12000

4. Desactivar logs de medicion al terminar:

   heroku config:unset PHOTO_TIMING_LOGS -a desycon-staging
   heroku config:unset PHOTO_TIMING_LOGS -a desycon

Notas:

- El script reporta eventos, errores, min/p50/p95/p99/avg/max por etapa.
- Incluye diagnostico automatico de cuello de botella con recomendaciones accionables.
- Con PHOTO_TIMING_LOGS apagado, no se emiten logs de medicion.
 
## Deployment

### Heroku

La aplicación está configurada para deployment en Heroku:

Las migraciones se ejecutan automáticamente en la fase `release` de cada deploy. Si necesitas ejecutarlas manualmente para una operación de mantenimiento:

```bash
heroku run rails db:migrate
```

Para abrir la consola de producción:
```bash
heroku run rails console
```

Variables de ambiente requeridas:

```env
DATABASE_URL=          # PostgreSQL connection string
RAILS_MASTER_KEY=      # Rails credentials master key
SECRET_KEY_BASE=       # Rails secret key
```

### Excepcion de auto-facturacion (partida)

La regla especial para omitir auto-facturacion en nivel partida cuando consolidador = cliente a facturar
se controla con variables de entorno del proceso Rails.

Variables:

```env
AUTO_ISSUE_NIPON_EXCEPTION_ENABLED=false
AUTO_ISSUE_NIPON_RFC=
```

Donde configurarlas:

- Development local: archivo `.env` en la raiz del proyecto (cargado por `dotenv-rails`).
- Staging: variables del entorno de despliegue (pipeline/servidor/contenedor).
- Produccion: secret manager o variables del runtime del servicio.

Valores recomendados por entorno:

```env
# development / staging (pruebas)
AUTO_ISSUE_NIPON_EXCEPTION_ENABLED=true
AUTO_ISSUE_NIPON_RFC=EWE1709045U0

# produccion (dato real)
AUTO_ISSUE_NIPON_EXCEPTION_ENABLED=true
AUTO_ISSUE_NIPON_RFC=<RFC_REAL_NIPON>
```

Notas:

- Si `AUTO_ISSUE_NIPON_EXCEPTION_ENABLED` es `false`, la regla no aplica.
- Si `AUTO_ISSUE_NIPON_RFC` esta vacio, la regla no aplica.

### Patron reusable: autocomplete para catalogos extensos

Para evitar lentitud en formularios con listas largas, se implemento un patron reusable de
autocomplete con busqueda en servidor. El primer piloto esta en el formulario de contenedores
para `Linea Naviera`, pero el mismo enfoque puede aplicarse a otros campos.

Objetivo:

- Mejorar UX en listas grandes sin cargar miles de opciones en el navegador.
- Reducir carga de servidor con limites, debounce y cache corta.
- Mantener compatibilidad con Turbo/Stimulus y fallback cuando no hay JavaScript.

Parametros de rendimiento (estandar):

- `minChars`: 2
- `limit`: 20 resultados maximos por consulta
- `debounce`: 300ms en cliente
- `cache TTL`: 60 segundos por termino

Implementacion actual del patron (estado vigente):

- Endpoint de busqueda dedicado por recurso (en el piloto: `shipping_lines_search`).
- Retorno temprano cuando el termino tiene menos de 2 caracteres.
- Limite duro de 20 resultados aplicado en backend.
- Cache corta por termino (60s) para reducir consultas repetidas.
- Payload compacto para UI (`id`, `label`, `subtitle`, `meta`).
- Input visible + hidden field para enviar el `*_id` real al submit.
- Componente Stimulus reusable con debounce y cancelacion de requests obsoletos (`AbortController`).
- Estado visual de carga, sin resultados y errores de red.
- Navegacion por teclado (flechas arriba/abajo, Enter, Escape).
- Preseleccion automatica de la primera opcion para seleccionar con Enter sin clic.
- Fallback funcional para no-JS usando `noscript`.

Nota operativa importante (filtros GET en index):

- Si el autocomplete vive dentro de un formulario de filtros (`form_with method: :get`), puede fallar de forma intermitente con Turbo (por ejemplo: funciona una vez y en intentos posteriores no aplica el filtro correctamente hasta recargar).
- Solucion recomendada: desactivar Turbo solo para ese formulario de filtros con `data: { turbo: false }`.
- Esta medida mantiene el componente Stimulus estable entre busquedas consecutivas y evita estados residuales del snapshot de navegacion.

Ejemplo recomendado para filtros con autocomplete:

```erb
<%= form_with url: containers_path, method: :get, class: "w-full", data: { turbo: false } do |f| %>
   <!-- filtros -->
<% end %>
```

Comportamiento UX esperado del componente:

1. Usuario escribe 2+ caracteres.
2. Se ejecuta busqueda con debounce.
3. Se muestran resultados y la primera opcion queda activa.
4. Enter selecciona la opcion activa y llena el input + hidden id.
5. Si cambia el texto manualmente, se limpia el hidden id para evitar submit inconsistente.

Contrato JSON recomendado:

```json
{
   "results": [
      {
         "id": 123,
         "label": "Nombre visible",
         "subtitle": "Dato secundario opcional"
      }
   ],
   "meta": {
      "query": "na",
      "min_chars": 2,
      "limit": 20,
      "count": 1
   }
}
```

Checklist para implementar en otro formulario:

1. Modelo: agregar scope de busqueda seguro (sanitizar termino y ordenar por nombre).
2. Ruta: exponer endpoint `collection` de busqueda para ese recurso.
3. Controlador: validar `minChars`, aplicar `limit` duro, cachear resultados y autorizar acceso.
4. Vista: usar input visible + hidden field para el `*_id` real enviado al submit.
5. Frontend: reutilizar `catalog_autocomplete_controller.js` con `data-*` para URL, minChars y debounce.
6. Fallback: mantener una opcion funcional para usuarios sin JS (por ejemplo `noscript` + `collection_select`).
7. Pruebas: cubrir endpoint JSON, limites, autorizacion y persistencia de `*_id` en create/update.
8. UX: verificar que la primera opcion se preselecciona y Enter funciona sin clic.
9. Si es filtro GET en index: desactivar Turbo en ese `form_with` para evitar comportamiento intermitente del autocomplete.

Archivos de referencia del piloto:

- `app/javascript/controllers/catalog_autocomplete_controller.js`
- `app/controllers/containers_controller.rb` (`shipping_lines_search`)
- `app/models/shipping_line.rb` (`search_by_name`)
- `app/views/containers/_form.html.erb`
- `spec/requests/containers_spec.rb`

Recomendacion de adopcion incremental:

1. Migrar primero campos de alta frecuencia de uso.
2. Medir latencia p95 del endpoint antes y despues.
3. Mantener los mismos guardrails (2 caracteres, limite 20, cache 60s) salvo justificacion puntual.

Plantilla minima de integracion (copiar y adaptar):

1. Ruta (collection):

```ruby
resources :mi_recurso do
   collection do
      get :catalog_search
   end
end
```

2. Accion en controlador:

```ruby
def catalog_search
   authorize MiRecurso, :create?

   query = params[:q].to_s.strip
   min_chars = 2
   limit = 20

   if query.length < min_chars
      return render json: { results: [], meta: { query: query, min_chars: min_chars, limit: limit, count: 0 } }
   end

   cache_key = ["mi_recurso", "catalog_search", query.downcase, limit].join(":")
   results = Rails.cache.fetch(cache_key, expires_in: 60.seconds) do
      CatalogModel.search_by_name(query).limit(limit).pluck(:id, :name).map do |id, name|
         { id: id, label: name }
      end
   end

   render json: { results: results, meta: { query: query, min_chars: min_chars, limit: limit, count: results.size } }
end
```

3. Scope en modelo:

```ruby
scope :search_by_name, lambda { |query|
   term = query.to_s.strip
   return none if term.blank?

   sanitized = ActiveRecord::Base.sanitize_sql_like(term.downcase)
   where("LOWER(name) LIKE ?", "%#{sanitized}%").order(:name)
}
```

4. Vista (input visible + hidden id):

```erb
<div
   data-controller="catalog-autocomplete"
   data-catalog-autocomplete-url-value="<%= catalog_search_mi_recurso_index_path %>"
   data-catalog-autocomplete-min-chars-value="2"
   data-catalog-autocomplete-debounce-value="300"
>
   <%= form.hidden_field :catalog_model_id,
            disabled: true,
            data: { catalog_autocomplete_target: "hiddenInput" } %>

   <%= text_field_tag :catalog_model_search,
            @registro.catalog_model&.name,
            autocomplete: "off",
            data: {
               catalog_autocomplete_target: "input",
               action: "input->catalog-autocomplete#onInput keydown->catalog-autocomplete#onKeydown focus->catalog-autocomplete#onFocus blur->catalog-autocomplete#onBlur"
            } %>

   <div data-catalog-autocomplete-target="status"></div>
   <div data-catalog-autocomplete-target="results" class="hidden"></div>
</div>

<noscript>
   <%= form.collection_select :catalog_model_id, @catalog_models, :id, :name, { prompt: "Seleccione" }, required: true %>
</noscript>
```

5. Reglas de QA rapido:

- Con 1 caracter: no debe consultar ni mostrar lista.
- Con 2+ caracteres: debe consultar con debounce.
- Enter sin clic: debe seleccionar la primera opcion activa.
- Si el usuario edita texto despues de seleccionar: hidden id debe limpiarse.
- Submit final: debe persistir `*_id`, no el texto visible.
- Repetir 2+ ciclos de filtrar-cambiar-filtar sin recarga manual: el filtro debe seguir aplicando correctamente.

## CI/CD

El proyecto usa GitHub Actions para:
- ✅ Análisis de seguridad (Brakeman)
- ✅ Linting (RuboCop)
- ✅ Tests automáticos (RSpec)
- ✅ Checks en cada PR y push


## Roadmap

- [ ] Módulo de Puertos
- [ ] Módulo de Embarcaciones
- [ ] Módulo de Contenedores
- [ ] Sistema de Revalidaciones (Partidas)
- [ ] Carga de documentos con ActiveStorage
- [ ] Sistema de notificaciones
- [ ] Dashboard con estadísticas
- [ ] Exportación de reportes (PDF/Excel)
- [ ] API REST para integraciones

## Licencia

MIT License - ver el archivo [LICENSE](LICENSE) para más detalles.

## Contacto

Proyecto desarrollado para la gestión de operaciones aduanales LCL.

## Escalado horario de dynos en recurring.yml

El escalado horario se ejecuta por jobs recurrentes en `config/recurring.yml` (solo `production`), mediante `Heroku::ScaleFormationJob`.

Regla implementada:

- `07:30` -> perfil `day` -> `standard-2x`
- `19:00` -> perfil `night` -> `standard-1x`

Procesos afectados:

- `web`
- `worker_active_storage`

El proceso `worker` no se modifica.

Archivo de job:

- `app/jobs/heroku/scale_formation_job.rb`

Config vars requeridas en producción:

- `SCALE_APP_NAME` (ejemplo: `desycon`)
- `SCALE_HEROKU_API_KEY` (token API de Heroku con permisos sobre la app)

Comandos sugeridos:

```bash
heroku config:set SCALE_APP_NAME=desycon -a desycon
heroku config:set SCALE_HEROKU_API_KEY=TU_TOKEN -a desycon
```

Migración recomendada si ya creaste variables legacy `HEROKU_*`:

```bash
heroku config:set SCALE_APP_NAME=desycon -a desycon
heroku config:set SCALE_HEROKU_API_KEY=TU_TOKEN -a desycon
heroku config:unset HEROKU_SCALE_APP -a desycon
heroku config:unset HEROKU_API_KEY -a desycon
```

Notas:

- El job aborta fuera de `production`.
- Si el tamaño ya coincide, no envía actualización (idempotente).
