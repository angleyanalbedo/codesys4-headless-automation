[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [Parameter(Mandatory = $true)]
    [string]$ProjectsRoot,

    [Parameter(Mandatory = $true)]
    [string]$OutputDir,

    [string]$CliPath = 'C:\Program Files\CODESYS-4\c4-cli.exe',

    [int]$TimeoutSeconds = 45,

    [switch]$ResolveLibraries
)

$ErrorActionPreference = 'Stop'

function Invoke-CodesysCommand {
    param(
        [string[]]$Arguments,
        [string]$StdoutPath,
        [string]$StderrPath,
        [int]$TimeoutMilliseconds
    )

    $process = Start-Process `
        -FilePath $CliPath `
        -ArgumentList $Arguments `
        -RedirectStandardOutput $StdoutPath `
        -RedirectStandardError $StderrPath `
        -PassThru `
        -WindowStyle Hidden

    $finished = $process.WaitForExit($TimeoutMilliseconds)
    if (-not $finished) {
        try { $process.Kill($true) } catch { }
        return [pscustomobject]@{
            ExitCode = -2
            TimedOut = $true
        }
    }

    return [pscustomobject]@{
        ExitCode = $process.ExitCode
        TimedOut = $false
    }
}

function Read-TextOrEmpty {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        return [System.IO.File]::ReadAllText($Path)
    }
    return ''
}

if (-not (Test-Path -LiteralPath $CliPath)) {
    throw "CODESYS CLI not found: $CliPath"
}
if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "Manifest not found: $ManifestPath"
}
if (-not (Test-Path -LiteralPath $ProjectsRoot)) {
    throw "Projects root not found: $ProjectsRoot"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$logsDir = Join-Path $OutputDir 'logs'
$tmpDir = Join-Path $OutputDir '.tmp'
New-Item -ItemType Directory -Force -Path $logsDir, $tmpDir | Out-Null

$manifest = Import-Csv -LiteralPath $ManifestPath
$rows = [System.Collections.Generic.List[object]]::new()
$timeoutMilliseconds = $TimeoutSeconds * 1000
$items = @($manifest)
$index = 0

foreach ($item in $items) {
    $index++
    $sampleId = [string]$item.sample_id
    $sourceFile = [string]$item.file
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($sourceFile)
    $matches = @(Get-ChildItem -LiteralPath $ProjectsRoot -Directory -Filter "*$stem.fbslib")
    if ($matches.Count -eq 0) {
        $matches = @(Get-ChildItem -LiteralPath $ProjectsRoot -Directory -Filter "Sample_$stem.fbslib")
    }

    $logRelative = "logs/$sampleId.log"
    $logPath = Join-Path $OutputDir ($logRelative -replace '/', '\')

    if ($matches.Count -eq 0) {
        $row = [pscustomobject]@{
            sample_id = $sampleId
            source_file = $sourceFile
            source_position = [int]$item.source_position
            idx = [int]$item.idx
            syntax_status = 'unknown'
            compile_status = 'not_run'
            first_error = ''
            platform_compatibility = 'unknown'
            required_library = ''
            reviewer_notes = 'No matching test project directory was found.'
            warning_count = 0
            error_count = 0
            build_log = $logRelative
        }
        [System.IO.File]::WriteAllText($logPath, $row.reviewer_notes)
        [void]$rows.Add($row)
        continue
    }

    $project = $matches[0]
    $stdoutPath = Join-Path $tmpDir "$sampleId.stdout"
    $stderrPath = Join-Path $tmpDir "$sampleId.stderr"
    Remove-Item -LiteralPath $stdoutPath, $stderrPath, $logPath -Force -ErrorAction SilentlyContinue

    $resolveResult = $null
    if ($ResolveLibraries) {
        $resolveResult = Invoke-CodesysCommand `
            -Arguments @('library', 'resolve', $project.FullName, '--log-level', 'error') `
            -StdoutPath $stdoutPath `
            -StderrPath $stderrPath `
            -TimeoutMilliseconds $timeoutMilliseconds

        $lockPath = Join-Path $project.FullName 'Libraries.lock.json'
        $lockDeadline = (Get-Date).AddSeconds(30)
        while (-not (Test-Path -LiteralPath $lockPath) -and (Get-Date) -lt $lockDeadline) {
            Start-Sleep -Milliseconds 250
        }
    }

    $checkResult = Invoke-CodesysCommand `
        -Arguments @('library', 'check', $project.FullName, '--log-level', 'error') `
        -StdoutPath $stdoutPath `
        -StderrPath $stderrPath `
        -TimeoutMilliseconds $timeoutMilliseconds

    $stdout = Read-TextOrEmpty $stdoutPath
    $stderr = Read-TextOrEmpty $stderrPath
    $text = "$stdout`r`n$stderr"
    [System.IO.File]::WriteAllText($logPath, $text, [System.Text.Encoding]::UTF8)
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue

    $summary = [regex]::Match($text, 'Compile complete\s*--\s*(\d+)\s*errors?,\s*(\d+)\s*warnings?')
    $errorCount = 0
    $warningCount = 0
    if ($summary.Success) {
        $errorCount = [int]$summary.Groups[1].Value
        $warningCount = [int]$summary.Groups[2].Value
    }

    $firstError = ''
    $errorMatch = [regex]::Match($text, '(?m)^.*(?:Error:|error|Unexpected token|expected instead of|not found|No initial value|Border ).*$')
    if ($errorMatch.Success) { $firstError = $errorMatch.Value.Trim() }

    $timedOut = $checkResult.TimedOut
    $loadProblem = $text -match 'No file was found|Path is outside a project|Unable to use this command'
    $sourceCandidates = @(Get-ChildItem -LiteralPath $project.FullName -File | Where-Object { $_.Name -notin @('Libraries.json', 'Libraries.lock.json', 'ProjectInfo.json') })
    $sourceRecognized = $sourceCandidates.Count -gt 0 -and (($sourceCandidates | ForEach-Object { $text -match [regex]::Escape($_.Name) }) -contains $true)

    if ($timedOut) {
        $syntaxStatus = 'unknown'
        $compileStatus = 'timeout'
        $compatibility = 'unknown'
        $notes = "Compiler exceeded $TimeoutSeconds seconds; inspect the complete log."
    } elseif ($summary.Success) {
        $syntaxStatus = if ($errorCount -eq 0) { 'pass' } else { 'fail' }
        $compileStatus = if ($checkResult.ExitCode -eq 0 -and $errorCount -eq 0) { 'pass' } else { 'fail' }
        $platformDependent = $text -match '(%I|%Q|%M|device|I/O|file|socket|network|external|vendor|runtime)'
        $compatibility = if ($compileStatus -eq 'pass' -and $platformDependent) { 'possibly_compatible' } elseif ($compileStatus -eq 'pass') { 'compatible' } elseif ($text -match 'library|placeholder|unknown type|not found') { 'incompatible' } else { 'incompatible' }
        $notes = if ($compileStatus -eq 'pass') { 'Compiler completed without errors.' } else { 'Compiler reported errors; inspect first_error and build_log.' }
    } elseif ($loadProblem -or -not $sourceRecognized) {
        $syntaxStatus = 'unknown'
        $compileStatus = 'fail'
        $compatibility = 'unknown'
        $notes = 'The project or source object was not fully recognized; this is not proof that the IEC code compiled.'
    } else {
        $syntaxStatus = if ($checkResult.ExitCode -eq 0) { 'unknown' } else { 'fail' }
        $compileStatus = if ($checkResult.ExitCode -eq 0) { 'unknown' } else { 'fail' }
        $compatibility = 'unknown'
        $notes = 'No standard compiler summary was found; inspect the complete log.'
    }

    $libraries = ([regex]::Matches($text, '(?i)(?:library|placeholder)[^\r\n]*')).Value -join '; '
    $row = [pscustomobject]@{
        sample_id = $sampleId
        source_file = $sourceFile
        source_position = [int]$item.source_position
        idx = [int]$item.idx
        syntax_status = $syntaxStatus
        compile_status = $compileStatus
        first_error = $firstError
        platform_compatibility = $compatibility
        required_library = $libraries
        reviewer_notes = $notes
        warning_count = $warningCount
        error_count = $errorCount
        build_log = $logRelative
    }
    [void]$rows.Add($row)
    Write-Host "[$index/$($items.Count)] $sampleId -> $compileStatus / $compatibility"
}

$csvPath = Join-Path $OutputDir 'codesys_30_samples.csv'
$jsonPath = Join-Path $OutputDir 'codesys_30_samples.json'
$rows | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath $csvPath
$rows | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 -LiteralPath $jsonPath

Write-Host 'Results:'
$rows | Group-Object compile_status | Select-Object Name, Count
