# Configures the git "redact" filter for this clone (run once, from anywhere in the repo):
#   powershell -File tools\setup_redaction.ps1
#
# Org identifiers (org ID, My Domain, agent user, AWS account) are needed by the metadata to deploy,
# but must not be published. .gitattributes routes text files through this filter:
#   clean  (on git add)      real value -> __TOKEN__   so commits only ever contain tokens
#   smudge (on git checkout) __TOKEN__  -> real value  so the working copy stays deployable
# Values come from REDACT_* lines in secrets.env (git-ignored); REDACT_X maps to __X__.
# The generated sed commands live in .git/config, which is never pushed.
# Without this setup a clone simply keeps the tokens; fill them in to deploy to your own org.

$root = (git rev-parse --show-toplevel).Trim()
$envFile = Join-Path $root 'secrets.env'
if (-not (Test-Path $envFile)) { throw "No secrets.env at $envFile (copy secrets.env.example first)." }

$pairs = @()
foreach ($line in [IO.File]::ReadAllLines($envFile)) {
    if ($line.Trim() -match '^REDACT_([A-Z0-9_]+)\s*=\s*(.+)$') {
        $value = $Matches[2].Trim()
        if ($value.StartsWith('<')) { continue }   # unfilled template placeholder
        $pairs += [pscustomobject]@{ Token = "__$($Matches[1])__"; Value = $value }
    }
}
if ($pairs.Count -eq 0) { throw 'No REDACT_* values found in secrets.env.' }
foreach ($p in $pairs) {
    if ($p.Value -match "['&\\/]") { throw "Unsupported character in $($p.Token) value." }
}

# Longest value first, so the 18-char org ID is replaced before its 15-char prefix.
$pairs = $pairs | Sort-Object { $_.Value.Length } -Descending
$escape = { param($s) [regex]::Replace($s, '[.\[\]*^$]', { '\' + $args[0].Value }) }
$clean  = 'sed' + (($pairs | ForEach-Object { " -e 's/$(& $escape $_.Value)/$($_.Token)/g'" }) -join '')
$smudge = 'sed' + (($pairs | ForEach-Object { " -e 's/$($_.Token)/$($_.Value)/g'" }) -join '')

git config filter.redact.clean $clean
git config filter.redact.smudge $smudge
git config filter.redact.required true
Write-Host "Redact filter configured with $($pairs.Count) values: $(($pairs.Token) -join ', ')" -ForegroundColor Green
