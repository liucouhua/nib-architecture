# Data–model matching

Status: draft for expert review
Date: 2026-08-21
Code: no prototype changes in this pass

## Decision

Pair a data package and a model package by **task profile**, then by the
field constraints we already check. There is no universal weather tensor.

A source adapter reads its native files and states which profiles it can
offer. A model adapter states which profile it was trained against. The
Matcher intersects the two. An empty intersection is a hard error: the UI
must not offer that pair.

Complexity is N data implementations + K profiles + M model implementations.
K stays small. Today K = 1: `precip-nowcast.v1`.

Two jobs, not one:

- **Interface** (B1 data, C1 model): write the Protocol, the manifest schema,
  and tests a fake package must pass. A new dataset or model must not edit
  this code.
- **Implementation**: one package per dataset (`datas/SEVIR`, later radar,
  satellite, …) or per model (`models/WADEPre`, …). SEVIR is an example
  dataset, not the data layer.

The person who owns B1 does not decode HDF5. The person who owns SEVIR
does not change `DataAdapter`.

This is the same idea MLCast uses for radar nowcasting: each dataset has
its own converter; models share one forward contract; mismatches fail in
config checks instead of being coerced at runtime.

## Why the demo label is wrong

The current architecture diagram says Data Adapter does `any format →
universal data`. The running prototype almost does that: `CanonicalSample`
is one `context` ndarray plus an optional `target`.

That works for SEVIR VIL → WADEPre / NowcastNet / SimVP / exPreCast. It
does not extend. Radar, satellite, and lightning differ in variable,
grid, cadence, projection, and missing-data convention. Models want
input close to their training distribution. Forcing one tensor either
invents a format nobody trained on, or produces N×M pairwise bridges.

What we keep from the demo:

- Package + `manifest.json`
- Shared layer never truncates frames or rescales values
- `validate_contracts` runs before inference
- Read-only data mount; results written only under the run directory

What we change in the **design** (later, in code):

- `CanonicalSample` becomes a `TaskSample` for `precip-nowcast.v1`
- Manifests grow `offers` / `requires` profile ids
- Matcher checks profile id first, then the existing field rules

## Layers

```
native files (HDF5, ODIM_H5, GRIB, NetCDF, TIFF, …)
    │  Source Adapter (one per dataset family)
    ▼
Source Cube   annotated fields: names, grid, time, units, missing
    │  only if the source lists this profile under offers
    ▼
TaskSample    precip-nowcast.v1
    │  Model Adapter (frame pick, training normalisation, ONNX/Torch layout)
    ▼
Prediction → Evaluation → Visualization → run artifacts
```

The Source Cube does not have to be a separate on-disk store. For SEVIR
the adapter can load a TaskSample directly because the HDF5 is already
that task. The cube is the adapter's private representation of "what this
file actually contains".

QC stays inside each source adapter until two adapters share a real
routine.

## `precip-nowcast.v1`

| Axis | Rule |
| --- | --- |
| Physical quantity | One 2D precipitation-related field (rain rate, VIL, or reflectivity). The field name is declared, not implied. |
| Layout | `(time, channel, y, x)`. `channel` is usually 1. |
| Time | UTC, regular cadence in minutes. |
| Grid | Regular. Height × width is **not** fixed by the profile. Source and model each declare it; Matcher compares. |
| Missing data | Explicit mask or a declared fill. Shared code must not silently write 0. |
| Context frames | Source keeps every context frame. The model adapter applies `context_frames.mode` (today: `latest`). |
| On disk | Native file stays native. SEVIR stays HDF5. A future MLCast Zarr source stays Zarr. |

Current demo pairs all sit on this profile: SEVIR VIL with WADEPre,
NowcastNet, SimVP, exPreCast.

## Matcher

Hard errors (pair forbidden):

- Data `offers` does not include model `requires`
- Context or target field missing
- Spatial shape mismatch
- Cadence mismatch
- Model `context_frames.required_count` > data context `frame_count`
- Model output `frame_count` ≠ data target `frame_count` (when a target exists)

Warnings (pair allowed, UI shows the text):

- dtype differs (model adapter casts)
- Training domain / region metadata differs, when both sides declare it

Matcher never converts arrays. Conversion is either a source adapter
projecting into a profile it claims, or a model adapter preparing its
own input.

Today's `utils.validation.validate_contracts` is the field half of this.
The profile-id check is the missing first step.

## Extra data sources

Local radar, satellite, and lightning are **data packages**. They
implement the Source Adapter protocol (B1). They do not add layers, task
profiles, or Matcher cases.

| Package | Typical native form | `offers` |
| --- | --- | --- |
| B2 SEVIR | HDF5 VIL cubes | `precip-nowcast.v1` |
| B4 Local radar | ODIM_H5 / national composite | `precip-nowcast.v1` if the adapter can project to the profile |
| B5 Satellite | geostationary IR / derived precip | `precip-nowcast.v1` only if the adapter emits that field (learned satellite-to-radar lives here, not as a platform module) |
| B6 Lightning | stroke / density grids | `precip-nowcast.v1` only if it can project; otherwise it matches no current model |

A package that cannot offer `precip-nowcast.v1` is still a valid package.
It just will not pair with today's models. A second profile is a later
RFC, and only when a real task family needs one. New profiles are opened
for a task family, not for a single model.

## Manifest sketch (design only)

Data:

```json
{
  "id": "sevir-vil",
  "offers": ["precip-nowcast.v1"],
  "fields": ["…existing FieldSpec list…"]
}
```

Model:

```json
{
  "id": "wadepre",
  "requires": "precip-nowcast.v1",
  "context_frames": {"required_count": 5, "mode": "latest"},
  "input": ["…existing FieldSpec…"],
  "output": ["…existing FieldSpec…"]
}
```

FieldSpec, spatial shape, cadence, and frame counts stay as they are in
`prototype/interfaces/types.py`.

## Ownership split

| Concern | Owner |
| --- | --- |
| Profile name and version | A1 |
| Compatibility result | A2 |
| Dataclass / Protocol / manifest parse | A3 |
| Decode, QC, coordinates, `offers` | each data package (B2, B4, …) |
| Frame pick, normalisation, weights, `requires` | each model package (C2, …) |
| Metrics, figures, result directory | D1–D3 |
| Discover, run, stream, persist | E1–E5 |

## Out of scope for this RFC

- Training or fine-tuning inside the box
- A remote Hub / governance service (installed packages + manifests are
  the local catalog)
- A second task profile
- Rewriting SEVIR files into Zarr
- Hardware-profile orchestration

## Open points for reviewers

1. Is `precip-nowcast.v1` allowed to cover VIL **and** rain rate **and**
   reflectivity as long as the field name is declared, or should rain
   rate be a separate profile from the start?
2. Should spatial-shape mismatch stay a hard error, or may a model
   adapter crop/pad when it declares that it will?
3. For satellite: is emitting `precip-nowcast.v1` from a learned
   translator acceptable inside B5, or do you want that translator as
   its own data package id (still B1, still one profile)?
