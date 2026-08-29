param([string]$GamePath)
$ErrorActionPreference = 'Stop'
if (-not $GamePath) {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = [Windows.Forms.FolderBrowserDialog]::new()
    $dialog.Description = 'Glow Box가 설치된 GlowMachine 폴더를 선택하세요.'
    if ($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { throw '취소되었습니다.' }
    $GamePath = $dialog.SelectedPath
}
$Backup = Join-Path $GamePath 'KoreanPatch_Backup'
$Target = Join-Path $GamePath 'Glow Box_Data\StreamingAssets\aa\StandaloneWindows64'
if (-not (Test-Path -LiteralPath $Backup)) { throw '복구용 백업을 찾지 못했습니다.' }
if (Get-Process -Name 'Glow Box' -ErrorAction SilentlyContinue) { throw '게임을 종료한 뒤 다시 실행하세요.' }
Get-ChildItem -LiteralPath $Backup -File -Filter '*.bundle' | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $Target $_.Name) -Force
}
$marker = Join-Path $GamePath 'KoreanPatch.json'
if (Test-Path -LiteralPath $marker) { Remove-Item -LiteralPath $marker }
Write-Host "`n한국어 패치를 제거하고 원본 파일을 복구했습니다." -ForegroundColor Cyan
Write-Host "안전을 위해 백업 폴더는 유지했습니다: $Backup"
