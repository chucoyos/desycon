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

```bash
 
 
# Ejecutar migraciones
heroku run rails db:migrate

# Crear datos iniciales
heroku run rails console
 
## Configuración de Ambiente

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

