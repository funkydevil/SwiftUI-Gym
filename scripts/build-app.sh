#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
configuration=${1:-release}
app_dir="$project_dir/dist/SwiftUI Gym.app"
contents_dir="$app_dir/Contents"
macos_dir="$contents_dir/MacOS"

cd "$project_dir"
swift build -c "$configuration"

mkdir -p "$macos_dir"
cp ".build/$configuration/LiveCodeTrainer" "$macos_dir/LiveCodeTrainer"
cp "Packaging/Info.plist" "$contents_dir/Info.plist"
codesign --force --deep --sign - "$app_dir"

echo "$app_dir"
