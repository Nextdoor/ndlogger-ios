#!/bin/bash -e

swift package generate-xcodeproj --xcconfig-overrides xcode.config

PLISTCMD="Set :CFBundleVersion 0.0.1"
/usr/libexec/PlistBuddy -c "$PLISTCMD" ../Logger.xcodeproj/Logger_Info.plist
