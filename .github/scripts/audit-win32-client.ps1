# Read-only inventory of Last Chaos Win32 build outputs.
# This script does not certify that a binary is safe or works at runtime.
param(
    [string]$BinDir = 'D:\Bin',
    [string]$ReportPath = 'win32-client-audit.txt',
    [string]$DumpbinExe = ''
)
$ErrorActionPreference = 'Stop'
$files = @('Engine.dll', 'EntitiesMP.dll', 'GameMP.dll', 'Shaders.dll', 'Nksp.exe')
$rows = [System.Collections.Generic.List[string]]::new()
$rows.Add('Last Chaos Win32 diagnostic inventory (NOT a security certification)')
$rows.Add('UTC: ' + [DateTime]::UtcNow.ToString('u'))
$rows.Add('Source commit: ' + (& git rev-parse HEAD))
$rows.Add('')

if ($DumpbinExe -and -not (Test-Path -LiteralPath $DumpbinExe)) {
    throw "dumpbin.exe not found: $DumpbinExe"
}
$missing = [System.Collections.Generic.List[string]]::new()
foreach ($name in $files) {
    $file = Join-Path $BinDir $name
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        $missing.Add($name)
        continue
    }
    $item = Get-Item -LiteralPath $file
    $hash = Get-FileHash -LiteralPath $file -Algorithm SHA256
    $sig = Get-AuthenticodeSignature -LiteralPath $file
    $rows.Add("FILE: $name")
    $rows.Add("SIZE: $($item.Length)")
    $rows.Add("SHA256: $($hash.Hash)")
    $rows.Add("SIGNATURE: $($sig.Status)")

    if ($DumpbinExe) {
        $headers = (& $DumpbinExe /headers $file 2>&1 | Out-String)
        if ($LASTEXITCODE -ne 0) { throw "dumpbin /headers failed for $name" }
        $rows.Add("DYNAMICBASE_FLAG: $([bool]($headers -match '(?i)Dynamic base'))")
        $rows.Add("NXCOMPAT_FLAG: $([bool]($headers -match '(?i)NX compatible'))")
        $loadconfig = (& $DumpbinExe /loadconfig $file 2>&1 | Out-String)
        if ($LASTEXITCODE -eq 0) {
            $rows.Add("SAFESEH_TABLE_REPORTED: $([bool]($loadconfig -match '(?i)SE Handler Table|Safe Exception Handler Table'))")
        } else {
            $rows.Add('SAFESEH_TABLE_REPORTED: could not inspect load configuration')
        }
        $dependents = (& $DumpbinExe /dependents $file 2>&1 | Out-String)
        if ($LASTEXITCODE -ne 0) { throw "dumpbin /dependents failed for $name" }
        $rows.Add('DEPENDENCY REPORT:')
        foreach ($line in $dependents.Split([Environment]::NewLine)) {
            if ($line -match '(?i)\b[A-Za-z0-9_.+-]+\.dll\b') {
                $rows.Add('  ' + $line.Trim())
            }
        }
    } else {
        $rows.Add('PE MITIGATIONS/DEPENDENCIES: not checked (dumpbin was not supplied)')
    }
    $rows.Add('')
}
if ($missing.Count -gt 0) {
    $rows.Add('MISSING REQUIRED: ' + ($missing -join ', '))
}
$rows.Add('No executables are published by the diagnostic workflow.')
$rows | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Get-Content -LiteralPath $ReportPath | ForEach-Object { Write-Host $_ }
if ($missing.Count -gt 0) {
    throw ('Missing core client outputs: ' + ($missing -join ', '))
}
