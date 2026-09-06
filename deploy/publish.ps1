# Creates publish/ folder + inventoryinonetap-deploy.zip for EC2
# Excludes: node_modules, .git, dist, backend/.env
# Run from PawanPutra:
#   .\deploy\publish.ps1

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

$publishDir = Join-Path $root "publish"
$outZip = Join-Path $root "inventoryinonetap-deploy.zip"

Write-Host "Packaging from: $root"

if (Test-Path $publishDir) { Remove-Item $publishDir -Recurse -Force }
if (Test-Path $outZip) { Remove-Item $outZip -Force }

New-Item -ItemType Directory -Path $publishDir | Out-Null

$excludeDirs = @('node_modules', '.git', 'dist', 'publish')
$excludeFiles = @('.env', 'inventoryinonetap-deploy.zip')

function Copy-ProjectTree {
    param([string]$Source, [string]$Dest)
    Get-ChildItem -Path $Source -Force | ForEach-Object {
        if ($_.PSIsContainer) {
            if ($excludeDirs -contains $_.Name) { return }
            $target = Join-Path $Dest $_.Name
            New-Item -ItemType Directory -Path $target -Force | Out-Null
            Copy-ProjectTree -Source $_.FullName -Dest $target
        } else {
            if ($excludeFiles -contains $_.Name) { return }
            Copy-Item $_.FullName -Destination $Dest
        }
    }
}

Copy-ProjectTree -Source $root -Dest $publishDir

# Ensure .env.example is present for server setup reference
$envExample = Join-Path $root "backend\.env.example"
if (Test-Path $envExample) {
    Copy-Item $envExample -Destination (Join-Path $publishDir "backend\.env.example") -Force
}

Compress-Archive -Path "$publishDir\*" -DestinationPath $outZip -Force

Write-Host ""
Write-Host "Publish folder: $publishDir"
Write-Host "Zip created:    $outZip"
Write-Host ""
Write-Host "Upload zip:"
Write-Host "  scp -i your-key.pem `"$outZip`" ec2-user@13.205.231.60:~/"
Write-Host ""
Write-Host "On EC2:"
Write-Host "  sudo unzip -o ~/inventoryinonetap-deploy.zip -d /opt/inventoryinonetap"
Write-Host "  sudo chown -R ec2-user:ec2-user /opt/inventoryinonetap"
Write-Host "  cd /opt/inventoryinonetap && bash deploy/install-https.sh"
