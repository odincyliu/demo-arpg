$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $projectRoot '.tools\godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe'

if (-not (Test-Path -LiteralPath $godot)) {
    throw "找不到專案內 Godot：$godot"
}

& $godot `
    --headless `
    --path $projectRoot `
    --log-file (Join-Path $projectRoot '.tools\combat-tests.log') `
    --script 'res://tests/run_tests.gd'
exit $LASTEXITCODE

