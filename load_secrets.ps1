# Loads secrets.env into the current PowerShell session as environment variables.
# Usage (note the leading dot — it must run in your session, not a child process):
#   . .\load_secrets.ps1
param([string]$Path = (Join-Path $PSScriptRoot 'secrets.env'))

if (-not (Test-Path $Path)) {
    Write-Host "No secrets file at $Path. Copy secrets.env.example to secrets.env and fill it in." -ForegroundColor Yellow
    return
}

$loaded = @()
foreach ($line in Get-Content $Path) {
    $trimmed = $line.Trim()
    if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
    $idx = $trimmed.IndexOf('=')
    if ($idx -lt 1) { continue }
    $name = $trimmed.Substring(0, $idx).Trim()
    $value = $trimmed.Substring($idx + 1).Trim()
    if ($value.Length -ge 2 -and (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'")))) {
        $value = $value.Substring(1, $value.Length - 2)
    }
    Set-Item -Path "env:$name" -Value $value
    $loaded += $name
}

Write-Host ("Loaded " + $loaded.Count + " secrets: " + ($loaded -join ', ')) -ForegroundColor Green
