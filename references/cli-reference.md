# CODESYS 4 CLI Reference

This reference records the command surface observed from the local CODESYS 4 installation. Always run `--help` on the target runner because commands can change between releases.

## Top-level commands observed

```text
version
about
standalone-session
library
librepo
bootapp
```

The installed CLI does not expose a generic top-level `build` or `compile` command in its help output. The compile operation is reached through the relevant target command, especially `library check` and `library save-compiled` for library projects.

## Library commands observed

The installed CLI exposes commands including:

```text
set-managed
set-relative
set-placeholder
install
install-placeholder
install-managed
install-relative
restore
clean-install
uninstall
resolve
prune
outdated
list
explain
pack
save-compiled
verify
check
```

Use `c4-cli library <command> --help` before invoking a less common command.

## Command selection table

| Need | Command | Success evidence |
|---|---|---|
| resolve references | `library resolve` | lockfile written, exit `0` |
| compile/check source library | `library check` | `Compile complete -- 0 errors, 0 warnings`, exit `0` |
| create compiled artifact | `library save-compiled` | non-empty `.compiled-library-v3`, exit `0` |
| validate an application lockfile | `library verify` | verification completes for application target, exit `0` |
| source archive | `library pack` | source archive created according to command's path contract |
| install/manage repositories | `librepo` or `library install*` | repository operation completes, exit `0` |

`library verify` is not a substitute for compiling a library. In the local test, running it directly against a library project returned `Unable to use this command in a Library project`; use it against an application directory, `Libraries.json`, or `Libraries.lock.json` as documented by the installed help.

## Minimal smoke test

```powershell
$C4Cli = 'C:\Program Files\CODESYS-4\c4-cli.exe'
$Library = 'C:\ci\src\SmokeLib.fbslib'
$Artifact = 'C:\ci\artifacts\SmokeLib.compiled-library-v3'

& $C4Cli library resolve $Library --log-level error
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $C4Cli library check $Library --log-level error
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $C4Cli library save-compiled $Library $Artifact --overwrite --log-level error
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
```

## Python orchestration pattern

Python is useful outside CODESYS 4 as the agent's orchestration language. Keep the vendor compiler as a subprocess and fail on its exit code:

```python
from pathlib import Path
import subprocess

c4 = Path(r"C:\Program Files\CODESYS-4\c4-cli.exe")
library = Path(r"C:\ci\src\ControlLib.fbslib")
artifact = Path(r"C:\ci\artifacts\ControlLib.compiled-library-v3")

commands = [
    [str(c4), "library", "resolve", str(library), "--log-level", "error"],
    [str(c4), "library", "check", str(library), "--log-level", "error"],
    [str(c4), "library", "save-compiled", str(library), str(artifact), "--overwrite", "--log-level", "error"],
]

for command in commands:
    result = subprocess.run(command, text=True, capture_output=True)
    print(result.stdout, end="")
    print(result.stderr, end="")
    if result.returncode != 0:
        raise SystemExit(result.returncode)

if not artifact.is_file() or artifact.stat().st_size == 0:
    raise RuntimeError("compiled artifact is missing or empty")
```

For an agent, this external-Python pattern is preferable to depending on an interactive IDE scripting API. The Python layer handles planning, file edits, validation, and CI orchestration; `c4-cli` handles IEC compilation.

## Diagnostics interpretation

- `Path is outside a project`: the supplied path is not a recognized `.fbslib`, application, or other supported project target.
- `No Libraries.lock.json file exists`: resolve libraries before checking.
- `Compile complete -- 0 errors, 0 warnings`: the compiler completed successfully; still check the process exit code.
- a log-directory access exception before normal CLI output: runner permissions or sandbox setup problem, not necessarily an IEC error.
- missing compiled output after a successful-looking command: treat the build as failed and inspect the command's destination path and exit code.

## Tested local result

The following sequence was executed successfully on the local installation:

```text
c4-cli library resolve SmokeLib.fbslib       -> exit 0
c4-cli library check SmokeLib.fbslib         -> exit 0
c4-cli library save-compiled ...             -> exit 0
compiler version                             -> 3.5.22.30
diagnostics                                  -> 0 errors, 0 warnings
artifact                                     -> 6252 bytes
```

