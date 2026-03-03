using Microsoft.AspNetCore.Mvc;
using OnlyOfficeAPI.Models.Wopi;
using System;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace OnlyOfficeAPI.Controllers
{
    /// <summary>
    /// WOPI (Web Open Platform Interface) 控制器
    /// 用于处理 Microsoft Office Online Server (OOS) 的文件操作请求
    /// 规范: https://docs.microsoft.com/en-us/microsoft-365/cloud-storage-partner-program/online/build-wopi-host
    /// </summary>
    [ApiController]
    [Route("wopi")]
    public class WopiController : ControllerBase
    {
        private readonly string _wopiFilePath = "C:\\WopiFiles";
        private readonly ILogger<WopiController> _logger;

        public WopiController(ILogger<WopiController> logger)
        {
            _logger = logger;
        }

        /// <summary>
        /// 第一步：CheckFileInfo (GET)
        /// OOS 调用此端点来获取文件的基本信息
        /// 路由: GET /wopi/files/{fileId}
        /// </summary>
        [HttpGet("files/{fileId}")]
        public async Task<IActionResult> CheckFileInfo(string fileId)
        {
            try
            {
                // 构建完整的文件路径
                var filePath = Path.Combine(_wopiFilePath, fileId);
                
                _logger.LogInformation($"CheckFileInfo: 查找文件 {filePath}");

                // 检查文件是否存在
                if (!System.IO.File.Exists(filePath))
                {
                    _logger.LogWarning($"CheckFileInfo: 文件不存在 {filePath}");
                    return NotFound(new { error = "File not found" });
                }

                // 获取文件信息
                var fileInfo = new FileInfo(filePath);

                var wopiFileInfo = new WopiFileInfo
                {
                    BaseFileName = fileInfo.Name,
                    OwnerId = "admin",
                    Size = fileInfo.Length,
                    UserId = "user@example.com",
                    Version = fileInfo.LastWriteTime.Ticks.ToString(),
                    UserCanWrite = true,        // 允许用户编辑
                    SupportsUpdate = true,      // 支持 PutFile 保存
                    ReadOnly = false
                };

                // 使用 camelCase JSON 反序列化选项
                var options = new JsonSerializerOptions
                {
                    PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                    WriteIndented = true
                };

                _logger.LogInformation($"CheckFileInfo: 成功返回文件信息, 大小: {wopiFileInfo.Size} 字节");
                return Ok(wopiFileInfo);
            }
            catch (Exception ex)
            {
                _logger.LogError($"CheckFileInfo 错误: {ex.Message}");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        /// <summary>
        /// 第二步：GetFile (GET)
        /// OOS 调用此端点来下载文件内容用于编辑
        /// 路由: GET /wopi/files/{fileId}/contents
        /// </summary>
        [HttpGet("files/{fileId}/contents")]
        public async Task<IActionResult> GetFile(string fileId)
        {
            try
            {
                var filePath = Path.Combine(_wopiFilePath, fileId);

                _logger.LogInformation($"GetFile: 读取文件 {filePath}");

                if (!System.IO.File.Exists(filePath))
                {
                    _logger.LogWarning($"GetFile: 文件不存在 {filePath}");
                    return NotFound();
                }

                // 读取文件内容并返回为文件流
                var fileStream = System.IO.File.OpenRead(filePath);
                var fileName = Path.GetFileName(filePath);

                _logger.LogInformation($"GetFile: 成功加载文件 {fileName}");
                
                return File(fileStream, "application/octet-stream", fileName);
            }
            catch (Exception ex)
            {
                _logger.LogError($"GetFile 错误: {ex.Message}");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        /// <summary>
        /// 第三步：PutFile (POST) - 关键的保存操作
        /// OOS 调用此端点来保存用户编辑后的文件内容回服务器
        /// 路由: POST /wopi/files/{fileId}/contents
        /// 
        /// 这是«编辑完同步回 Server»的核心实现
        /// </summary>
        [HttpPost("files/{fileId}/contents")]
        public async Task<IActionResult> PutFile(string fileId)
        {
            try
            {
                // 检查 WOPI 覆盖头 (可选但推荐)
                if (Request.Headers.TryGetValue("X-WOPI-Override", out var wopiOverride))
                {
                    if (wopiOverride != "PUT")
                    {
                        _logger.LogWarning($"PutFile: 无效的 X-WOPI-Override 值: {wopiOverride}");
                        return BadRequest(new { error = "Invalid X-WOPI-Override header" });
                    }
                }

                var filePath = Path.Combine(_wopiFilePath, fileId);

                _logger.LogInformation($"PutFile: 保存文件 {filePath}");

                // 确保目录存在
                Directory.CreateDirectory(_wopiFilePath);

                // 从请求体读取二进制数据
                using (var stream = new MemoryStream())
                {
                    await Request.Body.CopyToAsync(stream);
                    var fileContent = stream.ToArray();

                    // 覆盖现有文件
                    await System.IO.File.WriteAllBytesAsync(filePath, fileContent);

                    _logger.LogInformation($"PutFile: 文件已成功保存, 大小: {fileContent.Length} 字节");
                }

                return Ok(new { status = "success", message = "File saved successfully" });
            }
            catch (Exception ex)
            {
                _logger.LogError($"PutFile 错误: {ex.Message}");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        /// <summary>
        /// 文件上传端点
        /// 用户在 OnlyOffice 中编辑完文件后，可以下载文件然后通过此端点上传回服务器
        /// 路由: POST /wopi/upload
        /// </summary>
        [HttpPost("upload")]
        public async Task<IActionResult> Upload([FromQuery] string fileName)
        {
            try
            {
                if (string.IsNullOrEmpty(fileName))
                {
                    return BadRequest(new { error = "fileName query parameter is required" });
                }

                var filePath = Path.Combine(_wopiFilePath, fileName);

                _logger.LogInformation($"Upload: 接收文件上传 {filePath}");

                // 确保目录存在
                Directory.CreateDirectory(_wopiFilePath);

                // 从请求体读取二进制数据
                using (var stream = new MemoryStream())
                {
                    await Request.Body.CopyToAsync(stream);
                    var fileContent = stream.ToArray();

                    if (fileContent.Length == 0)
                    {
                        return BadRequest(new { error = "File content is empty" });
                    }

                    // 保存文件
                    await System.IO.File.WriteAllBytesAsync(filePath, fileContent);

                    _logger.LogInformation($"Upload: 文件已成功保存, 大小: {fileContent.Length} 字节");
                }

                return Ok(new { 
                    status = "success", 
                    message = "File uploaded and saved successfully",
                    fileName = fileName,
                    filePath = filePath
                });
            }
            catch (Exception ex)
            {
                _logger.LogError($"Upload 错误: {ex.Message}");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        /// <summary>
        /// 健康检查端点
        /// </summary>
        [HttpGet("health")]
        public IActionResult Health()
        {
            return Ok(new { status = "WOPI API is running" });
        }
    }
}
