cd CocoaTop
chmod 0555 postinst
make
if [[ $? != 0 ]]; then exit; fi
mv obj/CocoaTop.app/CocoaTop obj/CocoaTop.app/CocoaTop5
./sucp -f obj/CocoaTop.app/CocoaTop5 /Applications/CocoaTop.app/CocoaTop5
open ru.domo.CocoaTop
exit
