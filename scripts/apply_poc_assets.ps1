param([Parameter(Mandatory=$true)][string]$ProjectRoot)
$ErrorActionPreference = 'Stop'

$uab = Join-Path $ProjectRoot 'tools\UABEA-v8'
Add-Type -Path (Join-Path $uab 'Mono.Cecil.dll')
Add-Type -Path (Join-Path $uab 'AssetsTools.NET.dll')
Add-Type -Path (Join-Path $uab 'AssetsTools.NET.MonoCecil.dll')

$decrypted = Join-Path $ProjectRoot 'analysis\decrypted_bundles'
$poc = Join-Path $ProjectRoot 'analysis\poc'
$output = Join-Path $poc 'patched_decrypted'
$managed = Join-Path $ProjectRoot 'work\game\Glow Box_Data\Managed'
$classData = Join-Path $uab 'classdata.tpk'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$glyphFile = Get-Content -LiteralPath (Join-Path $poc 'glyphs.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$translations = Get-Content -LiteralPath (Join-Path $ProjectRoot 'translations\system_text_ko.json') -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
$eventTranslations = Get-Content -LiteralPath (Join-Path $ProjectRoot 'translations\main_event_ko.json') -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable

function New-Manager {
    $manager = [AssetsTools.NET.Extra.AssetsManager]::new()
    [void]$manager.LoadClassPackage($classData)
    $manager.MonoTempGenerator = [AssetsTools.NET.Extra.MonoCecilTempGenerator]::new($managed)
    return $manager
}

function New-GenericList([Type]$type) {
    $listType = [System.Collections.Generic.List``1].MakeGenericType($type)
    $list = [Activator]::CreateInstance($listType)
    return ,$list
}

function Write-AssetsFile($assets, $info, $field) {
    [byte[]]$saved = $field.WriteToByteArray($false)
    [int]$classId = $info.GetTypeId($assets.file)
    [int]$monoId = $assets.file.GetScriptIndex($info)
    $replacer = [AssetsTools.NET.AssetsReplacerFromMemory]::new(
        [long]$info.PathId, $classId, $monoId, $saved)
    $list = New-GenericList ([AssetsTools.NET.AssetsReplacer])
    $list.Add($replacer)
    $stream = [IO.MemoryStream]::new()
    $writer = [AssetsTools.NET.AssetsFileWriter]::new($stream)
    $assets.file.Write($writer, [long]0, $list, $null)
    $writer.Dispose()
    [byte[]]$result = $stream.ToArray()
    $stream.Dispose()
    return $result
}

function Write-Bundle($bundle, [string]$path, $replacer) {
    $list = New-GenericList ([AssetsTools.NET.BundleReplacer])
    $list.Add($replacer)
    $stream = [IO.File]::Create($path)
    $writer = [AssetsTools.NET.AssetsFileWriter]::new($stream)
    $bundle.file.Write($writer, $list, $null)
    $writer.Dispose()
    $stream.Dispose()
}

function Set-Pair($field, [single]$x, [single]$y) {
    $valueType = $field['x'].Value.ValueType
    if ($valueType -eq [AssetsTools.NET.AssetValueType]::Int32 -or
        $valueType -eq [AssetsTools.NET.AssetValueType]::UInt32) {
        $field['x'].AsInt = [int]$x
        $field['y'].AsInt = [int]$y
    } else {
        $field['x'].AsFloat = $x
        $field['y'].AsFloat = $y
    }
}

# Patch Japanese FontAtlasData: embedded TTF plus seven appended glyph records.
$manager = New-Manager
$fontInput = Join-Path $decrypted '4acc258f619ac06b664ed91b69b7f2a1.bundle'
$bundle = $manager.LoadBundleFile($fontInput, $true)
$assets = $manager.LoadAssetsFileFromBundle($bundle, 0, $false)
$info = $assets.file.GetAssetInfo([long]-8171738479205027984)
if ($null -eq $info) { throw 'Japanese FontAtlasData was not found' }
$field = $manager.GetBaseField($assets, $info, [AssetsTools.NET.Extra.AssetReadFlags]::None)
[byte[]]$fontBytes = [IO.File]::ReadAllBytes((Join-Path $poc 'KH-Dot-Kodenmachou-16-Korean-PoC.ttf'))
$field['fontSource']['Array'].AsByteArray = $fontBytes
$glyphArray = $field['glyphs']['Array']
if ($glyphArray.Children.Count -ne [int]$glyphFile.original_glyph_count) {
    throw "Unexpected glyph count: $($glyphArray.Children.Count)"
}
$template = $glyphArray.Children[0].TemplateField
$refManager = $manager.GetRefTypeManager($assets)
foreach ($glyph in $glyphFile.glyphs) {
    [byte[]]$seed = $glyphArray.Children[0].WriteToByteArray($false)
    $seedStream = [IO.MemoryStream]::new($seed)
    $reader = [AssetsTools.NET.AssetsFileReader]::new($seedStream)
    $added = $template.MakeValue($reader, $refManager)
    Set-Pair $added['inAtlasFrom'] $glyph.atlas_x $glyph.atlas_y
    Set-Pair $added['inAtlasSize'] $glyph.atlas_width $glyph.atlas_height
    Set-Pair $added['baseBearing'] $glyph.bearing_x $glyph.bearing_y
    Set-Pair $added['baseBearingVertical'] $glyph.vertical_x $glyph.vertical_y
    $glyphArray.Children.Add($added)
    $reader.Dispose()
    $seedStream.Dispose()
}
[byte[]]$fontAssetData = Write-AssetsFile $assets $info $field
$entryName = $bundle.file.GetFileName(0)
$replacer = [AssetsTools.NET.BundleReplacerFromMemory]::new(
    $entryName, $entryName, $true, $fontAssetData, [long]-1, [int]0)
Write-Bundle $bundle (Join-Path $output '4acc258f619ac06b664ed91b69b7f2a1.bundle') $replacer
$manager.UnloadAll($true)
Write-Output "FontAtlasData patched: $($glyphArray.Children.Count) glyphs"

# Replace the streamed RGB24 texture bytes without changing its size or metadata.
$manager = [AssetsTools.NET.Extra.AssetsManager]::new()
$atlasInput = Join-Path $decrypted '11ee4a0ca6d5e27a4192b31f12d7b10a.bundle'
$bundle = $manager.LoadBundleFile($atlasInput, $true)
$entryName = $bundle.file.GetFileName(1)
[byte[]]$atlasBytes = [IO.File]::ReadAllBytes((Join-Path $poc 'JapaneseFontAtlas-Korean-PoC.rgb24'))
$replacer = [AssetsTools.NET.BundleReplacerFromMemory]::new(
    $entryName, $entryName, $false, $atlasBytes, [long]-1, [int]0)
Write-Bundle $bundle (Join-Path $output '11ee4a0ca6d5e27a4192b31f12d7b10a.bundle') $replacer
$manager.UnloadAll($true)
Write-Output "Atlas texture patched: $($atlasBytes.Length) bytes"

# Reuse the Japanese language slot for the Korean system/menu text.
$manager = New-Manager
$textInput = Join-Path $decrypted 'b79bff27dd04232ee4d7bc9d1c2236b8.bundle'
$bundle = $manager.LoadBundleFile($textInput, $true)
$assets = $manager.LoadAssetsFileFromBundle($bundle, 0, $false)
$info = $assets.file.GetAssetInfo([long]-8455639814239168238)
if ($null -eq $info) { throw 'Japanese SystemText was not found' }
$field = $manager.GetBaseField($assets, $info, [AssetsTools.NET.Extra.AssetReadFlags]::None)
foreach ($item in $translations.GetEnumerator()) {
    if ($field[$item.Key].IsDummy) { throw "Unknown SystemText field: $($item.Key)" }
    $field[$item.Key].AsString = [string]$item.Value
}
[byte[]]$textAssetData = Write-AssetsFile $assets $info $field
$entryName = $bundle.file.GetFileName(0)
$replacer = [AssetsTools.NET.BundleReplacerFromMemory]::new(
    $entryName, $entryName, $true, $textAssetData, [long]-1, [int]0)
Write-Bundle $bundle (Join-Path $output 'b79bff27dd04232ee4d7bc9d1c2236b8.bundle') $replacer
$manager.UnloadAll($true)
Write-Output "SystemText patched: $($translations.Count) Korean fields"

# Patch the translated opening section of the Japanese MainEvent slot.
$manager = New-Manager
$eventInput = Join-Path $decrypted 'a83647f242c8e97a23ee6bcd801cb623.bundle'
$bundle = $manager.LoadBundleFile($eventInput, $true)
$assets = $manager.LoadAssetsFileFromBundle($bundle, 0, $false)
$info = $assets.file.GetAssetInfo([long]-158109455917131333)
if ($null -eq $info) { throw 'Japanese MainEvent asset was not found' }
$field = $manager.GetBaseField($assets, $info, [AssetsTools.NET.Extra.AssetReadFlags]::None)
$eventValues = $field['texts']['values']['Array'].Children
if ($eventValues.Count -ne 1411) { throw "Unexpected MainEvent count: $($eventValues.Count)" }
foreach ($item in $eventTranslations.GetEnumerator()) {
    $index = [int]$item.Key
    if ($index -lt 0 -or $index -ge $eventValues.Count) { throw "MainEvent index out of range: $index" }
    $eventValues[$index].AsString = [string]$item.Value
}
[byte[]]$eventAssetData = Write-AssetsFile $assets $info $field
$entryName = $bundle.file.GetFileName(0)
$replacer = [AssetsTools.NET.BundleReplacerFromMemory]::new(
    $entryName, $entryName, $true, $eventAssetData, [long]-1, [int]0)
Write-Bundle $bundle (Join-Path $output 'a83647f242c8e97a23ee6bcd801cb623.bundle') $replacer
$manager.UnloadAll($true)
Write-Output "MainEvent patched: $($eventTranslations.Count) opening lines"

# Replace the Japanese language slot's rasterized title logo.
$manager = [AssetsTools.NET.Extra.AssetsManager]::new()
$titleInput = Join-Path $decrypted '7bd755be8ba5171f40812b455a8a4ff1.bundle'
$bundle = $manager.LoadBundleFile($titleInput, $true)
$entryName = $bundle.file.GetFileName(1)
[byte[]]$titleBytes = [IO.File]::ReadAllBytes((Join-Path $poc 'GameTitleLogo-Korean.rgba32'))
if ($titleBytes.Length -ne 65536) { throw "Unexpected Korean title texture size: $($titleBytes.Length)" }
$replacer = [AssetsTools.NET.BundleReplacerFromMemory]::new(
    $entryName, $entryName, $false, $titleBytes, [long]-1, [int]0)
Write-Bundle $bundle (Join-Path $output '7bd755be8ba5171f40812b455a8a4ff1.bundle') $replacer
$manager.UnloadAll($true)
Write-Output "GameTitleLogo patched: $($titleBytes.Length) bytes"
