# WebDAV 本機驗證設定完成 ✅

## 📊 架設進度總結

| 項目 | 狀態 | URL | 備註 |
|------|------|-----|------|
| **IIS WebDAV 伺服器** | ✅ 已啟用 | `http://localhost:8081` | Port 8081，D:\WebDavShare |
| **測試檔案** | ✅ 已建立 | 2023_002.docx | 位於 D:\WebDavShare |
| **HTTP 下載** | ✅ 驗證成功 | GET /2023_002.docx | 返回 HTTP 200 |
| **WebDAV 基礎功能** | ✅ 可用 | OPTIONS 方法 | 基本支援 |
| **Nginx 反代配置** | 📝 範本已建立 | Port 88 | 需手動配置 |
| **Word 測試連結** | 📄 已建立 | test-webdav-word.html | ms-word:ofe 協議 |

---

## 🚀 下一步：完整驗證流程

### Step 1: 驗證本機 WebDAV 可下載
```powershell
# 測試檔案下載
Invoke-WebRequest -Uri "http://localhost:8081/2023_002.docx" -OutFile "C:\Test\downloaded.docx"
```

### Step 2: 開啟 Word 測試頁面
1. **在瀏覽器打開：**
   ```
   file:///D:/git/webdav/test-webdav-word.html
   ```

2. **點擊連結之一：**
   - ▶ `用 Word 開啟 (localhost:8081)` - 直接連線到 IIS
   - ▶ `用 Word 開啟 (localhost:88)` - 經 Nginx 反代（需配置）
   - ▶ `用 Word 開啟 (192.168.2.76:88)` - 跨機器測試（需配置）

3. **編輯和儲存**
   - 在 Word 中修改文檔內容
   - 按 Ctrl+S 儲存
   - 觀察是否成功同步

### Step 3: 確認檔案同步
```powershell
# 檢查檔案修改時間
Get-ChildItem "D:\WebDavShare\2023_002.docx" -Force | 
  Select-Object Name, LastWriteTime, Length
```

---

## 📋 資源位置清單

| 項目 | 路徑 |
|------|-----|
| **WebDAV 資料夾** | `D:\WebDavShare\` |
| **IIS 日誌** | `C:\inetpub\logs\LogFiles\W3SVC1\` |
| **安裝腳本** | `D:\git\webdav\01-install-webdav-simple.ps1` |
| **驗證腳本** | `D:\git\webdav\02-verify-webdav-simple.ps1` |
| **測試頁面** | `D:\git\webdav\test-webdav-word.html` |
| **Nginx 配置** | `D:\git\webdav\nginx-webdav-server.conf` |
| **說明文檔** | `D:\git\webdav\README.md` |

---

## ⚙️ 手動配置項目（如需進階功能）

### 啟用 WebDAV 寫入支援
```powershell
# 編輯 D:\WebDavShare\web.config（已預先配置，無需修改）
# 或在 IIS 管理器中：
# 1. 選擇 "WebDavSite"
# 2. 雙擊 "WebDAV Authoring Rules"
# 3. 在右側面板按 "Enable WebDAV"
```

### 配置 Nginx 反向代理（下一步）
```nginx
# 將以下配置添加至 nginx.conf
upstream webdav_backend {
    server localhost:8081;
}

server {
    listen 88;
    location /WebDav/ {
        proxy_pass http://webdav_backend/;
        proxy_buffering off;
        # 更多設定見 nginx-webdav-server.conf
    }
}
```

---

## 🔧 故障排除

### Word 無法開啟連結
- ✅ 確認 Word 已安裝
- ✅ 檢查防火牆是否擋住 Port 8081
- ✅ 嘗試在 Word 中手動 File > Open > 粘貼 URL

### 檔案無法儲存
- ✅ 檢查 D:\WebDavShare 的權限（IIS_IUSRS 應有完整控制）
- ✅ 查看 IIS 日誌是否有錯誤
- ✅ 確認磁碟空間充足

### 連接被拒
- ✅ 驗證 IIS 網站狀態：`Get-IISSite -Name "WebDavSite"`
- ✅ 重啟 IIS：`iisreset /restart`
- ✅ 檢查 Port 是否被佔用：`netstat -ano | findstr :8081`

---

## 📝 測試記錄

**測試日期：** 2026-03-02  
**IIS WebDAV 狀態：** ✅ 運行中  
**網站名稱：** WebDavSite  
**監聽 Port：** 8081  
**分享目錄：** D:\WebDavShare  
**測試檔案：** 2023_002.docx (18 bytes)  

---

## 🎯 驗證檢查清單

在啟動完整測試前，確認以下項目：

- [ ] IIS 網站 "WebDavSite" 狀態為 **Started**（已驗證 ✅）
- [ ] 檔案 `D:\WebDavShare\2023_002.docx` 存在（已驗證 ✅）
- [ ] HTTP GET 請求返回 HTTP 200（已驗證 ✅）
- [ ] Word 已安裝
- [ ] 防火牆允許 localhost:8081 連線
- [ ] （可選）Nginx 已配置並監聽 Port 88

---

## 🎬 快速開始

```powershell
# 1. 驗證 WebDAV 狀態
powershell -NoProfile -ExecutionPolicy RemoteSigned -Command "D:\git\webdav\02-verify-webdav-simple.ps1"

# 2. 開啟測試 HTML 頁面
start file:///D:/git/webdav/test-webdav-word.html

# 3. 點擊連結在 Word 中打開文檔
# 預期：Word 開啟 2023_002.docx 檔案

# 4. 編輯並儲存，驗證同步
```

---

## 📞 後續支援

如需配置：
- **Nginx 反向代理** → 參考 `README.md` 第二步
- **HTTPS/TLS** → 需額外 SSL 證書配置
- **Windows 認證** → 需 Active Directory 域環境
- **版本控制** → 需要 WebDAV 與 Git 集成

---

**系統已就緒，可開始驗證！** 🚀
