@echo off
color 0A

:: ============================================
:: USER CONFIGURABLE VARIABLES
:: Edit these paths to match your system
:: ============================================

:: Path to the shortcut you want to modify
set "SHORTCUT_PATH=C:\Users\YOURNAME\Desktop\proxy_toggle.lnk"

:: Icon file paths (when proxy is OFF / ON)
set "ICON_OFF=C:\Icons\toggle-off.ico"
set "ICON_ON=C:\Icons\toggle-on.ico"

:: Proxy server configuration
set "PROXY_ADDRESS=127.0.0.1"
set "PROXY_PORT=8085"

:: ============================================
:: END OF USER CONFIGURABLE VARIABLES
:: ============================================

:: Build full proxy string from variables
set "PROXY_FULL=%PROXY_ADDRESS%:%PROXY_PORT%"

:: ============================================
:: MAIN SCRIPT
:: ============================================

:: Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Please run this script as Administrator!
    echo Right-click the file and select "Run as administrator"
    timeout /t 3 >nul
    exit /b 1
)

:: Check current proxy status from registry
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" | find /i "ProxyEnable" > nul

if %errorlevel% equ 0 (
    :: Get current proxy enable status
    for /f "tokens=3" %%a in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable ^| find "ProxyEnable"') do (
        
        :: If proxy is enabled, disable it
        if "%%a"=="0x1" (
            echo [1/3] Disabling proxy...
            
            :: Clear proxy settings
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f > nul
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer /t REG_SZ /d "" /f > nul
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyOverride /t REG_SZ /d "" /f > nul
            netsh winhttp reset proxy > nul
            
            echo [2/3] Updating shortcut icon...
            
            :: Change shortcut icon to OFF state
            call :ChangeShortcutIcon "%SHORTCUT_PATH%" "%ICON_OFF%" 0
            
            if errorlevel 1 (
                echo [WARNING] Failed to change icon!
            ) else (
                echo [SUCCESS] Icon changed to OFF state
            )
            
            echo [3/3] Proxy disabled successfully!
            
        ) else (
            :: Proxy is disabled, enable it
            echo [1/4] Enabling proxy %PROXY_FULL%...
            
            :: Clear any existing proxy settings first
            reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /f > nul 2>&1
            reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer /f > nul 2>&1
            reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyOverride /f > nul 2>&1
            
            :: Set new proxy configuration
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 1 /f > nul
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer /d "%PROXY_FULL%" /t REG_SZ /f > nul
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyOverride /d "<local>" /t REG_SZ /f > nul
            
            echo [2/4] Updating shortcut icon...
            
            :: Change shortcut icon to ON state
            call :ChangeShortcutIcon "%SHORTCUT_PATH%" "%ICON_ON%" 0
            
            if errorlevel 1 (
                echo [WARNING] Failed to change icon!
            ) else (
                echo [SUCCESS] Icon changed to ON state
            )
            
            echo [3/4] Applying changes...
            echo [4/4] Proxy enabled successfully!
        )
    )
) else (
    echo [ERROR] Could not read proxy settings from registry
    timeout /t 2 >nul
    exit /b 1
)

:: Pause briefly to show results before closing
timeout /t 2 >nul
exit /b 0

:: ============================================
:: FUNCTION: Change Shortcut Icon
:: Parameters: %1 = Shortcut path, %2 = Icon path, %3 = Icon index (optional, default 0)
:: ============================================
:ChangeShortcutIcon
setlocal enabledelayedexpansion

set "_SHORTCUT=%~1"
set "_ICON=%~2"
set "_INDEX=%~3"
if "%_INDEX%"=="" set "_INDEX=0"

:: Validate shortcut file exists
if not exist "%_SHORTCUT%" (
    echo [ERROR] Shortcut not found: %_SHORTCUT%
    exit /b 1
)

:: Validate icon file exists
if not exist "%_ICON%" (
    echo [ERROR] Icon file not found: %_ICON%
    exit /b 1
)

:: Create temporary VBS script to change icon
set "_VBS=%TEMP%\change_icon_%RANDOM%.vbs"
(
    echo Set WshShell = CreateObject^("WScript.Shell"^)
    echo Set shortcut = WshShell.CreateShortcut^("%_SHORTCUT%"^)
    echo shortcut.IconLocation = "%_ICON%, %_INDEX%"
    echo shortcut.Save
) > "%_VBS%"

:: Execute VBS script silently
cscript //nologo "%_VBS%" 2>nul
set "_RESULT=%errorlevel%"

:: Clean up temporary file
del "%_VBS%" 2>nul

exit /b %_RESULT%
