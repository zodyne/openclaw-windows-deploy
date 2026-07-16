@echo off
REM OpenClaw Windows 一键部署 — 批处理启动器
REM 以管理员身份运行 PowerShell 执行部署脚本

echo ========================================
echo  OpenClaw Windows 一键部署
echo ========================================
echo.
echo 正在启动 PowerShell 部署脚本...
echo.

powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0deploy.ps1" %*

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo 部署失败，请检查错误信息。
    echo 详细文档: docs\INSTALL.zh-CN.md
    pause
    exit /b 1
)

echo.
echo 部署成功！按任意键退出...
pause >nul
