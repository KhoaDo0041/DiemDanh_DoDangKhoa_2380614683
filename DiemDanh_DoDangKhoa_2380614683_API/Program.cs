using DiemDanh_DoDangKhoa_2380614683_API.Data;
using DiemDanh_DoDangKhoa_2380614683_API.Models;
using DiemDanh_DoDangKhoa_2380614683_API.Services;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;
using System.Text;

// ===== Web API ĐIỂM DANH SINH VIÊN - Đỗ Đăng Khoa - 2380614683 =====
var builder = WebApplication.CreateBuilder(args);

// PostgreSQL (Supabase)
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

// Identity: tài khoản + vai trò + bộ tạo mã OTP (AddDefaultTokenProviders)
builder.Services.AddIdentity<AppUser, IdentityRole>(o =>
    {
        o.User.RequireUniqueEmail = true;
        o.Password.RequiredLength = 6;
        // Nhập sai mật khẩu / OTP / khuôn mặt 5 lần -> khóa 5 phút
        o.Lockout.MaxFailedAccessAttempts = 5;
        o.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(5);
    })
    .AddEntityFrameworkStores<AppDbContext>()
    .AddDefaultTokenProviders();

builder.Services.AddScoped<TokenService>();
builder.Services.AddScoped<EmailService>();

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

// Swagger + nút Authorize để dán token (cú pháp Swashbuckle 10.x)
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "DiemDanh_DoDangKhoa_2380614683_API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        Description = "Dán token nhận được sau khi verify-otp (không cần chữ Bearer)"
    });
    c.AddSecurityRequirement(document => new OpenApiSecurityRequirement
    {
        [new OpenApiSecuritySchemeReference("Bearer", document)] = []
    });
});

builder.Services.AddCors(o => o.AddPolicy("AllowAll", p => p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

// JWT
var jwt = builder.Configuration.GetSection("JWTKey");
builder.Services.AddAuthentication(o =>
    {
        o.DefaultAuthenticateScheme = "Bearer";
        o.DefaultChallengeScheme = "Bearer";
        o.DefaultScheme = "Bearer";
    })
    .AddJwtBearer("Bearer", o =>
    {
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwt["ValidIssuer"],
            ValidAudience = jwt["ValidAudience"],
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt["Secret"]!)),
            ClockSkew = TimeSpan.FromMinutes(1)
        };
    });
builder.Services.AddAuthorization();

// /api/health -> kiểm tra server còn sống (dùng khi đưa lên Conveyor)
builder.Services.AddHealthChecks();

var app = builder.Build();

// Tự tạo database + dữ liệu mẫu
await DbSeeder.SeedAsync(app.Services);

// Bật Swagger cả trên Render để thầy cô / nhóm thử API; vào "/" tự chuyển sang Swagger
app.UseSwagger();
app.UseSwaggerUI();
app.MapGet("/", () => Results.Redirect("/swagger")).ExcludeFromDescription();

// Tắt để máy ảo gọi được http://10.0.2.2:5080 (Conveyor vẫn có https riêng)
// app.UseHttpsRedirection();

app.UseCors("AllowAll");
app.UseAuthentication();
app.UseAuthorization();

app.MapHealthChecks("/api/health");
app.MapControllers();

app.Run();
