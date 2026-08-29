param(
    [string]$ProjectRoot = $PSScriptRoot,
    [string]$TestGamePath
)
$ErrorActionPreference = 'Stop'
$version = (Get-Content -LiteralPath (Join-Path $ProjectRoot 'VERSION') -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "VERSION must use x.y.z format: $version" }
$manifestPath = Join-Path $ProjectRoot "versions\$version\manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath)) { throw "Missing manifest: $manifestPath" }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.patchVersion -ne $version) { throw 'VERSION and manifest patchVersion do not match.' }
$payloadDir = Join-Path $ProjectRoot $manifest.payloadDirectory
foreach ($bundle in $manifest.bundles) {
    $payload = Join-Path $payloadDir $bundle.name
    if (-not $bundle.patchedSha256 -or (Get-FileHash -Algorithm SHA256 -LiteralPath $payload).Hash -ne $bundle.patchedSha256) { throw "Patched payload hash mismatch: $($bundle.name)" }
}
$releaseDir = Join-Path $ProjectRoot "release\v$version"
$packageDir = Join-Path $releaseDir "GlowBox_Korean_Patch_v$version"
$exe = Join-Path $packageDir "GlowBox_Korean_Patch_v$version.exe"
New-Item -ItemType Directory -Force -Path $packageDir | Out-Null
& (Join-Path $ProjectRoot 'distribution\build_installer.ps1') -PayloadDir $payloadDir -OutputPath $exe -ManifestPath $manifestPath
$readmeTemplate = Get-Content -LiteralPath (Join-Path $ProjectRoot 'distribution\README.txt') -Raw
[IO.File]::WriteAllText((Join-Path $packageDir 'README.txt'), $readmeTemplate.Replace('__PATCH_VERSION__', $version), [Text.UTF8Encoding]::new($true))

if (-not $TestGamePath) { $TestGamePath = Join-Path $ProjectRoot 'analysis\distribution_install_test_20260830\GlowMachine' }
if (-not (Test-Path -LiteralPath (Join-Path $TestGamePath 'Glow Box.exe'))) { throw "Test game not found: $TestGamePath" }
$testRoot = Join-Path $ProjectRoot ("analysis\release_test_" + [guid]::NewGuid().ToString('N') + '\GlowMachine')
$target = Join-Path $testRoot 'Glow Box_Data\StreamingAssets\aa\StandaloneWindows64'
New-Item -ItemType Directory -Force -Path $target | Out-Null
Copy-Item -LiteralPath (Join-Path $TestGamePath 'Glow Box.exe') -Destination (Join-Path $testRoot 'Glow Box.exe')
foreach ($bundle in $manifest.bundles) {
    $source = Join-Path $TestGamePath "KoreanPatch_Backup\$($bundle.name)"
    if (-not (Test-Path -LiteralPath $source)) { $source = Join-Path $TestGamePath "Glow Box_Data\StreamingAssets\aa\StandaloneWindows64\$($bundle.name)" }
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash -ne $bundle.originalSha256) { throw "Original hash mismatch: $($bundle.name)" }
    Copy-Item -LiteralPath $source -Destination (Join-Path $target $bundle.name)
}
$process = Start-Process -FilePath $exe -ArgumentList @('--install', ('"' + $testRoot + '"')) -Wait -PassThru
if ($process.ExitCode -ne 0) { throw 'Installer test failed.' }
foreach ($bundle in $manifest.bundles) {
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $target $bundle.name)).Hash -ne $bundle.patchedSha256) { throw "Installed hash mismatch: $($bundle.name)" }
}
$process = Start-Process -FilePath $exe -ArgumentList @('--restore', ('"' + $testRoot + '"')) -Wait -PassThru
if ($process.ExitCode -ne 0) { throw 'Restore test failed.' }
foreach ($bundle in $manifest.bundles) {
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $target $bundle.name)).Hash -ne $bundle.originalSha256) { throw "Restore hash mismatch: $($bundle.name)" }
}
$zip = Join-Path $releaseDir "GlowBox_Korean_Patch_v$version.zip"
Compress-Archive -Path "$packageDir\*" -DestinationPath $zip -CompressionLevel Optimal -Force
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash
[IO.File]::WriteAllText((Join-Path $releaseDir 'SHA256SUMS.txt'), "$hash  $(Split-Path $zip -Leaf)`r`n", [Text.UTF8Encoding]::new($false))
Write-Output "Release v$version complete"
Write-Output "ZIP: $zip"
Write-Output "SHA-256: $hash"
