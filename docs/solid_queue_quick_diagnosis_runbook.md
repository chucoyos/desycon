# Solid Queue Quick Diagnosis Runbook (Production)

Aplicacion: desycon
Objetivo: tener a la mano un flujo corto para detectar y atender colas atoradas.

## Comandos rapidos (copiar/pegar)

1. Estado de dynos

```bash
heroku ps --app desycon
```

2. Salud de colas (ready/claimed/failed y por cola)

```bash
heroku run --app desycon 'bin/rails runner "puts({ready_total: SolidQueue::ReadyExecution.count, claimed_total: SolidQueue::ClaimedExecution.count, failed_total: SolidQueue::FailedExecution.count, ready_by_queue: SolidQueue::ReadyExecution.joins(:job).group(\"solid_queue_jobs.queue_name\").count, claimed_by_queue: SolidQueue::ClaimedExecution.joins(:job).group(\"solid_queue_jobs.queue_name\").count}.to_json)"'
```

3. Heartbeats y suscripciones de procesos Solid Queue

```bash
heroku run --app desycon 'bin/rails runner "puts SolidQueue::Process.order(last_heartbeat_at: :desc).limit(20).map { |p| {kind: p.kind, name: p.name, heartbeat: p.last_heartbeat_at, metadata: p.metadata} }.to_json"'
```

4. Verificar cola recurring (debe mantenerse en 0 en estado normal)

```bash
heroku run --app desycon 'bin/rails runner "scope = SolidQueue::ReadyExecution.joins(:job).where(solid_queue_jobs: { queue_name: \"solid_queue_recurring\" }); puts({count: scope.count, oldest: scope.minimum(:created_at), newest: scope.maximum(:created_at)}.to_json)"'
```

5. Logs de worker principal (errores/restarts)

```bash
heroku logs --dyno worker -n 300 --app desycon
```

6. Logs de worker active_storage (errores/restarts/memoria)

```bash
heroku logs --dyno worker_active_storage -n 300 --app desycon
```

7. Logs de memoria por dyno web (comparar procesos)

```bash
# Ver logs de memoria del 1
heroku logs --ps web.1 --app desycon | grep "sample#memory_total"

# Ver logs de memoria del 2
heroku logs --ps web.2 --app desycon | grep "sample#memory_total"
# ver logs de memoria del active_storage
heroku logs --dyno worker_active_storage -n 300 --app desycon | grep "sample#memory_total"

heroku logs --dyno worker -n 300 --app desycon | grep "sample#memory_total"

```

8. Entrar a Rails console en produccion

```bash
heroku run rails c -a desycon
```

## Inspeccion en Rails console (Solid Queue)

Para ver el nombre de la tarea especifica (ej. `ProcessXmlJob`):

```ruby
SolidQueue::Job.where(id: SolidQueue::ClaimedExecution.pluck(:job_id))
```

Para ver los procesos en Rails console:

```ruby
SolidQueue::Process.all.each do |process|
  job_ids = process.claimed_executions.pluck(:job_id)
  puts "Worker: #{process.metadata['hostname']} | Jobs en curso (ID): #{job_ids}"
end
```

Si quieres saber no solo el ID, sino que esta haciendo:

```ruby
SolidQueue::Process.all.each do |p|
  jobs = SolidQueue::Job.where(id: p.claimed_executions.pluck(:job_id))

  if jobs.any?
    jobs.each { |j| puts "Worker: #{p.metadata['hostname']} esta procesando: #{j.class_name} (ID: #{j.id})" }
  else
    puts "Worker: #{p.metadata['hostname']} esta libre (Idle)."
  end
end
```

## Interpretacion rapida

- Senal sana:
  - ready_total bajo o 0
  - claimed_total > 0 durante carga
  - heartbeats recientes en Scheduler/Dispatcher/Worker
- Senal de atoron:
  - ready_total creciendo por varios minutos
  - claimed_total en 0 mientras ready sube
  - una cola especifica se acumula (ej. active_storage o solid_queue_recurring)
  - heartbeats viejos o procesos faltantes

## Acciones inmediatas (sin deploy)

1. Reiniciar worker principal si default/mailers/recurring no reclaman jobs

```bash
heroku ps:restart worker --app desycon
```

2. Reiniciar worker active_storage si se atora esa cola

```bash
heroku ps:restart worker_active_storage --app desycon
```

3. Reiniciar dyno web puntual cuando un proceso se infla en memoria

```bash
# Forma tradicional
heroku restart web.1 --app desycon
heroku restart web.2 --app desycon

# Forma recomendada actual en Heroku CLI
heroku ps:restart web.1 --app desycon
heroku ps:restart web.2 --app desycon
```

4. Verificar configuracion de colas del worker principal

```bash
heroku config --app desycon | grep '^JOB_QUEUES:'
```

Valor esperado actual:

```text
JOB_QUEUES: default,mailers,solid_queue_recurring
```

## Contingencia para backlog viejo de recurring

Usar solo cuando se confirme que hay backlog historico de recurring que no corresponde ejecutar en cascada.

```bash
heroku run --app desycon 'bin/rails runner "deleted = SolidQueue::Job.where(queue_name: \"solid_queue_recurring\", finished_at: nil).delete_all; puts({deleted: deleted}.to_json)"'
```

## Nota operativa

Con Judoscale activo, los picos de cola deberian disiparse con autoscaling. Si el backlog persiste aun con scale-up, revisar:

- jobs pesados (fotos/lotes grandes)
- errores repetidos en provider externo
- limites de dynos maximos configurados en Judoscale