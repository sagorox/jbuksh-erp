@echo off
title JB UKSH ERP DB Backup

set MYSQLDUMP=C:\xampp\mysql\bin\mysqldump.exe
set DB_NAME=jbuksh_erp
set DB_USER=root
set OUT_FILE=E:\jbuksh\database\full_dump_latest.sql

if not exist "%MYSQLDUMP%" (
    echo mysqldump not found:
    echo %MYSQLDUMP%
    pause
    exit /b 1
)

echo Backing up database...
"%MYSQLDUMP%" -u%DB_USER% --routines --triggers --single-transaction %DB_NAME% > "%OUT_FILE%"

if errorlevel 1 (
    echo Backup failed.
    pause
    exit /b 1
)

echo.
echo Backup completed:
echo %OUT_FILE%
pause