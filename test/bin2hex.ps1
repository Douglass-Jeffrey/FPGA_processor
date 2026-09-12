# Converts a little-endian raw binary (from `objcopy -O binary`) into a
# $readmemh-compatible hex file: one 32-bit word per line, e.g.
#   .\bin2hex.ps1 prog.bin program.hex
param(
    [Parameter(Mandatory=$true)][string]$InFile,
    [Parameter(Mandatory=$true)][string]$OutFile
)

$bytes = [IO.File]::ReadAllBytes($InFile)
if ($bytes.Length % 4 -ne 0) {
    $pad = 4 - ($bytes.Length % 4)
    $bytes += ,([byte]0) * $pad
}
$lines = for ($i = 0; $i -lt $bytes.Length; $i += 4) {
    $w = [uint32]$bytes[$i] -bor ([uint32]$bytes[$i+1] -shl 8) `
         -bor ([uint32]$bytes[$i+2] -shl 16) -bor ([uint32]$bytes[$i+3] -shl 24)
    "{0:x8}" -f $w
}
Set-Content -Path $OutFile -Value $lines -Encoding ascii
Write-Host "wrote $($lines.Count) words to $OutFile"
