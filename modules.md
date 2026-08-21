# Module roster

Source of truth: [`modules.yaml`](modules.yaml). Import [`modules.csv`](modules.csv)
into Notion, or open a GitHub issue from `.github/ISSUE_TEMPLATE/claim-module.md`.

Two different jobs on the data/model sides:

| Role | Who | What they ship |
| --- | --- | --- |
| **interface** | One owner for the contract | Protocol, manifest schema, tests a fake package must pass. A new dataset/model must not edit this code. |
| **implementation** | One owner per package | `datas/X` or `models/X` that implements the interface. SEVIR is one dataset, not the data layer. |
| **platform** | Runtime / products | Mounts, runner, UI, metrics, artifacts. |

## A · Contracts (interface)

| ID | Name | Do | Done when | Owner |
| --- | --- | --- | --- | --- |
| A1 | Task profiles | Write `precip-nowcast.v1` (variable, layout, time, missing). | A data package can `offers` it without this owner decoding files. | |
| A2 | Matcher | `offers ∩ requires`, then shape/cadence/frames. Human-readable errors. | Incompatible pairs never reach the runner. | |
| A3 | Shared contracts | Types, Protocol, manifest parse. No IO. | Implementations depend only on this package plus their own files. | |

## B · Data

### Interface / platform

| ID | Role | Name | Do | Done when | Owner |
| --- | --- | --- | --- | --- | --- |
| B1 | interface | Data adapter interface | Protocol (`list_samples`, `load_sample`, `offers`, close). Manifest schema. Fake-adapter tests. | New dataset = new `datas/PACKAGE_ID/`, B1 unchanged. | |
| B3 | platform | Data catalog mount | `NIB_DATA_ROOT` layout, missing-path error before run. | Several implementations coexist on one mount. | |

### Implementations (same job, one package per dataset)

SEVIR is the example already in the prototype. Radar / satellite / lightning are more instances of the same job.

| ID | Name | Do | Done when | Owner |
| --- | --- | --- | --- | --- |
| B2 | SEVIR VIL (example) | `datas/SEVIR` implements B1. Offer `precip-nowcast.v1`. | Matcher accepts SEVIR with current models. | |
| B4 | Local radar | `datas/PACKAGE_ID` for ODIM / national composite. | Pairs through Matcher; B1 not edited. | |
| B5 | Satellite | `datas/PACKAGE_ID`. Sat-to-radar, if needed, stays in this package. | Offers are honest. | |
| B6 | Lightning | `datas/PACKAGE_ID`. | Loads and declares offers. | |

## C · Models

### Interface

| ID | Name | Do | Done when | Owner |
| --- | --- | --- | --- | --- |
| C1 | Model adapter interface | Protocol `predict(TaskSample)`. Manifest `requires` / input / output / `context_frames`. Fake-model tests. | New model = new `models/PACKAGE_ID/`, C1 unchanged. | |

### Implementations (same job, one package per model)

| ID | Name | Do | Done when | Owner |
| --- | --- | --- | --- | --- |
| C2 | WADEPre | Adapter + ONNX. Owns 6-to-5 latest frames and training-time norm. | `predict()` matches contract; bad samples rejected. | |
| C3 | NowcastNet | Adapter + artifact implementing C1. | Same bar as C2. | |
| C4 | SimVP | Adapter + artifact implementing C1. | Same bar as C2. | |
| C5 | exPreCast | Adapter + artifact implementing C1. | Same bar as C2. | |

## D · After inference (platform)

| ID | Name | Do | Done when | Owner |
| --- | --- | --- | --- | --- |
| D1 | Evaluation | Metrics from saved arrays. Thresholds change without rerunning inference. | Changing CSI does not start ONNX. | |
| D2 | Visualization | Registry by variable/product. `vil-frames` is one renderer. | A new variable registers without editing SEVIR. | |
| D3 | Artifacts | Standard result dir. Failed runs stay inspectable. | Failed run opens in the UI. | |

## E · Runtime (platform)

| ID | Name | Do | Done when | Owner |
| --- | --- | --- | --- | --- |
| E1 | Control service | Catalog scan, Matcher, one child run, SSE. | UI never imports an adapter. | |
| E2 | Runner | One process. Calls implementations through B1/C1. `NIB_PROGRESS`. | Truncation/norm only inside a model adapter. | |
| E3 | Workflow config | Strict YAML v2. | Hand-written YAML starts a run. | |
| E4 | Web UI | Select, run, compare. Hide Matcher-rejected pairs. | Browser never starts Docker. | |
| E5 | Compose / launcher | Image, port, read-only mount, workspace volume. | Docker + `NIB_DATA_ROOT` starts the box. | |
