# WebDAV Verification Script
param(
    [string]$WebDavUrl = "http://localhost:8081",
    [string]$TestFileName = "2023_002.docx"
)

Write-Host "=== WebDAV Verification Started ===" -ForegroundColor Green

# Test OPTIONS
Write-Host "`n[1/5] Testing OPTIONS..." -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri $WebDavUrl -Method OPTIONS -ErrorAction Stop
    Write-Host "   OPTIONS Success (HTTP $($response.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "   OPTIONS Failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test PROPFIND
Write-Host "`n[2/5] Testing PROPFIND..." -ForegroundColor Cyan
$propfindXml = '<?xml version="1.0" encoding="UTF-8"?><propfind xmlns="DAV:"><prop><displayname/><resourcetype/><getcontentlength/><getlastmodified/></prop></propfind>'
try {
    $headers = @{ "Content-Type" = "application/xml"; "Depth" = "0" }
    $response = Invoke-WebRequest -Uri $WebDavUrl -Method PROPFIND -Body $propfindXml -Headers $headers -ErrorAction Stop
    Write-Host "   PROPFIND Success (HTTP $($response.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "   PROPFIND Failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test LOCK
Write-Host "`n[3/5] Testing LOCK..." -ForegroundColor Cyan
$fileUrl = "$WebDavUrl/$TestFileName"
$lockXml = '<?xml version="1.0" encoding="UTF-8"?><lockinfo xmlns="DAV:"><lockscope><exclusive/></lockscope><locktype><write/></locktype><owner><href>http://localhost/user</href></owner></lockinfo>'

try {
    $headers = @{ "Content-Type" = "application/xml"; "Depth" = "0"; "Timeout" = "Second-3600" }
    $response = Invoke-WebRequest -Uri $fileUrl -Method LOCK -Body $lockXml -Headers $headers -ErrorAction Stop
    Write-Host "   LOCK Success (HTTP $($response.StatusCode))" -ForegroundColor Green
    $lockToken = $response.Headers["Lock-Token"]
    
    # Test PUT
    Write-Host "`n[4/5] Testing PUT..." -ForegroundColor Cyan
    try {
        $putHeaders = @{ "If" = "<$fileUrl> $lockToken" }
        $testContent = [System.Text.Encoding]::UTF8.GetBytes("Test at $(Get-Date)")
        $response = Invoke-WebRequest -Uri $fileUrl -Method PUT -Body $testContent -Headers $putHeaders -ErrorAction Stop
        Write-Host "   PUT Success (HTTP $($response.StatusCode))" -ForegroundColor Green
    } catch {
        Write-Host "   PUT Failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Test UNLOCK
    Write-Host "`n[5/5] Testing UNLOCK..." -ForegroundColor Cyan
    try {
        $unlockHeaders = @{ "Lock-Token" = $lockToken }
        $response = Invoke-WebRequest -Uri $fileUrl -Method UNLOCK -Headers $unlockHeaders -ErrorAction Stop
        Write-Host "   UNLOCK Success (HTTP $($response.StatusCode))" -ForegroundColor Green
    } catch {
        Write-Host "   UNLOCK Failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   LOCK Failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== WebDAV Verification Complete ===" -ForegroundColor Green
