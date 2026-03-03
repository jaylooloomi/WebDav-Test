var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// 启用 CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// 启用默认文件（将 / 映射到 index.html）
app.UseDefaultFiles();

// 启用静态文件（用于 index.html）
app.UseStaticFiles();

// 删除 HTTPS 重定向（开发阶段）
// app.UseHttpsRedirection();

// 使用 CORS
app.UseCors("AllowAll");

// 映射 Controllers
app.MapControllers();

app.Run();

