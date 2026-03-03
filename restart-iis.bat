@echo off
REM IIS WebDAV 重启脚本 (需要管理员权限)
echo 🔄 正在重启 IIS 服务...
iisreset /restart
echo ✅ IIS 已重启
timeout /t 3 /nobreak
echo.
echo 🧪 测试 WebDAV 连接...
powershell -Command "$response = Invoke-WebRequest -Uri 'http://localhost:8081/2023_002.docx' -UseBasicParsing -ErrorAction SilentlyContinue; if ($response -and $response.StatusCode -eq 200) { Write-Host '✅✅✅ WebDAV 成功!' -ForegroundColor Green; Write-Host \"文件大小: $($response.RawContentLength) 字节\" -ForegroundColor Green; Write-Host 'ms-word:ofe|u|http://localhost:8081/2023_002.docx' -ForegroundColor Yellow } else { Write-Host '❌ WebDAV 仍无法访问' -ForegroundColor Red }"
pause
