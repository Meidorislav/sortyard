# API & WebSocket Contracts

> Canonical interface specification between the Go backend and the React frontend.
> All team members working on either side must follow this document. | [Русская версия](./i18n/ru/README.md)

---

## 1. Conventions

| Convention | Value |
|---|---|
| Base URL | `http://localhost:8080` |
| Content-Type | `application/json` |
| IDs | UUID v4 strings |
| Timestamps | ISO 8601 (`2026-06-20T10:00:00Z`) |
| `sim_time_s` | Integer seconds of **simulation** time (not wall clock) |
| Boolean flags | `true` / `false` |

**Zone names** used consistently across REST and WebSocket:

| Key | Zone |
|---|---|
| `inbound` | Inbound (receiving docks) |
| `induction` | Induction stations |
| `sorter` | Main conveyor |
| `chutes` | Sorting chutes |
| `packing` | Packing workstations |
| `outbound` | Outbound (shipping docks) |
| `buffer` | Buffer storage (exceptions) |

---

## 2. REST API

### 2.1. Scenarios

#### `POST /api/scenarios` — Create scenario

**Request**

```json
{
  "name": "Baseline",
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

**Response `201`**

```json
{
  "id": "a1b2c3d4-...",
  "name": "Baseline",
  "config": { "...": "..." },
  "created_at": "2026-06-20T10:00:00Z"
}
```

---

#### `GET /api/scenarios` — List scenarios

**Response `200`**

```json
[
  {
    "id": "a1b2c3d4-...",
    "name": "Baseline",
    "created_at": "2026-06-20T10:00:00Z"
  }
]
```

---

#### `GET /api/scenarios/:id` — Get scenario

**Response `200`** — full object same as `POST` response.

---

### 2.2. Simulations

#### `POST /api/simulations` — Start simulation

Run parameters are separate from the scenario so the same scenario can be re-run with a different seed.

**Request**

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

**Response `201`**

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

#### `GET /api/simulations/:id` — Run status

**Response `200`** — same shape as `POST /api/simulations` response, with `sim_time_s` updated.

---

#### `GET /api/simulations/:id/results` — Final KPIs

Only available when `status == "done"`.

**Response `200`**

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
      "description": "Queue at induction exceeded 50 units"
    }
  ]
}
```

`bottleneck.type`: `"queue_overflow"` | `"high_utilization"` | `"chute_full"` | `"dock_wait"`
`bottleneck.severity`: `"warning"` | `"critical"`

---

#### `POST /api/simulations/:id/pause` — Pause / Resume

No request body. Toggles: pauses a running simulation, resumes a paused one.

**Response `200`**

```json
{ "status": "paused" }
```

or

```json
{ "status": "running" }
```

---

#### `POST /api/simulations/:id/stop` — Stop

No request body. Transitions status to `"done"` and closes the WebSocket stream.

**Response `200`**

```json
{ "status": "done" }
```

---

#### `GET /api/simulations/compare` — Compare runs

**Query params:** `?run_ids=uuid1,uuid2` (comma-separated, 2–5 IDs)

**Response `200`**

```json
{
  "runs": [
    {
      "run_id": "e5f6g7h8-...",
      "scenario_name": "Baseline",
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
      "scenario_name": "Peak Load",
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

### 2.3. Error Responses

All errors follow the same shape:

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Simulation run not found"
  }
}
```

| HTTP Status | Code | When |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Missing or invalid fields in request body |
| 404 | `NOT_FOUND` | Resource with given ID does not exist |
| 409 | `CONFLICT` | e.g. starting a simulation that is already running |
| 422 | `INVALID_STATE` | e.g. fetching results when status != "done" |
| 500 | `INTERNAL_ERROR` | Unexpected server-side error |

---

## 3. WebSocket Protocol

### 3.1. Connection

```
ws://localhost:8080/ws/simulations/:id
```

- **Direction:** server → client only. All simulation control goes through REST.
- **Format:** each message is a JSON object with a `type` field.
- The server closes the connection when simulation status becomes `"done"` or `"error"`.

---

### 3.2. Server → Client Events

#### `entity_move`

Emitted when an entity transitions between zones.

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

Emitted when a queue length or utilization changes at any zone. Sent at most once per simulation second per zone to avoid flooding.

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

Emitted every 60 seconds of simulation time (after the warmup period).

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

Emitted when a bottleneck condition is first triggered.

```json
{
  "type": "bottleneck_detected",
  "sim_time_s": 2341,
  "event_id": "uuid",
  "zone": "induction",
  "bottleneck_type": "queue_overflow",
  "severity": "warning",
  "description": "Queue at induction exceeded 50 units"
}
```

`bottleneck_type`: `"queue_overflow"` | `"high_utilization"` | `"chute_full"` | `"dock_wait"`
`severity`: `"warning"` | `"critical"`

---

#### `simulation_status`

Emitted when simulation state changes (pause, resume, done, error).

```json
{
  "type": "simulation_status",
  "sim_time_s": 5400,
  "status": "paused"
}
```

`status`: `"running"` | `"paused"` | `"done"` | `"error"`
