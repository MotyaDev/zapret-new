@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

:: ===== CONFIGURATION =====
set "VERSION=2.0"
set "SERVICE_NAME=zapret"
set "ROOT=%~dp0.."
set "BIN=%ROOT%\bin"
set "CONFIG=%ROOT%\config"
set "DATA=%ROOT%\data"
:: =========================

:: Check admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Требуются права администратора
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

if "%1"=="install" goto install_direct
if "%1"=="remove" goto remove_direct
if "%1"=="status" goto status_direct

:menu
cls
echo.
echo ========== ZAPRET SERVICE MANAGER v%VERSION% ==========
echo.
echo 1. Установить сервис
echo 2. Удалить сервис
echo 3. Проверить статус
echo 4. Диагностика
echo 0. Выход
echo.
set /p choice="Выберите действие: "

if "%choice%"=="1" goto install
if "%choice%"=="2" goto remove
if "%choice%"=="3" goto status
if "%choice%"=="4" goto diagnostics
if "%choice%"=="0" exit /b
goto menu

:: ==================== INSTALL ====================
:install
cls
echo.
echo === Доступные пресеты ===
echo.
set count=0
for %%F in ("%CONFIG%\*.cmd") do (
    set /a count+=1
    echo !count!. %%~nxF
    set "preset!count!=%%F"
)
if %count%==0 (
    call :error "Не найдены пресеты в %CONFIG%"
    goto menu
)
echo.
set /p selection="Выберите пресет (1-%count%): "
if not defined preset%selection% (
    call :error "Неверный выбор"
    goto menu
)
set "selected=!preset%selection%!"
goto do_install

:install_direct
set "selected=%~2"
if not exist "%selected%" (
    call :error "Пресет не найден: %selected%"
    exit /b 1
)
goto do_install

:do_install
echo.
echo [*] Парсинг пресета: %selected%
call :parse_preset "%selected%"
if %errorlevel% neq 0 (
    call :error "Ошибка парсинга пресета"
    pause
    goto menu
)

echo [*] Остановка старого сервиса...
sc stop %SERVICE_NAME% >nul 2>&1
sc delete %SERVICE_NAME% >nul 2>&1

echo [*] Создание сервиса...
echo DEBUG: %PARSED_CMD%
sc create %SERVICE_NAME% binPath= %PARSED_CMD% DisplayName= "Zapret DPI Bypass" start= auto >nul
if %errorlevel% neq 0 (
    call :error "Ошибка создания сервиса"
    sc create %SERVICE_NAME% binPath= %PARSED_CMD% DisplayName= "Zapret DPI Bypass" start= auto
    pause
    goto menu
)

sc description %SERVICE_NAME% "DPI bypass для обхода блокировок" >nul
timeout /t 1 >nul

echo [*] Запуск сервиса...
sc start %SERVICE_NAME% >nul
if %errorlevel% neq 0 (
    call :error "Ошибка запуска сервиса"
    pause
    goto menu
)

call :success "Сервис успешно установлен и запущен!"
if "%1"=="install" exit /b 0
pause
goto menu

:: ==================== REMOVE ====================
:remove
:remove_direct
cls
echo.
echo [*] Остановка сервиса...
sc stop %SERVICE_NAME% >nul 2>&1

echo [*] Удаление сервиса...
sc delete %SERVICE_NAME% >nul 2>&1

call :success "Сервис удален"
if "%1"=="remove" exit /b 0
pause
goto menu

:: ==================== STATUS ====================
:status
:status_direct
cls
echo.
echo === Статус сервиса ===
sc query %SERVICE_NAME% 2>nul | find "STATE" || echo Сервис не установлен
echo.
echo === Процесс winws.exe ===
tasklist /FI "IMAGENAME eq winws.exe" 2>nul | find /I "winws.exe" && (
    call :success "winws.exe запущен"
) || (
    call :error "winws.exe не найден"
)
echo.
if "%1"=="status" exit /b 0
pause
goto menu

:: ==================== DIAGNOSTICS ====================
:diagnostics
cls
echo.
echo === Диагностика ===
echo.

echo [*] Проверка файлов...
if exist "%BIN%\winws.exe" (call :success "winws.exe найден") else (call :error "winws.exe НЕ найден")
if exist "%BIN%\WinDivert.dll" (call :success "WinDivert.dll найден") else (call :error "WinDivert.dll НЕ найден")
if exist "%BIN%\WinDivert64.sys" (call :success "WinDivert64.sys найден") else (call :error "WinDivert64.sys НЕ найден")

echo.
echo [*] Проверка портов...
netstat -ano | findstr ":80.*LISTENING" >nul 2>&1 && (
    call :warning "Порт 80 занят"
) || (
    call :success "Порт 80 свободен"
)
netstat -ano | findstr ":443.*LISTENING" >nul 2>&1 && (
    call :warning "Порт 443 занят"
) || (
    call :success "Порт 443 свободен"
)

echo.
echo [*] Проверка конфликтных программ...
tasklist /FI "IMAGENAME eq AdguardSvc.exe" 2>nul | find /I "AdguardSvc.exe" >nul && call :warning "Найден Adguard (может конфликтовать)"
sc query | findstr /I "Killer" >nul && call :warning "Найдены Killer services (конфликтуют)"

echo.
pause
goto menu

:: ==================== PARSE PRESET ====================
:parse_preset
set "preset_file=%~1"
set "args_line="
set "capture=0"

for /f "usebackq delims=" %%L in ("%preset_file%") do (
    set "line=%%L"
    
    if !capture!==0 (
        echo !line! | findstr /I "winws.exe" >nul
        if !errorlevel!==0 set "capture=1"
    )
    
    if !capture!==1 (
        :: Remove ^ continuation character and append
        set "line=!line:^=!"
        set "args_line=!args_line! !line!"
    )
)

:: Remove "start" command wrapper
set "args_line=!args_line:*start=!"
:: Extract everything after winws.exe
for /f "tokens=1,* delims= " %%A in ("!args_line!") do (
    if "%%A"=="" (
        set "args_line="
    ) else (
        set "test=%%A"
        if "!test:winws.exe=!" neq "!test!" (
            set "args_line=%%B"
        )
    )
)

:: Find exe path
set "exe_path=%BIN%\winws.exe"

:: Substitute path variables
set "args_line=!args_line:%%~dp0..\bin\=%BIN%\!"
set "args_line=!args_line:%%~dp0..\data\hostlists\=%DATA%\hostlists\!"
set "args_line=!args_line:%%~dp0..\data\ipsets\=%DATA%\ipsets\!"
set "args_line=!args_line:%%~dp0..\data\payloads\=%DATA%\payloads\!"
set "args_line=!args_line:%%~dp0=%ROOT%\!"

:: Clean up extra spaces and quotes
set "args_line=!args_line:  = !"
set "args_line=!args_line:""="!"

:: Build final command - sc.exe needs special quoting
set PARSED_CMD="%exe_path%" !args_line!
exit /b 0

:: ==================== HELPERS ====================
:success
powershell -Command "Write-Host '[OK] %~1' -ForegroundColor Green"
exit /b

:error
powershell -Command "Write-Host '[X] %~1' -ForegroundColor Red"
exit /b

:warning
powershell -Command "Write-Host '[!] %~1' -ForegroundColor Yellow"
exit /b
