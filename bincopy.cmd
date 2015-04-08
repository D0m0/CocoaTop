@echo off
echo 1. iPhone
echo 2. iPad 1
echo 3. iPad Black
echo 4. iPad White
CHOICE /C 1234 /N /M "Which will you choose? "
IF ERRORLEVEL 1 SET DIP=192.168.0.109
IF ERRORLEVEL 2 SET DIP=192.168.0.106 & SET SUFFIX=5
IF ERRORLEVEL 3 SET DIP=192.168.0.104
IF ERRORLEVEL 4 SET DIP=192.168.0.110
set SIP=192.168.0.107
echo Copying CocoaTop%SUFFIX% from %SIP% to %DIP%
"c:\Program Files (x86)\Applets\Putty\PSCP.EXE" -pw wsprintf root@%SIP%:/Applications/CocoaTop.app/CocoaTop CocoaTop%SUFFIX%
"c:\Program Files (x86)\Applets\Putty\PSCP.EXE" -pw wsprintf CocoaTop%SUFFIX% root@%DIP%:/Applications/CocoaTop.app/CocoaTop%SUFFIX%
pause
