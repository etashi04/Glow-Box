param([Parameter(Mandatory=$true)][string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
$uab = Join-Path $ProjectRoot 'tools\UABEA-v8'
Add-Type -Path (Join-Path $uab 'AssetsTools.NET.dll')
$inputDir = Join-Path $ProjectRoot 'analysis\poc\patched_decrypted'
$outputDir = Join-Path $ProjectRoot 'analysis\poc\patched_decrypted_lz4'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

foreach ($input in Get-ChildItem -LiteralPath $inputDir -Filter '*.bundle') {
    $manager = [AssetsTools.NET.Extra.AssetsManager]::new()
    $bundle = $manager.LoadBundleFile($input.FullName, $true)
    $output = Join-Path $outputDir $input.Name
    $stream = [IO.File]::Create($output)
    $writer = [AssetsTools.NET.AssetsFileWriter]::new($stream)
    $bundle.file.Pack(
        $bundle.file.DataReader,
        $writer,
        [AssetsTools.NET.AssetBundleCompressionType]::LZ4,
        $false,
        $null)
    $writer.Dispose()
    $stream.Dispose()
    $manager.UnloadAll($true)

    # Reopen the packed output to ensure its directory and block table are readable.
    $checkManager = [AssetsTools.NET.Extra.AssetsManager]::new()
    $checkBundle = $checkManager.LoadBundleFile($output, $true)
    $names = $checkBundle.file.GetAllFileNames()
    if ($names.Count -eq 0) { throw "Packed bundle has no entries: $($input.Name)" }
    $checkManager.UnloadAll($true)
    [ordered]@{
        File = $input.Name
        UnpackedBytes = $input.Length
        LZ4Bytes = (Get-Item -LiteralPath $output).Length
        Entries = $names.Count
    } | ConvertTo-Json -Compress
}
