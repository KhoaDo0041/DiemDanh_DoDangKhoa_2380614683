using DiemDanh_DoDangKhoa_2380614683_API.Models;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

namespace DiemDanh_DoDangKhoa_2380614683_API.Data
{
    public class AppDbContext : IdentityDbContext<AppUser>
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

        public DbSet<Course> Courses { get; set; }
        public DbSet<Enrollment> Enrollments { get; set; }
        public DbSet<ClassSession> ClassSessions { get; set; }
        public DbSet<Attendance> Attendances { get; set; }

        protected override void OnModelCreating(ModelBuilder builder)
        {
            base.OnModelCreating(builder);

            builder.Entity<AppUser>(e =>
            {
                e.Property(u => u.FullName).HasMaxLength(100);
                e.Property(u => u.Code).HasMaxLength(20);
            });

            builder.Entity<Course>(e =>
            {
                e.Property(c => c.Code).HasMaxLength(20).IsRequired();
                e.Property(c => c.Name).HasMaxLength(150).IsRequired();
                e.HasIndex(c => c.Code).IsUnique();
                // Không xóa dây chuyền khi xóa giảng viên (xử lý trong UsersController)
                e.HasOne(c => c.Lecturer).WithMany()
                    .HasForeignKey(c => c.LecturerId)
                    .OnDelete(DeleteBehavior.NoAction);
            });

            builder.Entity<Enrollment>(e =>
            {
                e.HasIndex(x => new { x.CourseId, x.StudentId }).IsUnique();
                e.HasOne(x => x.Course).WithMany(c => c.Enrollments)
                    .HasForeignKey(x => x.CourseId).OnDelete(DeleteBehavior.Cascade);
                e.HasOne(x => x.Student).WithMany()
                    .HasForeignKey(x => x.StudentId).OnDelete(DeleteBehavior.NoAction);
            });

            builder.Entity<ClassSession>(e =>
            {
                e.Property(s => s.Title).HasMaxLength(150);
                e.HasOne(s => s.Course).WithMany(c => c.Sessions)
                    .HasForeignKey(s => s.CourseId).OnDelete(DeleteBehavior.Cascade);
            });

            builder.Entity<Attendance>(e =>
            {
                // Mỗi sinh viên chỉ điểm danh 1 lần / buổi
                e.HasIndex(a => new { a.SessionId, a.StudentId }).IsUnique();
                e.Property(a => a.Method).HasMaxLength(10);
                e.HasOne(a => a.Session).WithMany(s => s.Attendances)
                    .HasForeignKey(a => a.SessionId).OnDelete(DeleteBehavior.Cascade);
                e.HasOne(a => a.Student).WithMany()
                    .HasForeignKey(a => a.StudentId).OnDelete(DeleteBehavior.NoAction);
            });

            // Mọi DateTime đọc từ DB đều là giờ UTC -> JSON có chữ "Z", app đổi sang giờ VN đúng
            var utc = new ValueConverter<DateTime, DateTime>(
                v => v, v => DateTime.SpecifyKind(v, DateTimeKind.Utc));
            var utcNullable = new ValueConverter<DateTime?, DateTime?>(
                v => v, v => v.HasValue ? DateTime.SpecifyKind(v.Value, DateTimeKind.Utc) : v);

            foreach (var entity in builder.Model.GetEntityTypes())
            {
                foreach (var prop in entity.GetProperties())
                {
                    if (prop.ClrType == typeof(DateTime)) prop.SetValueConverter(utc);
                    else if (prop.ClrType == typeof(DateTime?)) prop.SetValueConverter(utcNullable);
                }
            }
        }
    }
}
