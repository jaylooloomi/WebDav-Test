param(
    [string]$DataPath = "D:\WebDavShare"
)

Write-Host "=== IIS WebDAV Setup ===" -ForegroundColor Green

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: Must run as Administrator!" -ForegroundColor Red
    exit 1
}

# Step 1: Enable IIS Features
Write-Host "`nStep 1: Enabling IIS WebDAV features..." -ForegroundColor Cyan
$features = @(
    "IIS-WebServer",
    "IIS-WebServerRole", 
    "IIS-WebServerManagementTools",
    "IIS-ManagementConsole",
    "IIS-StaticContent",
    "IIS-DefaultDocument",
    "IIS-WebDAV",
    "IIS-WebDAVPublishing"
)

foreach ($feature in $features) {
    Enable-WindowsOptionalFeature -FeatureName $feature -Online -NoRestart -ErrorAction SilentlyContinue | Out-Null
}
Write-Host "  OK: IIS features enabled" -ForegroundColor Green

# Step 2: Create folder
Write-Host "`nStep 2: Creating WebDAV folder at $DataPath" -ForegroundColor Cyan
if (-not (Test-Path $DataPath)) {
    New-Item -ItemType Directory -Path $DataPath -Force | Out-Null
}
Write-Host "  OK: Folder ready" -ForegroundColor Green

# Create test file
$testFile = Join-Path $DataPath "2023_002.docx"
if (-not (Test-Path $testFile)) {
    "Test document" | Out-File $testFile -Encoding UTF8
}
Write-Host "  OK: Test file created at $testFile" -ForegroundColor Green

# Step 3: Configure IIS
Write-Host "`nStep 3: Configuring IIS website..." -ForegroundColor Cyan
Import-Module WebAdministration

$siteName = "WebDavSite"
$site = Get-IISSite -Name $siteName -ErrorAction SilentlyContinue
if ($null -eq $site) {
    New-IISSite -Name $siteName -BindingInformation "*:8081:" -PhysicalPath $DataPath -Protocol http | Out-Null
    Write-Host "  OK: Website created on Port 8081" -ForegroundColor Green
} else {
    Write-Host "  OK: Website already exists" -ForegroundColor Green
}

# Step 4: Configure WebDAV
Write-Host "`nStep 4: Configuring WebDAV..." -ForegroundColor Cyan
$sitePath = "IIS:\Sites\$siteName"

Set-WebConfigurationProperty -PSPath $sitePath -Filter "system.webServer/webdav/authoring" -Name "enabled" -Value $true
Write-Host "  OK: WebDAV enabled" -ForegroundColor Green

Set-WebConfigurationProperty -PSPath $sitePath -Filter "system.webServer/security/authentication/anonymousAuthentication" -Name "enabled" -Value $true
Write-Host "  OK: Anonymous auth enabled" -ForegroundColor Green

# Step 5: Set permissions
Write-Host "`nStep 5: Setting folder permissions..." -ForegroundColor Cyan
$acl = Get-Acl $DataPath
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "IIS_IUSRS",
    "FullControl",
    "ContainerInherit,ObjectInherit",
    "None",
    "Allow"
)
$acl.AddAccessRule($rule)
Set-Acl -Path $DataPath -AclObject $acl
Write-Host "  OK: Permissions set" -ForegroundColor Green

# Step 6: Restart IIS
Write-Host "`nStep 6: Restarting IIS..." -ForegroundColor Cyan
iisreset /restart
Write-Host "  OK: IIS restarted" -ForegroundColor Green

Write-Host "`n=== Setup Complete ===" -ForegroundColor Green
Write-Host "WebDAV folder: $DataPath" -ForegroundColor Yellow
Write-Host "Test URL: http://localhost:8081/" -ForegroundColor Yellow
Write-Host "`nNext: Run 02-verify-webdav.ps1 to test" -ForegroundColor Cyan
