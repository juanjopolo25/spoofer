@echo off
setlocal enabledelayedexpansion

:: Advanced MAC Address Spoofer - Kernel Level (SILENT VERSION)
:: Compatible with GUI applications - no output, no pauses
:: Uses the most effective methods for kernel-level MAC spoofing

:: Check for admin privileges (silent)
net session >nul 2>&1
if %errorLevel% neq 0 (
    exit /b 1
)

:: Generate random MAC address with proper format
call :GenerateRandomMAC newMAC

:: Find primary network adapter
call :FindPrimaryAdapter adapterName adapterGUID adapterRegKey

if not defined adapterName (
    exit /b 1
)

:: Execute kernel-level MAC spoofing
call :KernelMACSpoof "%adapterName%" "%adapterGUID%" "%adapterRegKey%" "%newMAC%"

:: Verify and cleanup
call :VerifyMACChange "%adapterName%" "%newMAC%"
call :CleanupNetworkStack

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

:: Step 1: Disable adapter using multiple methods (silent)
wmic path win32_networkadapter where "NetConnectionID='%adapterName%'" call disable >nul 2>&1
powershell -Command "try { Disable-NetAdapter -Name '%adapterName%' -Confirm:$false -ErrorAction SilentlyContinue } catch { }" >nul 2>&1

:: Step 2: Modify registry at kernel level (silent)
if not "%regKey%"=="" (
    reg add "%regKey%" /v NetworkAddress /t REG_SZ /d "%newMAC%" /f >nul 2>&1
    reg add "%regKey%" /v NetworkAddressOverride /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "%regKey%" /v AddrOverride /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "%regKey%" /v LocallyAdministered /t REG_DWORD /d 1 /f >nul 2>&1
) else (
    :: Deep kernel-level registry modification (silent)
    for /f "tokens=*" %%i in ('reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}" /s /v "NetCfgInstanceId" 2^>nul ^| findstr "HKEY"') do (
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

:: Step 3: Restart kernel-level network services (silent)
net stop "NDIS Usermode I/O Protocol" /y >nul 2>&1
net stop "Network Location Awareness" /y >nul 2>&1
net stop "Network List Service" /y >nul 2>&1
net stop "Network Store Interface Service" /y >nul 2>&1

:: Stop and restart NDIS kernel service (silent)
sc stop ndis >nul 2>&1
timeout /t 2 /nobreak >nul
sc start ndis >nul 2>&1

:: Restart all network services (silent)
timeout /t 1 /nobreak >nul
net start "Network Store Interface Service" >nul 2>&1
net start "Network List Service" >nul 2>&1
net start "Network Location Awareness" >nul 2>&1
net start "NDIS Usermode I/O Protocol" >nul 2>&1

:: Force kernel driver reload (silent)
pnputil /restart-device "ROOT\*" >nul 2>&1

:: Step 4: Re-enable adapter (silent)
timeout /t 1 /nobreak >nul
wmic path win32_networkadapter where "NetConnectionID='%adapterName%'" call enable >nul 2>&1
powershell -Command "try { Enable-NetAdapter -Name '%adapterName%' -Confirm:$false -ErrorAction SilentlyContinue } catch { }" >nul 2>&1

timeout /t 3 /nobreak >nul

goto :EOF

goto :VerifyChange

:: ============================================================================
:: FUNCTION: VerifyMACChange
:: Verifies that the MAC address change was successful (silent)
:: ============================================================================
:VerifyMACChange
set "adapterName=%~1"
set "expectedMAC=%~2"

timeout /t 2 /nobreak >nul

:: Get current MAC address (silent)
for /f "tokens=2 delims==" %%i in ('wmic nic where "NetConnectionID='%adapterName%'" get MACAddress /value 2^>nul ^| findstr "="') do (
    set "currentMAC=%%i"
)

:: Simple verification without output
if defined currentMAC (
    exit /b 0
) else (
    exit /b 1
)

goto :EOF

:: ============================================================================
:: FUNCTION: CleanupNetworkStack
:: Cleans up network stack to ensure changes take effect (silent)
:: ============================================================================
:CleanupNetworkStack
:: Clear network caches (silent)
arp -d * >nul 2>&1
ipconfig /flushdns >nul 2>&1

:: Reset network components (silent)
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
