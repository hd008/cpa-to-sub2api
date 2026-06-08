@echo off
setlocal

set "TARGET_DIR=%~dp0."
set "BAT_FILE=%~f0"
set "PS_FILE=%TEMP%\cpa-to-sub2api-%RANDOM%-%RANDOM%.ps1"

echo CPA to Sub2API
echo.
echo Input folder:
echo %TARGET_DIR%
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$bat=$env:BAT_FILE; $out=$env:PS_FILE; $lines=Get-Content -LiteralPath $bat; $marker=($lines | Select-String -Pattern '^# POWERSHELL_PAYLOAD_START$' | Select-Object -First 1).LineNumber; if(-not $marker){ Write-Error 'PowerShell payload not found in BAT.'; exit 1 }; $lines[$marker..($lines.Count-1)] | Set-Content -LiteralPath $out -Encoding UTF8"

if errorlevel 1 (
  echo Failed to extract embedded converter.
  echo.
  pause
  exit /b 1
)

echo Generating sub2api.json ...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_FILE%" -InputDir "%TARGET_DIR%" -OutputJson "sub2api.json"
set "STATUS=%ERRORLEVEL%"

del "%PS_FILE%" >nul 2>nul

echo.
if not "%STATUS%"=="0" (
  echo Failed. See the message above.
) else (
  echo Done.
  echo Output: %TARGET_DIR%\sub2api.json
)
echo.
pause
exit /b %STATUS%

# POWERSHELL_PAYLOAD_START
param(
    [string]$InputDir = ".",
    [string]$OutputJson = "sub2api.json",
    [int]$Concurrency = 3,
    [int]$Priority = 50,
    [switch]$NoAutoPause
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertFrom-Base64Url {
    param([Parameter(Mandatory = $true)][string]$Value)

    $padded = $Value.Replace("-", "+").Replace("_", "/")
    switch ($padded.Length % 4) {
        2 { $padded += "==" }
        3 { $padded += "=" }
        1 { throw "Invalid base64url length" }
    }

    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($padded))
}

function Decode-JwtPayload {
    param([string]$Token)

    if ([string]::IsNullOrWhiteSpace($Token)) {
        return $null
    }

    $parts = $Token.Split(".")
    if ($parts.Count -ne 3) {
        return $null
    }

    try {
        $json = ConvertFrom-Base64Url -Value $parts[1]
        return $json | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Get-NestedProperty {
    param(
        [object]$Object,
        [string[]]$Path
    )

    $current = $Object
    foreach ($segment in $Path) {
        if ($null -eq $current) {
            return $null
        }
        $prop = $current.PSObject.Properties[$segment]
        if ($null -eq $prop) {
            return $null
        }
        $current = $prop.Value
    }
    return $current
}

function Get-PropertyValue {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Default = $null
    )

    if ($null -eq $Object) {
        return $Default
    }

    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop -or $null -eq $prop.Value) {
        return $Default
    }

    return $prop.Value
}

function ConvertTo-UnixSeconds {
    param([object]$Value)

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [int] -or $Value -is [long]) {
        if ([int64]$Value -gt 1000000000000) {
            return [int64]([math]::Floor(([double]$Value) / 1000))
        }
        return [int64]$Value
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    $number = 0L
    if ([int64]::TryParse($text, [ref]$number)) {
        if ($number -gt 1000000000000) {
            return [int64]([math]::Floor(([double]$number) / 1000))
        }
        return $number
    }

    try {
        $dt = [DateTimeOffset]::Parse($text)
        return $dt.ToUnixTimeSeconds()
    } catch {
        return $null
    }
}

function ConvertTo-Rfc3339 {
    param([object]$Value)

    $unix = ConvertTo-UnixSeconds -Value $Value
    if ($null -eq $unix) {
        return $null
    }
    return [DateTimeOffset]::FromUnixTimeSeconds($unix).UtcDateTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
}

function Add-IfNotBlank {
    param(
        [System.Collections.IDictionary]$Target,
        [string]$Key,
        [object]$Value
    )

    if ($null -eq $Value) {
        return
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return
    }

    $Target[$Key] = $text
}

$resolvedInput = Resolve-Path -LiteralPath $InputDir
$skipNames = @(
    $OutputJson,
    "cpa-to-sub2api-summary.csv",
    "sub2api.redacted.json",
    "cpa-summary.csv"
)

$jsonFiles = @(Get-ChildItem -LiteralPath $resolvedInput -Filter "*.json" -File |
    Where-Object { $skipNames -notcontains $_.Name } |
    Sort-Object Name)

if ($jsonFiles.Count -eq 0) {
    throw "No JSON files found in $resolvedInput"
}

$accounts = New-Object System.Collections.Generic.List[object]
$summary = New-Object System.Collections.Generic.List[object]

foreach ($file in $jsonFiles) {
    try {
        $raw = Get-Content -Raw -LiteralPath $file.FullName
        $cpa = $raw | ConvertFrom-Json
    } catch {
        $summary.Add([pscustomobject]@{
            file = $file.Name
            status = "failed_json"
            name = ""
            email = ""
            plan_type = ""
            expires_at = ""
            has_access_token = $false
            has_refresh_token = $false
            has_id_token = $false
            message = $_.Exception.Message
        })
        continue
    }

    $accessToken = [string](Get-PropertyValue -Object $cpa -Name "access_token" -Default "")
    if ([string]::IsNullOrWhiteSpace($accessToken)) {
        $summary.Add([pscustomobject]@{
            file = $file.Name
            status = "skipped"
            name = ""
            email = ""
            plan_type = ""
            expires_at = ""
            has_access_token = $false
            has_refresh_token = $false
            has_id_token = $false
            message = "missing top-level access_token"
        })
        continue
    }

    $refreshToken = [string](Get-PropertyValue -Object $cpa -Name "refresh_token" -Default "")
    $idToken = [string](Get-PropertyValue -Object $cpa -Name "id_token" -Default "")
    $clientId = [string](Get-PropertyValue -Object $cpa -Name "client_id" -Default "")
    $accessClaims = Decode-JwtPayload -Token $accessToken
    $idClaims = Decode-JwtPayload -Token $idToken

    $openaiAuth = Get-NestedProperty -Object $accessClaims -Path @("https://api.openai.com/auth")
    if ($null -eq $openaiAuth) {
        $openaiAuth = Get-NestedProperty -Object $idClaims -Path @("https://api.openai.com/auth")
    }

    $email = [string](Get-PropertyValue -Object $cpa -Name "email" -Default "")
    if ([string]::IsNullOrWhiteSpace($email)) {
        $email = [string](Get-NestedProperty -Object $accessClaims -Path @("https://api.openai.com/profile", "email"))
    }
    if ([string]::IsNullOrWhiteSpace($email)) {
        $email = [string](Get-PropertyValue -Object $idClaims -Name "email" -Default "")
    }

    $accountId = [string](Get-PropertyValue -Object $cpa -Name "account_id" -Default "")
    if ([string]::IsNullOrWhiteSpace($accountId)) {
        $accountId = [string](Get-NestedProperty -Object $openaiAuth -Path @("chatgpt_account_id"))
    }

    $userId = [string](Get-NestedProperty -Object $openaiAuth -Path @("chatgpt_user_id"))
    if ([string]::IsNullOrWhiteSpace($userId)) {
        $userId = [string](Get-NestedProperty -Object $openaiAuth -Path @("user_id"))
    }

    $organizationId = [string](Get-NestedProperty -Object $openaiAuth -Path @("poid"))
    if ([string]::IsNullOrWhiteSpace($organizationId)) {
        $organizations = Get-NestedProperty -Object $openaiAuth -Path @("organizations")
        if ($null -ne $organizations) {
            foreach ($org in $organizations) {
                $isDefault = [bool](Get-PropertyValue -Object $org -Name "is_default" -Default $false)
                if ($isDefault) {
                    $organizationId = [string](Get-PropertyValue -Object $org -Name "id" -Default "")
                    break
                }
            }
            if ([string]::IsNullOrWhiteSpace($organizationId) -and $organizations.Count -gt 0) {
                $organizationId = [string](Get-PropertyValue -Object $organizations[0] -Name "id" -Default "")
            }
        }
    }

    $planType = [string](Get-PropertyValue -Object $cpa -Name "plan_type" -Default "")
    if ([string]::IsNullOrWhiteSpace($planType)) {
        $planType = [string](Get-NestedProperty -Object $openaiAuth -Path @("chatgpt_plan_type"))
    }

    $expiredValue = Get-PropertyValue -Object $cpa -Name "expired" -Default $null
    $expiresUnix = ConvertTo-UnixSeconds -Value $expiredValue
    if ($null -eq $expiresUnix -and $null -ne $accessClaims -and $accessClaims.PSObject.Properties["exp"]) {
        $expiresUnix = ConvertTo-UnixSeconds -Value $accessClaims.exp
    }

    $credentialsExpiresAt = ConvertTo-Rfc3339 -Value $expiredValue
    if ($null -eq $credentialsExpiresAt -and $null -ne $expiresUnix) {
        $credentialsExpiresAt = ConvertTo-Rfc3339 -Value $expiresUnix
    }

    $name = $email
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = [IO.Path]::GetFileNameWithoutExtension($file.Name)
    }

    $credentials = [ordered]@{}
    $credentials["access_token"] = $accessToken
    Add-IfNotBlank -Target $credentials -Key "refresh_token" -Value $refreshToken
    Add-IfNotBlank -Target $credentials -Key "id_token" -Value $idToken
    Add-IfNotBlank -Target $credentials -Key "client_id" -Value $clientId
    Add-IfNotBlank -Target $credentials -Key "email" -Value $email
    Add-IfNotBlank -Target $credentials -Key "chatgpt_account_id" -Value $accountId
    Add-IfNotBlank -Target $credentials -Key "chatgpt_user_id" -Value $userId
    Add-IfNotBlank -Target $credentials -Key "organization_id" -Value $organizationId
    Add-IfNotBlank -Target $credentials -Key "plan_type" -Value $planType
    Add-IfNotBlank -Target $credentials -Key "expires_at" -Value $credentialsExpiresAt

    $account = [ordered]@{
        name = $name
        platform = "openai"
        type = "oauth"
        credentials = $credentials
        extra = [ordered]@{
            import_source = "cpa_json"
        }
        concurrency = $Concurrency
        priority = $Priority
        auto_pause_on_expired = (-not $NoAutoPause.IsPresent)
    }

    if ($null -ne $expiresUnix) {
        $account["expires_at"] = $expiresUnix
    }

    $accounts.Add($account)

    $summary.Add([pscustomobject]@{
        file = $file.Name
        status = "ok"
        name = $name
        email = $email
        plan_type = $planType
        expires_at = $credentialsExpiresAt
        has_access_token = $true
        has_refresh_token = -not [string]::IsNullOrWhiteSpace($refreshToken)
        has_id_token = -not [string]::IsNullOrWhiteSpace($idToken)
        message = ""
    })
}

if ($accounts.Count -eq 0) {
    throw "No importable CPA files found."
}

$payload = [ordered]@{
    type = "sub2api-data"
    version = 1
    exported_at = [DateTimeOffset]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
    proxies = @()
    accounts = $accounts
}

$outPath = Join-Path $resolvedInput $OutputJson

$payload | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $outPath -Encoding UTF8

$ok = @($summary | Where-Object { $_.status -eq "ok" }).Count
$failed = @($summary | Where-Object { $_.status -ne "ok" }).Count
Write-Host "Read $($jsonFiles.Count) JSON files. Importable=$ok SkippedOrFailed=$failed"
Write-Host "Wrote Sub2API import file: $OutputJson"
