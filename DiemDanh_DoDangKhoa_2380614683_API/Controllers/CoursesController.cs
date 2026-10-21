using DiemDanh_DoDangKhoa_2380614683_API.Data;
using DiemDanh_DoDangKhoa_2380614683_API.Dtos;
using DiemDanh_DoDangKhoa_2380614683_API.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace DiemDanh_DoDangKhoa_2380614683_API.Controllers
{
    /// CRUD MÔN HỌC + danh sách sinh viên của môn
    ///  - Admin: toàn quyền
    ///  - Giảng viên: xem môn mình dạy + sinh viên
    ///  - Sinh viên: xem môn mình học
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class CoursesController : ControllerBase
    {
        private readonly AppDbContext _db;
        private readonly UserManager<AppUser> _userManager;

        public CoursesController(AppDbContext db, UserManager<AppUser> userManager)
        {
            _db = db;
            _userManager = userManager;
        }

        private string UserId => User.FindFirstValue(ClaimTypes.NameIdentifier)!;

        // GET api/Courses
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var uid = UserId;
            var q = _db.Courses.AsQueryable();
            if (User.IsInRole(Roles.Admin)) { }
            else if (User.IsInRole(Roles.Lecturer)) q = q.Where(c => c.LecturerId == uid);
            else q = q.Where(c => c.Enrollments.Any(e => e.StudentId == uid));

            var list = await q.OrderBy(c => c.Code).Select(c => new
            {
                c.Id,
                c.Code,
                c.Name,
                c.Room,
                c.TotalSessions,
                c.MaxAbsentPercent,
                c.LecturerId,
                LecturerName = c.Lecturer != null ? c.Lecturer.FullName : null,
                StudentCount = c.Enrollments.Count,
                SessionCount = c.Sessions.Count,
                HasOpenSession = c.Sessions.Any(s => s.IsOpen)
            }).ToListAsync();
            return Ok(list);
        }

        // GET api/Courses/{id}
        [HttpGet("{id:int}")]
        public async Task<IActionResult> Get(int id)
        {
            if (!await CanAccess(id)) return Forbid();
            var c = await _db.Courses.Where(x => x.Id == id).Select(c => new
            {
                c.Id,
                c.Code,
                c.Name,
                c.Room,
                c.TotalSessions,
                c.MaxAbsentPercent,
                c.LecturerId,
                LecturerName = c.Lecturer != null ? c.Lecturer.FullName : null,
                StudentCount = c.Enrollments.Count,
                SessionCount = c.Sessions.Count,
                HasOpenSession = c.Sessions.Any(s => s.IsOpen)
            }).FirstOrDefaultAsync();
            return c == null ? NotFound() : Ok(c);
        }

        // POST api/Courses (Admin)
        [HttpPost]
        [Authorize(Roles = Roles.Admin)]
        public async Task<IActionResult> Create([FromBody] CourseDto dto)
        {
            var err = await Validate(dto, null);
            if (err != null) return BadRequest(new { Status = false, Message = err });

            var c = new Course();
            Apply(c, dto);
            _db.Courses.Add(c);
            await _db.SaveChangesAsync();
            return Ok(new { Status = true, Message = "Đã thêm môn học", c.Id });
        }

        // PUT api/Courses/{id} (Admin)
        [HttpPut("{id:int}")]
        [Authorize(Roles = Roles.Admin)]
        public async Task<IActionResult> Update(int id, [FromBody] CourseDto dto)
        {
            var c = await _db.Courses.FindAsync(id);
            if (c == null) return NotFound(new { Status = false, Message = "Không tìm thấy môn học" });
            var err = await Validate(dto, id);
            if (err != null) return BadRequest(new { Status = false, Message = err });

            Apply(c, dto);
            await _db.SaveChangesAsync();
            return Ok(new { Status = true, Message = "Đã cập nhật môn học" });
        }

        // DELETE api/Courses/{id} (Admin) -> xóa luôn sinh viên của lớp, buổi học, điểm danh
        [HttpDelete("{id:int}")]
        [Authorize(Roles = Roles.Admin)]
        public async Task<IActionResult> Delete(int id)
        {
            var c = await _db.Courses.FindAsync(id);
            if (c == null) return NotFound(new { Status = false, Message = "Không tìm thấy môn học" });
            _db.Courses.Remove(c);
            await _db.SaveChangesAsync();
            return Ok(new { Status = true, Message = "Đã xóa môn học" });
        }

        // GET api/Courses/{id}/students (Admin, Giảng viên của môn)
        [HttpGet("{id:int}/students")]
        [Authorize(Roles = Roles.Admin + "," + Roles.Lecturer)]
        public async Task<IActionResult> Students(int id)
        {
            if (!await CanAccess(id)) return Forbid();
            var list = await _db.Enrollments.Where(e => e.CourseId == id)
                .OrderBy(e => e.Student!.FullName)
                .Select(e => new
                {
                    StudentId = e.StudentId,
                    e.Student!.UserName,
                    e.Student.FullName,
                    e.Student.Code,
                    e.Student.Email
                }).ToListAsync();
            return Ok(list);
        }

        // POST api/Courses/{id}/students { studentCodeOrUsername } (Admin)
        [HttpPost("{id:int}/students")]
        [Authorize(Roles = Roles.Admin)]
        public async Task<IActionResult> AddStudent(int id, [FromBody] AddStudentDto dto)
        {
            if (!await _db.Courses.AnyAsync(c => c.Id == id))
                return NotFound(new { Status = false, Message = "Không tìm thấy môn học" });

            var key = dto.StudentCodeOrUsername.Trim();
            var student = await _userManager.Users.FirstOrDefaultAsync(u => u.Code == key || u.NormalizedUserName == key.ToUpperInvariant());
            if (student == null || !await _userManager.IsInRoleAsync(student, Roles.Student))
                return BadRequest(new { Status = false, Message = "Không tìm thấy sinh viên với MSSV / tên đăng nhập này" });

            if (await _db.Enrollments.AnyAsync(e => e.CourseId == id && e.StudentId == student.Id))
                return BadRequest(new { Status = false, Message = "Sinh viên đã có trong lớp" });

            _db.Enrollments.Add(new Enrollment { CourseId = id, StudentId = student.Id });
            await _db.SaveChangesAsync();
            return Ok(new { Status = true, Message = $"Đã thêm {student.FullName} vào lớp" });
        }

        // DELETE api/Courses/{id}/students/{studentId} (Admin)
        [HttpDelete("{id:int}/students/{studentId}")]
        [Authorize(Roles = Roles.Admin)]
        public async Task<IActionResult> RemoveStudent(int id, string studentId)
        {
            var e = await _db.Enrollments.FirstOrDefaultAsync(x => x.CourseId == id && x.StudentId == studentId);
            if (e == null) return NotFound(new { Status = false, Message = "Sinh viên không có trong lớp" });

            _db.Attendances.RemoveRange(_db.Attendances.Where(a => a.StudentId == studentId && a.Session!.CourseId == id));
            _db.Enrollments.Remove(e);
            await _db.SaveChangesAsync();
            return Ok(new { Status = true, Message = "Đã xóa sinh viên khỏi lớp" });
        }

        // ---------------- hàm phụ ----------------

        private async Task<bool> CanAccess(int courseId)
        {
            if (User.IsInRole(Roles.Admin)) return true;
            var uid = UserId;
            if (User.IsInRole(Roles.Lecturer))
                return await _db.Courses.AnyAsync(c => c.Id == courseId && c.LecturerId == uid);
            return await _db.Enrollments.AnyAsync(e => e.CourseId == courseId && e.StudentId == uid);
        }

        private async Task<string?> Validate(CourseDto dto, int? id)
        {
            if (await _db.Courses.AnyAsync(c => c.Code == dto.Code.Trim() && c.Id != id))
                return "Mã môn đã tồn tại";
            if (!string.IsNullOrEmpty(dto.LecturerId))
            {
                var lec = await _userManager.FindByIdAsync(dto.LecturerId);
                if (lec == null || !await _userManager.IsInRoleAsync(lec, Roles.Lecturer))
                    return "Giảng viên không hợp lệ";
            }
            return null;
        }

        private static void Apply(Course c, CourseDto dto)
        {
            c.Code = dto.Code.Trim();
            c.Name = dto.Name.Trim();
            c.Room = dto.Room?.Trim();
            c.TotalSessions = dto.TotalSessions;
            c.MaxAbsentPercent = dto.MaxAbsentPercent;
            c.LecturerId = string.IsNullOrEmpty(dto.LecturerId) ? null : dto.LecturerId;
        }
    }
}
