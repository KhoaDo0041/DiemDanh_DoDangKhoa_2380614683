using DiemDanh_DoDangKhoa_2380614683_API.Data;
using DiemDanh_DoDangKhoa_2380614683_API.Dtos;
using DiemDanh_DoDangKhoa_2380614683_API.Models;
using DiemDanh_DoDangKhoa_2380614683_API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace DiemDanh_DoDangKhoa_2380614683_API.Controllers
{
    /// CRUD BUỔI HỌC (giảng viên của môn / Admin) + QR động + danh sách điểm danh
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class SessionsController : ControllerBase
    {
        private readonly AppDbContext _db;

        public SessionsController(AppDbContext db)
        {
            _db = db;
        }

        private string UserId => User.FindFirstValue(ClaimTypes.NameIdentifier)!;
        private bool IsAdmin => User.IsInRole(Roles.Admin);

        // GET api/Sessions?courseId=1
        [HttpGet]
        public async Task<IActionResult> GetByCourse([FromQuery] int courseId)
        {
            var uid = UserId;
            var allowed = IsAdmin
                || await _db.Courses.AnyAsync(c => c.Id == courseId && c.LecturerId == uid)
                || await _db.Enrollments.AnyAsync(e => e.CourseId == courseId && e.StudentId == uid);
            if (!allowed) return Forbid();

            var total = await _db.Enrollments.CountAsync(e => e.CourseId == courseId);
            var list = await _db.ClassSessions.Where(s => s.CourseId == courseId)
                .OrderByDescending(s => s.StartTime)
                .Select(s => new
                {
                    s.Id,
                    s.CourseId,
                    s.Title,
                    s.StartTime,
                    s.EndTime,
                    s.IsOpen,
                    s.Latitude,
                    s.Longitude,
                    s.RadiusMeters,
                    PresentCount = s.Attendances.Count,
                    TotalStudents = total,
                    // Sinh viên xem: mình đã điểm danh buổi này chưa
                    IAmPresent = s.Attendances.Any(a => a.StudentId == uid)
                }).ToListAsync();
            return Ok(list);
        }

        // POST api/Sessions -> mở buổi học mới (lưu GPS của giảng viên làm vị trí lớp)
        [HttpPost]
        [Authorize(Roles = Roles.Admin + "," + Roles.Lecturer)]
        public async Task<IActionResult> Create([FromBody] SessionCreateDto dto)
        {
            if (!await OwnsCourse(dto.CourseId)) return Forbid();

            var s = new ClassSession
            {
                CourseId = dto.CourseId,
                Title = dto.Title.Trim(),
                Latitude = dto.Latitude,
                Longitude = dto.Longitude,
                RadiusMeters = dto.RadiusMeters,
                StartTime = DateTime.UtcNow,
                IsOpen = true,
                Secret = RotatingCode.NewSecret()
            };
            _db.ClassSessions.Add(s);
            await _db.SaveChangesAsync();
            return Ok(new { Status = true, Message = "Đã mở buổi học", s.Id });
        }

        // PUT api/Sessions/{id}
        [HttpPut("{id:int}")]
        [Authorize(Roles = Roles.Admin + "," + Roles.Lecturer)]
        public async Task<IActionResult> Update(int id, [FromBody] SessionUpdateDto dto)
        {
            var s = await _db.ClassSessions.FindAsync(id);
            if (s == null) return NotFound(new { Status = false, Message = "Không tìm thấy buổi học" });
            if (!await OwnsCourse(s.CourseId)) return Forbid();

            s.Title = dto.Title.Trim();
            s.RadiusMeters = dto.RadiusMeters;
            await _db.SaveChangesAsync();
            return Ok(new { Status = true, Message = "Đã cập nhật buổi học" });
        }

        // POST api/Sessions/{id}/close -> kết thúc buổi (sinh viên không quét được nữa)
        [HttpPost("{id:int}/close")]
        [Authorize(Roles = Roles.Admin + "," + Roles.Lecturer)]
        public async Task<IActionResult> Close(int id) => await SetOpen(id, false);

        // POST api/Sessions/{id}/reopen
        [HttpPost("{id:int}/reopen")]
        [Authorize(Roles = Roles.Admin + "," + Roles.Lecturer)]
        public async Task<IActionResult> Reopen(int id) => await SetOpen(id, true);

        // DELETE api/Sessions/{id}
        [HttpDelete("{id:int}")]
        [Authorize(Roles = Roles.Admin + "," + Roles.Lecturer)]
        public async Task<IActionResult> Delete(int id)
        {
            var s = await _db.ClassSessions.FindAsync(id);
            if (s == null) return NotFound(new { Status = false, Message = "Không tìm thấy buổi học" });
            if (!await OwnsCourse(s.CourseId)) return Forbid();
            _db.ClassSessions.Remove(s);
            await _db.SaveChangesAsync();
            return Ok(new { Status = true, Message = "Đã xóa buổi học" });
        }

        // GET api/Sessions/{id}/qr -> QR ĐỘNG: nội dung QR + mã 6 số, đổi mỗi 15 giây
        [HttpGet("{id:int}/qr")]
        [Authorize(Roles = Roles.Admin + "," + Roles.Lecturer)]
        public async Task<IActionResult> Qr(int id)
        {
            var s = await _db.ClassSessions.FindAsync(id);
            if (s == null) return NotFound(new { Status = false, Message = "Không tìm thấy buổi học" });
            if (!await OwnsCourse(s.CourseId)) return Forbid();
            if (!s.IsOpen) return BadRequest(new { Status = false, Message = "Buổi học đã kết thúc" });

            var code = RotatingCode.Compute(s.Secret, s.Id, RotatingCode.CurrentStep());
            return Ok(new
            {
                SessionId = s.Id,
                Code = code,
                QrContent = RotatingCode.QrContent(s.Id, code),
                SecondsLeft = RotatingCode.SecondsLeft(),
                StepSeconds = RotatingCode.StepSeconds
            });
        }

        // GET api/Sessions/{id}/attendances -> toàn bộ sinh viên của lớp: có mặt / vắng + vị trí
        [HttpGet("{id:int}/attendances")]
        [Authorize(Roles = Roles.Admin + "," + Roles.Lecturer)]
        public async Task<IActionResult> Attendances(int id)
        {
            var s = await _db.ClassSessions.FindAsync(id);
            if (s == null) return NotFound(new { Status = false, Message = "Không tìm thấy buổi học" });
            if (!await OwnsCourse(s.CourseId)) return Forbid();

            var students = await _db.Enrollments.Where(e => e.CourseId == s.CourseId)
                .Select(e => new { e.StudentId, e.Student!.FullName, e.Student.Code, e.Student.UserName })
                .ToListAsync();
            var att = await _db.Attendances.Where(a => a.SessionId == id).ToListAsync();

            var list = students.Select(st =>
            {
                var a = att.FirstOrDefault(x => x.StudentId == st.StudentId);
                return new
                {
                    st.StudentId,
                    st.FullName,
                    st.Code,
                    st.UserName,
                    Present = a != null,
                    CheckInTime = a?.CheckInTime,
                    Method = a?.Method,
                    Latitude = a?.Latitude,
                    Longitude = a?.Longitude,
                    DistanceMeters = a?.DistanceMeters,
                    OutOfRange = a?.DistanceMeters != null && a.DistanceMeters > s.RadiusMeters
                };
            })
            .OrderBy(x => x.Present).ThenBy(x => x.FullName)
            .ToList();

            return Ok(new
            {
                Session = new { s.Id, s.Title, s.IsOpen, s.StartTime, s.Latitude, s.Longitude, s.RadiusMeters },
                PresentCount = att.Count,
                Total = students.Count,
                Students = list
            });
        }

        // PUT api/Sessions/{id}/attendances/{studentId} { present } -> giảng viên điểm danh tay / hủy
        [HttpPut("{id:int}/attendances/{studentId}")]
        [Authorize(Roles = Roles.Admin + "," + Roles.Lecturer)]
        public async Task<IActionResult> SetAttendance(int id, string studentId, [FromBody] ManualAttendanceDto dto)
        {
            var s = await _db.ClassSessions.FindAsync(id);
            if (s == null) return NotFound(new { Status = false, Message = "Không tìm thấy buổi học" });
            if (!await OwnsCourse(s.CourseId)) return Forbid();
            if (!await _db.Enrollments.AnyAsync(e => e.CourseId == s.CourseId && e.StudentId == studentId))
                return BadRequest(new { Status = false, Message = "Sinh viên không thuộc lớp" });

            var a = await _db.Attendances.FirstOrDefaultAsync(x => x.SessionId == id && x.StudentId == studentId);
            if (dto.Present && a == null)
                _db.Attendances.Add(new Attendance { SessionId = id, StudentId = studentId, Method = "Manual" });
            else if (!dto.Present && a != null)
                _db.Attendances.Remove(a);
            await _db.SaveChangesAsync();
            return Ok(new { Status = true, Message = dto.Present ? "Đã đánh dấu có mặt" : "Đã đánh dấu vắng" });
        }

        // ---------------- hàm phụ ----------------

        private async Task<bool> OwnsCourse(int courseId)
        {
            if (IsAdmin) return await _db.Courses.AnyAsync(c => c.Id == courseId);
            var uid = UserId;
            return await _db.Courses.AnyAsync(c => c.Id == courseId && c.LecturerId == uid);
        }

        private async Task<IActionResult> SetOpen(int id, bool open)
        {
            var s = await _db.ClassSessions.FindAsync(id);
            if (s == null) return NotFound(new { Status = false, Message = "Không tìm thấy buổi học" });
            if (!await OwnsCourse(s.CourseId)) return Forbid();
            s.IsOpen = open;
            s.EndTime = open ? null : DateTime.UtcNow;
            await _db.SaveChangesAsync();
            return Ok(new { Status = true, Message = open ? "Đã mở lại buổi học" : "Đã kết thúc buổi học" });
        }
    }
}
