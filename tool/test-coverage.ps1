$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot

try {
    flutter test --coverage
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    $coveragePath = Join-Path $projectRoot 'coverage\lcov.info'
    if (-not (Test-Path -LiteralPath $coveragePath)) {
        throw "Coverage report was not created at $coveragePath"
    }

    $lineHits = @(
        Select-String -Path $coveragePath -Pattern '^DA:\d+,(\d+)' |
            ForEach-Object { [int]$_.Matches[0].Groups[1].Value }
    )
    if ($lineHits.Count -eq 0) {
        throw "No line coverage data was found in $coveragePath"
    }

    $coveredLines = @($lineHits | Where-Object { $_ -gt 0 }).Count
    $coveragePercent = 100 * $coveredLines / $lineHits.Count
    $summary = [string]::Format(
        [Globalization.CultureInfo]::InvariantCulture,
        'Line coverage: {0:F2}% ({1}/{2} lines)',
        $coveragePercent,
        $coveredLines,
        $lineHits.Count
    )
    Write-Host $summary
}
finally {
    Pop-Location
}
