namespace OnlyOfficeAPI.Models.Wopi
{
    /// <summary>
    /// WOPI 文件信息模型，符合 Microsoft WOPI 规范
    /// https://docs.microsoft.com/en-us/microsoft-365/cloud-storage-partner-program/online/build-wopi-host
    /// </summary>
    public class WopiFileInfo
    {
        /// <summary>
        /// 文件的基本名称 (不包含路径)
        /// </summary>
        public string BaseFileName { get; set; }

        /// <summary>
        /// 文件所有者的用户 ID
        /// </summary>
        public string OwnerId { get; set; }

        /// <summary>
        /// 文件大小 (字节)
        /// </summary>
        public long Size { get; set; }

        /// <summary>
        /// 当前用户的 ID
        /// </summary>
        public string UserId { get; set; }

        /// <summary>
        /// 文件版本号
        /// </summary>
        public string Version { get; set; }

        /// <summary>
        /// 当前用户是否可以写入
        /// </summary>
        public bool UserCanWrite { get; set; }

        /// <summary>
        /// 服务器是否支持 PutFile 操作
        /// </summary>
        public bool SupportsUpdate { get; set; }

        /// <summary>
        /// 文件是否为只读
        /// </summary>
        public bool ReadOnly { get; set; }
    }
}
