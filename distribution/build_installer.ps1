param(
    [Parameter(Mandatory=$true)][string]$PayloadDir,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [Parameter(Mandatory=$true)][string]$ManifestPath
)
$ErrorActionPreference = 'Stop'
$csc = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path -LiteralPath $csc)) { throw 'Windows C# compiler was not found.' }
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$names = @($manifest.bundles | ForEach-Object { $_.name })
if (-not $manifest.patchVersion -or -not $manifest.gameBuild -or $names.Count -eq 0) { throw 'Invalid release manifest.' }
$escape = { param($value) ([string]$value).Replace('\','\\').Replace('"','\"') }
$arrayLines = $names | ForEach-Object { '        "' + (& $escape $_) + '"' }
$hashLines = $manifest.bundles | ForEach-Object { '        { "' + (& $escape $_.name) + '", "' + $_.originalSha256 + '" }' }
$patchedHashLines = $manifest.bundles | ForEach-Object { '        { "' + (& $escape $_.name) + '", "' + $_.patchedSha256 + '" }' }
$configuration = "private static readonly string[] BundleNames = {`r`n" + ($arrayLines -join ",`r`n") + "`r`n    };`r`n    private static readonly Dictionary<string, string> OriginalHashes = new Dictionary<string, string> {`r`n" + ($hashLines -join ",`r`n") + "`r`n    };`r`n    private static readonly Dictionary<string, string> PatchedHashes = new Dictionary<string, string> {`r`n" + ($patchedHashLines -join ",`r`n") + "`r`n    };"
$template = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'GlowBoxKoreanPatchInstaller.cs') -Raw
$generatedSource = $template.Replace('__PATCH_VERSION__', (& $escape $manifest.patchVersion)).Replace('__GAME_BUILD__', (& $escape $manifest.gameBuild)).Replace('__BUNDLE_CONFIGURATION__', $configuration)
$source = Join-Path ([IO.Path]::GetTempPath()) ("GlowBoxInstaller_" + [guid]::NewGuid().ToString('N') + '.cs')
[IO.File]::WriteAllText($source, $generatedSource, [Text.UTF8Encoding]::new($false))
$resourceArgs = foreach ($name in $names) {
    $path = Join-Path $PayloadDir $name
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing payload: $name" }
    "/resource:$path,GlowBox.Payload.$name"
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
try {
    & $csc /nologo /target:winexe /platform:x64 /optimize+ `
        /reference:System.dll /reference:System.Core.dll /reference:System.Drawing.dll `
        /reference:System.Windows.Forms.dll /out:$OutputPath $source $resourceArgs
    if ($LASTEXITCODE -ne 0) { throw "Compiler failed with exit code $LASTEXITCODE" }
} finally { Remove-Item -LiteralPath $source -Force -ErrorAction SilentlyContinue }
Write-Output "Built: $OutputPath"
