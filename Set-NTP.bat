@echo off
echo Setting NTP server to pool.ntp.org...

REM Stop the Windows Time service
net stop w32time

REM Configure the NTP server
w32tm /config /manualpeerlist:"pool.ntp.org" /syncfromflags:manual /reliable:YES /update

REM Start the Windows Time service
net start w32time

REM Force synchronization
w32tm /resync

echo NTP server set to pool.ntp.org and time synchronized.
pause
