# IIS WebDAV 安裝與設定腳本
# 需要系統管理員權限執行
# 用途：啟用 IIS、WebDAV、設定資料夾共享

param(
    [string]$DataPath = "D:\WebDavShare"
)

Write-Host "=== IIS WebDAV 安裝開始 ===" -ForegroundColor Green

# 檢查管理員權限
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "錯誤：必須用系統管理員權限執行此腳本！" -ForegroundColor Red
    exit 1
}

# Step 1: 啟用 IIS 功能
Write-Host "`n[1/4] 啟用 IIS 與 WebDAV 功能..." -ForegroundColor Cyan
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
    Write-Host "  啟用 $feature..." -ForegroundColor Gray
    Enable-WindowsOptionalFeature -FeatureName $feature -Online -NoRestart -ErrorAction SilentlyContinue | Out-Null
}

# Step 2: 建立資料夾
Write-Host "`n[2/4] 建立 WebDAV 資料夾：$DataPath" -ForegroundColor Cyan
if (-not (Test-Path $DataPath)) {
    New-Item -ItemType Directory -Path $DataPath -Force | Out-Null
    Write-Host "  ✓ 資料夾已建立" -ForegroundColor Green
} else {
    Write-Host "  ✓ 資料夾已存在" -ForegroundColor Green
}

# 建立測試檔案
Write-Host "  建立測試 .docx 檔案..." -ForegroundColor Gray
$testDocPath = "$DataPath\2023_002.docx"
if (-not (Test-Path $testDocPath)) {
    # 創建簡單的文字檔案作為佔位符
    # 實際 DOCX 可由腳本執行後手動放置或下載範本
    "This is a test document for WebDAV synchronization." | Out-File $testDocPath -Encoding UTF8
    Write-Host "  ✓ 測試檔案已建立 (placeholder)" -ForegroundColor Green
    Write-Host "  注意: 建議用 Word 建立真實 .docx 檔案放至此位置" -ForegroundColor Yellow
}

# Step 3: 建立 IIS 網站
Write-Host "`n[3/4] 設定 IIS 網站..." -ForegroundColor Cyan

Import-Module WebAdministration

$siteName = "WebDavSite"
$siteBinding = "http/*:8081:*"

# 檢查網站是否存在
$site = Get-IISSite -Name $siteName -ErrorAction SilentlyContinue
if ($null -eq $site) {
    Write-Host "  建立新網站：$siteName (Port 8081)..." -ForegroundColor Gray
    New-IISSite -Name $siteName -BindingInformation "*:8081:" -PhysicalPath $DataPath -Protocol http | Out-Null
    Write-Host "  ✓ 網站已建立" -ForegroundColor Green
} else {
    Write-Host "  ✓ 網站已存在" -ForegroundColor Green
}

# Step 4: 設定 WebDAV 屬性
Write-Host "`n[4/4] 設定 WebDAV 權限..." -ForegroundColor Cyan

# 啟用 WebDAV 發佈
$sitePath = "IIS:\Sites\$siteName"
try {
    Set-WebConfigurationProperty -PSPath $sitePath -Filter "system.webServer/webdav/authoring" -Name "enabled" -Value $true
    Write-Host "  ✓ WebDAV 發佈已啟用" -ForegroundColor Green
} catch {
    Write-Host "  ⚠ WebDAV 設定步驟可能需手動完成" -ForegroundColor Yellow
}

# 設定匿名存取（簡易模式） 或 Windows 認證
try {
    Set-WebConfigurationProperty -PSPath $sitePath -Filter "system.webServer/security/authentication/anonymousAuthentication" -Name "enabled" -Value $true
    Write-Host "  ✓ 匿名認證已啟用" -ForegroundColor Green
} catch {
    Write-Host "  ⚠ 認證設定可能需手動調整" -ForegroundColor Yellow
}

# 設定檔案夾權限（給 IIS_IUSRS 完整權限）
Write-Host "`n[額外] 設定檔案系統權限..." -ForegroundColor Cyan
try {
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
    Write-Host "  ✓ IIS_IUSRS 權限已設定" -ForegroundColor Green
} catch {
    Write-Host "  ⚠ 檔案權限設定失敗，請手動檢查" -ForegroundColor Yellow
}

# 重啟 IIS
Write-Host "`n重啟 IIS 服務..." -ForegroundColor Cyan
iisreset /restart
Write-Host "  ✓ IIS 已重啟" -ForegroundColor Green

Write-Host "`n=== IIS WebDAV 安裝完成 ===" -ForegroundColor Green
Write-Host "網站位置: $DataPath" -ForegroundColor Yellow
Write-Host "本機 WebDAV URL: http://localhost:8081/WebDav/" -ForegroundColor Yellow
Write-Host "IP 存取 URL: http://localhost:8081/2023_002.docx" -ForegroundColor Yellow
Write-Host "`n下一步：執行 02-verify-webdav.ps1 進行驗證" -ForegroundColor Cyan
