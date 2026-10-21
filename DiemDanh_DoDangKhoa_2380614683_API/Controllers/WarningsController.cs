using DiemDanh_DoDangKhoa_2380614683_API.Data;
using DiemDanh_DoDangKhoa_2380614683_API.Models;
using DiemDanh_DoDangKhoa_2380614683_API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace DiemDanh_DoDangKhoa_2380614683_API.Controllers
{
    /// TÍNH NĂNG MỚI (YÊU CẦU 6): CẢNH BÁO NGUY CƠ CẤM THI
    /// Chỉ tính các buổi ĐÃ KẾT THÚC (buổi đang mở chưa tính vắng).
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class WarningsController : ControllerBase
    {
        private readonly AppDbContext _db;

        public WarningsController(AppDbContext db)
        {
            _db = db;
        }

        // GET api/Warnings/my -> sinh viên: tình trạng từng môn
        [HttpGet("my")]
        [Authorize(Roles = Roles.Student)]
        public async Task<IActionResult> My()
        {
            var uid = User.FindFirstValue(ClaimTypes.NameIdentifier)!;
            var data = await _db.Courses
                .Where(c => c.Enrollments.Any(e => e.StudentId == uid))
                .Select(c => new
                {
                    c.Id,
                    c.Code,
                    c.Name,
                    c.TotalSessions,
                    c.MaxAbsentPercent,
                    LecturerName = c.Lecturer != null ? c.Lecturer.FullName : null,
                    Held = c.Sessions.Count(s => !s.IsOpen),
                    Attended = c.Sessions.Count(s => !s.IsOpen && s.Attendances.Any(a => a.StudentId == uid)),
                    HasOpenSession = c.Sessions.Any(s => s.IsOpen)
                }).ToListAsync();

            var result = data.Select(c => new
            {
                CourseId = c.Id,
                c.Code,
                c.Name,
                c.LecturerName,
                c.HasOpenSession,
                Warning = ExamBanWarning.Compute(c.TotalSessions, c.MaxAbsentPercent, c.Held, c.Attended)
            });
            return Ok(result);
        }

        // GET api/Warnings/course/{courseId} -> giảng viên/Admin: sinh viên nào sắp bị cấm thi
        [HttpGet("course/{courseId:int}")]
        [Authorize(Roles = Roles.Admin + "," + Roles.Lecturer)]
        public async Task<IActionResult> ByCourse(int courseId)
        {
            var uid = User.FindFirstValue(ClaimTypes.NameIdentifier)!;
            var course = await _db.Courses.FirstOrDefaultAsync(c => c.Id == courseId);
            if (course == null) return NotFound();
            if (!User.IsInRole(Roles.Admin) && course.LecturerId != uid) return Forbid();

            var held = await _db.ClassSessions.CountAsync(s => s.CourseId == courseId && !s.IsOpen);
            var students = await _db.Enrollments.Where(e => e.CourseId == courseId)
                .Select(e => new
                {
                    e.StudentId,
                    e.Student!.FullName,
                    e.Student.Code,
                    Attended = _db.Attendances.Count(a => a.StudentId == e.StudentId
                                                          && a.Session!.CourseId == courseId && !a.Session.IsOpen)
                }).ToListAsync();

            var result = students.Select(s => new
            {
                s.StudentId,
                s.FullName,
                s.Code,
                Warning = ExamBanWarning.Compute(course.TotalSessions, course.MaxAbsentPercent, held, s.Attended)
            })
            .OrderByDescending(x => x.Warning.Absences)
            .ToList();
            return Ok(result);
        }

        // GET api/Warnings/at-risk -> Admin: tất cả sinh viên đang WARNING / DANGER / BANNED
        [HttpGet("at-risk")]
        [Authorize(Roles = Roles.Admin)]
        public async Task<IActionResult> AtRisk()
        {
            var rows = await _db.Enrollments.Select(e => new
            {
                e.StudentId,
                e.Student!.FullName,
                e.Student.Code,
                e.CourseId,
                CourseName = e.Course!.Name,
                e.Course.TotalSessions,
                e.Course.MaxAbsentPercent,
                Held = e.Course.Sessions.Count(s => !s.IsOpen),
                Attended = e.Course.Sessions.Count(s => !s.IsOpen && s.Attendances.Any(a => a.StudentId == e.StudentId))
            }).ToListAsync();

            var result = rows
                .Select(r => new
                {
                    r.StudentId,
                    r.FullName,
                    r.Code,
                    r.CourseId,
                    r.CourseName,
                    Warning = ExamBanWarning.Compute(r.TotalSessions, r.MaxAbsentPercent, r.Held, r.Attended)
                })
                .Where(r => r.Warning.Level != ExamBanWarning.Safe)
                .OrderByDescending(r => r.Warning.Absences)
                .ToList();
            return Ok(result);
        }
    }
}
