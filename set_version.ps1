param(
    [Parameter(Mandatory = $true)]
    [string]$VersionName,

    [Parameter(Mandatory = $true)]
    [int]$VersionCode
)

$ErrorActionPreference = "Stop"
trap {
    [Console]::Error.WriteLine("Error: {0}", $_.Exception.Message)
    exit 1
}

if ($VersionName -notmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$') {
    throw "versionName must follow X.Y.Z using non-negative integers."
}
if ($VersionCode -lt 1) {
    throw "versionCode must be a positive integer."
}

$gradleFile = Join-Path $PSScriptRoot "app\build.gradle.kts"
$content = [IO.File]::ReadAllText($gradleFile)
$currentNameMatch = [regex]::Match($content, 'versionName = "([^"]+)"')
$currentCodeMatch = [regex]::Match($content, 'versionCode = ([0-9]+)')
if (-not $currentNameMatch.Success -or -not $currentCodeMatch.Success) {
    throw "Could not read the current Android version."
}

$currentName = $currentNameMatch.Groups[1].Value
$currentCode = [int]$currentCodeMatch.Groups[1].Value
$currentParts = @($currentName.Split('.') | ForEach-Object { [int]$_ })
$newParts = @($VersionName.Split('.') | ForEach-Object { [int]$_ })
$isNewer = $false
for ($index = 0; $index -lt 3; $index++) {
    if ($newParts[$index] -gt $currentParts[$index]) {
        $isNewer = $true
        break
    }
    if ($newParts[$index] -lt $currentParts[$index]) {
        break
    }
}

if (-not $isNewer) {
    throw "versionName must be newer than the current version $currentName."
}
if ($VersionCode -le $currentCode) {
    throw "versionCode must be greater than the current code $currentCode."
}

$content = [regex]::Replace($content, 'versionCode = [0-9]+', "versionCode = $VersionCode", 1)
$content = [regex]::Replace($content, 'versionName = "[^"]+"', "versionName = `"$VersionName`"", 1)
[IO.File]::WriteAllText($gradleFile, $content, [Text.UTF8Encoding]::new($false))

Write-Output "Version updated: $currentName ($currentCode) -> $VersionName ($VersionCode)"
