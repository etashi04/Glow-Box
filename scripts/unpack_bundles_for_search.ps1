param([Parameter(Mandatory=$true)][string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
$uab = Join-Path $ProjectRoot 'tools\UABEA-v8'
Add-Type -Path (Join-Path $uab 'AssetsTools.NET.dll')
$inputDir = Join-Path $ProjectRoot 'analysis\decrypted_bundles'
$outputDir = Join-Path $ProjectRoot 'analysis\unpacked_bundles'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
foreach ($input in Get-ChildItem -LiteralPath $inputDir -Filter '*.bundle') {
    $output = Join-Path $outputDir $input.Name
    if (Test-Path -LiteralPath $output) { continue }
    $manager = [AssetsTools.NET.Extra.AssetsManager]::new()
    $bundle = $manager.LoadBundleFile($input.FullName, $false)
    $stream = [IO.File]::Create($output)
    $writer = [AssetsTools.NET.AssetsFileWriter]::new($stream)
    $bundle.file.Unpack($writer)
    $writer.Dispose()
    $stream.Dispose()
    $manager.UnloadAll($true)
}
Write-Output "Unpacked $((Get-ChildItem -LiteralPath $outputDir -Filter '*.bundle').Count) bundles"
