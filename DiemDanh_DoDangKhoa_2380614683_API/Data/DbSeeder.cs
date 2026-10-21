using DiemDanh_DoDangKhoa_2380614683_API.Models;
using DiemDanh_DoDangKhoa_2380614683_API.Services;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace DiemDanh_DoDangKhoa_2380614683_API.Data
{
    /// Tạo dữ liệu mẫu lần đầu chạy để demo ngay:
    ///   admin / Admin@123      (Quản trị)
    ///   gv_khoa / Gv@12345     (Giảng viên)
    ///   sv_khoa / Sv@12345     (Sinh viên, MSSV 2380614683)
    ///   sv_an / Sv@12345, sv_binh / Sv@12345
    public static class DbSeeder
    {
        public static async Task SeedAsync(IServiceProvider services)
        {
            using var scope = services.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var roleManager = scope.ServiceProvider.GetRequiredService<RoleManager<IdentityRole>>();
            var userManager = scope.ServiceProvider.GetRequiredService<UserManager<AppUser>>();

            // Tự tạo / cập nhật database theo Migrations -> cả nhóm chỉ cần F5
            await db.Database.MigrateAsync();

            foreach (var role in Roles.All)
                if (!await roleManager.RoleExistsAsync(role))
                    await roleManager.CreateAsync(new IdentityRole(role));

            async Task<AppUser> Ensure(string username, string email, string password, string fullName, string? code, string role)
            {
                var u = await userManager.FindByNameAsync(username);
                if (u != null) return u;
                u = new AppUser { UserName = username, Email = email, FullName = fullName, Code = code, EmailConfirmed = true };
                await userManager.CreateAsync(u, password);
                await userManager.AddToRoleAsync(u, role);
                return u;
            }

            await Ensure("admin", "admin@diemdanh.local", "Admin@123", "Quản trị viên", null, Roles.Admin);
            var gv = await Ensure("gv_khoa", "gv_khoa@diemdanh.local", "Gv@12345", "GV. Nguyễn Văn Giảng", "GV001", Roles.Lecturer);
            var sv1 = await Ensure("sv_khoa", "sv_khoa@diemdanh.local", "Sv@12345", "Đỗ Đăng Khoa", "2380614683", Roles.Student);
            var sv2 = await Ensure("sv_an", "sv_an@diemdanh.local", "Sv@12345", "Trần Thị An", "2380000001", Roles.Student);
            var sv3 = await Ensure("sv_binh", "sv_binh@diemdanh.local", "Sv@12345", "Lê Văn Bình", "2380000002", Roles.Student);

            if (!await db.Courses.AnyAsync())
            {
                var ltdd = new Course { Code = "LTDD01", Name = "Lập trình di động", Room = "E1-02.05", TotalSessions = 15, MaxAbsentPercent = 20, LecturerId = gv.Id };
                var csdl = new Course { Code = "CSDL02", Name = "Cơ sở dữ liệu", Room = "E2-03.01", TotalSessions = 10, MaxAbsentPercent = 20, LecturerId = gv.Id };
                db.Courses.AddRange(ltdd, csdl);
                await db.SaveChangesAsync();

                foreach (var sv in new[] { sv1, sv2, sv3 })
                {
                    db.Enrollments.Add(new Enrollment { CourseId = ltdd.Id, StudentId = sv.Id });
                    db.Enrollments.Add(new Enrollment { CourseId = csdl.Id, StudentId = sv.Id });
                }

                // 2 buổi đã học của môn CSDL (10 buổi, vắng tối đa 2): sv_khoa vắng 2 buổi -> DANGER để demo cảnh báo
                var b1 = new ClassSession { CourseId = csdl.Id, Title = "Buổi 1 - Mô hình quan hệ", StartTime = DateTime.UtcNow.AddDays(-14), EndTime = DateTime.UtcNow.AddDays(-14).AddHours(3), IsOpen = false, Secret = RotatingCode.NewSecret() };
                var b2 = new ClassSession { CourseId = csdl.Id, Title = "Buổi 2 - Chuẩn hóa", StartTime = DateTime.UtcNow.AddDays(-7), EndTime = DateTime.UtcNow.AddDays(-7).AddHours(3), IsOpen = false, Secret = RotatingCode.NewSecret() };
                db.ClassSessions.AddRange(b1, b2);
                await db.SaveChangesAsync();

                db.Attendances.AddRange(
                    new Attendance { SessionId = b1.Id, StudentId = sv2.Id, Method = "Manual", CheckInTime = b1.StartTime.AddMinutes(5) },
                    new Attendance { SessionId = b1.Id, StudentId = sv3.Id, Method = "Manual", CheckInTime = b1.StartTime.AddMinutes(7) },
                    new Attendance { SessionId = b2.Id, StudentId = sv2.Id, Method = "Manual", CheckInTime = b2.StartTime.AddMinutes(3) });
                await db.SaveChangesAsync();
            }
        }
    }
}
