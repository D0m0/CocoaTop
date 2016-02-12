@echo off
echo 1. iPhone
echo 2. iPad 1
echo 3. iPad Black
echo 4. iPad White
echo 5. iPhone 4S
CHOICE /C 12345 /N /M "Which will you choose? "
IF ERRORLEVEL 5 SET DIP=192.168.0.111
IF ERRORLEVEL 4 SET DIP=192.168.0.110
IF ERRORLEVEL 3 SET DIP=192.168.0.104
IF ERRORLEVEL 2 SET DIP=192.168.0.106 & SET SUFFIX=5
IF ERRORLEVEL 1 SET DIP=192.168.0.109
set SIP=192.168.0.107
echo Copying CocoaTop%SUFFIX% from %SIP% to %DIP%
"c:\Program Files (x86)\Applets\Putty\PSCP.EXE" -pw wsprintf root@%SIP%:/Applications/CocoaTop.app/CocoaTop CocoaTop%SUFFIX%
"c:\Program Files (x86)\Applets\Putty\PSCP.EXE" -pw wsprintf CocoaTop%SUFFIX% root@%DIP%:/Applications/CocoaTop.app/CocoaTop%SUFFIX%
pause
