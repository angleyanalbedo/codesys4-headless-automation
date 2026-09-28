# Batch Compilation Workflow

Use this workflow when a manifest contains many independent `.st` samples. It is intentionally conservative: a sample is not considered compatible merely because `c4-cli` started or because an unrecognized source file was ignored.

## Required test layout

Each sample must be tested inside its own valid project directory. The project directory and namespace must start with a letter or underscore:

```text
Sample_MV001_Control.fbslib/
├── ProjectInfo.json
├── Libraries.json
├── Libraries.lock.json
└── MAIN.prg.st
```

Do not use a directory such as `01_Control.fbslib`; CODESYS can derive an internal project-error identifier from the directory name and reject it even when `defaultNamespace` is valid.

## Required process invariants

1. Map manifest metadata from `manifest.csv`; do not infer `sample_id` from compiler output.
2. Run `library resolve` and wait until `Libraries.lock.json` physically exists before running `library check`. CODESYS may return from the resolve command while background processing is still writing the lockfile.
3. Capture stdout and stderr to separate temporary files. Windows `Start-Process` rejects identical redirect paths.
4. Merge the two streams into the sample log only after the process exits.
5. Read the process exit code from `System.Diagnostics.Process` or `Start-Process`. Do not pipe `& c4-cli ... 2>&1 | Out-String` before reading `$LASTEXITCODE`; the downstream PowerShell command can hide the compiler's return value.
6. Apply a per-sample timeout and retain a timeout log.
7. Require both exit code `0` and a valid compile summary before reporting `pass`.
8. Detect source recognition. A source file with an unrecognized extension/name can be ignored by the project loader and must be reported as `unknown`, not `pass`.

## Usage

```powershell
& .\scripts\Invoke-Codesys4Batch.ps1 `
    -ManifestPath C:\ci\codesys_30_samples\manifest.csv `
    -ProjectsRoot C:\ci\projects `
    -OutputDir C:\ci\results `
    -ResolveLibraries
```

The script writes:

```text
<OutputDir>\codesys_30_samples.csv
<OutputDir>\codesys_30_samples.json
<OutputDir>\logs\MV-001.log
<OutputDir>\logs\MV-002.log
...
```

## Single-sample validation before a batch

Always validate one sample first. Confirm that:

- the project folder name is valid;
- `ProjectInfo.json` is valid;
- `Libraries.json` resolves;
- `Libraries.lock.json` exists before checking;
- the source file has a valid CODESYS object suffix such as `.prg.st`, `.fb.st`, or `.fn.st`;
- the compiler log names the source file;
- the exit code and compiler summary agree.

Only then run the complete manifest. This avoids spending several minutes diagnosing a test-harness error across every sample.

