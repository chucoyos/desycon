# New Relic Add-on Setup (Heroku)

Aplicacion objetivo: desycon

## 1) Elegir y crear el add-on

Primero revisa los planes disponibles:

```bash
heroku addons:plans newrelic
```

Luego crea el add-on en la app:

```bash
heroku addons:create newrelic:<PLAN> -a desycon
```

Ejemplo (sustituye por un plan valido en tu cuenta):

```bash
heroku addons:create newrelic:standard -a desycon
```

## 2) Configurar nombre de aplicacion para APM

```bash
heroku config:set NEW_RELIC_APP_NAME=desycon -a desycon
```

Si quieres separar por entorno, usa otro nombre en staging.

## 3) Confirmar variables en Heroku

```bash
heroku config -a desycon | grep NEW_RELIC
```

Debes ver al menos:
- NEW_RELIC_LICENSE_KEY (inyectada por el add-on)
- NEW_RELIC_APP_NAME

## 4) Codigo necesario en Rails

Este repositorio ya incluye:
- Gem `newrelic_rpm` en Gemfile
- Archivo `config/newrelic.yml`

Instala dependencias y despliega para activar instrumentacion:

```bash
bundle install
git add Gemfile Gemfile.lock config/newrelic.yml
git commit -m "Add New Relic Ruby agent configuration"
git push heroku HEAD:main
```

Ajusta el push segun tu flujo real de ramas/pipeline.

## 5) Reiniciar dynos

```bash
heroku ps:restart -a desycon
```

## 6) Validar que reporta datos

1. Abre New Relic:

```bash
heroku addons:open newrelic -a desycon
```

2. Genera trafico a la app (navegacion normal o curl).

3. Verifica en APM que aparezca la aplicacion y transacciones web en pocos minutos.

## 7) Troubleshooting rapido

Si no aparece telemetria:
- Verifica que `NEW_RELIC_LICENSE_KEY` exista en Heroku.
- Revisa que `NEW_RELIC_APP_NAME` no este vacio.
- Confirma que el deploy incluye `Gemfile.lock` con `newrelic_rpm`.
- Reinicia dynos tras cambiar variables.
- Revisa logs:

```bash
heroku logs --tail -a desycon | grep -i newrelic
```
