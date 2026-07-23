#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
configuration=${1:-release}
app_dir="$project_dir/dist/SwiftUI Gym.app"
contents_dir="$app_dir/Contents"
macos_dir="$contents_dir/MacOS"
resources_dir="$contents_dir/Resources"

cd "$project_dir"
swift build -c "$configuration"

mkdir -p "$macos_dir" "$resources_dir"
cp ".build/$configuration/LiveCodeTrainer" "$macos_dir/LiveCodeTrainer"
cp "Packaging/Info.plist" "$contents_dir/Info.plist"
xcrun actool \
    --compile "$resources_dir" \
    --platform macosx \
    --minimum-deployment-target 14.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "$contents_dir/assetcatalog_generated_info.plist" \
    "Packaging/Assets.xcassets"
codesign --force --deep --sign - "$app_dir"

echo "$app_dir"
