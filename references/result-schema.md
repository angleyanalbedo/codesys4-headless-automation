# CODESYS Sample Compilation Result Schema

Use this schema when compiling a dataset of independent ST samples. Do not reduce the result to a single `compile_status`: the original build log and first diagnostic are required for later review.

## Recommended CSV fields

```text
sample_id,source_file,source_position,idx,syntax_status,compile_status,first_error,platform_compatibility,required_library,reviewer_notes,warning_count,error_count,build_log
```

| Field | Source or rule | Recommended value |
|---|---|---|
| `sample_id` | `manifest.csv` | stable ID such as `MV-001` |
| `source_file` | manifest | original source filename |
| `source_position` | manifest | original dataset position |
| `idx` | manifest | original index |
| `syntax_status` | compiler diagnostics | `pass`, `fail`, or `unknown` |
| `compile_status` | build result | `pass`, `fail`, `timeout`, or `not_run` |
| `first_error` | first complete compiler error | preserve full text, not only a code |
| `platform_compatibility` | diagnostic classification | `compatible`, `possibly_compatible`, `incompatible`, or `unknown` |
| `required_library` | missing-library diagnostics or library manager | semicolon-separated names, JSON list, or empty |
| `reviewer_notes` | automated diagnosis plus later human notes | explain the reason without replacing the raw log |
| `warning_count` | compiler output | integer |
| `error_count` | compiler output | integer |
| `build_log` | generated artifact path | relative path such as `logs/MV-001.log` |

## JSON representation

For machine processing, use one object per sample:

```json
{
  "sample_id": "MV-001",
  "source_file": "01_Computing_and_logical_processing_idx2510.st",
  "source_position": 2509,
  "idx": 2510,
  "syntax_status": "fail",
  "compile_status": "fail",
  "first_error": "'END_VAR' expected instead of 'END_STRUCT' ...",
  "platform_compatibility": "incompatible",
  "required_library": [],
  "reviewer_notes": "The source contains a POU-level syntax/type error before platform-specific resolution can be assessed.",
  "warning_count": 1,
  "error_count": 4,
  "build_log": "logs/MV-001.log"
}
```

Keep `first_error` human-readable and complete enough to locate the source line. Keep the full unmodified compiler output in the referenced log file.

## Required artifacts

For a dataset named `codesys_30_samples`, produce at least:

```text
results/codesys_30_samples.csv
results/codesys_30_samples.json
results/logs/MV-001.log
results/logs/MV-002.log
...
```

The result file should use paths relative to the result directory. Each compiler invocation must write both stdout and stderr to its sample log, including timeout and process-start failures.

## Status rules

### `syntax_status`

- `pass`: compiler parsed the source and produced no syntax/type errors.
- `fail`: the compiler reported a syntax or type error.
- `unknown`: the project did not load, the source was a fragment, or the log is insufficient.

### `compile_status`

- `pass`: build returned exit code `0` and produced no errors.
- `fail`: build returned a nonzero exit code or reported errors.
- `timeout`: compiler did not return within the configured limit.
- `not_run`: no compile attempt was made.

### `platform_compatibility`

Use the following conservative classification:

- `compatible`: successfully compiles in the target CODESYS project; referenced blocks/libraries exist; no platform-specific error is present.
- `possibly_compatible`: syntax passes, but the sample uses files, networking, device I/O, external functions, vendor extensions, or other target-dependent facilities that are not configured in the test project.
- `incompatible`: the source uses unsupported syntax, unresolved types/function blocks, or a dialect that the target compiler cannot parse.
- `unknown`: the log is insufficient, the project did not load correctly, or the sample is only a fragment rather than a complete POU.

Never classify a sample as `compatible` merely because the CLI process started or because a source file was ignored by the project loader.

## Automatic diagnosis guidelines

1. Count errors and warnings from the compiler summary when available; otherwise count structured diagnostic lines and mark the count as approximate in `reviewer_notes`.
2. Extract the first complete error, including file and line information where available.
3. Detect missing libraries from phrases such as `library not found`, `unresolved library`, `placeholder`, or `unknown type` associated with a library namespace.
4. Detect platform dependence from I/O addresses, `AT %I/%Q/%M`, device APIs, file/network APIs, external calls, vendor namespaces, and runtime-specific functions.
5. Detect fragments by checking whether the source has a complete POU/DUT envelope and whether the project loader recognized the source object.
6. Preserve human review in `reviewer_notes`; never overwrite the raw diagnostic log.

