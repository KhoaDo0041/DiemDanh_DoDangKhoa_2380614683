using System.ComponentModel.DataAnnotations;

namespace DiemDanh_DoDangKhoa_2380614683_API.Dtos
{
    // ================= ĐĂNG KÝ / ĐĂNG NHẬP =================

    public class RegisterDto
    {
        [Required, MinLength(3)] public string Username { get; set; } = "";
        [Required, EmailAddress] public string Email { get; set; } = "";
        [Required, MinLength(6)] public string Password { get; set; } = "";
        [Required] public string FullName { get; set; } = "";
        public string? Code { get; set; }   // MSSV
    }

    public class CodeDto
    {
        [Required] public string Username { get; set; } = "";
        [Required] public string Code { get; set; } = "";
    }

    public class UsernameDto
    {
        [Required] public string Username { get; set; } = "";
    }

    public class LoginDto
    {
        [Required] public string Username { get; set; } = "";   // tên đăng nhập hoặc email
        [Required] public string Password { get; set; } = "";
    }

    public class FaceLoginDto
    {
        [Required] public string Username { get; set; } = "";
        [Required] public List<double> FaceVector { get; set; } = new();
    }

    public class FaceEnrollDto
    {
        [Required] public List<double> FaceVector { get; set; } = new();
    }

    // ================= ADMIN: NGƯỜI DÙNG =================

    public class UserCreateDto
    {
        [Required, MinLength(3)] public string Username { get; set; } = "";
        [Required, EmailAddress] public string Email { get; set; } = "";
        [Required, MinLength(6)] public string Password { get; set; } = "";
        [Required] public string FullName { get; set; } = "";
        public string? Code { get; set; }
        [Required] public string Role { get; set; } = "Student";
    }

    public class UserUpdateDto
    {
        [Required, EmailAddress] public string Email { get; set; } = "";
        [Required] public string FullName { get; set; } = "";
        public string? Code { get; set; }
        [Required] public string Role { get; set; } = "Student";
        public string? NewPassword { get; set; }   // để trống = giữ mật khẩu cũ
    }

    // ================= MÔN HỌC =================

    public class CourseDto
    {
        [Required] public string Code { get; set; } = "";
        [Required] public string Name { get; set; } = "";
        public string? Room { get; set; }
        [Range(1, 100)] public int TotalSessions { get; set; } = 15;
        [Range(0, 100)] public int MaxAbsentPercent { get; set; } = 20;
        public string? LecturerId { get; set; }
    }

    public class AddStudentDto
    {
        /// MSSV hoặc tên đăng nhập của sinh viên
        [Required] public string StudentCodeOrUsername { get; set; } = "";
    }

    // ================= BUỔI HỌC / ĐIỂM DANH =================

    public class SessionCreateDto
    {
        [Required] public int CourseId { get; set; }
        [Required] public string Title { get; set; } = "";
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        [Range(10, 5000)] public int RadiusMeters { get; set; } = 100;
    }

    public class SessionUpdateDto
    {
        [Required] public string Title { get; set; } = "";
        [Range(10, 5000)] public int RadiusMeters { get; set; } = 100;
    }

    public class ManualAttendanceDto
    {
        public bool Present { get; set; }
    }

    public class CheckInDto
    {
        /// Nội dung QR quét được: "DIEMDANH:{sessionId}:{code}"
        public string? QrContent { get; set; }

        /// Hoặc nhập tay mã 6 số đang hiện dưới QR
        public int? SessionId { get; set; }
        public string? Code { get; set; }

        /// Vị trí sinh viên chia sẻ lúc điểm danh
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
    }
}
