@echo off
REM Poseiden V2 MAC Address Spoofer
REM Compatible with Poseiden spoofing verification system

echo Starting MAC Address Spoofing... >nul 2>&1

REM Find physical network adapters (exclude virtual ones)
for /f "tokens=2 delims==" %%i in ('wmic path win32_networkadapter where "PhysicalAdapter=True and NetEnabled=True" get PNPDeviceID /value 2^>nul ^| findstr "PNPDeviceID"') do (
    set "DEVICE_ID=%%i"
    goto :found_device
)

:found_device
if "%DEVICE_ID%"=="" (
    echo No physical network adapter found. >nul 2>&1
    exit /b 1
)

REM Generate random MAC with proper OUI (first 3 bytes)
REM Use common OUI to avoid detection: 00:50:56 (VMware), 02:00:4C (Locally administered)
set /a "MAC1=2"
set /a "MAC2=%RANDOM% %% 256"
set /a "MAC3=%RANDOM% %% 256"
set /a "MAC4=%RANDOM% %% 256"
set /a "MAC5=%RANDOM% %% 256"
set /a "MAC6=%RANDOM% %% 256"

REM Convert to hex with proper formatting
call :dec2hex %MAC1% HEX1
call :dec2hex %MAC2% HEX2
call :dec2hex %MAC3% HEX3
call :dec2hex %MAC4% HEX4
call :dec2hex %MAC5% HEX5
call :dec2hex %MAC6% HEX6

REM Create MAC in registry format (no dashes)
set REG_MAC=%HEX1%%HEX2%%HEX3%%HEX4%%HEX5%%HEX6%

REM Find the registry key for the network adapter
for /f "tokens=*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}" /s /f "%DEVICE_ID%" 2^>nul ^| findstr "HKEY"') do (
    set "REG_KEY=%%a"
    goto :found_key
)

:found_key
if "%REG_KEY%"=="" (
    echo Registry key not found. >nul 2>&1
    exit /b 1
)

REM Get adapter name for netsh commands
for /f "tokens=2*" %%a in ('reg query "%REG_KEY%" /v "DriverDesc" 2^>nul ^| findstr "DriverDesc"') do (
    set "ADAPTER_NAME=%%b"
)

if "%ADAPTER_NAME%"=="" (
    echo Adapter name not found. >nul 2>&1
    exit /b 1
)

REM Apply MAC address change
echo Applying MAC address change... >nul 2>&1

REM Disable adapter
netsh interface set interface "%ADAPTER_NAME%" admin=disable >nul 2>&1
timeout /t 2 /nobreak >nul 2>&1

REM Set new MAC in registry
reg add "%REG_KEY%" /v "NetworkAddress" /t REG_SZ /d "%REG_MAC%" /f >nul 2>&1

REM Enable adapter
netsh interface set interface "%ADAPTER_NAME%" admin=enable >nul 2>&1
timeout /t 3 /nobreak >nul 2>&1

REM Restart network services for immediate effect
net stop "Network Location Awareness" /y >nul 2>&1
net start "Network Location Awareness" >nul 2>&1

echo MAC address spoofing completed successfully. >nul 2>&1
exit /b 0

:dec2hex
set /a "num=%1"
if %num% lss 16 (
    if %num% lss 10 (
        set "%2=0%num%"
    ) else (
        if %num%==10 set "%2=0A"
        if %num%==11 set "%2=0B"
        if %num%==12 set "%2=0C"
        if %num%==13 set "%2=0D"
        if %num%==14 set "%2=0E"
        if %num%==15 set "%2=0F"
    )
) else (
    set /a "high=%num% / 16"
    set /a "low=%num% %% 16"
    call :gethex %high% HEXH
    call :gethex %low% HEXL
    set "%2=%HEXH%%HEXL%"
)
goto :eof

:gethex
if %1==10 set "%2=A" & goto :eof
if %1==11 set "%2=B" & goto :eof
if %1==12 set "%2=C" & goto :eof
if %1==13 set "%2=D" & goto :eof
if %1==14 set "%2=E" & goto :eof
if %1==15 set "%2=F" & goto :eof
set "%2=%1"
goto :eof
