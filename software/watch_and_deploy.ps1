# Lumina Auto-Deploy Watcher
# This script monitors your lib folder AND esp32_firmware folder.
# It automatically syncs ESP32 code into the app and deploys to Firebase.

$libPath = ".\lib"
$espPath = ".\esp32_firmware"

# Watcher for Dart files
$dartWatcher = New-Object IO.FileSystemWatcher $libPath, "*.dart"
$dartWatcher.IncludeSubdirectories = $true
$dartWatcher.EnableRaisingEvents = $true

# Watcher for ESP32 files
$espWatcher = New-Object IO.FileSystemWatcher $espPath, "*.ino"
$espWatcher.EnableRaisingEvents = $true

Write-Host "🚀 Lumina Sync & Deploy is WATCHING for changes..." -ForegroundColor Cyan

function Update-EspCodeInApp {
    param($inoFile)
    Write-Host "🔄 Syncing ESP32 code to App..." -ForegroundColor Cyan
    $content = Get-Content $inoFile -Raw
    # Escape single quotes and backslashes for Dart raw string
    $content = $content.Replace("'", "''")
    $dartFileContent = "const String esp32Code = r'''$content''';"
    Set-Content -Path ".\lib\esp_code.dart" -Value $dartFileContent
    Write-Host "✅ lib/esp_code.dart updated." -ForegroundColor Green
}

$action = {
    $path = $Event.SourceEventArgs.FullPath
    $name = $Event.SourceEventArgs.Name
    $changeType = $Event.SourceEventArgs.ChangeType
    
    Write-Host "⚡ Change detected: $name ($changeType)" -ForegroundColor Yellow

    if ($name -like "*.ino") {
        Update-EspCodeInApp -inoFile $path
    }
    
    Write-Host "📦 Building Flutter Web..." -ForegroundColor White
    flutter build web --release
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "🌐 Deploying to Firebase..." -ForegroundColor Green
        firebase deploy --only hosting
    } else {
        Write-Host "❌ Build failed. Fix errors to deploy." -ForegroundColor Red
    }
    
    Write-Host "👀 Waiting for next change..." -ForegroundColor Cyan
}

Register-ObjectEvent $dartWatcher "Changed" -Action $action
Register-ObjectEvent $espWatcher "Changed" -Action $action
Register-ObjectEvent $espWatcher "Created" -Action $action

while ($true) { sleep 5 }
