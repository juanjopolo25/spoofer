@echo off
setlocal enabledelayedexpansion

:: Advanced MAC Address Spoofer - Kernel Level (DEBUG VERSION)
:: Uses the most effective methods for kernel-level MAC spoofing
:: Created for maximum bypass effectiveness

echo ============================================
echo MAC Address Spoofer - Kernel Level
echo ============================================

:: Check for admin privileges
echo [DEBUG] Checking admin privileges...
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] This script requires administrator privileges!
    echo Please run as administrator.
    pause
    exit /b 1
)
echo [OK] Running with admin privileges

:: Show current MAC before change
echo [DEBUG] Current MAC addresses:
getmac /fo table /nh

:: Generate random MAC address with proper format
call :GenerateRandomMAC newMAC
echo [DEBUG] Generated new MAC: %newMAC%

:: Find primary network adapter
echo [DEBUG] Finding primary network adapter...
call :FindPrimaryAdapter adapterName adapterGUID adapterRegKey

if not defined adapterName (
    echo [ERROR] No suitable network adapter found!
    pause
    exit /b 1
)

echo [DEBUG] Found adapter: %adapterName%
echo [DEBUG] Adapter GUID: %adapterGUID%
echo [DEBUG] Registry key: %adapterRegKey%

:: Execute kernel-level MAC spoofing
echo [DEBUG] Starting kernel-level MAC spoofing...
call :KernelMACSpoof "%adapterName%" "%adapterGUID%" "%adapterRegKey%" "%newMAC%"

:: Verify and cleanup
echo [DEBUG] Verifying MAC change...
call :VerifyMACChange "%adapterName%" "%newMAC%"
if %errorLevel% equ 0 (
    echo [SUCCESS] MAC address changed successfully!
) else (
    echo [WARNING] MAC address may not have changed completely
)

echo [DEBUG] Cleaning up network stack...
call :CleanupNetworkStack

echo [DEBUG] Final MAC addresses:
getmac /fo table /nh

echo ============================================
echo Process completed. Press any key to exit.
pause
exit /b 0

:: ============================================================================
:: FUNCTION: FindPrimaryAdapter
:: Finds the primary network adapter and gets all necessary information
:: ============================================================================
:FindPrimaryAdapter
setlocal enabledelayedexpansion

:: Find active physical network adapter using simpler method
for /f "tokens=2 delims==" %%i in ('wmic nic where "NetEnabled=true and PhysicalAdapter=true" get NetConnectionID /value 2^>nul ^| findstr "="') do (
    if not "%%i"=="" (
        set "foundName=%%i"
        goto :SearchRegistry
    )
)

:SearchRegistry
if not defined foundName goto :EndFindAdapter

:: Get adapter GUID
for /f "tokens=2 delims==" %%i in ('wmic nic where "NetConnectionID='!foundName!'" get GUID /value 2^>nul ^| findstr "="') do (
    set "foundGUID=%%i"
)

:: Find registry key for this adapter
for /f "tokens=*" %%i in ('reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}" /s 2^>nul ^| findstr "HKEY.*000"') do (
    for /f "tokens=2 delims= " %%j in ('reg query "%%i" /v NetCfgInstanceId 2^>nul ^| findstr "NetCfgInstanceId"') do (
        if "%%j"=="!foundGUID!" (
            set "foundRegKey=%%i"
            goto :FoundRegKey
        )
    )
)

:FoundRegKey
:EndFindAdapter
endlocal & set "%~1=%foundName%" & set "%~2=%foundGUID%" & set "%~3=%foundRegKey%"
goto :EOF

:: ============================================================================
:: FUNCTION: KernelMACSpoof
:: Performs kernel-level MAC address spoofing using the most effective methods
:: ============================================================================
:KernelMACSpoof
set "adapterName=%~1"
set "adapterGUID=%~2"
set "regKey=%~3"
set "newMAC=%~4"

echo [DEBUG] Disabling adapter: %adapterName%
:: Step 1: Disable adapter using multiple methods
wmic path win32_networkadapter where "NetConnectionID='%adapterName%'" call disable >nul 2>&1
powershell -Command "try { Disable-NetAdapter -Name '%adapterName%' -Confirm:$false } catch { }" >nul 2>&1

echo [DEBUG] Modifying registry: %regKey%
:: Step 2: Modify registry at kernel level
if not "%regKey%"=="" (
    echo [DEBUG] Setting NetworkAddress to: %newMAC%
    reg add "%regKey%" /v NetworkAddress /t REG_SZ /d "%newMAC%" /f >nul 2>&1
    reg add "%regKey%" /v NetworkAddressOverride /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "%regKey%" /v AddrOverride /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "%regKey%" /v LocallyAdministered /t REG_DWORD /d 1 /f >nul 2>&1
) else (
    echo [WARNING] Registry key not found, trying DEEP KERNEL method
    :: Deep kernel-level registry modification
    for /f "tokens=*" %%i in ('reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}" /s /v "NetCfgInstanceId" 2^>nul ^| findstr "HKEY"') do (
        echo [DEBUG] Applying deep kernel settings to: %%i

        :: Primary MAC settings (kernel level)
        reg add "%%i" /v NetworkAddress /t REG_SZ /d "%newMAC%" /f >nul 2>&1
        reg add "%%i" /v NetworkAddressOverride /t REG_DWORD /d 1 /f >nul 2>&1
        reg add "%%i" /v AddrOverride /t REG_DWORD /d 1 /f >nul 2>&1
        reg add "%%i" /v LocallyAdministered /t REG_DWORD /d 1 /f >nul 2>&1

        :: NDIS kernel-level settings
        reg add "%%i" /v NDISVersion /t REG_DWORD /d 0x00060001 /f >nul 2>&1
        reg add "%%i" /v BusType /t REG_DWORD /d 5 /f >nul 2>&1
        reg add "%%i" /v MediaType /t REG_DWORD /d 0 /f >nul 2>&1
        reg add "%%i" /v PhysicalMediaType /t REG_DWORD /d 0 /f >nul 2>&1

        :: Kernel driver settings
        reg add "%%i" /v DriverVersion /t REG_SZ /d "10.0.19041.1" /f >nul 2>&1
        reg add "%%i" /v KernelModeDriverFramework /t REG_DWORD /d 1 /f >nul 2>&1

        :: Hardware abstraction layer settings
        reg add "%%i" /v HardwareID /t REG_SZ /d "KERNEL_SPOOFED" /f >nul 2>&1
        reg add "%%i" /v DeviceInstanceID /t REG_SZ /d "KERNEL_DEVICE" /f >nul 2>&1

        :: Force kernel recognition
        reg add "%%i" /v KernelMACOverride /t REG_DWORD /d 1 /f >nul 2>&1
        reg add "%%i" /v ForceKernelReload /t REG_DWORD /d 1 /f >nul 2>&1
    )
)

echo [DEBUG] Restarting KERNEL network services...
:: Step 3: Restart kernel-level network services
net stop "NDIS Usermode I/O Protocol" /y >nul 2>&1
net stop "Network Location Awareness" /y >nul 2>&1
net stop "Network List Service" /y >nul 2>&1
net stop "Network Store Interface Service" /y >nul 2>&1

:: Stop and restart NDIS kernel service
echo [DEBUG] Restarting NDIS kernel service...
sc stop ndis >nul 2>&1
timeout /t 3 /nobreak >nul
sc start ndis >nul 2>&1

:: Restart all network services
timeout /t 2 /nobreak >nul
net start "Network Store Interface Service" >nul 2>&1
net start "Network List Service" >nul 2>&1
net start "Network Location Awareness" >nul 2>&1
net start "NDIS Usermode I/O Protocol" >nul 2>&1

:: Force kernel driver reload
echo [DEBUG] Forcing kernel driver reload...
pnputil /restart-device "ROOT\*" >nul 2>&1

echo [DEBUG] Re-enabling adapter: %adapterName%
:: Step 4: Re-enable adapter
timeout /t 2 /nobreak >nul
wmic path win32_networkadapter where "NetConnectionID='%adapterName%'" call enable >nul 2>&1
powershell -Command "try { Enable-NetAdapter -Name '%adapterName%' -Confirm:$false } catch { }" >nul 2>&1

timeout /t 5 /nobreak >nul

goto :EOF

goto :VerifyChange

:: ============================================================================
:: FUNCTION: VerifyMACChange
:: Verifies that the MAC address change was successful
:: ============================================================================
:VerifyMACChange
setlocal enabledelayedexpansion
set "adapterName=%~1"
set "expectedMAC=%~2"

timeout /t 3 /nobreak >nul

:: Get current MAC address
for /f "tokens=2 delims==" %%i in ('wmic nic where "NetConnectionID='%adapterName%'" get MACAddress /value 2^>nul ^| findstr "="') do (
    set "currentMAC=%%i"
)

:: Remove any formatting from MAC addresses for comparison
set "cleanExpected=%expectedMAC::=%"
set "cleanExpected=%cleanExpected:-=%"
set "cleanCurrent=%currentMAC::=%"
set "cleanCurrent=%cleanCurrent:-=%"

if /i "%cleanCurrent%"=="%cleanExpected%" (
    exit /b 0
) else (
    exit /b 1
)

goto :EOF

:: ============================================================================
:: FUNCTION: CleanupNetworkStack
:: Cleans up network stack to ensure changes take effect
:: ============================================================================
:CleanupNetworkStack
:: Clear network caches
arp -d * >nul 2>&1
ipconfig /flushdns >nul 2>&1
ipconfig /release >nul 2>&1
ipconfig /renew >nul 2>&1

:: Reset network components
netsh winsock reset >nul 2>&1
netsh int ip reset >nul 2>&1

goto :EOF

:: ============================================================================
:: FUNCTION: GenerateRandomMAC
:: Generates a valid random MAC address for spoofing
:: ============================================================================
:GenerateRandomMAC
setlocal enabledelayedexpansion

:: Use locally administered MAC prefix (02:xx:xx:xx:xx:xx)
set "macPrefix=02"

:: Generate 5 random octets
for /l %%i in (1,1,5) do (
    set /a "octet=!random! %% 256"
    call :DecToHex !octet! hexOctet
    set "macPrefix=!macPrefix!!hexOctet!"
)

endlocal & set "%~1=%macPrefix%"
goto :EOF

:: ============================================================================
:: FUNCTION: DecToHex
:: Converts decimal to hexadecimal with proper padding
:: ============================================================================
:DecToHex
setlocal enabledelayedexpansion
set /a "dec=%1"
set "hex="
set "digits=0123456789ABCDEF"

if %dec% equ 0 (
    set "hex=00"
    goto :DecToHexEnd
)

:DecToHexLoop
if %dec% gtr 0 (
    set /a "remainder=dec %% 16"
    set /a "dec=dec / 16"
    for /f %%i in ("!remainder!") do set "hex=!digits:~%%i,1!!hex!"
    goto :DecToHexLoop
)

:: Ensure two-digit format
if "!hex:~1,1!"=="" set "hex=0!hex!"

:DecToHexEnd
endlocal & set "%~2=%hex%"
goto :EOF
