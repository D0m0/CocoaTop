@set IP=192.168.0.106
@"c:\Program Files (x86)\Applets\Putty\PSCP.EXE" -pw wsprintf src5\* mobile@%IP%:/User/CocoaTop
@"c:\Program Files (x86)\Applets\Putty\ansicon.exe" "c:\Program Files (x86)\Applets\Putty\PLINK.EXE" mobile@%IP% -pw wsprintf -batch <build.sh
@"c:\Program Files (x86)\Applets\Putty\ansicon.exe" "c:\Program Files (x86)\Applets\Putty\PLINK.EXE" root@%IP% -pw wsprintf -batch <buildtask.sh
@pause