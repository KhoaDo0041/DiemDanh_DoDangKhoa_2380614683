namespace DiemDanh_DoDangKhoa_2380614683_API.Models
{
    /// Môn học / lớp học phần
    public class Course
    {
        public int Id { get; set; }
        public string Code { get; set; } = string.Empty;     // VD: LTDD01
        public string Name { get; set; } = string.Empty;     // VD: Lập trình di động
        public string? Room { get; set; }                    // VD: E1-02.05

        /// Tổng số buổi của môn (dùng để tính % vắng - cảnh báo cấm thi)
        public int TotalSessions { get; set; } = 15;

        /// Vắng quá bao nhiêu % thì bị cấm thi (thường 20%)
        public int MaxAbsentPercent { get; set; } = 20;

        public string? LecturerId { get; set; }
        public AppUser? Lecturer { get; set; }

        public List<Enrollment> Enrollments { get; set; } = new();
        public List<ClassSession> Sessions { get; set; } = new();
    }

    /// Sinh viên thuộc lớp nào
    public class Enrollment
    {
        public int Id { get; set; }
        public int CourseId { get; set; }
        public Course? Course { get; set; }
        public string StudentId { get; set; } = string.Empty;
        public AppUser? Student { get; set; }
    }
}
