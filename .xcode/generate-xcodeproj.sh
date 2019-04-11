#!/bin/bash -e

swift package generate-xcodeproj --xcconfig-overrides xcode.config
GIT_TAG=`git describe --tags $(git rev-list --tags --max-count=1)`
PLISTCMD="Set :CFBundleVersion $GIT_TAG"
/usr/libexec/PlistBuddy -c "$PLISTCMD" ../Logger.xcodeproj/Logger_Info.plist
