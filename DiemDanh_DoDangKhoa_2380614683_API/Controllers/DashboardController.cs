using DiemDanh_DoDangKhoa_2380614683_API.Data;
using DiemDanh_DoDangKhoa_2380614683_API.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace DiemDanh_DoDangKhoa_2380614683_API.Controllers
{
    /// Số liệu tổng quan cho trang quản trị / dashboard giảng viên
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class DashboardController : ControllerBase
    {
        private readonly AppDbContext _db;
        private readonly UserManager<AppUser> _userManager;

        public DashboardController(AppDbContext db, UserManager<AppUser> userManager)
        {
            _db = db;
            _userManager = userManager;
        }

        // GET api/Dashboard/admin
        [HttpGet("admin")]
        [Authorize(Roles = Roles.Admin)]
        public async Task<IActionResult> Admin()
        {
            var since = DateTime.UtcNow.AddDays(-7);
            return Ok(new
            {
                Students = (await _userManager.GetUsersInRoleAsync(Roles.Student)).Count,
                Lecturers = (await _userManager.GetUsersInRoleAsync(Roles.Lecturer)).Count,
                Admins = (await _userManager.GetUsersInRoleAsync(Roles.Admin)).Count,
                Courses = await _db.Courses.CountAsync(),
                Sessions = await _db.ClassSessions.CountAsync(),
                OpenSessions = await _db.ClassSessions.CountAsync(s => s.IsOpen),
                Attendances = await _db.Attendances.CountAsync(),
                AttendancesLast7Days = await _db.Attendances.CountAsync(a => a.CheckInTime >= since)
            });
        }

        // GET api/Dashboard/lecturer
        [HttpGet("lecturer")]
        [Authorize(Roles = Roles.Lecturer)]
        public async Task<IActionResult> Lecturer()
        {
            var uid = User.FindFirstValue(ClaimTypes.NameIdentifier)!;
            var courses = _db.Courses.Where(c => c.LecturerId == uid);
            return Ok(new
            {
                Courses = await courses.CountAsync(),
                Students = await _db.Enrollments.CountAsync(e => e.Course!.LecturerId == uid),
                Sessions = await _db.ClassSessions.CountAsync(s => s.Course!.LecturerId == uid),
                OpenSessions = await _db.ClassSessions.CountAsync(s => s.Course!.LecturerId == uid && s.IsOpen)
            });
        }
    }
}
