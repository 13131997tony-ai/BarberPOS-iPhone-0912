#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"

if [ "$(uname -s)" != Darwin ]; then
    printf '%s\n' 'Cần macOS có Xcode để build và chạy kiểm thử iPhone.' >&2
    exit 1
fi
if ! command -v xcodegen >/dev/null; then
    printf '%s\n' 'Cài XcodeGen từ https://github.com/yonaskolb/XcodeGen rồi chạy lại.' >&2
    exit 1
fi
xcodegen generate

if [ -n "${IOS_SIMULATOR_DESTINATION:-}" ]; then
    xcodebuild -project BarberPOSiOS.xcodeproj -scheme BarberPOSiOS \
        -destination "$IOS_SIMULATOR_DESTINATION" CODE_SIGNING_ALLOWED=NO test
else
    xcodebuild -project BarberPOSiOS.xcodeproj -scheme BarberPOSiOS \
        -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
fi
