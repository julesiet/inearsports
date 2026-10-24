#!/bin/bash
set -e

APP="build/AirPodBridge.app"

mkdir -p "$APP/Contents/MacOS"

swiftc Sources/*.swift \
    -framework CoreMotion \
    -framework Network \
    -o "$APP/Contents/MacOS/AirPodBridge"

cp Info.plist "$APP/Contents/Info.plist"

codesign --force --sign - "$APP"

echo "AirPod Bridge built successfully!"