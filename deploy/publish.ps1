# PetGuardian — Windows publish script (build -> upload -> switch).
#
# Usage:
#   .\deploy\publish.ps1 -Host <ec2-public-dns-or-ip> [-User ubuntu] [-KeyFile <path-to.pem>]
#
# What it does:
#   1. flutter build web --release
#   2. uploads build\web to /tmp/petguardian-next on the server (scp -C, compressed)
#   3. ssh's in to run server-deploy.sh (atomic symlink swap + nginx reload + smoke check)
#
# Requires: Flutter on PATH (or -FlutterBat), OpenSSH scp/ssh (built into Win10+).

param(
    [Parameter(Mandatory = $true)][string]$Host,
    [string]$User = 'ubuntu',
    [string]$KeyFile = '',
    [string]$FlutterBat = 'C:\Users\deli\flutter\bin\flutter.bat',
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
# PowerShell 5.1 pipes strings to native stdin using the OEM console code
# page, which mangles UTF-8 Turkish text in the streamed script. Force UTF-8
# so bash receives the file byte-identical.
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ssh = @()
if ($KeyFile) { $ssh += @('-i', $KeyFile) }
$target = "$User@$Host"

if (-not $SkipBuild) {
    Write-Host '==> flutter build web --release'
    & $FlutterBat build web --release
    if ($LASTEXITCODE -ne 0) { throw "build failed (exit $LASTEXITCODE)" }
}

$dist = Join-Path $ProjectRoot 'build\web'
if (-not (Test-Path (Join-Path $dist 'index.html'))) { throw "missing $dist\index.html" }

Write-Host "==> uploading $dist -> ${target}:/tmp/petguardian-next"
# Windows scp.exe does NOT expand local wildcards (build\web\* would be sent
# literally and fail), so upload the 'web' directory as a whole and rename it
# on the server. Stale staging dirs are removed first so server-deploy.sh can
# never mix old and new files.
& ssh @ssh $target 'rm -rf /tmp/petguardian-next /tmp/web'
if ($LASTEXITCODE -ne 0) { throw "ssh cleanup failed (exit $LASTEXITCODE)" }

& scp -r @ssh $dist "${target}:/tmp/"
if ($LASTEXITCODE -ne 0) { throw "scp failed (exit $LASTEXITCODE)" }

& ssh @ssh $target 'mv /tmp/web /tmp/petguardian-next'
if ($LASTEXITCODE -ne 0) { throw "staging rename failed (exit $LASTEXITCODE)" }

Write-Host '==> switching release on server'
# server-deploy.sh lives in deploy/ of the repo; it may not be on the server
# yet, so stream it over stdin to bash — no git checkout needed on the VM.
# PS 5.1 Get-Content defaults to ANSI (1254 on Turkish Windows), which
# corrupts the UTF-8 script before it even reaches the pipe; read as UTF-8.
$script = Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'server-deploy.sh')
$script | & ssh @ssh $target 'bash -s'
if ($LASTEXITCODE -ne 0) { throw "server deploy failed (exit $LASTEXITCODE)" }

Write-Host ''
Write-Host "LIVE: http://$Host" -ForegroundColor Green
