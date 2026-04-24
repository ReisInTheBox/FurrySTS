param(
    [string]$GodotPath = "G:\Godot\Godot.exe",
    [string]$ProjectPath = "G:\FurrySTS"
)

$ErrorActionPreference = "Stop"

Write-Host "[SMOKE] Using Godot command: $GodotPath"
Write-Host "[SMOKE] Project path: $ProjectPath"

if ($GodotPath -eq "godot") {
    try {
        & godot --version | Out-Null
    } catch {
        Write-Error "godot not found. Pass -GodotPath `"C:\path\to\Godot_v4.x-stable_win64.exe`""
        exit 1
    }
}

& $GodotPath --headless --path $ProjectPath --quit
$exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }

if ($exitCode -ne 0) {
    Write-Error "Godot headless smoke failed with exit code $exitCode"
    exit $exitCode
}

Write-Host "[SMOKE] Completed."
