using System.Security.Cryptography;
using System.Text;

namespace DiemDanh_DoDangKhoa_2380614683_API.Services
{
    /// QR ĐỘNG: mã 6 số đổi mỗi 15 giây, tính bằng HMAC(secret của buổi, bước thời gian).
    /// Chụp màn hình QR gửi cho bạn thì 15-30 giây sau đã hết hạn.
    public static class RotatingCode
    {
        public const int StepSeconds = 15;

        public static long CurrentStep() =>
            DateTimeOffset.UtcNow.ToUnixTimeSeconds() / StepSeconds;

        public static int SecondsLeft() =>
            StepSeconds - (int)(DateTimeOffset.UtcNow.ToUnixTimeSeconds() % StepSeconds);

        public static string NewSecret() =>
            Convert.ToBase64String(RandomNumberGenerator.GetBytes(32));

        public static string Compute(string secret, int sessionId, long step)
        {
            using var hmac = new HMACSHA256(Convert.FromBase64String(secret));
            var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes($"{sessionId}:{step}"));
            int value = ((hash[0] & 0x7f) << 24) | (hash[1] << 16) | (hash[2] << 8) | hash[3];
            return (value % 1_000_000).ToString("D6");
        }

        /// Chấp nhận mã hiện tại hoặc mã của 15 giây trước (bù thời gian quét)
        public static bool Verify(string secret, int sessionId, string code)
        {
            var step = CurrentStep();
            code = code.Trim();
            return code == Compute(secret, sessionId, step) || code == Compute(secret, sessionId, step - 1);
        }

        public static string QrContent(int sessionId, string code) => $"DIEMDANH:{sessionId}:{code}";

        /// Đọc "DIEMDANH:{id}:{code}"
        public static bool TryParse(string content, out int sessionId, out string code)
        {
            sessionId = 0;
            code = "";
            var parts = content.Trim().Split(':');
            if (parts.Length != 3 || parts[0] != "DIEMDANH") return false;
            if (!int.TryParse(parts[1], out sessionId)) return false;
            code = parts[2];
            return true;
        }
    }

    /// Khoảng cách GPS (mét) - công thức Haversine
    public static class Geo
    {
        public static double DistanceMeters(double lat1, double lon1, double lat2, double lon2)
        {
            const double R = 6371000;
            double dLat = (lat2 - lat1) * Math.PI / 180;
            double dLon = (lon2 - lon1) * Math.PI / 180;
            double a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                       Math.Cos(lat1 * Math.PI / 180) * Math.Cos(lat2 * Math.PI / 180) *
                       Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
            return R * 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        }
    }

    /// So khớp 2 vector khuôn mặt (các điểm đường viền ML Kit đã chuẩn hóa)
    public static class FaceMatcher
    {
        /// Khoảng cách trung bình giữa các điểm tương ứng; càng nhỏ càng giống
        public static double Distance(IReadOnlyList<double> a, IReadOnlyList<double> b)
        {
            if (a.Count == 0 || a.Count != b.Count || a.Count % 2 != 0) return double.MaxValue;
            double sum = 0;
            int points = a.Count / 2;
            for (int i = 0; i < a.Count; i += 2)
            {
                double dx = a[i] - b[i], dy = a[i + 1] - b[i + 1];
                sum += Math.Sqrt(dx * dx + dy * dy);
            }
            return sum / points;
        }
    }

    /// TÍNH NĂNG MỚI: CẢNH BÁO CẤM THI
    /// Tự tính số buổi vắng, số buổi còn được vắng, mức độ nguy cơ cấm thi.
    public static class ExamBanWarning
    {
        public const string Safe = "SAFE";        // an toàn
        public const string Warning = "WARNING";  // đã vắng >= nửa số buổi cho phép
        public const string Danger = "DANGER";    // vắng thêm 1 buổi nữa là bị cấm thi
        public const string Banned = "BANNED";    // đã vượt ngưỡng -> cấm thi

        public class Result
        {
            public int TotalSessions { get; set; }
            public int HeldSessions { get; set; }
            public int Attended { get; set; }
            public int Absences { get; set; }
            public int MaxAbsent { get; set; }
            public int Remaining { get; set; }
            public double AbsentPercent { get; set; }
            public string Level { get; set; } = Safe;
            public string Message { get; set; } = "";
        }

        public static Result Compute(int totalSessions, int maxAbsentPercent, int heldSessions, int attended)
        {
            int maxAbsent = (int)Math.Floor(totalSessions * maxAbsentPercent / 100.0);
            int absences = Math.Max(0, heldSessions - attended);
            int remaining = maxAbsent - absences;
            double absentPercent = totalSessions == 0 ? 0 : Math.Round(absences * 100.0 / totalSessions, 1);

            string level;
            string message;
            if (absences > maxAbsent)
            {
                level = Banned;
                message = $"Đã vắng {absences}/{totalSessions} buổi ({absentPercent}%), vượt mức {maxAbsentPercent}% - CẤM THI";
            }
            else if (absences > 0 && remaining == 0)
            {
                level = Danger;
                message = $"Đã vắng {absences} buổi - vắng thêm 1 buổi nữa sẽ bị CẤM THI!";
            }
            else if (absences > 0 && absences * 2 >= maxAbsent)
            {
                level = Warning;
                message = $"Đã vắng {absences} buổi, chỉ còn được vắng {remaining} buổi";
            }
            else
            {
                level = Safe;
                message = absences == 0
                    ? $"Chưa vắng buổi nào - được vắng tối đa {maxAbsent} buổi"
                    : $"Đã vắng {absences} buổi, còn được vắng {remaining} buổi";
            }

            return new Result
            {
                TotalSessions = totalSessions,
                HeldSessions = heldSessions,
                Attended = attended,
                Absences = absences,
                MaxAbsent = maxAbsent,
                Remaining = Math.Max(0, remaining),
                AbsentPercent = absentPercent,
                Level = level,
                Message = message
            };
        }
    }
}
