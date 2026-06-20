CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE scenarios (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT        NOT NULL,
  config      JSONB       NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE simulation_runs (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario_id       UUID        NOT NULL REFERENCES scenarios(id),
  status            TEXT        NOT NULL DEFAULT 'pending',
  seed              BIGINT      NOT NULL,
  speed_multiplier  INT         NOT NULL DEFAULT 1,
  duration_s        INT         NOT NULL,
  warmup_s          INT         NOT NULL DEFAULT 0,
  started_at        TIMESTAMPTZ,
  ended_at          TIMESTAMPTZ
);

CREATE TABLE run_kpi_snapshots (
  run_id          UUID   NOT NULL REFERENCES simulation_runs(id),
  sim_time_s      BIGINT NOT NULL,
  throughput      INT,
  avg_cycle_time  FLOAT,
  utilization     JSONB,
  queue_lengths   JSONB,
  PRIMARY KEY (run_id, sim_time_s)
);

CREATE TABLE bottleneck_events (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id       UUID        NOT NULL REFERENCES simulation_runs(id),
  sim_time_s   BIGINT      NOT NULL,
  zone         TEXT        NOT NULL,
  type         TEXT        NOT NULL,
  severity     TEXT        NOT NULL,
  description  TEXT
);

CREATE TABLE entity_log (
  run_id      UUID   NOT NULL,
  entity_id   UUID   NOT NULL,
  event_type  TEXT   NOT NULL,
  zone        TEXT,
  sim_time_s  BIGINT NOT NULL
);
