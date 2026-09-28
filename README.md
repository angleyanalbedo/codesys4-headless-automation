# CODESYS 4 Headless Automation

A Codex Skill for PLC code generation, validation, compilation, and CI/CD automation with CODESYS 4.

The Skill helps an agent work with CODESYS 4 file-based projects and the vendor command-line compiler instead of relying only on manual IDE operations.

## What it covers

- CODESYS 4 architecture and automation boundaries
- `.fbslib`, `.fbsdev`, and `.fbsws` project formats
- `ProjectInfo.json`, `Libraries.json`, and `Libraries.lock.json`
- Structured Text source naming and project layout
- `c4-cli` dependency resolution and compilation
- Compiled library artifact generation
- External Python orchestration
- CODESYS Development System MCP Server integration boundaries
- CI/CD diagnostics, exit codes, and reproducibility rules

## Supported workflow

```text
PLC requirement
    -> generate/edit IEC source and project files
    -> resolve Libraries.json
    -> compile with c4-cli
    -> inspect diagnostics
    -> generate compiled-library artifact
```

The tested library workflow is:

```powershell
$C4Cli = 'C:\Program Files\CODESYS-4\c4-cli.exe'
$Library = 'C:\ci\src\ControlLib.fbslib'
$Artifact = 'C:\ci\artifacts\ControlLib.compiled-library-v3'

& $C4Cli library resolve $Library --log-level error
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $C4Cli library check $Library --log-level error
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $C4Cli library save-compiled $Library $Artifact --overwrite --log-level error
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
```

Successful compilation should report:

```text
Compile complete -- 0 errors, 0 warnings
```

and return exit code `0`.

## Installation as a Codex Skill

Clone or download this repository, then copy the repository directory into the Codex skills directory:

```text
<CODEX_HOME>\skills\codesys4-headless-automation\
```

The entry point is [`SKILL.md`](SKILL.md).

## Directory structure

```text
SKILL.md
references/
├── architecture.md
├── cli-reference.md
├── file-format.md
├── mcp-reference.md
└── ci-pipeline.md
```

Read the reference that matches the current task instead of loading all references every time.

## Python and MCP

Python is recommended as an external orchestration layer for file edits, validation, subprocess execution, and CI reporting. The CODESYS Development System MCP Server is useful for project-aware inspection and Structured Text operations, but it should not automatically be treated as a native CODESYS 4 MCP endpoint.

For a reproducible CODESYS 4 pipeline, use:

```text
LLM / MCP
    -> Python or file tools
    -> CODESYS 4 project files
    -> c4-cli compiler
    -> CI artifact and diagnostics
```

## Validation baseline

This Skill was validated against a local CODESYS 4 installation using a minimal Structured Text library:

- compiler: `3.5.22.30`
- result: `0 errors, 0 warnings`
- artifact: `.compiled-library-v3`

## Safety boundary

Compilation and controller deployment are separate operations. This Skill does not imply permission to log in to a PLC, download an application, start a controller, or modify live equipment.

## License

This repository contains automation guidance and examples. CODESYS itself remains subject to its own licenses and product terms.

