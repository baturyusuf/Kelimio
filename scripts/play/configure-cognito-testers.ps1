[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$UserPoolId,

    [Parameter(Mandatory = $true)]
    [string[]]$TesterEmails,

    [string]$Region = "eu-central-1",
    [string]$GroupName = "kelimio-internal-testers",
    [string]$AwsProfile
)

. (Join-Path $PSScriptRoot "common.ps1")

Assert-KelimioCommand "aws"

$commonArgs = @("--region", $Region)
if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) {
    $commonArgs += @("--profile", $AwsProfile)
}

& aws @commonArgs cognito-idp get-group `
    --user-pool-id $UserPoolId `
    --group-name $GroupName `
    --output json 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Creating Cognito group '$GroupName'..."
    Invoke-KelimioCommand aws @commonArgs cognito-idp create-group `
        --user-pool-id $UserPoolId `
        --group-name $GroupName `
        --description "Kelimio Google Play internal testers"
}

foreach ($email in $TesterEmails) {
    if ($email -notmatch "^[^@\s]+@[^@\s]+\.[^@\s]+$") {
        throw "Invalid tester email: $email"
    }

    $filter = "email = `"$email`""
    $usersJson = & aws @commonArgs cognito-idp list-users `
        --user-pool-id $UserPoolId `
        --filter $filter `
        --limit 2 `
        --output json
    if ($LASTEXITCODE -ne 0) {
        throw "Could not search Cognito for $email."
    }
    $users = ($usersJson | ConvertFrom-Json).Users
    if ($users.Count -eq 0) {
        throw "No Cognito user exists for $email. Ask the tester to register and verify email first."
    }
    if ($users.Count -gt 1) {
        throw "More than one Cognito user matched $email; resolve the identity collision before continuing."
    }

    $username = $users[0].Username
    Invoke-KelimioCommand aws @commonArgs cognito-idp admin-add-user-to-group `
        --user-pool-id $UserPoolId `
        --username $username `
        --group-name $GroupName
    Write-Host "Added $email ($username) to $GroupName."
}

Write-Host ""
Write-Host "Group assignment is complete. Testers must sign out and sign in again so the access token contains cognito:groups."
