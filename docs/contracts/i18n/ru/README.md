# Контракты API и WebSocket

> Официальная спецификация интерфейсов между Go бэкендом и React фронтендом.
> Все участники команды, работающие на любой из сторон, обязаны следовать этому документу.

---

## 1. Соглашения

| Параметр | Значение |
|---|---|
| Base URL | `http://localhost:8080` |
| Content-Type | `application/json` |
| ID | UUID v4 строки |
| Временны́е метки | ISO 8601 (`2026-06-20T10:00:00Z`) |
| `sim_time_s` | Целое число секунд **симуляционного** времени (не реального) |
| Булевы значения | `true` / `false` |

**Названия зон** — используются единообразно в REST и WebSocket:

| Ключ | Зона |
|---|---|
| `inbound` | Зона приёмки |
| `induction` | Зона индукции |
| `sorter` | Главный конвейер |
| `chutes` | Лотки сортировки |
| `packing` | Зона упаковки |
| `outbound` | Зона отгрузки |
| `buffer` | Буферный склад (исключения) |

---

## 2. REST API

### 2.1. Сценарии

#### `POST /api/scenarios` — Создать сценарий

**Запрос**

```json
{
  "name": "Базовый",
  "config": {
    "load_generator": {
      "distribution": "poisson",
      "intensity_per_hour": 5000,
      "pattern": "flat",
      "oversized_fraction": 0.05,
      "unreadable_barcode_fraction": 0.02
    },
    "inbound": {
      "num_docks": 4,
      "unloading_time_mean_s": 30,
      "unloading_time_std_s": 5,
      "mtbf_s": 3600,
      "mttr_s": 300
    },
    "induction": {
      "num_stations": 6,
      "throughput_per_hour": 1200,
      "error_rate": 0.01,
      "mtbf_s": 7200,
      "mttr_s": 180
    },
    "sorter": {
      "belt_speed_mps": 2.0,
      "loop_length_m": 200,
      "num_scanners": 4,
      "mtbf_s": 14400,
      "mttr_s": 600
    },
    "chutes": {
      "num_chutes": 40,
      "chute_capacity": 50,
      "sort_error_rate": 0.001
    },
    "packing": {
      "num_workstations": 8,
      "handling_time_mean_s": 45,
      "handling_time_std_s": 10
    },
    "outbound": {
      "num_docks": 6,
      "departure_interval_s": 1800
    }
  }
}
```

`distribution`: `"poisson"` | `"uniform"`
`pattern`: `"flat"` | `"single_peak"` | `"double_peak"`

**Ответ `201`**

```json
{
  "id": "a1b2c3d4-...",
  "name": "Базовый",
  "config": { "...": "..." },
  "created_at": "2026-06-20T10:00:00Z"
}
```

---

#### `GET /api/scenarios` — Список сценариев

**Ответ `200`**

```json
[
  {
    "id": "a1b2c3d4-...",
    "name": "Базовый",
    "created_at": "2026-06-20T10:00:00Z"
  }
]
```

---

#### `GET /api/scenarios/:id` — Получить сценарий

**Ответ `200`** — полный объект, аналогичный ответу `POST`.

---

### 2.2. Симуляции

#### `POST /api/simulations` — Запустить симуляцию

Параметры запуска отделены от сценария, чтобы один сценарий можно было перезапустить с другим seed.

**Запрос**

```json
{
  "scenario_id": "a1b2c3d4-...",
  "seed": 42,
  "speed_multiplier": 60,
  "duration_s": 28800,
  "warmup_s": 1800
}
```

`speed_multiplier`: `1` | `5` | `10` | `60`

**Ответ `201`**

```json
{
  "id": "e5f6g7h8-...",
  "scenario_id": "a1b2c3d4-...",
  "status": "running",
  "seed": 42,
  "speed_multiplier": 60,
  "duration_s": 28800,
  "warmup_s": 1800,
  "sim_time_s": 0,
  "started_at": "2026-06-20T10:00:00Z",
  "ended_at": null
}
```

`status`: `"pending"` | `"running"` | `"paused"` | `"done"` | `"error"`

---

#### `GET /api/simulations/:id` — Статус прогона

**Ответ `200`** — та же структура, что в ответе `POST /api/simulations`, с обновлённым `sim_time_s`.

---

#### `GET /api/simulations/:id/results` — Итоговые KPI

Доступен только при `status == "done"`.

**Ответ `200`**

```json
{
  "run_id": "e5f6g7h8-...",
  "status": "done",
  "summary": {
    "throughput_per_hour": 4823,
    "avg_cycle_time_s": 342.5,
    "error_rate": 0.0012,
    "conveyor_oee": 0.91,
    "utilization": {
      "inbound": 0.72,
      "induction": 0.88,
      "sorter": 0.91,
      "chutes": 0.65,
      "packing": 0.78,
      "outbound": 0.55
    },
    "max_queue_lengths": {
      "inbound": 18,
      "induction": 67,
      "packing": 23
    }
  },
  "bottlenecks": [
    {
      "id": "uuid",
      "sim_time_s": 3821,
      "zone": "induction",
      "type": "queue_overflow",
      "severity": "critical",
      "description": "Очередь на индукции превысила 50 единиц"
    }
  ]
}
```

`bottleneck.type`: `"queue_overflow"` | `"high_utilization"` | `"chute_full"` | `"dock_wait"`
`bottleneck.severity`: `"warning"` | `"critical"`

---

#### `POST /api/simulations/:id/pause` — Пауза / Возобновление

Тело запроса не нужно. Переключает состояние: ставит на паузу работающую симуляцию, возобновляет приостановленную.

**Ответ `200`**

```json
{ "status": "paused" }
```

или

```json
{ "status": "running" }
```

---

#### `POST /api/simulations/:id/stop` — Остановить

Тело запроса не нужно. Переводит статус в `"done"` и закрывает WebSocket-соединение.

**Ответ `200`**

```json
{ "status": "done" }
```

---

#### `GET /api/simulations/compare` — Сравнение прогонов

**Query-параметры:** `?run_ids=uuid1,uuid2` (через запятую, от 2 до 5 ID)

**Ответ `200`**

```json
{
  "runs": [
    {
      "run_id": "e5f6g7h8-...",
      "scenario_name": "Базовый",
      "seed": 42,
      "kpis": {
        "throughput_per_hour": 4823,
        "avg_cycle_time_s": 342.5,
        "error_rate": 0.0012,
        "conveyor_oee": 0.91,
        "utilization": {
          "inbound": 0.72,
          "induction": 0.88,
          "sorter": 0.91,
          "chutes": 0.65,
          "packing": 0.78,
          "outbound": 0.55
        }
      }
    },
    {
      "run_id": "i9j0k1l2-...",
      "scenario_name": "Пиковая нагрузка",
      "seed": 42,
      "kpis": {
        "throughput_per_hour": 3201,
        "avg_cycle_time_s": 518.7,
        "error_rate": 0.0031,
        "conveyor_oee": 0.74,
        "utilization": {
          "inbound": 0.95,
          "induction": 0.99,
          "sorter": 0.97,
          "chutes": 0.88,
          "packing": 0.94,
          "outbound": 0.81
        }
      }
    }
  ]
}
```

---

### 2.3. Ошибки

Все ошибки возвращаются в едином формате:

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Simulation run not found"
  }
}
```

| HTTP статус | Code | Когда |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Отсутствующие или невалидные поля в теле запроса |
| 404 | `NOT_FOUND` | Ресурс с указанным ID не существует |
| 409 | `CONFLICT` | Например, запуск уже запущенной симуляции |
| 422 | `INVALID_STATE` | Например, запрос результатов при status != "done" |
| 500 | `INTERNAL_ERROR` | Неожиданная ошибка на стороне сервера |

---

## 3. Протокол WebSocket

### 3.1. Подключение

```
ws://localhost:8080/ws/simulations/:id
```

- **Направление:** только сервер → клиент. Всё управление симуляцией идёт через REST.
- **Формат:** каждое сообщение — JSON-объект с полем `type`.
- Сервер закрывает соединение, когда статус симуляции становится `"done"` или `"error"`.

---

### 3.2. События сервера → клиент

#### `entity_move`

Отправляется при переходе сущности между зонами.

```json
{
  "type": "entity_move",
  "sim_time_s": 1423,
  "entity_id": "uuid",
  "entity_type": "parcel",
  "from_zone": "induction",
  "to_zone": "sorter",
  "status": "moving"
}
```

`entity_type`: `"parcel"` | `"vehicle"` | `"container"`
`status`: `"moving"` | `"waiting"` | `"processing"` | `"done"`

---

#### `queue_update`

Отправляется при изменении длины очереди или утилизации в любой зоне. Не чаще одного раза в секунду симуляционного времени на зону.

```json
{
  "type": "queue_update",
  "sim_time_s": 1423,
  "zone": "induction",
  "queue_length": 42,
  "utilization": 0.87
}
```

---

#### `kpi_update`

Отправляется каждые 60 секунд симуляционного времени (после окончания warm-up периода).

```json
{
  "type": "kpi_update",
  "sim_time_s": 1800,
  "throughput_per_hour": 4650,
  "avg_cycle_time_s": 318.2,
  "error_rate": 0.0014,
  "conveyor_oee": 0.89,
  "utilization": {
    "inbound": 0.71,
    "induction": 0.85,
    "sorter": 0.88,
    "chutes": 0.62,
    "packing": 0.76,
    "outbound": 0.51
  },
  "queue_lengths": {
    "inbound": 2,
    "induction": 15,
    "packing": 8
  }
}
```

---

#### `bottleneck_detected`

Отправляется в момент первого срабатывания условия узкого места.

```json
{
  "type": "bottleneck_detected",
  "sim_time_s": 2341,
  "event_id": "uuid",
  "zone": "induction",
  "bottleneck_type": "queue_overflow",
  "severity": "warning",
  "description": "Очередь на индукции превысила 50 единиц"
}
```

`bottleneck_type`: `"queue_overflow"` | `"high_utilization"` | `"chute_full"` | `"dock_wait"`
`severity`: `"warning"` | `"critical"`

---

#### `simulation_status`

Отправляется при изменении состояния симуляции (пауза, возобновление, завершение, ошибка).

```json
{
  "type": "simulation_status",
  "sim_time_s": 5400,
  "status": "paused"
}
```

`status`: `"running"` | `"paused"` | `"done"` | `"error"`
