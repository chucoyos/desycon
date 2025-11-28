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

