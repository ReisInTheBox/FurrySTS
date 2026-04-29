param(
    [string]$GodotPath = "G:\Godot\Godot.exe",
    [string]$ProjectPath = $PSScriptRoot,
    [switch]$Editor,
    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $GodotPath)) {
    Write-Error "Godot executable not found: $GodotPath"
    exit 1
}

if (-not (Test-Path -LiteralPath (Join-Path $ProjectPath "project.godot"))) {
    Write-Error "Project path does not contain project.godot: $ProjectPath"
    exit 1
}

$argsList = @("--path", $ProjectPath)
if ($Editor) {
    $argsList = @("--editor") + $argsList
}
if ($CheckOnly) {
    $argsList = @("--headless", "--check-only") + $argsList
}

Write-Host "[RUN] Godot: $GodotPath"
Write-Host "[RUN] Project: $ProjectPath"
Write-Host "[RUN] Args: $($argsList -join ' ')"

& $GodotPath @argsList
exit $LASTEXITCODE
