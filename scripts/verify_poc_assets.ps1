param([Parameter(Mandatory=$true)][string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
$uab = Join-Path $ProjectRoot 'tools\UABEA-v8'
Add-Type -Path (Join-Path $uab 'Mono.Cecil.dll')
Add-Type -Path (Join-Path $uab 'AssetsTools.NET.dll')
Add-Type -Path (Join-Path $uab 'AssetsTools.NET.MonoCecil.dll')
$patched = Join-Path $ProjectRoot 'analysis\poc\patched_decrypted'
$managed = Join-Path $ProjectRoot 'work\game\Glow Box_Data\Managed'

function New-Manager {
    $manager = [AssetsTools.NET.Extra.AssetsManager]::new()
    [void]$manager.LoadClassPackage((Join-Path $uab 'classdata.tpk'))
    $manager.MonoTempGenerator = [AssetsTools.NET.Extra.MonoCecilTempGenerator]::new($managed)
    return $manager
}

$manager = New-Manager
$bundle = $manager.LoadBundleFile((Join-Path $patched '4acc258f619ac06b664ed91b69b7f2a1.bundle'), $true)
$assets = $manager.LoadAssetsFileFromBundle($bundle, 0, $false)
$info = $assets.file.GetAssetInfo([long]-8171738479205027984)
if ($null -eq $info) {
    $ids = ($assets.file.AssetInfos | ForEach-Object PathId) -join ','
    throw "FontAtlasData path ID missing; found: $ids"
}
Write-Output "Font info: PathId=$($info.PathId) ClassId=$($info.ClassId) ScriptTypeIndex=$($info.ScriptTypeIndex) TypeId=$($info.TypeId)"
$field = $manager.GetBaseField($assets, $info, [AssetsTools.NET.Extra.AssetReadFlags]::None)
$fontSize = $field['fontSource']['Array'].AsByteArray.Length
$glyphCount = $field['glyphs']['Array'].Children.Count
$glyphMetadata = Get-Content -LiteralPath (Join-Path $ProjectRoot 'analysis\poc\glyphs.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$expectedGlyphCount = [int]$glyphMetadata.original_glyph_count + $glyphMetadata.glyphs.Count
if ($glyphCount -ne $expectedGlyphCount) { throw "Patched glyph count is $glyphCount, expected $expectedGlyphCount" }
if ($fontSize -lt 2000000) { throw "Patched TTF is unexpectedly small: $fontSize" }
$manager.UnloadAll($true)

$manager = [AssetsTools.NET.Extra.AssetsManager]::new()
$bundle = $manager.LoadBundleFile((Join-Path $patched '7bd755be8ba5171f40812b455a8a4ff1.bundle'), $true)
[long]$titleOffset = 0; [long]$titleSize = 0
$bundle.file.GetFileRange(1, [ref]$titleOffset, [ref]$titleSize)
if ($titleSize -ne 65536) { throw "Patched title texture size is $titleSize" }
$bundle.file.DataReader.Position = $titleOffset
[byte[]]$embeddedTitle = $bundle.file.DataReader.ReadBytes([int]$titleSize)
$expectedTitleHash = (Get-FileHash -LiteralPath (Join-Path $ProjectRoot 'analysis\poc\GameTitleLogo-Korean.rgba32') -Algorithm SHA256).Hash
$actualTitleHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($embeddedTitle))
if ($actualTitleHash -ne $expectedTitleHash) { throw 'Patched title texture hash mismatch' }
$manager.UnloadAll($true)

$eventTranslations = Get-Content -LiteralPath (Join-Path $ProjectRoot 'translations\main_event_ko.json') -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
$manager = New-Manager
$bundle = $manager.LoadBundleFile((Join-Path $patched 'a83647f242c8e97a23ee6bcd801cb623.bundle'), $true)
$assets = $manager.LoadAssetsFileFromBundle($bundle, 0, $false)
$info = $assets.file.GetAssetInfo([long]-158109455917131333)
$field = $manager.GetBaseField($assets, $info, [AssetsTools.NET.Extra.AssetReadFlags]::None)
$eventValues = $field['texts']['values']['Array'].Children
if ($eventValues.Count -ne 1411) { throw "Patched MainEvent count is $($eventValues.Count)" }
foreach ($item in $eventTranslations.GetEnumerator()) {
    if ($eventValues[[int]$item.Key].AsString -ne [string]$item.Value) {
        throw "Patched MainEvent mismatch: $($item.Key)"
    }
}
$manager.UnloadAll($true)

$manager = [AssetsTools.NET.Extra.AssetsManager]::new()
$bundle = $manager.LoadBundleFile((Join-Path $patched '11ee4a0ca6d5e27a4192b31f12d7b10a.bundle'), $true)
$entryName = $bundle.file.GetFileName(1)
[long]$offset = 0; [long]$size = 0
$bundle.file.GetFileRange(1, [ref]$offset, [ref]$size)
if ($size -ne 12582912) { throw "Patched atlas entry size is $size" }
$reader = $bundle.file.DataReader
$reader.Position = $offset
[byte[]]$embeddedAtlas = $reader.ReadBytes([int]$size)
$expectedHash = (Get-FileHash -LiteralPath (Join-Path $ProjectRoot 'analysis\poc\JapaneseFontAtlas-Korean-PoC.rgb24') -Algorithm SHA256).Hash
$actualHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($embeddedAtlas))
if ($actualHash -ne $expectedHash) { throw 'Patched atlas entry hash mismatch' }
$manager.UnloadAll($true)

$manager = New-Manager
$bundle = $manager.LoadBundleFile((Join-Path $patched 'b79bff27dd04232ee4d7bc9d1c2236b8.bundle'), $true)
$assets = $manager.LoadAssetsFileFromBundle($bundle, 0, $false)
$info = $assets.file.GetAssetInfo([long]-8455639814239168238)
$field = $manager.GetBaseField($assets, $info, [AssetsTools.NET.Extra.AssetReadFlags]::None)
$translations = Get-Content -LiteralPath (Join-Path $ProjectRoot 'translations\system_text_ko.json') -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
foreach ($item in $translations.GetEnumerator()) {
    if ($field[$item.Key].AsString -ne [string]$item.Value) {
        throw "Patched SystemText mismatch: $($item.Key)"
    }
}
$languageName = $field['LanguageName'].AsString
$fromStart = $field['FromStart'].AsString
$manager.UnloadAll($true)

[ordered]@{
    FontBytes = $fontSize
    GlyphCount = $glyphCount
    AtlasEntry = $entryName
    AtlasBytes = $size
    AtlasSHA256 = $actualHash
    LanguageName = $languageName
    FromStart = $fromStart
    TranslatedFields = $translations.Count
    MainEventTranslatedLines = $eventTranslations.Count
    TitleTextureBytes = $titleSize
    TitleTextureSHA256 = $actualTitleHash
} | ConvertTo-Json
