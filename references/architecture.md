# CODESYS 4 Architecture Notes

This document is a cached research note for headless automation. Prefer it over repeating a web search. It combines official CODESYS documentation with observations from the local installation at `C:\Program Files\CODESYS-4`.

## Product model

CODESYS 4 is the next-generation engineering environment alongside CODESYS 3. Its first releases emphasize file-based projects, library development, and simple applications. The engineering UI is web-based, but the compiler and automation services can run without the graphical UI.

The important separation for an agent is:

```text
PLC requirement
    -> IEC source files and project metadata
    -> Libraries.json dependency manifest
    -> Libraries.lock.json resolved graph and hashes
    -> CODESYS compiler/front-end
    -> compiled library or application/boot artifact
    -> optional deployment to a controller
```

Compilation and deployment are different stages. A compile-only agent must stop before controller connection, login, download, or start unless the user explicitly requests deployment.

## Compiler and runtime compatibility

Official CODESYS 4 documentation states that CODESYS 4 uses the same compiler/runtime family as CODESYS 3. Generated machine code is intended to be compatible, and compiled libraries can be exchanged between the two tools within the supported compatibility rules.

This matters for an agent because the generated IEC code is not compiled by an LLM. The agent edits project files and invokes the vendor compiler. The compiler remains the source of truth for typing, language semantics, target compatibility, and diagnostics.

## Local installation observations

The tested Windows installation contains:

- `CODESYS-4.exe` and supporting runtime assemblies;
- `c4-cli.exe` for command-line automation;
- `c4-pkm.exe` for package management;
- compiler and target extensions under `extensions`;
- `sdk`, `dist`, `runtimes`, and `dependencies` directories;
- a .NET 8 runtime configuration for the CODESYS 4 host;
- compiler/target packages including x86-64, ARM, ARM64, RISC, Ladder, Modbus, and device/library components.

These observations are installation-specific. At runtime, always inspect the actual installation and print the CLI/compiler versions instead of hard-coding extension versions.

## Agent architecture implication

A reliable PLC coding agent should have separate roles:

1. **Requirement interpreter**: extracts I/O, states, timing, safety assumptions, and acceptance tests.
2. **IEC generator**: writes ST/LD/FBD/CFC source in the project format.
3. **Project manager**: updates `ProjectInfo.json`, `Libraries.json`, project folders, and lockfiles.
4. **Compiler adapter**: invokes `c4-cli` and normalizes diagnostics.
5. **Static validator**: checks naming, forbidden constructs, scan-cycle assumptions, and generated diff.
6. **Test adapter**: runs simulation or controller tests when an approved test target exists.
7. **Artifact/deployment adapter**: publishes compiled files or deploys to a controller only as a separate authorized stage.

Do not combine all roles into one unrestricted prompt. In particular, compilation should be a tool call with captured stdout, stderr, and exit code; deployment should be a separately authorized capability.

## Python support: three different meanings

Do not answer simply “CODESYS 4 supports Python” without identifying the layer:

1. **Python inside the CODESYS 4 engineering environment**: CODESYS 4's official migration documentation describes the CODESYS 4 scripting interface as unavailable. The intended replacement is direct file access with external tools such as Python or GitLab, together with `c4-cli`.
2. **External Python automation**: supported as an engineering and CI pattern. A normal Python process can generate or edit file-based project files, inspect JSON and IEC source, call `c4-cli`, capture diagnostics, calculate artifact hashes, and orchestrate tests. This is the recommended approach for a PLC code-generation agent.
3. **Python running as PLC application code**: not the same as IEC 61131-3 ST/LD/FBD execution. Do not assume a standard CODESYS 4 controller can execute Python as a PLC task. This requires a separate runtime integration or device-specific product and must be verified for the target.

The well-known `scriptengine` Python API (`from scriptengine import *`, `projects`, `online`, and `librarymanager`) belongs to the CODESYS Scripting add-on/documentation associated with the classic CODESYS development system. It should not be presented as a built-in CODESYS 4 API unless the installed product explicitly provides and documents that integration.

## Official references

- [CODESYS 4 overview](https://www.codesys.com/products/engineering/codesys-4/)
- [CODESYS 4 documentation start page](https://content.helpme-codesys.com/en/CODESYS%204/_c4_start_page.html)
- [CODESYS 4 file-based storage](https://content.helpme-codesys.com/en/CODESYS%204/_c4_file_based_storage.html)
- [CODESYS 4 compatibility with CODESYS 3](https://content.helpme-codesys.com/en/CODESYS%20File-Based%20Storage/_fbstrge_compatibility_with_c4.html)
- [CODESYS 4 migration: scripting and automation differences](https://content.helpme-codesys.com/en/CODESYS%204/_c4_start_page-2083130.html)
- [CODESYS Scripting API reference](https://content.helpme-codesys.com/en/CODESYS%20Scripting/_cds_access_cds_func_in_python_scripts.html) (legacy/classic scripting context; not automatic proof of CODESYS 4 support)
