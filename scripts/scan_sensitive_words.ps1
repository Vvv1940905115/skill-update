param(
  [Parameter(Mandatory = $true)]
  [string]$Path,

  [string]$ListPath = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ListPath)) {
  $ListPath = Join-Path $PSScriptRoot "..\references\sensitive-words.md"
}

if (-not (Test-Path -LiteralPath $Path)) {
  Write-Error "Target file not found: $Path"
  exit 2
}

if (-not (Test-Path -LiteralPath $ListPath)) {
  Write-Error "Sensitive word list not found: $ListPath"
  exit 2
}

$words = @{}
foreach ($line in Get-Content -LiteralPath $ListPath -Encoding UTF8) {
  $separator = $line.IndexOf(':')
  if ($separator -le 0) {
    continue
  }

  $category = $line.Substring(0, $separator).Trim()
  $delimiters = [string][char]0xFF1B + [string][char]0xFF0C + ";,"
  $items = $line.Substring($separator + 1) -split "[$delimiters]" |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_.Length -gt 0 }
  $words[$category] = $items
}

$hits = New-Object System.Collections.Generic.List[string]
$index = 0
foreach ($textLine in Get-Content -LiteralPath $Path -Encoding UTF8) {
  $index++
  foreach ($category in $words.Keys) {
    foreach ($word in $words[$category]) {
      if ($textLine.IndexOf($word, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $snippet = $textLine.Trim()
        if ($snippet.Length -gt 100) { $snippet = $snippet.Substring(0, 100) + "..." }
        $hits.Add("line $index | $category | $word | $snippet")
      }
    }
  }
}

if ($hits.Count -gt 0) {
  Write-Host "[SENSITIVE_HIT] count=$($hits.Count)"
  $hits | ForEach-Object { Write-Host $_ }
  exit 1
}

Write-Host "[SENSITIVE_SCAN] PASS"
exit 0
