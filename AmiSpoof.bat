@echo off
REM AmiSpoof.bat - AMI Driver Management for BIOS Spoofing
REM Handles installation, operation, and cleanup of AMI drivers

setlocal enabledelayedexpansion

REM Check for administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    exit /b 1
)

REM Parse command line arguments
set OPERATION=install
if "%1"=="cleanup" set OPERATION=cleanup
if "%1"=="uninstall" set OPERATION=cleanup

REM Define paths and service names
set DRIVER_PATH=%~dp0
set AMI_FL_DRIVER=%DRIVER_PATH%amifldrv64.sys
set AMI_GEN_DRIVER=%DRIVER_PATH%amigendrv64.sys
set AMIDEWIN_EXE=%DRIVER_PATH%AMIDEWINx64.EXE
set FL_SERVICE=amifldrv64
set GEN_SERVICE=amigendrv64

if "%OPERATION%"=="cleanup" goto cleanup_drivers

REM === INSTALLATION PHASE ===

REM Verify required files exist
if not exist "%AMI_FL_DRIVER%" (
    exit /b 1
)

if not exist "%AMI_GEN_DRIVER%" (
    exit /b 1
)

if not exist "%AMIDEWIN_EXE%" (
    exit /b 1
)

REM Stop and remove any existing services
sc stop "%FL_SERVICE%" >nul 2>&1
sc stop "%GEN_SERVICE%" >nul 2>&1
timeout /t 2 >nul
sc delete "%FL_SERVICE%" >nul 2>&1
sc delete "%GEN_SERVICE%" >nul 2>&1

REM Create and start AMI Flash Driver service
sc create "%FL_SERVICE%" binPath= "%AMI_FL_DRIVER%" type= kernel start= demand error= normal DisplayName= "AMI Flash Driver" >nul 2>&1
if %errorLevel% neq 0 (
    goto error_exit
)

sc start "%FL_SERVICE%" >nul 2>&1

REM Create and start AMI Generic Driver service
sc create "%GEN_SERVICE%" binPath= "%AMI_GEN_DRIVER%" type= kernel start= demand error= normal DisplayName= "AMI Generic Driver" >nul 2>&1
if %errorLevel% neq 0 (
    goto error_exit
)

sc start "%GEN_SERVICE%" >nul 2>&1

REM Wait for drivers to initialize
timeout /t 5 >nul

goto normal_exit

REM === CLEANUP PHASE ===
:cleanup_drivers

sc stop "%FL_SERVICE%" >nul 2>&1
sc stop "%GEN_SERVICE%" >nul 2>&1

timeout /t 3 >nul

sc delete "%FL_SERVICE%" >nul 2>&1
sc delete "%GEN_SERVICE%" >nul 2>&1

goto normal_exit

:error_exit
sc stop "%FL_SERVICE%" >nul 2>&1
sc stop "%GEN_SERVICE%" >nul 2>&1
sc delete "%FL_SERVICE%" >nul 2>&1
sc delete "%GEN_SERVICE%" >nul 2>&1
exit /b 1

:normal_exit
exit /b 0
