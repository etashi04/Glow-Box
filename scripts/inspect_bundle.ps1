param(
    [Parameter(Mandatory=$true)][string]$ProjectRoot,
    [Parameter(Mandatory=$true)][string]$BundlePath
)
$ErrorActionPreference = 'Stop'
$uab = Join-Path $ProjectRoot 'tools\UABEA-v8'
Add-Type -Path (Join-Path $uab 'Mono.Cecil.dll')
Add-Type -Path (Join-Path $uab 'AssetsTools.NET.dll')
Add-Type -Path (Join-Path $uab 'AssetsTools.NET.MonoCecil.dll')
$manager = [AssetsTools.NET.Extra.AssetsManager]::new()
[void]$manager.LoadClassPackage((Join-Path $uab 'classdata.tpk'))
$manager.MonoTempGenerator = [AssetsTools.NET.Extra.MonoCecilTempGenerator]::new(
    (Join-Path $ProjectRoot 'work\game\Glow Box_Data\Managed'))
$bundle = $manager.LoadBundleFile($BundlePath, $true)
for ($entry = 0; $entry -lt $bundle.file.GetAllFileNames().Count; $entry++) {
    if (-not $bundle.file.IsAssetsFile($entry)) { continue }
    $assets = $manager.LoadAssetsFileFromBundle($bundle, $entry, $false)
    foreach ($info in $assets.file.AssetInfos) {
        $classId = $info.GetTypeId($assets.file)
        $name = ''
        try {
            $field = $manager.GetBaseField($assets, $info, [AssetsTools.NET.Extra.AssetReadFlags]::None)
            if (-not $field['m_Name'].IsDummy) { $name = $field['m_Name'].AsString }
        } catch { $name = '<unreadable>' }
        [pscustomobject]@{
            Entry = $bundle.file.GetFileName($entry)
            PathId = $info.PathId
            ClassId = $classId
            Class = if ([Enum]::IsDefined([AssetsTools.NET.Extra.AssetClassID], $classId)) {
                ([AssetsTools.NET.Extra.AssetClassID]$classId).ToString()
            } else { $classId }
            Name = $name
            Bytes = $info.ByteSize
        }
    }
}
$manager.UnloadAll($true)
