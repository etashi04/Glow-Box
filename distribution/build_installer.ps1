param(
    [Parameter(Mandatory=$true)][string]$PayloadDir,
    [Parameter(Mandatory=$true)][string]$OutputPath
)
$ErrorActionPreference = 'Stop'
$csc = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path -LiteralPath $csc)) { throw 'Windows C# compiler was not found.' }
$source = Join-Path $PSScriptRoot 'GlowBoxKoreanPatchInstaller.cs'
$names = @(
    '11ee4a0ca6d5e27a4192b31f12d7b10a.bundle',
    '4acc258f619ac06b664ed91b69b7f2a1.bundle',
    '7bd755be8ba5171f40812b455a8a4ff1.bundle',
    'a83647f242c8e97a23ee6bcd801cb623.bundle',
    'b79bff27dd04232ee4d7bc9d1c2236b8.bundle'
)
$resourceArgs = foreach ($name in $names) {
    $path = Join-Path $PayloadDir $name
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing payload: $name" }
    "/resource:$path,GlowBox.Payload.$name"
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
& $csc /nologo /target:winexe /platform:x64 /optimize+ `
    /reference:System.dll /reference:System.Core.dll /reference:System.Drawing.dll `
    /reference:System.Windows.Forms.dll /out:$OutputPath $source $resourceArgs
if ($LASTEXITCODE -ne 0) { throw "Compiler failed with exit code $LASTEXITCODE" }
Write-Output "Built: $OutputPath"
