param(
    [string]$GodotPath = "D:\funny\Godot_latest_version\Godot_console.exe"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ExportPath = Join-Path $ProjectRoot "docs\index.html"
$ExportDirectory = Split-Path -Parent $ExportPath
$ProjectAppData = Join-Path $ProjectRoot ".validation-appdata"
$ExpectedGodotVersion = "4.7.1.stable"
$TemplateDirectory = Join-Path $ProjectAppData "Godot\export_templates\$ExpectedGodotVersion"

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "找不到 Godot console executable：$GodotPath"
}

$ActualGodotVersion = (& $GodotPath --version).Trim()
if ($LASTEXITCODE -ne 0 -or -not $ActualGodotVersion.StartsWith($ExpectedGodotVersion)) {
    throw "Godot 版本不符：預期 $ExpectedGodotVersion，實際 $ActualGodotVersion"
}

$RequiredTemplates = @("web_nothreads_debug.zip", "web_nothreads_release.zip")
$MissingTemplates = @(
    $RequiredTemplates | Where-Object {
        -not (Test-Path -LiteralPath (Join-Path $TemplateDirectory $_) -PathType Leaf)
    }
)
if ($MissingTemplates.Count -gt 0) {
    throw "找不到 Godot $ExpectedGodotVersion Web export template：$($MissingTemplates -join ', ')"
}

New-Item -ItemType Directory -Force -Path $ExportDirectory | Out-Null

$PreviousAppData = $env:APPDATA
try {
    $env:APPDATA = $ProjectAppData
    & $GodotPath --headless --path $ProjectRoot --export-release Web $ExportPath
    if ($LASTEXITCODE -ne 0) {
        throw "Godot Web 匯出失敗，exit code：$LASTEXITCODE"
    }
}
finally {
    $env:APPDATA = $PreviousAppData
}

Set-Content -LiteralPath (Join-Path $ExportDirectory ".nojekyll") -Value "" -NoNewline
Write-Host "Web export ready: $ExportPath"
