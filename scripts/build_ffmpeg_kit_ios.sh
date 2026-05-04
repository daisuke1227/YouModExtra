#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_DIR="${ROOT_DIR}/Vendor/FFmpegKit"
SOURCE_DIR="${VENDOR_DIR}/Source"
FRAMEWORK_DIR="${VENDOR_DIR}/Frameworks"
REPO_URL="${FFMPEG_KIT_REPO_URL:-https://github.com/arthenica/ffmpeg-kit.git}"
REF="${FFMPEG_KIT_REF:-main}"

if ! command -v xcrun >/dev/null 2>&1 || ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcrun and xcodebuild are required. Run this on macOS with Xcode command line tools installed." >&2
  exit 1
fi

mkdir -p "${VENDOR_DIR}"

if [[ ! -d "${SOURCE_DIR}/.git" ]]; then
  git clone "${REPO_URL}" "${SOURCE_DIR}"
fi

git -C "${SOURCE_DIR}" fetch --tags origin "${REF}"
git -C "${SOURCE_DIR}" checkout "${REF}"

pushd "${SOURCE_DIR}" >/dev/null
./ios.sh \
  --target=14.0 \
  --no-bitcode \
  --disable-armv7 \
  --disable-armv7s \
  --disable-arm64e \
  --disable-i386 \
  --disable-x86-64 \
  --disable-arm64-simulator \
  --disable-x86-64-mac-catalyst \
  --disable-arm64-mac-catalyst \
  "$@"
popd >/dev/null

rm -rf "${FRAMEWORK_DIR}"
mkdir -p "${FRAMEWORK_DIR}"
rsync -a "${SOURCE_DIR}/prebuilt/bundle-apple-framework-ios/"*.framework "${FRAMEWORK_DIR}/"

echo "FFmpegKit frameworks copied to ${FRAMEWORK_DIR}"
