param([string]$GamePath)
$ErrorActionPreference = 'Stop'
$PatchVersion = '1.0.0'
$BundleNames = @(
    '11ee4a0ca6d5e27a4192b31f12d7b10a.bundle',
    '4acc258f619ac06b664ed91b69b7f2a1.bundle',
    '7bd755be8ba5171f40812b455a8a4ff1.bundle',
    'a83647f242c8e97a23ee6bcd801cb623.bundle',
    'b79bff27dd04232ee4d7bc9d1c2236b8.bundle'
)
$OriginalHashes = @{
    '11ee4a0ca6d5e27a4192b31f12d7b10a.bundle' = '7AE36FD537ACBFFFA9D20A8D1C439982D0C7806696E8468F681AB3ED67E5CEE2'
    '4acc258f619ac06b664ed91b69b7f2a1.bundle' = '6DBCE59D4C90FB3D3A6704FC877EFACA77D36A7AAAAACE165945DABF8A07F48D'
    '7bd755be8ba5171f40812b455a8a4ff1.bundle' = '6EC3D3DB085064A4D1D97B0B375B475966F90668F3068DEB1EDE8FB192E6B3AE'
    'a83647f242c8e97a23ee6bcd801cb623.bundle' = '4633E027E17F0B4AB44EFEDF717736C78256C5FD4E1846567267BC5A48F3C2E6'
    'b79bff27dd04232ee4d7bc9d1c2236b8.bundle' = '74D5C1A1C6D22E3DB89F227A1B30561A5CA492C9F354A8F743741C12844D5F77'
}

function Find-GamePath {
    param([string]$Requested)
    $candidates = [Collections.Generic.List[string]]::new()
    if ($Requested) { $candidates.Add($Requested) }
    $candidates.Add((Get-Location).Path)
    $steamRoots = @(
        (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath,
        (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -ErrorAction SilentlyContinue).InstallPath
    ) | Where-Object { $_ }
    foreach ($steam in $steamRoots) {
        $candidates.Add((Join-Path $steam 'steamapps\common\GlowMachine'))
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) {
            foreach ($match in [regex]::Matches([IO.File]::ReadAllText($vdf), '"path"\s+"([^"]+)"')) {
                $library = $match.Groups[1].Value.Replace('\\', '\')
                $candidates.Add((Join-Path $library 'steamapps\common\GlowMachine'))
            }
        }
    }
    foreach ($candidate in $candidates | Select-Object -Unique) {
        if (Test-Path -LiteralPath (Join-Path $candidate 'Glow Box.exe')) { return (Resolve-Path -LiteralPath $candidate).Path }
    }
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = [Windows.Forms.FolderBrowserDialog]::new()
    $dialog.Description = 'Glow Box가 설치된 GlowMachine 폴더를 선택하세요.'
    if ($dialog.ShowDialog() -eq [Windows.Forms.DialogResult]::OK -and
        (Test-Path -LiteralPath (Join-Path $dialog.SelectedPath 'Glow Box.exe'))) {
        return $dialog.SelectedPath
    }
    throw 'Glow Box 설치 폴더를 찾지 못했습니다.'
}

$GamePath = Find-GamePath $GamePath
$Payload = Join-Path $PSScriptRoot 'payload'
$Target = Join-Path $GamePath 'Glow Box_Data\StreamingAssets\aa\StandaloneWindows64'
$Backup = Join-Path $GamePath 'KoreanPatch_Backup'
if (-not (Test-Path -LiteralPath $Payload)) { throw 'payload 폴더가 없습니다.' }
if (Get-Process -Name 'Glow Box' -ErrorAction SilentlyContinue) { throw '게임을 종료한 뒤 다시 실행하세요.' }
New-Item -ItemType Directory -Force -Path $Backup | Out-Null

foreach ($name in $BundleNames) {
    $source = Join-Path $Payload $name
    $targetFile = Join-Path $Target $name
    $backupFile = Join-Path $Backup $name
    if (-not (Test-Path -LiteralPath $source)) { throw "패치 파일 누락: $name" }
    if (-not (Test-Path -LiteralPath $targetFile)) { throw "게임 파일 누락: $name" }
    if (-not (Test-Path -LiteralPath $backupFile)) {
        $currentHash = (Get-FileHash -LiteralPath $targetFile -Algorithm SHA256).Hash
        if ($currentHash -ne $OriginalHashes[$name]) { throw "지원하지 않는 게임 버전 또는 이미 수정된 파일입니다: $name" }
        Copy-Item -LiteralPath $targetFile -Destination $backupFile
    }
    Copy-Item -LiteralPath $source -Destination ($targetFile + '.tmp') -Force
    Move-Item -LiteralPath ($targetFile + '.tmp') -Destination $targetFile -Force
}
@{ version = $PatchVersion; installedAt = (Get-Date).ToString('o') } |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $GamePath 'KoreanPatch.json') -Encoding UTF8
Write-Host "`nGlow Box 한국어 패치 $PatchVersion 설치 완료" -ForegroundColor Cyan
Write-Host "설치 위치: $GamePath"
