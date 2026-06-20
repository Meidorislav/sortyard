# PRD — Sorting Center Simulation

| Attribute | Value |
|---|---|
| Version | 1.0 |
| Date | June 2026 |
| Type | Hackathon |
| Stack | Go · PostgreSQL · TypeScript · React |

---

## 1. Product Overview

### 1.1. Goal

Build an interactive simulation of a sorting center that visualizes the movement of parcels, containers, and key flows in real time, detects bottlenecks, and demonstrates the measurable impact of optimization decisions.

### 1.2. Problem

Real sorting centers cannot test configuration changes without halting operations. Without a visual simulation tool, decisions are made without sufficient analytical grounding and often result in suboptimal outcomes.

### 1.3. Value Proposition

- Risk reduction: test changes without touching the real process
- Detect bottlenecks before they appear in production
- Compare optimization scenarios with quantitative metrics
- Educational value: intuitive understanding of sorting center dynamics

### 1.4. Hackathon Success Criteria

1. Working simulation with real-time flow visualization
2. Parameter changes visibly affect KPI output
3. At least 2–3 types of bottlenecks are detected and highlighted
4. Demo runs stably through a 5-minute simulation run

---

## 2. Scope

### 2.1. In Scope

| Component | Description |
|---|---|
| Simulation Engine (Go) | DES core: events, queues, resources, load generator |
| API Server (Go + REST/WS) | HTTP API for control, WebSocket for event streaming |
| Database (PostgreSQL) | Scenarios, run results, configuration storage |
| Web Client (TS + React) | Dashboard with visualization, parameter config, KPI panel |
| Bottleneck Analysis Module | Auto-detection and highlighting of problem zones |
| Load Generator | Configurable load patterns (flat, peak, double-peak) |

### 2.2. Out of Scope

- Integration with real WMS/TMS systems
- 3D warehouse visualization
- Mobile application
- Real-time multi-user collaboration
- ML-based predictive maintenance

---

## 3. Functional Requirements

### 3.1. Simulation Engine

**FR-SIM-01: Discrete-Event Simulation**
The engine implements DES with a priority event queue sorted by virtual time. Supports accelerated playback at 1x, 5x, 10x, 60x.

**FR-SIM-02: Modeled Zones**

- Inbound zone — N docks with configurable unloading time
- Induction zone — M stations with configurable throughput
- Main conveyor — belt speed, loop length, number of scanners
- Sorting chutes — K chutes with capacity and destination mapping
- Packing zone — J workstations with configurable handling time
- Outbound zone — L docks with departure schedule

**FR-SIM-03: Entity Types**

- Parcel: ID, destination, weight, dimensions, status, timestamps
- Vehicle: type, capacity, schedule
- Container (pallet/bin): ID, location, fill level

**FR-SIM-04: Load Generator**

Parameters: arrival distribution (Poisson / Uniform), intensity (units/hour), load pattern (flat / single-peak / double-peak), fraction of oversized items, fraction of unreadable barcodes.

**FR-SIM-05: Random Events**

- Equipment failures: configurable MTBF and MTTR per resource
- Unreadable barcodes: % of parcels routed to manual processing
- Sorting errors: % of parcels sent to wrong chute

---

### 3.2. API Server

**FR-API-01: REST Endpoints**

| Method | Path | Description |
|---|---|---|
| POST | /api/scenarios | Create scenario |
| GET | /api/scenarios | List scenarios |
| GET | /api/scenarios/:id | Get scenario |
| POST | /api/simulations | Start simulation |
| GET | /api/simulations/:id | Run status |
| GET | /api/simulations/:id/results | Results and KPIs |
| POST | /api/simulations/:id/pause | Pause / resume |
| POST | /api/simulations/:id/stop | Stop run |
| GET | /api/simulations/compare | Compare runs |

**FR-API-02: WebSocket Stream**

`ws://host/ws/simulations/:id` — streams events as JSON. Client subscribes to: `entity_move`, `queue_update`, `kpi_update`, `bottleneck_detected`.

---

### 3.3. Analytics and Bottleneck Detection

**FR-ANALYTICS-01: Automatic Bottleneck Detection**

- Queue Length Alert: queue exceeds configurable threshold
- Utilization Alert: resource utilization > 90% for > 5 min of simulation time
- Chute Overflow: chute fill > 80%, conveyor slows down
- Dock Congestion: all docks occupied, vehicle waiting

**FR-ANALYTICS-02: KPI Dashboard (real-time)**

Throughput (units/hour) · Average Cycle Time · Utilization by zone · Queue Length · Error Rate · Conveyor OEE

**FR-ANALYTICS-03: Scenario Comparison**

Run 2+ scenarios and compare final KPIs in a table and chart side-by-side.

---

### 3.4. Web Client

**FR-UI-01: Main View**
- Topological map of the center with live entity icons
- Color-coded zone status (green / yellow / red by load)
- Queue size overlay per resource

**FR-UI-02: Simulation Controls**
- Buttons: Start / Pause / Stop / Reset
- Speed slider: 1x / 5x / 10x / 60x
- Simulation time indicator and progress bar

**FR-UI-03: Scenario Editor**
- Parameter form per zone
- Presets: "Baseline", "Peak Load", "Minimum Staff"
- Save / load scenario to/from database

**FR-UI-04: KPI Panel**
- Recharts time-series charts: throughput, queue lengths
- Alerts with problem zone highlights on the map
- Multi-run comparison table

---

## 4. Non-Functional Requirements

| Category | Requirement | Target |
|---|---|---|
| Performance | Simulate 1 hour of center operation | < 10 sec real time at 60x |
| Performance | WebSocket streaming latency | < 100 ms |
| Performance | API response time (p95) | < 200 ms |
| Scale | Concurrent entities in system | Up to 10,000 parcels |
| Reliability | Determinism with same seed | 100% reproducibility |
| Reliability | Stability on 5-min demo | Mandatory |
| Usability | Time To First Result | < 30 sec from Start |
| Code quality | Engine unit test coverage | > 70% |

---

## 5. Tech Stack and Architecture

### 5.1. Stack

| Layer | Technology | Role | Rationale |
|---|---|---|---|
| Simulation | Go 1.22+ | DES engine, goroutines | Speed, concurrency |
| API | Go + chi | REST + WebSocket | Low latency |
| Database | PostgreSQL 16 | Scenarios, results | JSONB + analytics |
| Query | sqlc / pgx | Type-safe SQL | No ORM overhead |
| Frontend | TypeScript + React 18 | SPA | Type safety |
| Charts | Recharts + D3.js | KPI, center map | React-native, SVG |
| State | Zustand + React Query | Global state + server data | Lightweight |
| Build | Vite | Dev server + build | Fast HMR |
| Environment | Docker + docker-compose | Local stack | Easy demo setup |

### 5.2. Component Interaction

```
React SPA ──HTTPS REST──► Go API ──in-process──► Simulation Engine
React SPA ──WebSocket────► Go WS Server                   │
                                                           ▼
                                                    PostgreSQL 16
```

### 5.3. Database Schema

```sql
-- Scenario configurations
scenarios (
  id          UUID PRIMARY KEY,
  name        TEXT,
  config      JSONB,   -- parameters for all zones
  created_at  TIMESTAMPTZ
)

-- Simulation runs
simulation_runs (
  id                UUID PRIMARY KEY,
  scenario_id       UUID REFERENCES scenarios,
  status            TEXT,        -- pending | running | paused | done | error
  seed              BIGINT,
  speed_multiplier  INT,
  started_at        TIMESTAMPTZ,
  ended_at          TIMESTAMPTZ
)

-- KPI time series (snapshot every N sec of simulation time)
run_kpi_snapshots (
  run_id          UUID REFERENCES simulation_runs,
  sim_time        BIGINT,
  throughput      INT,
  avg_cycle_time  FLOAT,
  utilization     JSONB,    -- { "inbound": 0.72, "sorter": 0.91, ... }
  queue_lengths   JSONB
)

-- Detected bottleneck events
bottleneck_events (
  id          UUID PRIMARY KEY,
  run_id      UUID REFERENCES simulation_runs,
  sim_time    BIGINT,
  zone        TEXT,
  type        TEXT,    -- queue_overflow | high_utilization | chute_full | dock_wait
  severity    TEXT,    -- warning | critical
  description TEXT
)

-- Entity trace log (optional, debug mode only)
entity_log (
  run_id      UUID,
  entity_id   UUID,
  event_type  TEXT,
  zone        TEXT,
  sim_time    BIGINT
)
```

### 5.4. Libraries

**Backend (Go)**
- `github.com/go-chi/chi/v5` — HTTP router
- `github.com/gorilla/websocket` — WebSocket
- `github.com/jackc/pgx/v5` — PostgreSQL driver
- `github.com/google/uuid` — ID generation
- `golang.org/x/sync` — errgroup for goroutine management

**Frontend (TypeScript + React)**
- `recharts` — KPI charts
- `@tanstack/react-query` — server state
- `zustand` — global state (WS data, simulation status)
- `tailwindcss` — utility CSS
- `react-hook-form` + `zod` — forms with validation

---

## 6. User Stories

| ID | Role | Want | So That |
|---|---|---|---|
| US-01 | Analyst | Configure center parameters | Model a specific facility |
| US-02 | Analyst | Watch parcel movement | Understand system behavior |
| US-03 | Analyst | See where queues form | Find bottlenecks |
| US-04 | Manager | Compare 2 configurations | Justify automation investment |
| US-05 | Manager | Real-time KPIs | Assess operational efficiency |
| US-06 | Developer | Change the seed | Reproduce an experiment |
| US-07 | Analyst | Save a scenario | Return to it later |
| US-08 | Analyst | Trigger a peak load mid-run | Test system stress response |

---

## 7. Hackathon Roadmap

| Phase | Tasks |
|---|---|
| 0: Bootstrap | docker-compose, Go module, Vite + React, DB schema, base router |
| 1: Engine | Event queue, entities, DES loop, load generator, unit tests |
| 2: API + WS | REST CRUD, simulation runner, WebSocket streaming, DB integration |
| 3: Frontend | Center map (SVG), live WS events, KPI charts, scenario form |
| 4: Analytics | Bottleneck detector, map alerts, scenario comparison |
| 5: Polish | Presets, UX, result export, final demo rehearsal |

---

## 8. Risks and Mitigation

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Engine performance under load | Medium | High | Profile early; fall back to pure in-memory if needed |
| WebSocket sync complexity | Medium | Medium | Start with polling, migrate to WS later |
| Map visualization time cost | High | High | MVP: static SVG + numbers; animation is P2 |
| Simulation/render speed mismatch | Medium | Medium | Buffer events on client (500 ms queue) |
| Warm-up period skewing stats | Low | Medium | Add warm-up time param, exclude from KPI calculation |

---

## 9. Glossary

| Term | Definition |
|---|---|
| DES | Discrete-Event Simulation |
| SC | Sort Center |
| WMS | Warehouse Management System |
| TMS | Transport Management System |
| OEE | Overall Equipment Effectiveness |
| MTBF | Mean Time Between Failures |
| MTTR | Mean Time To Repair |
| WIP | Work In Progress — parcels currently being processed |
| Throughput | Processing capacity in units per hour |
| Utilization | Fraction of time a resource is busy |
| Cycle Time | End-to-end time for a parcel to traverse the center |
| Chute | Sorting output lane where parcels accumulate |
| Induction | Singulating and feeding parcels onto the conveyor one by one |
| Seed | Initial value for the PRNG ensuring reproducibility |

