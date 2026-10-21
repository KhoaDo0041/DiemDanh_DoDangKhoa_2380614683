using DiemDanh_DoDangKhoa_2380614683_API.Dtos;
using DiemDanh_DoDangKhoa_2380614683_API.Models;
using DiemDanh_DoDangKhoa_2380614683_API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using System.Text.Json;

namespace DiemDanh_DoDangKhoa_2380614683_API.Controllers
{
    /// YÊU CẦU 1 + 2 + 5a:
    ///  - Đăng ký qua email (gửi mã xác nhận về email)
    ///  - Đăng nhập: tên đăng nhập + mật khẩu + OTP gửi qua email
    ///  - Đăng nhập bằng khuôn mặt
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController : ControllerBase
    {
        private const string PurposeConfirmEmail = "confirm-email";
        private const string PurposeLoginOtp = "login-otp";

        private readonly UserManager<AppUser> _userManager;
        private readonly TokenService _tokens;
        private readonly EmailService _email;
        private readonly IWebHostEnvironment _env;
        private readonly IConfiguration _config;
        private readonly ILogger<AuthController> _logger;

        public AuthController(UserManager<AppUser> userManager, TokenService tokens, EmailService email,
            IWebHostEnvironment env, IConfiguration config, ILogger<AuthController> logger)
        {
            _userManager = userManager;
            _tokens = tokens;
            _email = email;
            _env = env;
            _config = config;
            _logger = logger;
        }

        // ---------------- 1. ĐĂNG KÝ QUA EMAIL ----------------

        // POST api/Auth/register  -> tạo tài khoản Sinh viên (chưa kích hoạt) + gửi mã về email
        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] RegisterDto dto)
        {
            if (await _userManager.FindByNameAsync(dto.Username) != null)
                return BadRequest(new { Status = false, Message = "Tên đăng nhập đã tồn tại" });
            if (await _userManager.FindByEmailAsync(dto.Email) != null)
                return BadRequest(new { Status = false, Message = "Email đã được sử dụng" });

            var user = new AppUser
            {
                UserName = dto.Username.Trim(),
                Email = dto.Email.Trim(),
                FullName = dto.FullName.Trim(),
                Code = dto.Code?.Trim(),
                EmailConfirmed = false
            };
            var result = await _userManager.CreateAsync(user, dto.Password);
            if (!result.Succeeded)
                return BadRequest(new { Status = false, Message = string.Join("; ", result.Errors.Select(e => e.Description)) });

            // Tự đăng ký luôn là Sinh viên; Giảng viên/Admin do Admin tạo
            await _userManager.AddToRoleAsync(user, Roles.Student);

            var (sent, devCode) = await SendCodeAsync(user, PurposeConfirmEmail, "Mã xác nhận đăng ký");
            return Ok(new
            {
                Status = true,
                Message = sent ? $"Đã gửi mã xác nhận tới {Mask(user.Email)}" : "Đăng ký thành công - nhập mã xác nhận",
                EmailSent = sent,
                DevCode = devCode
            });
        }

        // POST api/Auth/confirm-email  { username, code }
        [HttpPost("confirm-email")]
        public async Task<IActionResult> ConfirmEmail([FromBody] CodeDto dto)
        {
            var user = await FindAsync(dto.Username);
            if (user == null) return NotFound(new { Status = false, Message = "Không tìm thấy tài khoản" });
            if (user.EmailConfirmed) return Ok(new { Status = true, Message = "Email đã được xác nhận trước đó" });

            var ok = await _userManager.VerifyUserTokenAsync(user, TokenOptions.DefaultEmailProvider,
                PurposeConfirmEmail, dto.Code.Trim());
            if (!ok) return BadRequest(new { Status = false, Message = "Mã xác nhận không đúng hoặc đã hết hạn" });

            user.EmailConfirmed = true;
            await _userManager.UpdateAsync(user);
            return Ok(new { Status = true, Message = "Xác nhận email thành công, hãy đăng nhập" });
        }

        // POST api/Auth/resend-confirm  { username }
        [HttpPost("resend-confirm")]
        public async Task<IActionResult> ResendConfirm([FromBody] UsernameDto dto)
        {
            var user = await FindAsync(dto.Username);
            if (user == null) return NotFound(new { Status = false, Message = "Không tìm thấy tài khoản" });
            if (user.EmailConfirmed) return Ok(new { Status = true, Message = "Email đã được xác nhận" });

            var (sent, devCode) = await SendCodeAsync(user, PurposeConfirmEmail, "Mã xác nhận đăng ký");
            return Ok(new { Status = true, Message = sent ? $"Đã gửi lại mã tới {Mask(user.Email)}" : "Đã tạo mã mới", EmailSent = sent, DevCode = devCode });
        }

        // ---------------- 2. ĐĂNG NHẬP: MẬT KHẨU + OTP ----------------

        // Bước 1: POST api/Auth/login  { username, password }  -> đúng mật khẩu thì gửi OTP về email
        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginDto dto)
        {
            var user = await FindAsync(dto.Username);
            if (user == null)
                return Unauthorized(new { Status = false, Message = "Sai tên đăng nhập hoặc mật khẩu" });

            if (await _userManager.IsLockedOutAsync(user))
                return StatusCode(423, new { Status = false, Message = "Tài khoản tạm khóa 5 phút do nhập sai nhiều lần" });

            if (!await _userManager.CheckPasswordAsync(user, dto.Password))
            {
                await _userManager.AccessFailedAsync(user);
                return Unauthorized(new { Status = false, Message = "Sai tên đăng nhập hoặc mật khẩu" });
            }

            if (!user.EmailConfirmed)
            {
                var (s, dc) = await SendCodeAsync(user, PurposeConfirmEmail, "Mã xác nhận đăng ký");
                return StatusCode(403, new
                {
                    Status = false,
                    NeedConfirmEmail = true,
                    Username = user.UserName,
                    Message = "Email chưa được xác nhận - đã gửi lại mã xác nhận",
                    DevCode = dc
                });
            }

            await _userManager.ResetAccessFailedCountAsync(user);
            var (sent, devCode) = await SendCodeAsync(user, PurposeLoginOtp, "Mã OTP đăng nhập");
            return Ok(new
            {
                Status = true,
                OtpRequired = true,
                Username = user.UserName,
                Message = sent ? $"Đã gửi mã OTP tới {Mask(user.Email)}" : "Nhập mã OTP để đăng nhập",
                EmailSent = sent,
                DevCode = devCode
            });
        }

        // Bước 2: POST api/Auth/verify-otp  { username, code }  -> đúng OTP thì trả JWT
        [HttpPost("verify-otp")]
        public async Task<IActionResult> VerifyOtp([FromBody] CodeDto dto)
        {
            var user = await FindAsync(dto.Username);
            if (user == null) return Unauthorized(new { Status = false, Message = "Mã OTP không đúng" });

            if (await _userManager.IsLockedOutAsync(user))
                return StatusCode(423, new { Status = false, Message = "Tài khoản tạm khóa 5 phút do nhập sai nhiều lần" });

            var ok = await _userManager.VerifyUserTokenAsync(user, TokenOptions.DefaultEmailProvider,
                PurposeLoginOtp, dto.Code.Trim());
            if (!ok)
            {
                await _userManager.AccessFailedAsync(user);
                return Unauthorized(new { Status = false, Message = "Mã OTP không đúng hoặc đã hết hạn" });
            }

            await _userManager.ResetAccessFailedCountAsync(user);
            return Ok(await _tokens.BuildLoginResponseAsync(user, "Đăng nhập thành công"));
        }

        // ---------------- 5a. ĐĂNG NHẬP BẰNG KHUÔN MẶT ----------------

        // POST api/Auth/face-login  { username, faceVector: [...] }
        [HttpPost("face-login")]
        public async Task<IActionResult> FaceLogin([FromBody] FaceLoginDto dto)
        {
            var user = await FindAsync(dto.Username);
            if (user == null) return Unauthorized(new { Status = false, Message = "Không tìm thấy tài khoản" });
            if (string.IsNullOrEmpty(user.FaceTemplate))
                return BadRequest(new { Status = false, Message = "Tài khoản chưa đăng ký khuôn mặt (vào Hồ sơ → Đăng ký khuôn mặt)" });
            if (await _userManager.IsLockedOutAsync(user))
                return StatusCode(423, new { Status = false, Message = "Tài khoản tạm khóa 5 phút do thử sai nhiều lần" });

            var template = JsonSerializer.Deserialize<List<double>>(user.FaceTemplate) ?? new();
            var distance = FaceMatcher.Distance(template, dto.FaceVector);
            var threshold = _config.GetValue<double?>("Face:Threshold") ?? 0.08;
            _logger.LogInformation("Face login {User}: distance={Distance:F4} threshold={Threshold}", user.UserName, distance, threshold);

            if (distance > threshold)
            {
                await _userManager.AccessFailedAsync(user);
                return Unauthorized(new
                {
                    Status = false,
                    Message = "Khuôn mặt không khớp",
                    Distance = _env.IsDevelopment() ? Math.Round(distance, 4) : (double?)null
                });
            }

            await _userManager.ResetAccessFailedCountAsync(user);
            return Ok(await _tokens.BuildLoginResponseAsync(user, "Đăng nhập bằng khuôn mặt thành công"));
        }

        // POST api/Auth/face-enroll  (đã đăng nhập) -> lưu mẫu khuôn mặt
        [Authorize]
        [HttpPost("face-enroll")]
        public async Task<IActionResult> FaceEnroll([FromBody] FaceEnrollDto dto)
        {
            if (dto.FaceVector.Count < 20 || dto.FaceVector.Count % 2 != 0)
                return BadRequest(new { Status = false, Message = "Dữ liệu khuôn mặt không hợp lệ" });

            var user = await _userManager.FindByIdAsync(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
            if (user == null) return Unauthorized();

            user.FaceTemplate = JsonSerializer.Serialize(dto.FaceVector);
            await _userManager.UpdateAsync(user);
            return Ok(new { Status = true, Message = "Đã đăng ký khuôn mặt" });
        }

        // DELETE api/Auth/face-enroll -> xóa mẫu khuôn mặt
        [Authorize]
        [HttpDelete("face-enroll")]
        public async Task<IActionResult> FaceRemove()
        {
            var user = await _userManager.FindByIdAsync(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
            if (user == null) return Unauthorized();
            user.FaceTemplate = null;
            await _userManager.UpdateAsync(user);
            return Ok(new { Status = true, Message = "Đã xóa khuôn mặt" });
        }

        // GET api/Auth/me -> thông tin tài khoản đang đăng nhập
        [Authorize]
        [HttpGet("me")]
        public async Task<IActionResult> Me()
        {
            var user = await _userManager.FindByIdAsync(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
            if (user == null) return Unauthorized();
            var roles = await _userManager.GetRolesAsync(user);
            return Ok(new
            {
                user.Id,
                user.UserName,
                user.Email,
                user.FullName,
                user.Code,
                Role = TokenService.MainRole(roles),
                HasFace = !string.IsNullOrEmpty(user.FaceTemplate)
            });
        }

        // ---------------- HÀM PHỤ ----------------

        private async Task<AppUser?> FindAsync(string usernameOrEmail)
        {
            var key = usernameOrEmail.Trim();
            return await _userManager.FindByNameAsync(key) ?? await _userManager.FindByEmailAsync(key);
        }

        /// Tạo mã 6 số (Identity, có hạn vài phút) và gửi email.
        /// Chưa cấu hình Gmail -> trả mã về (chỉ khi Development) để demo.
        private async Task<(bool sent, string? devCode)> SendCodeAsync(AppUser user, string purpose, string title)
        {
            var code = await _userManager.GenerateUserTokenAsync(user, TokenOptions.DefaultEmailProvider, purpose);
            var sent = await _email.SendAsync(user.Email!, $"{title}: {code}",
                EmailService.CodeEmail(user.FullName, title, code));
            if (!sent) _logger.LogWarning("==> {Title} cho {User}: {Code}", title, user.UserName, code);
            return (sent, !sent && _env.IsDevelopment() ? code : null);
        }

        private static string Mask(string? email)
        {
            if (string.IsNullOrEmpty(email) || !email.Contains('@')) return "email của bạn";
            var at = email.IndexOf('@');
            var name = email[..at];
            var shown = name.Length <= 2 ? name[..1] : name[..2];
            return $"{shown}***{email[at..]}";
        }
    }
}
