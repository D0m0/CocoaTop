cd CocoaTop
chmod 0555 postinst
make
if [[ $? != 0 ]]; then exit; fi
./sucp -f obj/CocoaTop.app/CocoaTop /Applications/CocoaTop.app/CocoaTop5
open ru.domo.CocoaTop
exit
