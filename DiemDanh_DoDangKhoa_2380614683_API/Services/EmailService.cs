using System.Net;
using System.Net.Mail;

namespace DiemDanh_DoDangKhoa_2380614683_API.Services
{
    /// Gửi email (mã xác nhận đăng ký, mã OTP đăng nhập) qua Gmail SMTP
    public class EmailService
    {
        private readonly IConfiguration _config;
        private readonly ILogger<EmailService> _logger;

        public EmailService(IConfiguration config, ILogger<EmailService> logger)
        {
            _config = config;
            _logger = logger;
        }

        /// Đã cấu hình Gmail trong appsettings.json chưa
        public bool IsConfigured =>
            !string.IsNullOrWhiteSpace(_config["Email:User"]) &&
            !string.IsNullOrWhiteSpace(_config["Email:AppPassword"]);

        /// Trả về true nếu gửi thành công
        public async Task<bool> SendAsync(string to, string subject, string htmlBody)
        {
            if (!IsConfigured)
            {
                _logger.LogWarning("[EMAIL chưa cấu hình] Tới: {To} | {Subject}", to, subject);
                return false;
            }

            try
            {
                var user = _config["Email:User"]!;
                using var client = new SmtpClient(_config["Email:Host"] ?? "smtp.gmail.com",
                    int.Parse(_config["Email:Port"] ?? "587"))
                {
                    EnableSsl = true,
                    Credentials = new NetworkCredential(user, _config["Email:AppPassword"])
                };
                using var mail = new MailMessage
                {
                    From = new MailAddress(user, _config["Email:FromName"] ?? "Điểm danh SV"),
                    Subject = subject,
                    Body = htmlBody,
                    IsBodyHtml = true
                };
                mail.To.Add(to);
                await client.SendMailAsync(mail);
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Gửi email tới {To} thất bại", to);
                return false;
            }
        }

        public static string CodeEmail(string fullName, string title, string code) => $@"
<div style='font-family:Arial,sans-serif;max-width:480px;margin:auto'>
  <h2 style='color:#3949ab'>Điểm danh sinh viên</h2>
  <p>Xin chào <b>{WebUtility.HtmlEncode(fullName)}</b>,</p>
  <p>{title}:</p>
  <p style='font-size:32px;font-weight:bold;letter-spacing:8px;color:#3949ab'>{code}</p>
  <p>Mã có hiệu lực trong vài phút. Không chia sẻ mã này cho người khác.</p>
</div>";
    }
}
