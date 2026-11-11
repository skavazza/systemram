@echo off
setlocal
cd /d "%~dp0"

:: 1. Verifica se ja possui privilegios de Administrador
net session >nul 2>&1
if %errorlevel% equ 0 goto :RUN

:: 2. Se nao estiver elevado e for chamado sem argumentos (clique duplo na GUI), solicita elevacao UAC
if "%~1"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\" __elevated\"' -Verb runAs -WindowStyle Hidden"
    exit /b
)

:RUN
if "%~1"=="__elevated" shift

:: 3. Verifica se o Python 3.13 (com PyQt6) esta disponivel
py -3.13 -c "import PyQt6" >nul 2>&1
if %errorlevel% equ 0 goto :PY313

:: 4. Fallback para python padrao
python main.py %*
exit /b

:PY313
py -3.13 main.py %*
exit /b
