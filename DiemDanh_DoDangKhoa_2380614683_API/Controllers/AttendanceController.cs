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
    /// SINH VIÊN ĐIỂM DANH: quét QR động (5e) + chia sẻ vị trí (5b)
    [Route("api/[controller]")]
    [ApiController]
    [Authorize(Roles = Roles.Student)]
    public class AttendanceController : ControllerBase
    {
        private readonly AppDbContext _db;

        public AttendanceController(AppDbContext db)
        {
            _db = db;
        }

        private string UserId => User.FindFirstValue(ClaimTypes.NameIdentifier)!;

        // POST api/Attendance/checkin { qrContent | (sessionId + code), latitude, longitude }
        [HttpPost("checkin")]
        public async Task<IActionResult> CheckIn([FromBody] CheckInDto dto)
        {
            int sessionId;
            string code;
            if (!string.IsNullOrWhiteSpace(dto.QrContent))
            {
                if (!RotatingCode.TryParse(dto.QrContent, out sessionId, out code))
                    return BadRequest(new { Status = false, Message = "Mã QR không phải mã điểm danh" });
            }
            else if (dto.SessionId != null && !string.IsNullOrWhiteSpace(dto.Code))
            {
                sessionId = dto.SessionId.Value;
                code = dto.Code;
            }
            else return BadRequest(new { Status = false, Message = "Thiếu mã điểm danh" });

            var s = await _db.ClassSessions.Include(x => x.Course).FirstOrDefaultAsync(x => x.Id == sessionId);
            if (s == null) return NotFound(new { Status = false, Message = "Không tìm thấy buổi học" });
            if (!s.IsOpen) return BadRequest(new { Status = false, Message = "Buổi học đã kết thúc điểm danh" });

            var uid = UserId;
            if (!await _db.Enrollments.AnyAsync(e => e.CourseId == s.CourseId && e.StudentId == uid))
                return BadRequest(new { Status = false, Message = $"Bạn không thuộc lớp {s.Course!.Name}" });

            if (!RotatingCode.Verify(s.Secret, s.Id, code))
                return BadRequest(new { Status = false, Message = "Mã QR đã hết hạn (đổi mỗi 15 giây) - hãy quét lại" });

            if (await _db.Attendances.AnyAsync(a => a.SessionId == s.Id && a.StudentId == uid))
                return Ok(new { Status = true, Message = "Bạn đã điểm danh buổi này rồi", CourseName = s.Course!.Name, Already = true });

            // Chia sẻ vị trí: tính khoảng cách tới lớp
            double? distance = null;
            if (dto.Latitude != null && dto.Longitude != null && s.Latitude != null && s.Longitude != null)
                distance = Math.Round(Geo.DistanceMeters(s.Latitude.Value, s.Longitude.Value,
                    dto.Latitude.Value, dto.Longitude.Value), 1);

            _db.Attendances.Add(new Attendance
            {
                SessionId = s.Id,
                StudentId = uid,
                CheckInTime = DateTime.UtcNow,
                Latitude = dto.Latitude,
                Longitude = dto.Longitude,
                DistanceMeters = distance,
                Method = "QR"
            });
            await _db.SaveChangesAsync();

            var outOfRange = distance != null && distance > s.RadiusMeters;
            return Ok(new
            {
                Status = true,
                Message = outOfRange
                    ? $"Đã điểm danh, nhưng bạn đang cách lớp {distance:0} m (giảng viên sẽ thấy)"
                    : "Điểm danh thành công!",
                CourseName = s.Course!.Name,
                SessionTitle = s.Title,
                DistanceMeters = distance,
                OutOfRange = outOfRange
            });
        }

        // GET api/Attendance/my?courseId=1 -> lịch sử điểm danh của tôi
        [HttpGet("my")]
        public async Task<IActionResult> My([FromQuery] int? courseId)
        {
            var uid = UserId;
            var q = _db.ClassSessions.Where(s => s.Course!.Enrollments.Any(e => e.StudentId == uid));
            if (courseId != null) q = q.Where(s => s.CourseId == courseId);

            var list = await q.OrderByDescending(s => s.StartTime).Select(s => new
            {
                SessionId = s.Id,
                s.CourseId,
                CourseCode = s.Course!.Code,
                CourseName = s.Course.Name,
                s.Title,
                s.StartTime,
                s.IsOpen,
                Present = s.Attendances.Any(a => a.StudentId == uid),
                CheckInTime = s.Attendances.Where(a => a.StudentId == uid).Select(a => (DateTime?)a.CheckInTime).FirstOrDefault(),
                Method = s.Attendances.Where(a => a.StudentId == uid).Select(a => a.Method).FirstOrDefault()
            }).ToListAsync();
            return Ok(list);
        }
    }
}
