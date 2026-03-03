# OnlyOffice 文档编辑系统 - 解决方案总结

## 📋 项目概述

**目标**：用 OnlyOffice 替代失败的 WebDAV 方案，实现浏览器内编辑 Word 文档并自动保存到本地

**技术栈**：
- 后端: ASP.NET Core 8.0 Web API (端口 5001)
- 编辑器: OnlyOffice Document Server 容器 (端口 8080)
- 前端: HTML5 + OnlyOffice JavaScript SDK
- 存储: `D:\WebDavShare\`
- 宿主机 IP: `192.168.137.1`

---

## 🔧 关键修正清单

### 1️⃣ **网络绑定配置 (launchSettings.json)**

**问题**: API 只监听 localhost (127.0.0.1)，Docker 容器无法访问

**文件**: `OnlyOfficeAPI/Properties/launchSettings.json`

```json
❌ 错误配置:
"applicationUrl": "http://localhost:5001"

✅ 正确配置:
"applicationUrl": "http://*:5001"
```

**影响**: 
- 允许容器通过 192.168.137.1:5001 访问 API
- OnlyOffice can reach `/api/document/fetch` 和 `/api/document/callback`

**关键点**: `*` 表示监听所有网卡（所有 IPv4 和 IPv6 地址）

---

### 2️⃣ **OnlyOffice 私有 IP 访问 (容器配置)**

**问题**: OnlyOffice 容器默认不允许访问私有 IP 地址

**文件**: OnlyOffice 容器内 `/etc/onlyoffice/documentserver/default.json`

```json
❌ 错误配置:
"allowPrivateIPAddress": false

✅ 正确配置:
"allowPrivateIPAddress": true
```

**修改步骤**:
```bash
# 进入容器
docker exec -it 91098d2d25b2 bash

# 编辑配置文件
vi /etc/onlyoffice/documentserver/default.json

# 重启容器使配置生效
docker restart 91098d2d25b2
```

**影响**: 容器能够连接到 192.168.137.1:5001 回调接口

---

### 3️⃣ **JavaScript 初始化时序 (index.html)**

**问题**: OnlyOffice SDK 异步加载，保存按钮设置时 docEditor 对象未初始化

**原始错误代码** ❌:
```javascript
document.addEventListener('DOMContentLoaded', () => {
  setupSaveButton();  // docEditor 还未构建
});
```

**修复代码** ✅:
```javascript
window.addEventListener('load', () => {
  // 等待所有资源加载，包括异步 SDK
  const checkEditor = setInterval(() => {
    if (window.docEditor) {
      clearInterval(checkEditor);
      initializeEditor();
    }
  }, 100);
});

// 在 OnlyOffice 编辑器初始化完成后设置按钮
function initializeEditor() {
  window.docEditor.registerCallback((event) => {
    if (event.type === 'onDocumentReady') {
      setupSaveButton();
    }
  });
}
```

**替代方案** (更简洁):
```javascript
// 直接在 onDocumentReady 回调中设置按钮
new DocsAPI.DocEditor("placeholder", {
  // ... 配置
  events: {
    onDocumentReady: () => {
      setupSaveButton();  // 此时 docEditor 已就绪
    }
  }
});
```

**影响**: 保存按钮正确初始化，避免 "Cannot read property of undefined" 错误

---

### 4️⃣ **URL 配置 (index.html)**

**问题**: 前端和后端必须使用一致的 IP 地址

**配置**:
```javascript
const API_HOST = "192.168.137.1";  // 必须用宿主机实际 IP，不能用 localhost
const API_PORT = "5001";

const fetchUrl = `http://${API_HOST}:${API_PORT}/api/document/fetch/2023_002.docx`;
const callbackUrl = `http://${API_HOST}:${API_PORT}/api/document/callback`;
```

**为什么必须用 IP 地址?**
- OnlyOffice 容器运行在 Docker 中，localhost 指向容器内部
- 必须用宿主机 IP (192.168.137.1) 才能访问宿主机 API
- 前端加载 SDK 的 URL: `http://localhost:8080/...` (容器内部网络正常)

---

### 5️⃣ **API 端点实现 (DocumentController.cs)**

#### GET `/api/document/fetch/{fileName}`
```csharp
[HttpGet("fetch/{fileName}")]
public IActionResult FetchDocument(string fileName)
{
    string filePath = Path.Combine(@"D:\WebDavShare", fileName);
    
    if (!System.IO.File.Exists(filePath))
        return NotFound(new { error = "文件未找到" });
    
    var fileBytes = System.IO.File.ReadAllBytes(filePath);
    return File(fileBytes, "application/vnd.openxmlformats-officedocument.wordprocessingml.document");
}
```

**关键点**:
- 返回正确的 MIME 类型: `application/vnd.openxmlformats-officedocument.wordprocessingml.document`
- 文件路径: `D:\WebDavShare\{fileName}`

#### POST `/api/document/callback`
```csharp
[HttpPost("callback")]
public IActionResult DocumentCallback([FromBody] CallbackData data)
{
    // 处理不同的状态码:
    // 1 = 用户正在编辑
    // 2 = 自动保存完成
    // 6 = 用户手动保存
    
    if (data.Status == 2 || data.Status == 6)
    {
        // 下载已编辑的文档
        string downloadUrl = data.Url;
        byte[] editedFile = DownloadFromOnlyOffice(downloadUrl);
        
        // 保存回本地
        string filePath = Path.Combine(@"D:\WebDavShare", data.FileName);
        System.IO.File.WriteAllBytes(filePath, editedFile);
        
        return Ok(new { error = 0 });  // OnlyOffice 期望此响应
    }
    
    return Ok(new { error = 0 });
}
```

---

## 📊 启动流程验证

### 启动顺序:

```
1. 杀死所有现存 dotnet 进程
   └─ taskkill /IM dotnet.exe /F /T

2. 等待端口释放 (3-5 秒)
   └─ Start-Sleep -Seconds 3

3. 启动 API 服务
   └─ cd D:\git\webdav\OnlyOfficeAPI
   └─ dotnet run --no-build

4. 验证监听状态
   └─ netstat -ano | Select-String "5001.*LISTENING"
   
5. 打开浏览器
   └─ http://192.168.137.1:5001
```

### 预期输出:

```
Using launch settings from Properties/launchSettings.json
Now listening on: http://0.0.0.0:5001
Now listening on: http://[::]:5001
Application started. Press Ctrl+C to shut down.
```

### 容器状态验证:

```bash
# 检查 OnlyOffice 容器是否运行
docker ps | grep onlyoffice

# 输出应包含: 91098d2d25b2, port 8080
```

---

## 🐛 常见问题排查

### 问题 1: "地址已在使用" (Address already in use)

**症状**: 
```
System.IO.IOException: Failed to bind to address http://[::]:5001
```

**解决**:
```powershell
# 强制杀死所有 dotnet 进程
taskkill /IM dotnet.exe /F /T

# 等待端口释放
Start-Sleep -Seconds 5

# 验证端口空闲
netstat -ano | Select-String "5001"
# 无输出 = 端口已释放，可启动
```

### 问题 2: OnlyOffice 报错 "Download failed"

**症状**: OnlyOffice 界面显示红色错误

**原因**: 
- 前端使用了 localhost，容器无法访问
- OnlyOffice 容器中的 allowPrivateIPAddress = false

**解决**:
- ✅ 所有 URL 使用宿主机 IP (192.168.137.1)
- ✅ 容器配置 allowPrivateIPAddress = true
- ✅ 重启容器

### 问题 3: 保存按钮不工作

**症状**: 点击按钮无反应，或 console 报错 "docEditor is undefined"

**原因**: JavaScript 在 OnlyOffice SDK 加载完成前运行

**解决**:
- 使用 `window.load` 而非 `DOMContentLoaded`
- 或在 `onDocumentReady` 回调中设置按钮

### 问题 4: API 收不到回调请求

**症状**: 点击保存，文件未更新，API 日志无 "[Callback]" 记录

**原因**:
- OnlyOffice 容器无法连接 API
- callbackUrl 配置错误

**验证**:
```bash
# 从宿主机测试 API
curl http://192.168.137.1:5001/api/document/fetch/2023_002.docx

# 从 OnlyOffice 容器测试
docker exec 91098d2d25b2 curl http://192.168.137.1:5001/api/document/fetch/2023_002.docx
```

---

## 📁 完整文件清单

| 文件路径 | 状态 | 关键修改 |
|---------|------|--------|
| `OnlyOfficeAPI/Properties/launchSettings.json` | ✅ 已修正 | `*:5001` 替代 `localhost:5001` |
| `OnlyOfficeAPI/Controllers/DocumentController.cs` | ✅ 已实现 | fetch & callback 端点 |
| `OnlyOfficeAPI/wwwroot/index.html` | ✅ 已优化 | 使用 192.168.137.1 IP 配置 |
| `OnlyOfficeAPI/Program.cs` | ✅ 已配置 | CORS, DefaultFiles, StaticFiles 中间件 |
| OnlyOffice 容器 `default.json` | ✅ 已修正 | `allowPrivateIPAddress: true` |

---

## 🎯 最终验证清单

```
✅ API 服务启动在 http://0.0.0.0:5001
✅ OnlyOffice 容器运行 (port 8080)
✅ LaunchSettings 监听所有网卡 (*:5001)
✅ OnlyOffice allowPrivateIPAddress = true
✅ 前端 URL 使用 192.168.137.1:5001
✅ JavaScript 正确初始化时序
✅ DocumentController 实现完整
✅ MIMO 类型正确 (.docx)
✅ 文件存储路径有效 (D:\WebDavShare)
```

---

## 🚀 使用步骤

### 1. 启动 API 服务
```powershell
cd D:\git\webdav\OnlyOfficeAPI
dotnet run --no-build
```

### 2. 打开浏览器
```
http://192.168.137.1:5001
```

### 3. 编辑文档
- 等待 OnlyOffice 编辑器加载
- 在文档内添加或修改内容
- 点击绿色 "💾 保存" 按钮

### 4. 验证保存成功
```powershell
# 检查文件修改时间
Get-Item D:\WebDavShare\2023_002.docx | Select-Object FullName, LastWriteTime
```

---

## 📝 技术亮点总结

| 难点 | 解决方案 | 学到的知识 |
|-----|--------|----------|
| Docker 容器访问宿主机 API | 使用宿主机 IP 而非 localhost | 容器网络隔离原理 |
| ASP.NET Core 仅监听 localhost | 修改 launchSettings.json `*:5001` | Kestrel 网络绑定 |
| OnlyOffice 异步 SDK 加载 | window.load + onDocumentReady 回调 | JavaScript 事件顺序 |
| 私有 IP 地址访问限制 | 修改容器配置文件 allowPrivateIPAddress | OnlyOffice 安全策略 |
| 文件实时同步 | 回调机制 + HTTP 下载编辑版本 | 文档协作原理 |

---

**创建日期**: 2026-03-03  
**项目状态**: ✅ 功能运行正常
