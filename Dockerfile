# ===== Docker image cho Web API điểm danh - Đỗ Đăng Khoa - 2380614683 =====
# Đặt ở thư mục gốc repo để Render (và docker build .) tìm thấy

# --- Bước 1: build + publish ---
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Restore trước để tận dụng cache khi chỉ sửa code
COPY DiemDanh_DoDangKhoa_2380614683_API/DiemDanh_DoDangKhoa_2380614683_API.csproj ./
RUN dotnet restore DiemDanh_DoDangKhoa_2380614683_API.csproj

COPY DiemDanh_DoDangKhoa_2380614683_API/ ./
RUN dotnet publish DiemDanh_DoDangKhoa_2380614683_API.csproj -c Release -o /app/publish --no-restore /p:UseAppHost=false

# --- Bước 2: chạy ---
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app

ENV ASPNETCORE_ENVIRONMENT=Production \
    PORT=8080
EXPOSE 8080

# Npgsql cần thư viện GSSAPI (thiếu thì log báo lỗi libgssapi_krb5.so.2)
RUN apt-get update && apt-get install -y --no-install-recommends libgssapi-krb5-2     && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/publish ./

# Chạy bằng user không phải root (có sẵn trong image .NET 8+)
USER $APP_UID

# Render cấp cổng qua biến PORT -> nghe đúng cổng đó (mặc định 8080)
ENTRYPOINT ["sh", "-c", "ASPNETCORE_URLS=http://+:${PORT} exec dotnet DiemDanh_DoDangKhoa_2380614683_API.dll"]
