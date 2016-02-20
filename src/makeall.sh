#!/bin/sh
make clean
make
make TARGET=iphone:clang:5.0 SCHEMA=five
make TARGET=iphone:clang:6.0 SCHEMA=six
make package
