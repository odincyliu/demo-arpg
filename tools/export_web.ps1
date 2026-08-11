$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $projectRoot '.tools\godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe'
$outputDir = Join-Path $projectRoot 'docs'
$outputFile = Join-Path $outputDir 'index.html'
$logFile = Join-Path $projectRoot '.tools\web-export.log'

if (-not (Test-Path -LiteralPath $godot)) {
    throw "找不到專案內 Godot：$godot"
}

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

& $godot `
    --headless `
    --path $projectRoot `
    --log-file $logFile `
    --export-release 'Web' `
    $outputFile

if ($LASTEXITCODE -ne 0) {
    throw "Godot Web export 失敗。請檢查：$logFile"
}

New-Item -ItemType File -Path (Join-Path $outputDir '.nojekyll') -Force | Out-Null
Write-Host "Web export 完成：$outputFile"

