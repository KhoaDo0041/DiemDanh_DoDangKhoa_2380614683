using Microsoft.AspNetCore.Identity;

namespace DiemDanh_DoDangKhoa_2380614683_API.Models
{
    /// Người dùng = IdentityUser (UserName, Email, PasswordHash...) + thông tin riêng
    public class AppUser : IdentityUser
    {
        public string FullName { get; set; } = string.Empty;

        /// MSSV (sinh viên) hoặc mã giảng viên
        public string? Code { get; set; }

        /// Mẫu khuôn mặt (JSON mảng số) để đăng nhập bằng khuôn mặt
        public string? FaceTemplate { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }

    /// 3 vai trò của app
    public static class Roles
    {
        public const string Admin = "Admin";
        public const string Lecturer = "Lecturer";   // Giảng viên (vai trò "nhân viên")
        public const string Student = "Student";     // Sinh viên  (vai trò "khách hàng")

        public static readonly string[] All = { Admin, Lecturer, Student };
    }
}
