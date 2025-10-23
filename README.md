# zapret-newtochno

DPI bypass tool для обхода блокировок YouTube, Discord и других сервисов.

## Быстрый старт

1. Запустите **service-run.bat** (автоматически запросит права админа)
2. Выберите "1. Установить сервис"
3. Выберите нужный пресет
4. Готово! Сервис работает

## Управление сервисом

### Через меню (рекомендуется)
```cmd
service-run.bat
```

### Через командную строку
```cmd
:: Установка
scripts\service-manager.cmd install "config\general.cmd"

:: Удаление
scripts\service-manager.cmd remove

:: Статус
scripts\service-manager.cmd status
```

## Структура проекта

```
/
├── bin/                    # Исполняемые файлы
│   ├── winws.exe          # Основной движок DPI bypass
│   ├── WinDivert.*        # Драйвер перехвата пакетов
│   └── elevator.exe       # Запрос прав администратора
│
├── config/                 # Конфигурации (пресеты)
│   ├── general.cmd        # Универсальная конфигурация
│   ├── mypreset.cmd       # Пользовательский пресет
│   └── preset_russia*.cmd # Пресеты для России
│
├── data/                   # Данные
│   ├── hostlists/         # Списки доменов
│   ├── ipsets/            # Списки IP адресов  
│   └── payloads/          # Бинарные пакеты для обмана DPI
│
├── scripts/                # Вспомогательные скрипты
│   ├── service-manager.cmd # Менеджер сервиса (основной)
│   └── windivert_delete.cmd
│
├── docs/                   # Документация
│
├── service-run.bat         # Запуск менеджера сервиса
└── service.bat             # Легаси-обертка
```

## Создание своих пресетов

Создайте файл `config/custom.cmd`:

```cmd
start "zapret" /min "%~dp0..\bin\winws.exe" ^
--wf-tcp=80,443 ^
--filter-tcp=443 --hostlist="%~dp0..\data\hostlists\list-youtube.txt" ^
--dpi-desync=fake,split --dpi-desync-repeats=6
```

## Требования

- Windows 7+ (x64)
- Права администратора

---

**Версия:** 2.0  
**Репозиторий:** https://github.com/Flowseal/zapret-discord-youtube
