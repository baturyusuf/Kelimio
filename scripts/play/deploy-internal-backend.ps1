[CmdletBinding()]
param(
    [string]$Ref = "main",
    [switch]$ConfirmProductionImpact
)

. (Join-Path $PSScriptRoot "common.ps1")

if (-not $ConfirmProductionImpact) {
    throw "This activates one task in the protected AWS production environment. Re-run with -ConfirmProductionImpact."
}
Assert-KelimioCommand "gh"
Invoke-KelimioCommand gh auth status

$existingRuns = @(
    gh run list `
        --workflow production-deploy.yml `
        --event workflow_dispatch `
        --limit 20 `
        --json databaseId |
        ConvertFrom-Json |
        ForEach-Object databaseId
)

Invoke-KelimioCommand gh workflow run production-deploy.yml `
    --ref $Ref `
    -f activate_api=true

$runId = $null
for ($attempt = 0; $attempt -lt 30 -and -not $runId; $attempt++) {
    Start-Sleep -Seconds 2
    $runs = gh run list `
        --workflow production-deploy.yml `
        --event workflow_dispatch `
        --limit 20 `
        --json databaseId,headBranch,createdAt |
        ConvertFrom-Json
    $runId = $runs |
        Where-Object {
            $_.headBranch -eq $Ref -and
            $_.databaseId -notin $existingRuns
        } |
        Sort-Object createdAt -Descending |
        Select-Object -First 1 -ExpandProperty databaseId
}
if (-not $runId) {
    throw "The dispatched production deployment run could not be located."
}

Write-Host "Watching production deployment run $runId..."
Invoke-KelimioCommand gh run watch $runId --exit-status

Write-Host ""
Write-Host "Backend deployment completed."
Write-Host "Next: register each verified tester in the Cognito group with configure-cognito-testers.ps1."
