$ErrorActionPreference = "Stop"

param(
    [string]$GodotPath = "godot4",
    [string]$ProjectPath = "G:\FurrySTS"
)

Write-Host "[SMOKE] Using Godot command: $GodotPath"
Write-Host "[SMOKE] Project path: $ProjectPath"

if ($GodotPath -eq "godot4") {
    try {
        & godot4 --version | Out-Null
    } catch {
        Write-Error "godot4 not found. Pass -GodotPath `"C:\path\to\Godot_v4.x-stable_win64.exe`""
        exit 1
    }
}

& $GodotPath --headless --path $ProjectPath --quit

if ($LASTEXITCODE -ne 0) {
    Write-Error "Godot headless smoke failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host "[SMOKE] Completed."
