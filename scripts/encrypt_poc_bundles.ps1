param(
    [Parameter(Mandatory=$true)][string]$ProjectRoot,
    [string]$InputDir,
    [string]$OutputDir
)
$ErrorActionPreference = 'Stop'
$managed = Join-Path $ProjectRoot 'work\game\Glow Box_Data\Managed'
$lz4Dir = Join-Path $ProjectRoot 'analysis\poc\patched_decrypted_lz4'
if ([string]::IsNullOrEmpty($InputDir)) {
    $InputDir = if (Test-Path -LiteralPath $lz4Dir) { $lz4Dir } else {
        Join-Path $ProjectRoot 'analysis\poc\patched_decrypted'
    }
}
if ([string]::IsNullOrEmpty($OutputDir)) {
    $OutputDir = Join-Path $ProjectRoot 'analysis\poc\patched_encrypted'
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$encAssembly = [Reflection.Assembly]::LoadFrom(
    (Join-Path $managed 'com.voidd0g.unity_utilities.libraries.encryption.dll'))
$gameAssembly = [Reflection.Assembly]::LoadFrom(
    (Join-Path $managed 'voidd0g.GlowMachine.Runtime.dll'))
$streamType = $encAssembly.GetType('voidd0g.UnityUtilities.Libraries.Encryption.SeekableAesStream', $true)
$parametersType = $gameAssembly.GetType('voidd0g.GlowMachine.Persistent.GameEncryptionParameters', $true)
$passwordProperty = $parametersType.GetProperty(
    'CombinedPassword', [Reflection.BindingFlags]'Public,NonPublic,Static')
$combinedPassword = [string]$passwordProperty.GetValue($null)
if ([string]::IsNullOrEmpty($combinedPassword)) { throw 'Game encryption password could not be obtained' }

foreach ($input in Get-ChildItem -LiteralPath $InputDir -Filter '*.bundle') {
    $output = Join-Path $OutputDir $input.Name
    [byte[]]$salt = [Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFileNameWithoutExtension($input.Name))
    $source = [IO.File]::OpenRead($input.FullName)
    $target = [IO.File]::Open($output, [IO.FileMode]::Create, [IO.FileAccess]::ReadWrite)
    $cipher = [Activator]::CreateInstance($streamType, @($target, $combinedPassword, $salt, [int]1024))
    $source.CopyTo($cipher)
    $cipher.Flush()
    $cipher.Dispose()
    $source.Dispose()
    $target.Dispose()

    # The cipher is seekable and symmetric: decrypt the new file and compare it byte-for-byte.
    $encrypted = [IO.File]::OpenRead($output)
    $decrypt = [Activator]::CreateInstance($streamType, @($encrypted, $combinedPassword, $salt, [int]1024))
    $roundTrip = [IO.MemoryStream]::new()
    $decrypt.CopyTo($roundTrip)
    [byte[]]$roundTripBytes = $roundTrip.ToArray()
    $roundTrip.Dispose()
    $decrypt.Dispose()
    $encrypted.Dispose()
    [byte[]]$plainBytes = [IO.File]::ReadAllBytes($input.FullName)
    $plainHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($plainBytes))
    $roundTripHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($roundTripBytes))
    if ($plainBytes.Length -ne $roundTripBytes.Length -or $plainHash -ne $roundTripHash) {
        throw "Encryption round-trip failed for $($input.Name)"
    }
    [ordered]@{
        File = $input.Name
        Bytes = $plainBytes.Length
        SHA256 = $plainHash
        RoundTrip = 'OK'
    } | ConvertTo-Json -Compress
}
