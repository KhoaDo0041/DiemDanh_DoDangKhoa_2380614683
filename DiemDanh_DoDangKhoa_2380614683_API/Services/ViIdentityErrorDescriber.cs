using Microsoft.AspNetCore.Identity;

namespace DiemDanh_DoDangKhoa_2380614683_API.Services
{
    /// Thông báo lỗi Identity bằng tiếng Việt (mặc định là tiếng Anh)
    public class ViIdentityErrorDescriber : IdentityErrorDescriber
    {
        public override IdentityError InvalidUserName(string? userName) => new()
        {
            Code = nameof(InvalidUserName),
            Description = $"Tên đăng nhập '{userName}' không hợp lệ: chỉ dùng chữ không dấu, số và . _ - @ + (không có dấu cách)"
        };

        public override IdentityError DuplicateUserName(string userName) => new()
        {
            Code = nameof(DuplicateUserName),
            Description = $"Tên đăng nhập '{userName}' đã tồn tại"
        };

        public override IdentityError InvalidEmail(string? email) => new()
        {
            Code = nameof(InvalidEmail),
            Description = $"Email '{email}' không hợp lệ"
        };

        public override IdentityError DuplicateEmail(string email) => new()
        {
            Code = nameof(DuplicateEmail),
            Description = $"Email '{email}' đã được sử dụng"
        };

        public override IdentityError PasswordTooShort(int length) => new()
        {
            Code = nameof(PasswordTooShort),
            Description = $"Mật khẩu phải có ít nhất {length} ký tự"
        };

        public override IdentityError PasswordRequiresDigit() => new()
        {
            Code = nameof(PasswordRequiresDigit),
            Description = "Mật khẩu phải có ít nhất 1 chữ số (0-9)"
        };

        public override IdentityError PasswordRequiresLower() => new()
        {
            Code = nameof(PasswordRequiresLower),
            Description = "Mật khẩu phải có ít nhất 1 chữ thường (a-z)"
        };

        public override IdentityError PasswordRequiresUpper() => new()
        {
            Code = nameof(PasswordRequiresUpper),
            Description = "Mật khẩu phải có ít nhất 1 chữ hoa (A-Z)"
        };

        public override IdentityError PasswordRequiresNonAlphanumeric() => new()
        {
            Code = nameof(PasswordRequiresNonAlphanumeric),
            Description = "Mật khẩu phải có ít nhất 1 ký tự đặc biệt (ví dụ @, #, !)"
        };
    }
}
