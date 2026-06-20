# Theory: Sorting Center Simulation

> Hackathon 2026 — Preparation Material

---

## 1. Introduction to Simulation Modeling

Discrete-Event Simulation (DES) is a method for studying the behavior of complex systems by building computer models and running controlled experiments. In the context of a sorting center, DES lets you reproduce parcel movement, container flow, and staffing patterns, identify bottlenecks, and evaluate the impact of changes — all without stopping real operations.

### 1.1. Core Concepts

| Concept | Definition |
|---|---|
| Event | An instantaneous change of system state: parcel arrival, sort completion, conveyor failure |
| Entity | An object moving through the system: parcel, pallet, courier |
| Resource | A finite element consumed by entities: sorter, conveyor belt, storage cell |
| Queue | An entity waiting for a resource to become available |
| Simulation time | Virtual time, accelerated relative to real time (hours in seconds) |

### 1.2. Modeling Approaches

| Approach | Description | Use in SC |
|---|---|---|
| DES (event-driven) | Model advances from event to event | Primary method for sorting centers |
| Agent-Based | Autonomous agents with behavioral rules | Modeling robotic sorters |
| System Dynamics | Continuous flows and stocks | Macro-level throughput analysis |
| Monte Carlo | Statistical sampling | Analyzing input flow variability |

### 1.3. DES Event Loop Algorithm

The engine core is a **min-heap priority queue** sorted by virtual timestamp. The main loop:

```
EventQueue: min-heap ordered by (sim_time, sequence_number)

loop:
    if EventQueue is empty → stop
    event = EventQueue.pop()           // O(log n)
    current_sim_time = event.sim_time
    event.execute(state)               // may enqueue new events
```

Each event implements a single interface:

```go
type Event interface {
    Time() int64        // simulation nanoseconds
    Execute(s *State)   // mutates state, may schedule new events
}
```

Execution is **single-threaded** — only one event runs at a time, which guarantees determinism. Go goroutines are used only to isolate the simulation loop from the API server, not for parallelism inside the loop.

When two events share the same timestamp, `sequence_number` (auto-increment at scheduling time) breaks the tie deterministically.

---

## 2. Sorting Center Architecture

A Sort Center (SC) receives inbound shipments, classifies them by destination, and routes them into the appropriate outbound flows. A typical facility processes 50,000–500,000 parcels per shift.

### 2.1. Zones and Processes

| Zone | Function | Key Parameters |
|---|---|---|
| Inbound | Vehicle unloading, scanning, weighing | Number of docks, unloading time |
| Induction | Singulating parcels onto the main conveyor | Throughput (units/hour), error rate |
| Main Conveyor (Sorter) | Transport and barcode reading | Belt speed (m/s), loop length |
| Sorting Chutes | Routing by destination | Number of chutes, chute capacity |
| Packing | Consolidation and packaging | Handling time norms |
| Outbound | Loading by route | Number of docks, departure windows |
| Buffer Storage | Temporary holding for exception parcels | Capacity, dwell time |

### 2.2. System Flows

**Physical Flows**
- Parcel flow: Inbound → Induction → Sorter → Chutes → Outbound
- Container flow (returns): Outbound → cleaning → Packing → Induction
- Staff flow: workstation zones, inter-zone movement
- Vehicle flow: inbound/outbound docks, staging areas

**Information Flows**
- WMS → sort assignments
- TMS → vehicle schedule, routes
- Scanners → events as parcels pass checkpoints
- Dimensioning systems → parcel attributes (weight, size)

### 2.3. Conveyor Modeling in DES

A conveyor belt is **not** a standard M/M/c queue — items travel at a fixed speed along a path of known length, so exit time is deterministic given entry time and belt state.

Two approaches:

| Approach | How it works | When to use |
|---|---|---|
| **Travel-time event** (used here) | Schedule one `ConveyorExitEvent` at `entry_time + loop_length / belt_speed` | No parcel-to-parcel interaction needed |
| Position-based | Track each parcel's exact position as a continuous variable | Density-dependent slowdowns, collision modeling |

**Travel-time implementation:**

```
parcel enters belt at sim_time T:
    schedule ConveyorExitEvent at T + (loop_length / belt_speed)

belt failure at sim_time F, repair at sim_time F + MTTR:
    for each pending ConveyorExitEvent:
        shift exit_time += MTTR
```

**Scanner events:** place N scanners at fixed positions along the loop. Each generates a `ScanEvent` at `entry_time + scanner_position / belt_speed`. If scan fails (unreadable barcode), schedule a `ManualHandlingEvent` instead of a `ChuteSortEvent`.

---

## 3. Mathematical Foundations

### 3.1. Queueing Theory

Queueing theory is the mathematical backbone of DES logistics modeling. Kendall notation: **A/B/c/K**, where:
- **A** — arrival distribution
- **B** — service time distribution
- **c** — number of servers (resources)
- **K** — system capacity

Most nodes in a sorting center are modeled as **M/M/c**:

| Parameter | Formula | Meaning |
|---|---|---|
| Traffic intensity (ρ) | `ρ = λ / (c · μ)` | λ = arrival rate, μ = service rate |
| Utilization (U) | `U = λ / (c · μ)` | Must be < 1 for a stable queue |
| Mean queue length (Lq) | `Lq = P₀ · (λ/μ)ᶜ · ρ / (c! · (1−ρ)²)` | Average number waiting |
| Mean waiting time (Wq) | `Wq = Lq / λ` | Little's Law: L = λ · W |

> **In practice:** when U approaches 1 (100%), queues grow without bound. Target range: 70–85% utilization.

### 3.2. Probability Distributions

| Process | Distribution | Parameters | Rationale |
|---|---|---|---|
| Vehicle arrivals | Poisson / Uniform | λ = mean/hour | Poisson = random events; Uniform = scheduled |
| Unloading time | Normal / Lognormal | μ, σ | Lognormal handles right-skewed data |
| Sorting time | Exponential | μ = 1/mean | Classic assumption for M/M/c models |
| Batch size | Negative Binomial | n, p | Accounts for overdispersion |
| Failures (MTBF) | Exponential | λ_fail | Poisson failure process |
| Repair time (MTTR) | Lognormal / Weibull | μ, σ | Right tail = rare long repairs |

### 3.3. KPI Metrics

| KPI | Formula / Description | Target |
|---|---|---|
| Throughput | Units processed / hour | > planned norm |
| Cycle Time | t_exit − t_entry (per parcel) | Minimize |
| Utilization | Busy time / Available time | 70–85% |
| Queue Length (Lq) | Mean number waiting at a node | Minimize |
| OEE | Availability × Performance × Quality | > 85% |
| Error Rate | Mis-sorted / Total | < 0.1% |
| Dock Utilization | Occupied docks / Total docks | < 90% |

### 3.4. PRNG and Reproducibility

A seed initializes a Pseudo-Random Number Generator (PRNG) to a fixed sequence. The same seed always produces the same results — essential for debugging and fair scenario comparison (same random inputs, different parameters).

**Key rule: one PRNG per independent random process**, not one global PRNG. Adding a new random draw anywhere shifts all subsequent values from a shared source, silently changing results for unrelated code paths.

```go
// Good: isolated sources
arrivalRng  := rand.New(rand.NewSource(seed + 1))
failureRng  := rand.New(rand.NewSource(seed + 2))
barcodeRng  := rand.New(rand.NewSource(seed + 3))

// Bad: shared global — non-deterministic under concurrent use and insertion-sensitive
rand.Seed(seed)
```

**Warm-up period (Welch's method):** the simulation starts from an empty system, which is unrealistic — queues are not at steady state. Statistics collected during this transient phase skew KPIs downward. Standard fix: run a warm-up period (e.g., 30 min of simulation time), then reset all KPI accumulators. The warm-up length should be long enough for utilization levels to stabilize.

---

## 4. Bottlenecks and Detection Methods

### 4.1. Theory of Constraints (ToC)

Goldratt's method: every system is limited by its single weakest link. Five-step algorithm:

1. **Identify** — find the constraint (bottleneck)
2. **Exploit** — maximize use of the existing resource
3. **Subordinate** — align everything else to support the constraint
4. **Elevate** — expand the constraint (add resource, increase speed)
5. **Repeat** — find the next constraint and start over

### 4.2. Typical Bottlenecks in a Sorting Center

| Bottleneck | Symptoms in the Model | Detection Metric |
|---|---|---|
| Induction zone | Long queue before the conveyor | Queue length > 50 units |
| Barcode readers | Rising exception rate → manual handling | Exception rate > 2% |
| Sorting chutes | Overflow → conveyor slowdown | Chute fill > 80% |
| Packing zone | WIP accumulation, missed outbound windows | WIP > threshold |
| Outbound docks | Vehicles waiting, schedule violations | Dock wait > 15 min |
| IT system (WMS) | Response delays → equipment idle time | Response time > 200 ms |

### 4.3. Analysis Methods in Simulation

- **Process Mining** — analyze real event logs to build an As-Is model
- **Bottleneck Analysis** — compare utilization and queue lengths across all nodes
- **Sensitivity Analysis** — change one parameter, observe KPI response
- **What-If Analysis** — compare scenarios: add a sorter, change schedule
- **Warm-Up Period** — exclude the transient phase from statistics (Welch's method)

---

## 5. Automation and Efficiency Improvements

### 5.1. Automation Technologies

| Technology | Description | Modeled Effect |
|---|---|---|
| Auto-Induction | Robotic singulation onto the conveyor | Throughput +30–50%, lower variability |
| Cross-Belt Sorters | High-speed sorting with mini-belts | Up to 20,000 units/hour per sorter |
| AGV / AMR Robots | Autonomous internal vehicles | Replaces manual container movement |
| RFID / Vision AI | ID without barcodes, damage detection | Exception rate → ~0% |
| Automated Packing | Machine packing and labeling | Packing cycle time ↓ 60% |
| Predictive Maintenance | ML failure prediction | Unplanned downtime ↓ 40% |

### 5.2. Optimization Approaches

**Scheduling and Routing**
- Dynamic shift planning aligned with incoming load
- Transport route optimization (Vehicle Routing Problem)
- Chute load balancing — dynamic destination reassignment

**Queue Management**
- Priority Queuing — urgent parcels served first
- Batching — group similar parcels to improve packing efficiency
- Pull vs Push — shift to a pull system to reduce WIP

---

## 6. Model Verification and Validation

Verification confirms the model works as designed. Validation confirms it accurately reflects the real system.

### 6.1. Verification

- Unit testing of components (events, processes, queues)
- Trace logging: step-by-step event inspection
- Degenerate tests: zero load → empty queues; infinite load → full utilization
- Reproducibility test: same seed → identical results

### 6.2. Validation

- **Face Validation** — expert review by sorting center specialists
- **Historical Validation** — compare KPIs against real facility historical data
- **Sensitivity Analysis** — model responds predictably to parameter changes
- **Statistical Tests** — Kolmogorov–Smirnov, chi-square to compare distributions

### 6.3. Statistical Significance

Run multiple replications with different seeds (10–30 runs) to obtain reliable estimates. Build confidence intervals using Student's t-distribution.

---

## 7. Recommended Resources

**Books**
- Law A.M. *Simulation Modeling and Analysis* (5th ed., 2015) — the DES bible
- Banks J. et al. *Discrete-Event System Simulation* (5th ed., 2010)
- Goldratt E. *The Goal* — Theory of Constraints in production
- Hopp W., Spearman M. *Factory Physics* — mathematics of production systems

**Open Source Tools**
- SimPy (Python) — minimalist DES library
- AnyLogic Personal Learning Edition — professional simulation tool (free tier)

**Standards**
- SCOR Model — supply chain operations reference standard
- GS1 Standards — barcode and RFID identification standards in logistics
