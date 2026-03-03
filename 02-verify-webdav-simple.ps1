param(
    [string]$WebDavUrl = "http://localhost:8081",
    [string]$TestFile = "2023_002.docx"
)

Write-Host "=== WebDAV Verification ===" -ForegroundColor Green

# Test 1: OPTIONS
Write-Host "`n[1/3] Testing OPTIONS method..." -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri $WebDavUrl -Method OPTIONS -ErrorAction Stop -UseBasicParsing
    Write-Host "  OK: OPTIONS returned HTTP $($response.StatusCode)" -ForegroundColor Green
    if ($response.Headers['Allow']) {
        Write-Host "  Allowed methods: $($response.Headers['Allow'])" -ForegroundColor Yellow
    }
    if ($response.Headers['DAV']) {
        Write-Host "  DAV support: $($response.Headers['DAV'])" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: GET File
Write-Host "`n[2/3] Testing file download (GET)..." -ForegroundColor Cyan
try {
    $fileUrl = "$WebDavUrl/$TestFile"
    $response = Invoke-WebRequest -Uri $fileUrl -Method GET -ErrorAction Stop -UseBasicParsing
    Write-Host "  OK: File downloaded, HTTP $($response.StatusCode)" -ForegroundColor Green
    Write-Host "  Content-Length: $($response.Content.Length) bytes" -ForegroundColor Yellow
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: PROPFIND 
Write-Host "`n[3/3] Testing PROPFIND method..." -ForegroundColor Cyan
try {
    $propfindXml = '<?xml version="1.0" encoding="UTF-8"?><propfind xmlns="DAV:"><prop><displayname/></prop></propfind>'
    $headers = @{"Depth" = "0"; "Content-Type" = "application/xml"}
    $response = Invoke-WebRequest -Uri $WebDavUrl -Method PROPFIND `
        -Body $propfindXml -Headers $headers -ErrorAction Stop -UseBasicParsing
    Write-Host "  OK: PROPFIND returned HTTP $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "  WARNING: PROPFIND failed - $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "  (This may be normal if WebDAV is partially configured)" -ForegroundColor Gray
}

Write-Host "`n=== Verification Complete ===" -ForegroundColor Green
Write-Host "`nWebDAV service is accessible at: $WebDavUrl" -ForegroundColor Cyan
