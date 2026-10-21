using DiemDanh_DoDangKhoa_2380614683_API.Data;
using DiemDanh_DoDangKhoa_2380614683_API.Dtos;
using DiemDanh_DoDangKhoa_2380614683_API.Models;
using DiemDanh_DoDangKhoa_2380614683_API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace DiemDanh_DoDangKhoa_2380614683_API.Controllers
{
    /// CRUD NGƯỜI DÙNG (chỉ Admin): giảng viên, sinh viên, admin
    [Route("api/[controller]")]
    [ApiController]
    [Authorize(Roles = Roles.Admin)]
    public class UsersController : ControllerBase
    {
        private readonly UserManager<AppUser> _userManager;
        private readonly AppDbContext _db;

        public UsersController(UserManager<AppUser> userManager, AppDbContext db)
        {
            _userManager = userManager;
            _db = db;
        }

        // GET api/Users?role=Student&search=khoa
        [HttpGet]
        public async Task<IActionResult> GetAll([FromQuery] string? role, [FromQuery] string? search)
        {
            // Lấy vai trò của tất cả user (ít user nên làm đơn giản)
            var roleOf = new Dictionary<string, string>();
            foreach (var r in new[] { Roles.Student, Roles.Lecturer, Roles.Admin })
                foreach (var u in await _userManager.GetUsersInRoleAsync(r))
                    roleOf[u.Id] = r;   // Admin ghi đè sau cùng = vai trò cao nhất

            var query = _userManager.Users.AsQueryable();
            if (!string.IsNullOrWhiteSpace(search))
            {
                var s = search.Trim();
                query = query.Where(u => u.UserName!.Contains(s) || u.FullName.Contains(s)
                                         || (u.Code != null && u.Code.Contains(s)) || u.Email!.Contains(s));
            }
            var users = await query.OrderBy(u => u.FullName).ToListAsync();

            var result = users
                .Select(u => new
                {
                    u.Id,
                    u.UserName,
                    u.Email,
                    u.FullName,
                    u.Code,
                    Role = roleOf.GetValueOrDefault(u.Id, Roles.Student),
                    u.EmailConfirmed,
                    HasFace = u.FaceTemplate != null
                })
                .Where(u => string.IsNullOrEmpty(role) || u.Role == role)
                .ToList();
            return Ok(result);
        }

        // POST api/Users -> Admin tạo tài khoản (đã kích hoạt email sẵn)
        [HttpPost]
        public async Task<IActionResult> Create([FromBody] UserCreateDto dto)
        {
            if (!Roles.All.Contains(dto.Role)) return BadRequest(new { Status = false, Message = "Vai trò không hợp lệ" });
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
                EmailConfirmed = true
            };
            var result = await _userManager.CreateAsync(user, dto.Password);
            if (!result.Succeeded)
                return BadRequest(new { Status = false, Message = string.Join("; ", result.Errors.Select(e => e.Description)) });

            await _userManager.AddToRoleAsync(user, dto.Role);
            return Ok(new { Status = true, Message = "Đã tạo tài khoản", user.Id });
        }

        // PUT api/Users/{id}
        [HttpPut("{id}")]
        public async Task<IActionResult> Update(string id, [FromBody] UserUpdateDto dto)
        {
            if (!Roles.All.Contains(dto.Role)) return BadRequest(new { Status = false, Message = "Vai trò không hợp lệ" });
            var user = await _userManager.FindByIdAsync(id);
            if (user == null) return NotFound(new { Status = false, Message = "Không tìm thấy" });

            var other = await _userManager.FindByEmailAsync(dto.Email);
            if (other != null && other.Id != id)
                return BadRequest(new { Status = false, Message = "Email đã được sử dụng" });

            // Không cho Admin tự hạ quyền của chính mình
            if (id == User.FindFirstValue(ClaimTypes.NameIdentifier) && dto.Role != Roles.Admin)
                return BadRequest(new { Status = false, Message = "Không thể tự bỏ quyền Admin của chính mình" });

            user.Email = dto.Email.Trim();
            user.FullName = dto.FullName.Trim();
            user.Code = dto.Code?.Trim();
            var upd = await _userManager.UpdateAsync(user);
            if (!upd.Succeeded)
                return BadRequest(new { Status = false, Message = string.Join("; ", upd.Errors.Select(e => e.Description)) });

            var currentRoles = await _userManager.GetRolesAsync(user);
            if (!(currentRoles.Count == 1 && currentRoles[0] == dto.Role))
            {
                await _userManager.RemoveFromRolesAsync(user, currentRoles);
                await _userManager.AddToRoleAsync(user, dto.Role);
            }

            if (!string.IsNullOrWhiteSpace(dto.NewPassword))
            {
                var resetToken = await _userManager.GeneratePasswordResetTokenAsync(user);
                var pw = await _userManager.ResetPasswordAsync(user, resetToken, dto.NewPassword);
                if (!pw.Succeeded)
                    return BadRequest(new { Status = false, Message = string.Join("; ", pw.Errors.Select(e => e.Description)) });
            }
            return Ok(new { Status = true, Message = "Đã cập nhật" });
        }

        // DELETE api/Users/{id}
        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(string id)
        {
            if (id == User.FindFirstValue(ClaimTypes.NameIdentifier))
                return BadRequest(new { Status = false, Message = "Không thể tự xóa tài khoản đang đăng nhập" });

            var user = await _userManager.FindByIdAsync(id);
            if (user == null) return NotFound(new { Status = false, Message = "Không tìm thấy" });

            // Dọn dữ liệu liên quan trước khi xóa
            _db.Attendances.RemoveRange(_db.Attendances.Where(a => a.StudentId == id));
            _db.Enrollments.RemoveRange(_db.Enrollments.Where(e => e.StudentId == id));
            foreach (var c in _db.Courses.Where(c => c.LecturerId == id)) c.LecturerId = null;
            await _db.SaveChangesAsync();

            await _userManager.DeleteAsync(user);
            return Ok(new { Status = true, Message = "Đã xóa tài khoản" });
        }
    }
}
