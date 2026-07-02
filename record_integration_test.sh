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
Xvfb :99 -ac -screen 0 1024x768x24 > /dev/null 2>&1 &
XVFB_PID=$!
sleep 2

echo "Starting openbox..."
openbox > /dev/null 2>&1 &
OPENBOX_PID=$!
sleep 1

echo "Starting ffmpeg recording..."
mkdir -p integration_test_recordings
# Record display :99 at 10 fps, crf 30 for high compression
ffmpeg -f x11grab -video_size 1024x768 -i :99 -codec:v libx264 -pix_fmt yuv420p -r 10 -preset medium -crf 30 -y integration_test_recordings/test_run.mp4 > /dev/null 2>&1 &
FFMPEG_PID=$!
sleep 1

echo "Running integration tests..."
flutter test integration_test/branch_merge_flow_test.dart
flutter test integration_test/real_git_flow_test.dart

echo "Stopping ffmpeg recording..."
kill -INT $FFMPEG_PID
wait $FFMPEG_PID || true

echo "Cleaning up display servers..."
kill -9 $OPENBOX_PID || true
kill -9 $XVFB_PID || true

echo "Optimizing video file size..."
ls -lh integration_test_recordings/test_run.mp4

echo "Integration tests and recording finished!"
