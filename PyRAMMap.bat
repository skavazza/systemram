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

:: 2. Executa a aplicacao diretamente pelo Python do ambiente virtual
call .venv\Scripts\python.exe main.py %*
if errorlevel 1 (
    echo.
    echo [AVISO] Processo finalizado com codigo %errorlevel%.
)
