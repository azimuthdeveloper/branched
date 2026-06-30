#!/bin/bash
# run_integration_test.sh

killall Xvfb || true
killall openbox || true
killall branched || true
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

echo "Running integration tests..."
flutter test integration_test/branch_merge_flow_test.dart

echo "Cleaning up..."
kill -9 $OPENBOX_PID || true
kill -9 $XVFB_PID || true

echo "Integration tests finished!"
