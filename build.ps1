$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPath = Join-Path $projectRoot 'DibujovichScreen.ps1'
$source = [System.IO.File]::ReadAllText($scriptPath)
$match = [regex]::Match($source, '(?s)\$source = @''\r?\n(.*?)\r?\n''@')
if (-not $match.Success) { throw 'No se encontró el código C# en DibujovichScreen.ps1.' }

$buildDir = Join-Path $projectRoot 'obj'
$distDir = Join-Path $projectRoot 'dist'
[System.IO.Directory]::CreateDirectory($buildDir) | Out-Null
[System.IO.Directory]::CreateDirectory($distDir) | Out-Null
$csPath = Join-Path $buildDir 'DibujovichScreen.cs'
$exePath = Join-Path $distDir 'DibujovichScreen.exe'
[System.IO.File]::WriteAllText($csPath, $match.Groups[1].Value, [System.Text.Encoding]::UTF8)

$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw 'Falta el compilador de .NET Framework 4.' }
& $compiler /nologo /target:winexe /platform:anycpu /optimize+ /out:$exePath /reference:System.Windows.Forms.dll /reference:System.Drawing.dll $csPath
if ($LASTEXITCODE -ne 0) { throw "La compilación falló: código $LASTEXITCODE" }

Get-Item -LiteralPath $exePath | Select-Object FullName, Length, LastWriteTime
