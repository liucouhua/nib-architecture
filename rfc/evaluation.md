# Evaluation: metrics from stored arrays

Module: D1 Evaluation
Status: draft for expert review
Date: 2026-09-24
Code: no prototype changes in this pass

---

## Decision

D1 computes metrics from prediction and observation arrays that are already on
disk. It does not trigger inference, and it does not modify prediction arrays.
Results are persisted as **additive quantities** (counts and sums), never as
ratios.

Three consequences follow:

- Changing a CSI threshold or a neighbourhood window size is a re-aggregation of
  existing data, not a new inference.
- Re-summing over any period afterwards is exact.
- This is the executable form of D1's `done_when` — *"Changing a CSI threshold
  does not start ONNX again"*.

## Why the current shape is not enough

Metrics are currently accumulated inside the inference loop (for example
`Augur/eval.py` using `torchmetrics`): thresholds are constructed before the
loop starts, and the accumulation state lives only in memory.

Two consequences:

- Changing one threshold requires re-running the whole pass, and needs a GPU.
- Nothing can be recomputed after the process exits — only the final ratios
  survive, and ratios cannot be re-aggregated.

That is fine inside a training or benchmark script. It is not where D1 belongs.
D1's contract is to work from arrays already on disk.

---

## Design

### One config, one set of verification tasks

A config defines three things:

| | Content | Mutability |
|---|---------|------------|
| **Ruler** | ground truth source, spatial domain, time step | **Immutable**; a change means a new config |
| **Roster** | the forecast members under verification | added and removed through effective intervals |
| **Metrics** | which metrics to compute | append-only |

A set of verification tasks — many init times × many lead times × many members —
is derived from that one config. **Results are never aggregated across configs.**

### Three stages

```
① Scheduling ── derive the tasks from the config, drive them frame by frame
       ↓
② Metrics ───── produce additive quantities per frame, persist them
       ↓
③ Query ─────── re-aggregate by (metric, filter, expansion), return values
```

The interfaces between the stages are **①→② tasks** and **②→③ additive
quantities**.

### Where the data comes from

Two directions, both requested by name and time. **We do not resolve file
paths.**

| Direction | Source | Request |
|-----------|--------|---------|
| Observation | data layer | `name + valid_time` |
| Forecast | run artifacts | `name + init_time + lead` |

---

## What D1 delivers

Two parts: a **one-shot CLI** and a **resident query service**. Both locate the
data root through `--root`.

### One-shot CLI

```
nib-verify --root <ROOT> <subcommand>
```

| Subcommand | Purpose | Called by |
|------------|---------|-----------|
| `config create / validate / roster / retire / delete` | create and maintain configs | operators / HUB backend |
| `metrics list` | list supported metrics and their parameters | operators / HUB backend |
| `schedule create / list / remove` | declare scheduled jobs | operators / HUB backend |
| `task plan` | derive the tasks a config implies | operators / HUB backend |
| `task run` | execute tasks, in batch | **handler timer** |
| `backfill` | recompute; upsert semantics | operators / handler |

The three mutability rules above are **enforced** by the `config` subcommand,
not left to convention.

### Resident query service

Serves the frontend (E4 / D2). Listens on `127.0.0.1:8766`, the port the
architecture already reserves. This interface is **real-time only; there is no
one-shot command-line form.**

The shape follows the MetEva convention:

```
query_scores(group, method, s=None, g=None) -> dict
```

- `method`: the metric
- `s`: filters — time range, lead range, member, level
- `g`: expansion dimensions

Every response must carry four things: the ruler echoed back (ground truth
source, time step, spatial domain); coverage and the missing observation times;
`n_valid` per metric; and the dimensions with their values.

Never aggregate across `group`.

---

## How it fits the runtime

### Timing

The **handler** owns it. The handler only has to call, on a fixed cadence:

```
nib-verify --root <ROOT> task run
```

Which configs take part, and at what cadence, is decided by our own
declarations; **the handler does not parse them.** This keeps the timer on the
monitoring surface the system already has.

We commit to three things in return:

| # | Commitment | Content |
|---|------------|---------|
| 1 | **Exit codes** | `0` means everything succeeded (including nothing to do); non-zero means at least one failure |
| 2 | **Progress output** | follows the project's existing `NIB_PROGRESS` convention |
| 3 | **Single-instance lock** | locks on `--root`, so a timed call and a manual call cannot collide |

### Query service

Started and kept alive by the handler. The architecture document already says
the handler starts this page.

### Failure isolation

A verification failure **must not block inference.** This mirrors the first
entry of D1's `does_not_own`.

---

## Interfaces we need

We request fields by name and time only. We do not resolve data file paths.

| # | Interface | Purpose |
|---|-----------|---------|
| 1 | observation: `name + valid_time` | read observations from the data layer |
| 2 | forecast: `name + init_time + lead_minutes` | read predictions from run artifacts |
| 3 | run registry | which runs exist, and whether they finished |
| 4 | write access and layout of the run directory | so we can persist additive quantities |
| 5 | data name enumeration | the legal values of `name` in a config |
| 6 | A3 shared contracts | type and unit definitions |

### Five guarantees the field access interface must meet

1. **Carries its own grid definition** — the field declares its coordinates
   (lat/lon or projection); we resample internally to the domain and resolution
   the config declares
2. **Exact time match** — an integer multiple of the time step; no temporal
   interpolation
3. **Units match the declaration**
4. **Missing data is explicit** — a mask or a declared fill, never a silent zero;
   and we do not treat missing as zero when resampling
5. **Retrospective** — past times stay retrievable, not just "the latest"

Guarantee 5 is hard. If the provider can only serve the latest field, this
design does not work and backfill is impossible.

---

## What D1 does not own

- **Inference** — no model is loaded, no GPU is required
- **Prediction arrays** — read-only, never modified
- **Data decoding** — no path resolution, no format conversion, no quality control
- **Run directory layout** — that is D3
- **Visualization** — that is D2; we deliver numbers, not figures
- **Blocking the inference path** — verification is asynchronous, and that is
  what makes "change a threshold without a re-run" true

One clarification, because it looks like a contradiction above: **spatial
resampling is ours.** It follows from our declaring the target grid — the
provider supplies its native grid, and we align it.

---

## Open points

1. **Who implements the field access interface** — the data layer (B1 / B3), or
   E2 on its behalf
2. **The exact meaning of `--root`** — the workspace root, or a level below it
3. **How the query service meets the handler** — the frontend talks to `8766`
   directly, or through a handler reverse proxy
4. **How the CLI is invoked** — how the handler locates and calls us (absolute
   path / `PATH` / a fixed entry point under `review/`)
5. **Where the additive store lives and what it is called** — inside the run
   directory; needs agreement with D3
6. **The default trigger for backfill** — manual, scheduled, or automatic when
   observations arrive
