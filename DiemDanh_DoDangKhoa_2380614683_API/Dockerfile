# ===== Docker image cho Web API điểm danh - Đỗ Đăng Khoa - 2380614683 =====

# --- Bước 1: build + publish ---
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Restore trước để tận dụng cache khi chỉ sửa code
COPY DiemDanh_DoDangKhoa_2380614683_API.csproj ./
RUN dotnet restore DiemDanh_DoDangKhoa_2380614683_API.csproj

COPY . ./
RUN dotnet publish DiemDanh_DoDangKhoa_2380614683_API.csproj -c Release -o /app/publish --no-restore /p:UseAppHost=false

# --- Bước 2: chạy ---
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app

ENV ASPNETCORE_URLS=http://+:8080 \
    ASPNETCORE_ENVIRONMENT=Production
EXPOSE 8080

COPY --from=build /app/publish ./

# Chạy bằng user không phải root (có sẵn trong image .NET 8+)
USER $APP_UID

ENTRYPOINT ["dotnet", "DiemDanh_DoDangKhoa_2380614683_API.dll"]
