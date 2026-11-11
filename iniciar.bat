@echo off
setlocal
cd /d "%~dp0"

:: 1. Verifica se o ambiente virtual .venv ja existe. Se nao, cria e instala dependencias
if not exist ".venv\Scripts\python.exe" (
    echo [*] Ambiente virtual .venv nao encontrado.
    echo [*] Criando ambiente virtual isolado...

    py -3.13 -m venv .venv >nul 2>&1
    if errorlevel 1 (
        python -m venv .venv
    )

    if not exist ".venv\Scripts\python.exe" (
        echo [ERRO] Falha ao criar o ambiente virtual .venv.
        echo Verifique se o Python esta instalado no sistema.
        pause
        exit /b 1
    )

    echo [*] Instalando dependencias necessarias: PyQt6, psutil, pytest...
    call .venv\Scripts\python.exe -m pip install --upgrade pip >nul 2>&1
    call .venv\Scripts\python.exe -m pip install -r requirements.txt
    if errorlevel 1 (
        echo [ERRO] Falha ao instalar as dependencias em requirements.txt.
        pause
        exit /b 1
    )
    echo [*] Ambiente virtual configurado com sucesso!
)

:: 2. Verifica se ja possui privilegios de Administrador
net session >nul 2>&1
if %errorlevel% equ 0 goto :RUN

:: 3. Se nao estiver elevado e for chamado sem argumentos (clique duplo na GUI), solicita elevacao UAC
if "%~1"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\" __elevated\"' -Verb runAs -WindowStyle Hidden"
    exit /b
)

:RUN
if "%~1"=="__elevated" shift

:: 4. Executa sempre pelo Python do ambiente virtual isolado .venv
call .venv\Scripts\python.exe main.py %*
exit /b
