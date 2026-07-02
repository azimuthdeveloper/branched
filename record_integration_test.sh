#!/bin/bash
# record_integration_test.sh

killall Xvfb || true
killall openbox || true
killall branched || true
killall ffmpeg || true
sleep 1

export DISPLAY=:99
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe

echo "Starting virtual frame buffer Xvfb on DISPLAY :99..."
Xvfb :99 -ac -screen 0 1280x1024x24 > /dev/null 2>&1 &
XVFB_PID=$!
sleep 2

echo "Starting openbox..."
openbox > /dev/null 2>&1 &
OPENBOX_PID=$!
sleep 1

echo "Starting ffmpeg recording..."
mkdir -p integration_test_recordings
# Record display :99 at 1280x1024, 10 fps, crf 30 for high compression
ffmpeg -f x11grab -video_size 1280x1024 -i :99 -codec:v libx264 -pix_fmt yuv420p -r 10 -preset medium -crf 30 -y integration_test_recordings/test_run.mp4 > /dev/null 2>&1 &
FFMPEG_PID=$!
sleep 1

echo "Starting screenshot loop (every 10 seconds)..."
(
  count=1
  while true; do
    sleep 10
    ffmpeg -f x11grab -video_size 1280x1024 -i :99 -vframes 1 -y "integration_test_recordings/x11_screenshot_$(printf "%03d" $count).png" > /dev/null 2>&1
    count=$((count+1))
  done
) &
SCREENSHOT_LOOP_PID=$!

# Resolve git hash
GIT_HASH_VAL=$(git rev-parse --short HEAD 2>/dev/null || echo "local")
echo "Building and running integration tests with GIT_HASH=$GIT_HASH_VAL..."

echo "Running integration tests on linux device..."
flutter test -d linux --dart-define=GIT_HASH=$GIT_HASH_VAL integration_test/branch_merge_flow_test.dart
flutter test -d linux --dart-define=GIT_HASH=$GIT_HASH_VAL integration_test/real_git_flow_test.dart

echo "Stopping screenshot loop..."
kill $SCREENSHOT_LOOP_PID
wait $SCREENSHOT_LOOP_PID 2>/dev/null || true

echo "Stopping ffmpeg recording..."
kill -INT $FFMPEG_PID
wait $FFMPEG_PID || true

echo "Cleaning up display servers..."
kill -9 $OPENBOX_PID || true
kill -9 $XVFB_PID || true

echo "Optimizing video and screenshot file size..."
ls -lh integration_test_recordings/

echo "Integration tests and recording finished!"
