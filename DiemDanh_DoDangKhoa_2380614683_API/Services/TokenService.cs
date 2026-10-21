using DiemDanh_DoDangKhoa_2380614683_API.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace DiemDanh_DoDangKhoa_2380614683_API.Services
{
    /// Tạo JWT chứa: id, tên đăng nhập, họ tên, vai trò
    public class TokenService
    {
        private readonly UserManager<AppUser> _userManager;
        private readonly IConfiguration _config;

        public TokenService(UserManager<AppUser> userManager, IConfiguration config)
        {
            _userManager = userManager;
            _config = config;
        }

        /// Vai trò chính để app điều hướng: Admin > Lecturer > Student
        public static string MainRole(IList<string> roles) =>
            roles.Contains(Roles.Admin) ? Roles.Admin
            : roles.Contains(Roles.Lecturer) ? Roles.Lecturer
            : Roles.Student;

        public async Task<object> BuildLoginResponseAsync(AppUser user, string message)
        {
            var roles = await _userManager.GetRolesAsync(user);
            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, user.Id),
                new Claim(ClaimTypes.Name, user.UserName!),
                new Claim("fullName", user.FullName),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
            };
            foreach (var r in roles) claims.Add(new Claim(ClaimTypes.Role, r));

            var jwt = _config.GetSection("JWTKey");
            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt["Secret"]!));
            var descriptor = new SecurityTokenDescriptor
            {
                Subject = new ClaimsIdentity(claims),
                Expires = DateTime.UtcNow.AddHours(Convert.ToDouble(jwt["TokenExpiryTimeInHour"] ?? "8")),
                Issuer = jwt["ValidIssuer"],
                Audience = jwt["ValidAudience"],
                SigningCredentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256)
            };
            var handler = new JwtSecurityTokenHandler();
            var token = handler.WriteToken(handler.CreateToken(descriptor));

            return new
            {
                Status = true,
                Message = message,
                Token = token,
                Role = MainRole(roles),
                FullName = user.FullName
            };
        }
    }
}
