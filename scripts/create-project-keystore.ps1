[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$signingDirectory = Join-Path $repositoryRoot ".signing"
$keystorePath = Join-Path $signingDirectory "kristal-launcher.jks"
$propertiesPath = Join-Path $signingDirectory "keystore.properties"
$keyAlias = "kristal-launcher"

function Resolve-Keytool {
    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($env:JAVA_HOME) {
        $candidates.Add((Join-Path $env:JAVA_HOME "bin\keytool.exe"))
    }
    $candidates.Add((Join-Path $repositoryRoot ".jdk17\jdk\bin\keytool.exe"))

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    $command = Get-Command keytool.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }
    throw "JDK keytool was not found. Configure JAVA_HOME or install the local .jdk17 toolchain."
}

$keystoreExists = Test-Path -LiteralPath $keystorePath
$propertiesExist = Test-Path -LiteralPath $propertiesPath
if ($keystoreExists -and $propertiesExist) {
    Write-Output "The project keystore already exists. Nothing was changed."
    Write-Output "Keystore: $keystorePath"
    exit 0
}
if ($keystoreExists -or $propertiesExist) {
    throw "The signing setup is incomplete. Restore the missing .signing file instead of replacing the existing one."
}

$keytool = Resolve-Keytool
New-Item -ItemType Directory -Path $signingDirectory -Force | Out-Null

$randomBytes = [byte[]]::new(32)
$randomGenerator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try {
    $randomGenerator.GetBytes($randomBytes)
} finally {
    $randomGenerator.Dispose()
}
$password = -join ($randomBytes | ForEach-Object { $_.ToString("x2") })

$env:KRISTAL_LAUNCHER_KEYSTORE_PASSWORD = $password
try {
    & $keytool `
        -genkeypair `
        -noprompt `
        -keystore $keystorePath `
        -storetype JKS `
        -alias $keyAlias `
        -keyalg RSA `
        -keysize 4096 `
        -sigalg SHA256withRSA `
        -validity 10000 `
        -dname "CN=Kristal Launcher, O=Kristal Launcher, C=BR" `
        "-storepass:env" KRISTAL_LAUNCHER_KEYSTORE_PASSWORD `
        "-keypass:env" KRISTAL_LAUNCHER_KEYSTORE_PASSWORD
    if ($LASTEXITCODE -ne 0) {
        throw "keytool failed with exit code $LASTEXITCODE."
    }

    $properties = @(
        "storeFile=.signing/kristal-launcher.jks"
        "storePassword=$password"
        "keyAlias=$keyAlias"
        "keyPassword=$password"
        ""
    ) -join [Environment]::NewLine
    [System.IO.File]::WriteAllText(
        $propertiesPath,
        $properties,
        [System.Text.UTF8Encoding]::new($false)
    )

    & $keytool `
        -list `
        -keystore $keystorePath `
        -alias $keyAlias `
        "-storepass:env" KRISTAL_LAUNCHER_KEYSTORE_PASSWORD | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "The generated keystore could not be verified."
    }
} catch {
    if (-not (Test-Path -LiteralPath $propertiesPath) -and (Test-Path -LiteralPath $keystorePath)) {
        Remove-Item -LiteralPath $keystorePath -Force
    }
    throw
} finally {
    Remove-Item Env:\KRISTAL_LAUNCHER_KEYSTORE_PASSWORD -ErrorAction SilentlyContinue
}

Write-Output "Project keystore created successfully."
Write-Output "Keystore: $keystorePath"
Write-Output "Credentials: $propertiesPath"
Write-Warning "Back up both files securely. Losing either one prevents future APKs from updating existing installations."
