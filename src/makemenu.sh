#!/bin/sh
PS3="Please enter your choice: "
options=("Clean & Make" "Make for 5 & 6" "iPhone 5c" "iPhone 4s" "iPad Black" "iPad White" "iPad 1" "Quit")
select opt in "${options[@]}"
do
    case $opt in
	"Clean & Make")
	    make clean
	    make
	    ;;
	"Make for 5 & 6")
	    echo ===================================== iOS5
	    make TARGET=iphone:clang:5.0 SCHEMA=five
	    echo ===================================== iOS6
	    make TARGET=iphone:clang:6.0 SCHEMA=six
	    echo ===================================== DEB
	    make package
	    ;;
	"iPhone 5c")
	    make install THEOS_DEVICE_IP=192.168.0.109
	    break
	    ;;
	"iPhone 4s")
	    make install THEOS_DEVICE_IP=192.168.0.111
	    break
	    ;;
	"iPad Black")
	    make install THEOS_DEVICE_IP=192.168.0.104
	    break
	    ;;
	"iPad White")
	    make install THEOS_DEVICE_IP=192.168.0.110
	    break
	    ;;
	"iPad 1")
	    make install THEOS_DEVICE_IP=192.168.0.106
	    break
	    ;;
	"Quit") break;;
	*) echo invalid option;;
    esac
done
