cd CocoaTop
chmod 0555 postinst
make
if [[ $? != 0 ]]; then exit; fi
mv obj/CocoaTop.app/CocoaTop obj/CocoaTop.app/CocoaTop6
exit
