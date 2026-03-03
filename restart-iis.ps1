# 重启 IIS 以使 WebDAV 配置生效
$ErrorActionPreference = "Stop"

Write-Host "🔄 正在重启 IIS 服务..." -ForegroundColor Cyan

try {
    # 方法 1: 尝试使用 iisreset
    iisreset /restart
    Write-Host "✅ IIS 已重启，WebDAV 配置生效" -ForegroundColor Green
    Start-Sleep -Seconds 3
    
    # 测试 WebDAV
    Write-Host "`n🧪 测试 WebDAV 连接..." -ForegroundColor Yellow
    $response = Invoke-WebRequest -Uri "http://localhost:8081/2023_002.docx" -UseBasicParsing -ErrorAction SilentlyContinue
    
    if ($response -and $response.StatusCode -eq 200) {
        Write-Host "✅✅✅ WebDAV 完全可用！" -ForegroundColor Green
        Write-Host "文件大小: $($response.RawContentLength) 字节" -ForegroundColor Green
        Write-Host "`n📌 现在可以使用以下 URL:" -ForegroundColor Cyan
        Write-Host "ms-word:ofe|u|http://localhost:8081/2023_002.docx" -ForegroundColor Yellow
    } else {
        Write-Host "⚠️ WebDAV 仍无法访问，可能需要检查 IIS 日志" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "❌ 错误: $_" -ForegroundColor Red
    Write-Host "请确保以管理员身份运行此脚本" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n✅ 操作完成" -ForegroundColor Green
