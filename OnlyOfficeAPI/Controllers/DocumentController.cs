using Microsoft.AspNetCore.Mvc;
using System.Text.Json;

namespace OnlyOfficeAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class DocumentController : ControllerBase
    {
        // 使用你原本在 IIS 设定的实体路径
        private readonly string _basePath = @"D:\WebDavShare";

        [HttpGet("fetch/{fileName}")]
        public IActionResult FetchFile(string fileName)
        {
            var filePath = Path.Combine(_basePath, fileName);
            if (!System.IO.File.Exists(filePath)) 
                return NotFound(new { error = "File not found" });

            var bytes = System.IO.File.ReadAllBytes(filePath);
            // 回传正确的 Office MIME Type 避免内容空白
            return File(bytes, "application/vnd.openxmlformats-officedocument.wordprocessingml.document", fileName);
        }

        [HttpPost("callback")]
        public async Task<IActionResult> Callback([FromBody] JsonElement body)
        {
            try
            {
                var jsonString = body.GetRawText();
                System.Console.WriteLine($"\n[Callback] ======== 收到 OnlyOffice 回調請求 ========");
                System.Console.WriteLine($"[Callback] 完整數據: {jsonString}");
                
                // 獲取 status 代碼
                int statusCode = -1;
                if (body.TryGetProperty("status", out var status))
                {
                    statusCode = status.GetInt32();
                    System.Console.WriteLine($"[Callback] Status 代碼: {statusCode}");
                }
                
                // status 2: 文件已准备好可以保存（用户关闭编辑器 10 秒后）
                // status 6: 强制保存（用户点击保存按钮）
                if (statusCode == 2 || statusCode == 6)
                {
                    System.Console.WriteLine($"[Callback] ✓ 檢測到狀態 {statusCode} - 準備保存文件");
                    
                    if (body.TryGetProperty("url", out var urlElement))
                    {
                        var downloadUrl = urlElement.GetString();
                        System.Console.WriteLine($"[Callback] 原始 URL: {downloadUrl}");
                        
                        // 修复 URL 格式
                        if (!string.IsNullOrEmpty(downloadUrl))
                        {
                            // 如果 URL 没有协议，添加 http://
                            if (!downloadUrl.StartsWith("http://") && !downloadUrl.StartsWith("https://"))
                            {
                                downloadUrl = "http://" + downloadUrl;
                            }
                            
                            System.Console.WriteLine($"[Callback] 修正後的 URL: {downloadUrl}");
                            
                            try
                            {
                                using (var httpClient = new HttpClient())
                                {
                                    httpClient.Timeout = TimeSpan.FromSeconds(30);
                                    System.Console.WriteLine($"[Callback] 開始下載檔案...");
                                    var fileBytes = await httpClient.GetByteArrayAsync(downloadUrl);
                                    System.Console.WriteLine($"[Callback] ✓ 下載成功，大小: {fileBytes.Length} 字節");

                                    var savePath = Path.Combine(_basePath, "2023_002.docx");
                                    await System.IO.File.WriteAllBytesAsync(savePath, fileBytes);
                                    System.Console.WriteLine($"[Callback] ✓✓✓ 檔案已保存到: {savePath}");
                                    System.Console.WriteLine($"[Callback] 檔案修改時間: {System.IO.File.GetLastWriteTime(savePath)}");
                                    System.Console.WriteLine($"[Callback] ======== 保存完成 ========\n");
                                    
                                    return Ok(new { error = 0 });
                                }
                            }
                            catch (Exception downloadEx)
                            {
                                System.Console.WriteLine($"[Callback] ✗ 下載異常: {downloadEx.GetType().Name}");
                                System.Console.WriteLine($"[Callback] 錯誤訊息: {downloadEx.Message}");
                                System.Console.WriteLine($"[Callback] 堆棧追蹤: {downloadEx.StackTrace}");
                                System.Console.WriteLine($"[Callback] ======== 保存失敗 ========\n");
                                return Ok(new { error = 0 }); // 仍然返回 0 以避免 OnlyOffice 重试
                            }
                        }
                        else
                        {
                            System.Console.WriteLine($"[Callback] ✗ URL 為空");
                        }
                    }
                    else
                    {
                        System.Console.WriteLine($"[Callback] ✗ JSON 中找不到 url 欄位");
                    }
                }
                else
                {
                    System.Console.WriteLine($"[Callback] ℹ 狀態 {statusCode} - 不需要保存（通常是編輯中）");
                    System.Console.WriteLine($"[Callback] ======== 忽略此請求 ========\n");
                }
                
                return Ok(new { error = 0 });
            }
            catch (Exception ex)
            {
                System.Console.WriteLine($"[Callback] ✗ 主異常: {ex.Message}");
                System.Console.WriteLine($"[Callback] 異常類型: {ex.GetType().Name}");
                System.Console.WriteLine($"[Callback] ======== 處理失敗 ========\n");
                return Ok(new { error = 0 });
            }
        }
    }
}
