# Zertifikats-Server - CertEnrollWeb

Hey Gordan! Hier ist dein Zertifikats-Server Setup. Läuft super mit Portainer
und ist perfekt für Windows Server Integration.

## Was macht das Ding?

- **HTTP Server (Port 80):** Öffentlicher Download von Zertifikaten und Sperrlisten
- **WebDAV Server (Port 8080):** Authentifizierter Upload für deine Windows Server

## Portainer Deployment

1. **In Portainer → Stacks → Add Stack**
2. **Name:** `CertEnrollWeb`
3. **Paste diesen Code:**

```yaml
services:
  CertEnrollWeb:
    build:
      context: https://github.com/phily-me/CertEnrollWeb.git  # Dieses git repo
      dockerfile: Dockerfile
    ports:
      - "10080:80"     # HTTP Download (öffentlich)
      - "18080:8080"   # WebDAV Upload (authentifiziert)
    volumes:
      - cert-data:/var/www/CertEnroll
    environment:
      - USER_WEBDAV=${USER_WEBDAV}     # WebDAV Username
      - PASS_WEBDAV=${PASS_WEBDAV}     # WebDAV Passwort
    restart: unless-stopped

volumes:
  cert-data:
```

1. **Environment Variables setzen:**
   - `USER_WEBDAV`: Dein WebDAV Username
   - `PASS_WEBDAV`: Dein WebDAV Passwort

1. **Deploy** klicken - Portainer pullt automatisch aus Git und baut das Image!

## Windows Server Integration

### Port Mapping für deinen Windows Server

**Wichtig:** Ersetze `YOUR-DOCKER-HOST` mit der IP deines Docker/Portainer Servers!

| Service | Docker Port | Windows Zugriff | Zweck |
|---------|------------|-----------------|-------|
| HTTP | 80→10080 | `http://YOUR-DOCKER-HOST:10080/` | Download |
| WebDAV | 8080→18080 | `http://YOUR-DOCKER-HOST:18080/` | Upload |

### Windows PowerShell Upload

```powershell
# === Zertifikate hochladen ===

# === Konfiguration ===
$server = "YOUR-DOCKER-HOST"
$port = 18080
$user = "svc_certenrollweb-webdav"
$pass = "deinpasswort"
$sourceDir = "C:\Windows\System32\certsrv\CertEnroll"
$filePattern = @("*.crt", "*.crl")
$hoursBack = 4  # Upload files modified in the last X hours (0 = alle, die gefunden werden)
$eventLogSource = "ZMT"
$eventLogName = "Application"

# Check if event source exists
$eventSourceExists = $false
try {
    $eventSourceExists = [System.Diagnostics.EventLog]::SourceExists($eventLogSource)
} catch {
    Write-Warning "Cannot check event source existence. Continuing without event logging."
}

# If event source doesn't exist, warn user and exit
if (-not $eventSourceExists) {
    Write-Warning "Event source '$eventLogSource' is not registered."
    Write-Warning "To enable event logging, run as Administrator once:"
    Write-Warning "  New-EventLog -LogName $eventLogName -Source $eventLogSource"
    exit 1
}

# Create credentials
$cred = New-Object System.Management.Automation.PSCredential($user, `
    (ConvertTo-SecureString $pass -AsPlainText -Force))

# Build file filter
$files = Get-ChildItem $sourceDir -Include $filePattern -Recurse

# Apply time filter if hoursBack > 0
if ($hoursBack -gt 0) {
    $cutoffTime = (Get-Date).AddHours(-$hoursBack)
    $files = $files | Where-Object { $_.LastWriteTime -gt $cutoffTime }
    Write-Host "Uploading files modified in the last $hoursBack hours..."
} else {
    Write-Host "Uploading all certificate files..."
}

# Upload files
$successCount = 0
$failCount = 0

foreach ($file in $files) {
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Uploading $($file.Name)..."
    
    try {
        $uri = "http://${server}:${port}/$($file.Name)"
        Invoke-RestMethod -Uri $uri `
            -Method PUT `
            -Credential $cred `
            -InFile $file.FullName `
            -TimeoutSec 30
        
        Write-Host "  ✅ Successfully uploaded $($file.Name)" -ForegroundColor Green
        $successCount++
        
        Write-EventLog -LogName $eventLogName -Source $eventLogSource `
                    -EventId 1 -EntryType Information `
                    -Message "Successfully uploaded $($file.Name) to $uri"        
    } catch {
        Write-Host "  ❌ Failed to upload $($file.Name): $($_.Exception.Message)" `
            -ForegroundColor Red
        $failCount++

        Write-EventLog -LogName $eventLogName -Source $eventLogSource `
                    -EventId 2 -EntryType Error `
                    -Message "Failed to upload $($file.Name): $($_.Exception.Message)"
    }
}

# Summary
Write-Host "`n=== Upload Summary ===" -ForegroundColor Cyan
Write-Host "Total files processed: $($files.Count)"
Write-Host "Successful uploads: $successCount" -ForegroundColor Green
Write-Host "Failed uploads: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })

```

### Als Netzlaufwerk einbinden

```batch
REM WebDAV als Laufwerk Z: mounten  
net use Z: \\YOUR-DOCKER-HOST@18080\DavWWWRoot /user:gordan deinpasswort

REM Dateien kopieren
copy "C:\PKI\*.crt" Z:\
copy "C:\PKI\*.crl" Z:\

REM Laufwerk wieder trennen
net use Z: /delete
```

### Automatisierung mit Scheduled Task

**Erstelle `upload-certs.ps1`:**

```powershell
# Automatischer Upload alle 4 Stunden
$server = "YOUR-DOCKER-HOST"
$sourceDir = "C:\Windows\System32\certsrv\CertEnroll"
$user = "svc_certenrollweb-webdav" 
$pass = "deinpasswort"

$cred = New-Object System.Management.Automation.PSCredential($user, `
  (ConvertTo-SecureString $pass -AsPlainText -Force))

# Upload aller neuen/geänderten Zertifikate
Get-ChildItem "$sourceDir\*.crt", "$sourceDir\*.crl" | `
  Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-4) } | `
  ForEach-Object {
    Write-Host "$(Get-Date) - Uploading $($_.Name)..."
    try {
        Invoke-RestMethod -Uri "http://$server:18080/$($_.Name)" `
          -Method PUT -Credential $cred -InFile $_.FullName
        Write-EventLog -LogName Application -Source "CertUpload" `
          -EventId 1 -Message "Successfully uploaded $($_.Name)"
    } catch {
        Write-EventLog -LogName Application -Source "CertUpload" `
          -EventId 2 -EntryType Error `
          -Message "Failed to upload $($_.Name): $($_.Exception.Message)"
    }
}
```

**Scheduled Task erstellen:**

```cmd
schtasks /create /tn "Zertifikat Upload" ^
  /tr "powershell.exe -ExecutionPolicy Bypass ^
    -File C:\Scripts\upload-certs.ps1" ^
  /sc hourly /it /ru SYSTEM
```

### Using curl (Linux/macOS/Windows)

```bash
# === Download certificates ===
server="YOUR-DOCKER-HOST"

# Single file download
curl -o myfile.crt "http://$server:10080/myfile.crt"

# Download multiple files
for cert in myfile.crt intermediate.crt revocation.crl; do
    echo "Downloading $cert..."
    curl -o "$cert" "http://$server:10080/$cert"
done

# === Upload certificates ===
user="gordan"
pass="securepassword123"

# Single file upload
curl -T myfile.crt "http://$server:18080/myfile.crt" --user "$user:$pass"

# Upload multiple files
for file in *.crt *.crl; do
    if [ -f "$file" ]; then
        echo "Uploading $file..."
        curl -T "$file" "http://$server:18080/$file" --user "$user:$pass"
    fi
done
```

## Download der Zertifikate

### Für Clients/Browser

```text
http://YOUR-DOCKER-HOST:10080/myfile.crt
```

### Windows PowerShell Download

```powershell
# Single Download
Invoke-WebRequest -Uri "http://YOUR-DOCKER-HOST:10080/myfile.crt" -OutFile "C:\Downloads\myfile.crt"

# Bulk Download
$certs = @("myfile.crt", "intermediate.crt", "revocation.crl")
$certs | ForEach-Object {
    Invoke-WebRequest -Uri "http://YOUR-DOCKER-HOST:10080/$_" -OutFile "C:\Downloads\$_"
}
```
