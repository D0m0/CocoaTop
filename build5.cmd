@set IP=192.168.0.106
@"c:\Program Files (x86)\Applets\Putty\PSCP.EXE" -pw wsprintf src\* mobile@%IP%:/User/CocoaTop
@"c:\Program Files (x86)\Applets\Putty\ansicon.exe" "c:\Program Files (x86)\Applets\Putty\PLINK.EXE" mobile@%IP% -pw wsprintf -batch <build5.sh
@pause