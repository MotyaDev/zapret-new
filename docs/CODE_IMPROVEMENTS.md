# Рекомендации по улучшению кода

## 1. Структура проекта

### Текущие проблемы:
- Все файлы в корневой папке - плохая организация
- Конфигурационные файлы смешаны с бинарниками
- Нет четкого разделения между кодом и данными

### Предложения:
```
/
├── /bin/              # Все исполняемые файлы
│   ├── winws.exe
│   ├── elevator.exe
│   └── WinDivert.*
├── /config/           # Конфигурации
│   ├── general.cmd
│   ├── mypreset.cmd
│   └── *.cmd
├── /data/             # Данные
│   ├── /hostlists/
│   │   └── list-youtube.txt
│   ├── /ipsets/
│   │   └── ipset-all.txt
│   └── /payloads/
│       └── *.bin
├── /scripts/          # Служебные скрипты
│   ├── service.bat
│   └── windivert_delete.cmd
└── /docs/             # Документация
    ├── WARP.md
    └── README.md
```

## 2. Улучшение service.bat

### Проблемы:
- Монолитный скрипт на 533 строки
- Сложная логика парсинга
- Отсутствие функций повторного использования
- Нет валидации входных данных

### Предложения:

#### 2.1 Модульность
Разделить на отдельные файлы:
- `service-core.bat` - основная логика
- `service-parser.bat` - парсинг конфигов
- `service-diagnostics.bat` - диагностика
- `service-updater.bat` - обновления

#### 2.2 Валидация
```batch
:validate_preset
set "preset_file=%~1"
if not exist "%preset_file%" (
    call :PrintRed "Error: Preset file not found: %preset_file%"
    exit /b 1
)
if not "%preset_file:~-4%" == ".cmd" if not "%preset_file:~-4%" == ".bat" (
    call :PrintRed "Error: Invalid file type. Expected .cmd or .bat"
    exit /b 1
)
exit /b 0
```

#### 2.3 Логирование
```batch
set "LOG_FILE=%~dp0logs\service_%date:~-4,4%%date:~-7,2%%date:~-10,2%.log"

:log_message
echo [%date% %time%] %~1 >> "%LOG_FILE%"
echo %~1
exit /b
```

## 3. Улучшение конфигурационных файлов

### Проблемы:
- Нет комментариев о назначении параметров
- Сложно понять, какие параметры для чего
- Дублирование кода между preset файлами

### Предложения:

#### 3.1 Добавить конфигурационный JSON/YAML
```json
{
  "version": "1.8.1",
  "presets": {
    "general": {
      "description": "General-purpose DPI bypass",
      "filters": [
        {
          "protocol": "tcp",
          "port": 80,
          "techniques": ["fake", "fakedsplit"],
          "autottl": 2,
          "fooling": "md5sig"
        },
        {
          "protocol": "tcp",
          "port": 443,
          "hostlist": "list-youtube.txt",
          "techniques": ["fake", "multidisorder"],
          "splitPos": ["1", "midsld"],
          "repeats": 11
        }
      ]
    }
  }
}
```

#### 3.2 Генератор .cmd из JSON
Написать PowerShell скрипт для генерации .cmd файлов из JSON конфигурации

## 4. Улучшение диагностики

### Текущие проблемы:
- Диагностика только при запуске вручную
- Нет автоматических проверок перед установкой
- Нет проверки конфликтов портов

### Предложения:

```batch
:check_port_conflicts
netstat -ano | findstr ":80 " | findstr "LISTENING" > nul
if %errorlevel% == 0 (
    call :PrintYellow "Warning: Port 80 is already in use"
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":80 "') do (
        tasklist /fi "pid eq %%a" /fo csv /nh
    )
)
exit /b

:pre_install_check
call :check_port_conflicts
call :check_windivert_version
call :check_admin_rights
call :check_conflicting_software
exit /b
```

## 5. Безопасность

### Проблемы:
- Нет проверки целостности бинарных файлов
- Обновления скачиваются без проверки подписи
- Нет защиты от замены исполняемых файлов

### Предложения:

#### 5.1 Проверка хеш-сумм
```batch
:verify_binary_integrity
set "HASH_FILE=%~dp0checksums.txt"
if not exist "%HASH_FILE%" (
    call :PrintYellow "Warning: Checksum file not found"
    exit /b 1
)

for /f "tokens=1,2" %%a in (%HASH_FILE%) do (
    set "expected_hash=%%a"
    set "file=%%b"
    
    for /f %%h in ('certutil -hashfile "%~dp0%%b" SHA256 ^| findstr /v ":" ^| findstr /v "CertUtil"') do (
        if not "%%h" == "%%a" (
            call :PrintRed "Error: Hash mismatch for %%b"
            exit /b 1
        )
    )
)
call :PrintGreen "All checksums verified"
exit /b 0
```

#### 5.2 Проверка цифровых подписей
```powershell
function Verify-BinarySignature {
    param($FilePath)
    
    $signature = Get-AuthenticodeSignature -FilePath $FilePath
    if ($signature.Status -ne "Valid") {
        Write-Warning "Invalid signature for $FilePath"
        return $false
    }
    return $true
}
```

## 6. Обработка ошибок

### Проблемы:
- Минимальная обработка ошибок
- Нет rollback при неудачной установке
- Неинформативные сообщения об ошибках

### Предложения:

```batch
:install_service_safe
:: Backup current state
call :backup_service_state

:: Try to install
call :service_install
if %errorlevel% neq 0 (
    call :PrintRed "Installation failed. Rolling back..."
    call :restore_service_state
    exit /b 1
)

:: Verify installation
call :verify_service_running
if %errorlevel% neq 0 (
    call :PrintRed "Service not running. Rolling back..."
    call :restore_service_state
    exit /b 1
)

call :PrintGreen "Service installed successfully"
exit /b 0

:backup_service_state
sc query zapret > "%TEMP%\zapret_backup.txt" 2>&1
exit /b

:restore_service_state
if exist "%TEMP%\zapret_backup.txt" (
    call :service_remove
    :: Restore previous state if needed
)
exit /b
```

## 7. Тестирование

### Добавить:
- Автоматические тесты для парсинга конфигураций
- Тесты для проверки DPI bypass (пинг заблокированных сайтов)
- Unit тесты для функций батников

```batch
:test_parser
echo Running parser tests...

call :parse_preset_file "test_configs\valid.cmd"
if %errorlevel% neq 0 (
    call :PrintRed "FAIL: Valid config failed to parse"
    exit /b 1
)

call :parse_preset_file "test_configs\invalid.cmd"
if %errorlevel% equ 0 (
    call :PrintRed "FAIL: Invalid config should have failed"
    exit /b 1
)

call :PrintGreen "PASS: All parser tests passed"
exit /b 0

:test_connectivity
echo Testing connectivity to blocked sites...
set "test_sites=youtube.com discord.com"

for %%s in (%test_sites%) do (
    curl -s -o nul -w "%%{http_code}" "https://%%s" > "%TEMP%\status.txt"
    set /p status=<"%TEMP%\status.txt"
    if !status! == 200 (
        call :PrintGreen "PASS: %%s is accessible"
    ) else (
        call :PrintRed "FAIL: %%s returned status !status!"
    )
)
exit /b 0
```

## 8. Документация кода

### Добавить комментарии:
```batch
:: ============================================================================
:: Function: parse_preset_file
:: Description: Parses a preset .cmd/.bat file and extracts winws.exe arguments
:: Parameters:
::   %1 - Path to preset file
:: Returns:
::   0 on success, 1 on error
::   Sets %ARGS% variable with parsed arguments
:: ============================================================================
:parse_preset_file
...
```

## 9. Конфигурационные переменные

### Вынести хардкод в начало файла:
```batch
:: ============================================================================
:: CONFIGURATION SECTION
:: ============================================================================
set "APP_VERSION=1.8.1"
set "SERVICE_NAME=zapret"
set "SERVICE_DISPLAY_NAME=Zapret DPI Bypass"
set "GITHUB_REPO=Flowseal/zapret-discord-youtube"
set "GITHUB_API=https://api.github.com/repos/%GITHUB_REPO%"
set "UPDATE_CHECK_URL=https://raw.githubusercontent.com/%GITHUB_REPO%/main/.service/version.txt"

set "LOG_ENABLED=1"
set "LOG_DIR=%~dp0logs"
set "BACKUP_ENABLED=1"
set "BACKUP_DIR=%~dp0backups"

:: Conflicting software to check
set "CONFLICT_APPS=AdguardSvc.exe Killer TracSrvWrapper EPWD SmartByte"
:: ============================================================================
```

## 10. PowerShell миграция

### Рассмотреть переписывание на PowerShell:
- Лучшая обработка ошибок
- Встроенная работа с JSON
- Более читаемый код
- Лучшие возможности для тестирования

```powershell
# service.ps1
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Install', 'Remove', 'Status', 'Diagnose')]
    [string]$Action = 'Menu'
)

function Install-ZapretService {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$PresetFile
    )
    
    try {
        $config = Get-Content $PresetFile | ConvertFrom-Json
        # ... остальная логика
    }
    catch {
        Write-Error "Failed to install service: $_"
        return $false
    }
    return $true
}
```

## Приоритеты внедрения:

1. **Высокий приоритет:**
   - Улучшение обработки ошибок (6)
   - Добавление логирования (2.3)
   - Реорганизация структуры папок (1)

2. **Средний приоритет:**
   - Модульность service.bat (2.1)
   - Улучшение диагностики (4)
   - Добавление проверок безопасности (5)

3. **Низкий приоритет:**
   - Миграция на PowerShell (10)
   - JSON конфигурация (3.1)
   - Автоматические тесты (7)
