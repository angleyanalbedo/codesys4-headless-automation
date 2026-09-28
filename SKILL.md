---
name: codesys4-headless-automation
description: Use CODESYS 4 headlessly for reproducible PLC library validation, Structured Text compilation, dependency locking, and compiled-library artifact generation in CI/CD pipelines.
metadata:
  short-description: Automate CODESYS 4 compilation in CI/CD
---

# CODESYS 4 Headless Automation

Use this skill when the task involves compiling, validating, packaging, or testing a CODESYS 4 file-based project without relying on manual IDE interaction.

## Scope

Prefer CODESYS 4's `c4-cli.exe` for automation. The primary supported workflow is library-oriented because the installed CODESYS 4 CLI exposes stable commands for library resolution, validation, and compiled-library generation.

Do not claim that a generic device-application build succeeded unless the target contains a valid CODESYS 4 device project and the corresponding application build command has actually returned exit code `0`.

## Required discovery

1. Locate the installation. The usual Windows path is:

   `C:\Program Files\CODESYS-4\c4-cli.exe`

2. Inspect the installed command surface before choosing a command:

   ```powershell
   & 'C:\Program Files\CODESYS-4\c4-cli.exe' --help
   & 'C:\Program Files\CODESYS-4\c4-cli.exe' library --help
   ```

3. Use the actual installed CLI version and compiler version in the CI log.

## Project assumptions

A CODESYS 4 source library is a directory whose name ends in `.fbslib`. A minimal library project normally contains:

- `ProjectInfo.json`
- `Libraries.json`
- one or more IEC source files such as `Name.fn.st`, `Name.fb.st`, or `Name.prg.st`

Use UTF-8 without BOM. Keep `Libraries.lock.json` under version control when reproducible dependency resolution is required.

For a minimal smoke test, use an empty dependency manifest:

```json
{
  "references": {},
  "placeholderOverrides": {},
  "libraryParameters": {}
}
```

## Preferred pipeline

Run the stages in this order:

1. Resolve dependencies:

   ```powershell
   & $C4Cli library resolve $LibraryPath --log-level error
   if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
   ```

2. Check and compile the source library:

   ```powershell
   & $C4Cli library check $LibraryPath --log-level error
   if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
   ```

   A successful compile should contain `Compile complete -- 0 errors, 0 warnings` and return exit code `0`.

3. Generate a deliverable compiled library:

   ```powershell
   & $C4Cli library save-compiled $LibraryPath $ArtifactPath --overwrite --log-level error
   if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
   ```

4. Verify that the artifact exists and is non-empty. Record its size, compiler version, project version, and checksum in the CI output.

## Important command distinctions

- `library resolve` creates or updates `Libraries.lock.json`.
- `library check` performs the source-library validation and compilation check.
- `library save-compiled` creates a `.compiled-library-v3` artifact.
- `library verify` validates dependency resolution for an application target; it is not the correct verification command for a library project by itself.
- `library pack` is for source-library archives and has different path semantics from `save-compiled`; do not substitute it for compiled-library generation.

## Failure handling

- An empty directory is not a CODESYS project and should be reported as a project-structure error.
- If `library check` reports that `Libraries.lock.json` is missing, run `library resolve` first.
- Preserve the full CLI output and exit code in CI logs.
- Treat `0 errors, 0 warnings` plus exit code `0` as the success condition; a process that merely starts is not a successful build.
- If the CLI cannot write its default log directory, redirect or permit the log location in the runner environment; do not misclassify that infrastructure error as an IEC compiler error.

## Safety and reproducibility

- Work in an explicit project and artifact directory; never use a broad workspace root as an output target.
- Do not overwrite an existing release artifact unless the pipeline explicitly requests `--overwrite`.
- Keep generated `.compiled-library-v3` files in CI artifacts rather than committing them by default.
- Do not connect to or download to a PLC controller as part of a compile-only pipeline unless the user explicitly asks for deployment.

## Local knowledge base

Read only the reference that matches the current task:

- [architecture.md](references/architecture.md): CODESYS 4 architecture, runtime/compiler relationship, and CI/CD boundaries.
- [file-format.md](references/file-format.md): file-based project layout, IEC source naming, library manifests, lockfiles, and library formats.
- [cli-reference.md](references/cli-reference.md): locally observed `c4-cli` command surface, command selection, exit-code interpretation, and known failure modes.
- [mcp-reference.md](references/mcp-reference.md): CODESYS Development System MCP Server capabilities, licensing, CODESYS 3/4 boundary, and recommended agent architecture.
- [ci-pipeline.md](references/ci-pipeline.md): executable PowerShell pipeline template.

