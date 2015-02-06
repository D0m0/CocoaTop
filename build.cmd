@"c:\Program Files (x86)\Applets\Putty\PSCP.EXE" -pw wsprintf src\* mobile@192.168.0.108:/User/doomapp
@"c:\Program Files (x86)\Applets\Putty\ansicon.exe" "c:\Program Files (x86)\Applets\Putty\PLINK.EXE" mobile@192.168.0.108 -pw wsprintf -batch <build.sh
@"c:\Program Files (x86)\Applets\Putty\PLINK.EXE" root@192.168.0.108 -pw wsprintf -batch <buildtask.sh
@pause