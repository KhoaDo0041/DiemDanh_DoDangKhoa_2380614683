namespace DiemDanh_DoDangKhoa_2380614683_API.Models
{
    /// Một buổi học (giảng viên mở buổi -> hiện QR động -> sinh viên quét)
    public class ClassSession
    {
        public int Id { get; set; }
        public int CourseId { get; set; }
        public Course? Course { get; set; }

        public string Title { get; set; } = string.Empty;   // VD: Buổi 3 - Web API
        public DateTime StartTime { get; set; } = DateTime.UtcNow;
        public DateTime? EndTime { get; set; }
        public bool IsOpen { get; set; } = true;

        /// Khóa bí mật để sinh mã QR thay đổi mỗi 15 giây
        public string Secret { get; set; } = string.Empty;

        /// Vị trí lớp học (lấy GPS của giảng viên lúc mở buổi)
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public int RadiusMeters { get; set; } = 100;

        public List<Attendance> Attendances { get; set; } = new();
    }

    /// Một lượt điểm danh của sinh viên trong 1 buổi
    public class Attendance
    {
        public int Id { get; set; }
        public int SessionId { get; set; }
        public ClassSession? Session { get; set; }
        public string StudentId { get; set; } = string.Empty;
        public AppUser? Student { get; set; }

        public DateTime CheckInTime { get; set; } = DateTime.UtcNow;

        /// Vị trí sinh viên chia sẻ lúc điểm danh
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public double? DistanceMeters { get; set; }

        /// "QR" (sinh viên tự quét) hoặc "Manual" (giảng viên điểm danh tay)
        public string Method { get; set; } = "QR";
    }
}
