# WebDAV 架設與驗證完整指南

## 📋 目錄
1. [準備工作](#準備工作)
2. [第一步：安裝 IIS WebDAV](#第一步安裝-iis-webdav)
3. [第二步：設定 Nginx 反代](#第二步設定-nginx-反代)
4. [第三步：驗證 WebDAV](#第三步驗證-webdav)
5. [第四步：測試 Word 編輯](#第四步測試-word-編輯)
6. [常見問題](#常見問題)

---

## 準備工作

### 系統需求
- **OS**: Windows 10 / Server 2019 以上
- **軟體**:
  - IIS (via Windows Features)
  - Nginx (下載: https://nginx.org/download/)
  - Microsoft Word
  - PowerShell 5.0+
- **權限**: 需要系統管理員權限執行腳本

### 檔案清單
```
D:\git\webdav\
├── 01-install-webdav.ps1          # IIS 安裝腳本
├── 02-verify-webdav.ps1           # WebDAV 驗證腳本
├── nginx-webdav-server.conf        # Nginx 配置
├── test-webdav-word.html           # Word 連結測試頁面
└── README.md                       # 本檔案
```

---

## 第一步：安裝 IIS WebDAV

### 執行安裝腳本

**方式 1: PowerShell 直接執行**
```powershell
# 打開 PowerShell (以系統管理員身份)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
cd D:\git\webdav\
.\01-install-webdav.ps1
```

**方式 2: 右鍵執行**
1. 右鍵點擊 `01-install-webdav.ps1`
2. 選擇「使用 PowerShell 執行」
3. 如提示執行原則，輸入 `Y` 並按 Enter

### 預期結果
✓ IIS 已啟用  
✓ WebDAV 發佈已啟用  
✓ 網站已建立（Port 8081）  
✓ 測試檔案已建立（D:\WebDavShare\2023_002.docx）  

### 驗證安裝
在瀏覽器打開：
- `http://localhost:8081` - 應該看到 Windows 的目錄列表

---

## 第二步：設定 Nginx 反代

### 安裝 Nginx

1. **下載** Nginx for Windows
   ```
   https://nginx.org/en/download.html
   → 下載最新穩定版（nginx-x.xx.x.zip）
   ```

2. **解壓**
   ```powershell
   # 建議位置
   cd C:\
   Expand-Archive .\nginx-x.xx.x.zip -DestinationPath .\nginx
   cd C:\nginx-x.xx.x
   ```

3. **複製配置**
   ```powershell
   # 將我們的配置複製到 Nginx
   Copy-Item D:\git\webdav\nginx-webdav-server.conf .\conf\
   ```

### 編輯 Nginx 主配置

編輯 `C:\nginx\conf\nginx.conf`，在 `http { ... }` 區塊中添加：

```nginx
http {
    # ... 其他設定 ...
    
    # 包含 WebDAV 配置
    include nginx-webdav-server.conf;
}
```

或直接將 `nginx-webdav-server.conf` 的內容複製到 `nginx.conf` 中。

### 啟動 Nginx

```powershell
# 在 C:\nginx 目錄
.\nginx.exe

# 驗證啟動（應該看不到輸出，表示成功）
# 檢查 Port 88 是否監聽
netstat -ano | findstr :88
```

### 測試 Nginx 連線
在瀏覽器打開：
- `http://localhost:88/WebDav/`
- `http://192.168.2.76:88/WebDav/`

應該能看到與 `http://localhost:8081` 相同的目錄列表

---

## 第三步：驗證 WebDAV

### 執行驗證腳本

```powershell
cd D:\git\webdav\
.\02-verify-webdav.ps1
```

### 預期輸出
```
=== WebDAV 驗證開始 ===
目標 URL: http://localhost:8081

[1/5] 檢測 OPTIONS（可用方法）...
  ✓ OPTIONS 成功 (HTTP 200)
  允許的方法: GET,HEAD,POST,PUT,DELETE,OPTIONS,PROPFIND,PROPPATCH,MKCOL,COPY,MOVE,LOCK,UNLOCK

[2/5] 檢測 PROPFIND（查詢資源）...
  ✓ PROPFIND 成功 (HTTP 207)

[3/5] 檢測 LOCK（檔案鎖定）...
  ✓ LOCK 成功 (HTTP 200)
  Lock Token: ...

[4/5] 檢測 PUT（上傳修改）...
  ✓ PUT 成功 (HTTP 204)

[5/5] 檢測 UNLOCK（解除鎖定）...
  ✓ UNLOCK 成功 (HTTP 204)
```

### 常見驗證問題

| 問題 | 原因 | 解決方案 |
|------|------|---------|
| OPTIONS 失敗 (404/500) | IIS 未啟用 WebDAV | 重新執行 01-install-webdav.ps1 |
| PROPFIND 失敗 | Nginx 擋了方法 | 檢查 nginx.conf 中 proxy_method |
| LOCK 失敗 | 檔案不存在 | 確保 D:\WebDavShare\2023_002.docx 存在 |
| PUT/UNLOCK 失敗 | 權限問題 | 檢查 D:\WebDavShare 的 IIS_IUSRS 權限 |

---

## 第四步：測試 Word 編輯

### 方法 1：用 HTML 連結（推薦）

1. 在瀏覽器打開：
   ```
   file:///D:/git/webdav/test-webdav-word.html
   ```

2. 在頁面上點擊對應的連結，例如：
   - **本機測試**: `▶ 用 Word 開啟 (localhost:8081)`
   - **Nginx 反代**: `▶ 用 Word 開啟 (localhost:88)`
   - **IP 地址**: `▶ 用 Word 開啟 (192.168.2.76:88)`

3. Word 應該自動開啟檔案

### 方法 2：直接粘貼 URI

在 Word 中：
1. File > Open
2. 粘貼以下任一 URL：
   ```
   http://localhost:8081/2023_002.docx
   http://localhost:88/WebDav/2023_002.docx
   http://192.168.2.76:88/WebDav/2023_002.docx
   ```

### 編輯與同步驗證

1. **打開文件** - Word 應正常開啟
2. **修改內容** - 編輯文件中的文字
3. **儲存文件** - Ctrl+S
4. **確認同步**:
   - 查看 IIS 日誌（`C:\inetpub\logs\LogFiles`）
   - 應該看到 `PUT` 或 `LOCK/UNLOCK` 請求
   - 檔案時間戳應更新

5. **再次下載** - 用不同方式下載檔案，確認修改已保存

### 多客戶端測試（可選）

在另一台電腦：
1. 打開 URL: `http://192.168.2.76:88/WebDav/2023_002.docx`
2. 同時修改同一檔案
3. 觀察 WebDAV 的衝突處理（通常鎖定或提示覆蓋）

---

## 常見問題

### Q1: 連結無法開啟 Word
**症狀**: 點擊連結沒有反應

**解決**:
1. 確保 Word 已安裝
2. 檢查檔案關聯：`assoc .docx` 應顯示 `Word.Document.12`
3. 嘗試手動在 Word 中開啟（File > Open）
4. 檢查防火牆是否擋了連線

### Q2: 認證失敗（無法開啟）
**症狀**: 彈出認證對話框

**解決**:
1. 在腳本中修改：`Set-WebConfigurationProperty -PSPath $sitePath -Filter "system.webServer/security/authentication/anonymousAuthentication" -Name "enabled" -Value $true`
2. 或使用 Windows 驗證（需要相同域或信任設定）

### Q3: 修改未同步到 WebDAV
**症狀**: Word 儲存成功，但檔案未更新

**解決**:
1. 檢查 Nginx 日誌：`C:\nginx\logs\error.log`
2. 確認 Nginx 設定有包含 `proxy_buffering off`
3. 檢查 WebDAV 日誌：IIS > Logging
4. 驗證 PUT 請求是否成功（應為 HTTP 204/200）

### Q4: Nginx 啟動失敗
**症狀**: 執行 `nginx.exe` 無反應或馬上退出

**解決**:
```powershell
# 檢查配置語法
C:\nginx\nginx.exe -t

# 查看詳細錯誤
C:\nginx\nginx.exe -T

# Port 被佔用
netstat -ano | findstr :88
```

### Q5: WebDAV LOCK 導致檔案鎖定
**症狀**: 多人同時編輯時收到檔案被鎖定的提示

**說明**: 這是正常行為，表示 WebDAV LOCK 生效  
**處理**: 
- 關首個編輯的 Word（解除鎖定）
- 或等待鎖定逾時（預設 1 小時）
- 或用 UNLOCK 命令（見 02-verify-webdav.ps1）

---

## 📊 架構圖

```
┌─────────────────────────────────────┐
│ 用戶電腦 / 其他機器                   │
│ (192.168.2.76 同一網段)              │
└──────────────┬──────────────────────┘
               │
        ┌──────▼───────┐
        │  Internet    │
        │  Network     │
        └──────┬───────┘
               │
        ┌──────▼──────────────┐
        │  Nginx Reverse      │ (Port 88)
        │  Proxy Server       │
        │  192.168.2.76:88    │
        └──────┬──────────────┘
               │
        ┌──────▼──────────────┐
        │ Localhost NIC        │
        │ 127.0.0.1:8081      │
        └──────┬──────────────┘
               │
        ┌──────▼──────────────┐
        │ IIS WebDAV Server   │
        │ Port 8081           │
        │ D:\WebDavShare      │
        └─────────────────────┘

Word Client  ────→  PUT/LOCK/UNLOCK  ──→  Nginx  ──→  IIS  ──→  Storage
                   (ms-word:ofe protocol)
```

---

## 📝 後續步驟

- [ ] 執行 `01-install-webdav.ps1` 安裝
- [ ] 設定 Nginx 反代
- [ ] 執行 `02-verify-webdav.ps1` 驗證
- [ ] 打開 `test-webdav-word.html` 測試連結
- [ ] 編輯文件並確認同步
- [ ] （可選）配置 HTTPS/TLS
- [ ] （可選）配置域控認證

## 🆘 需要幫助?

檢查清單：
- [ ] IIS 已啟用並運行
- [ ] WebDAV 模組已啟用
- [ ] Nginx 已配置並運行
- [ ] 防火牆允許 Port 88（Nginx）
- [ ] Word 已安裝

如有問題，查看日誌：
- **IIS 日誌**: `C:\inetpub\logs\LogFiles\W3SVC1`
- **Nginx 日誌**: `C:\nginx\logs\error.log`
- **Windows 事件檢視器**: Event Viewer > Windows Logs > Application

---

*Document created: 2026-03-02*  
*WebDAV Setup Guide by GitHub Copilot*
