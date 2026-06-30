#!/bin/bash
# run_visual_test.sh

# Clean up processes
killall Xvfb || true
killall openbox || true
killall branched || true
sleep 1

export DISPLAY=:99

echo "Starting virtual frame buffer Xvfb on DISPLAY :99..."
Xvfb :99 -ac -screen 0 1024x768x24 > /dev/null 2>&1 &
XVFB_PID=$!
sleep 2

echo "Starting openbox..."
openbox > /dev/null 2>&1 &
OPENBOX_PID=$!
sleep 1

echo "Launching branched app..."
./build/linux/x64/debug/bundle/branched > /root/branched/app.log 2>&1 &
APP_PID=$!

echo "Waiting 10 seconds for window initialization and mapping..."
sleep 10

echo "--- Current Windows ---"
xdotool search --name ".*" | while read -r id; do
  name=$(xdotool getwindowname "$id" 2>/dev/null)
  geom=$(xdotool getwindowgeometry "$id" 2>/dev/null | grep Geometry)
  echo "ID: $id | Name: $name | $geom"
done
echo "-----------------------"

echo "Taking screenshot..."
mkdir -p /root/.gemini/antigravity-cli/brain/0053cb8d-118d-4863-9be5-8c4549886f5f
scrot -z /root/.gemini/antigravity-cli/brain/0053cb8d-118d-4863-9be5-8c4549886f5f/screenshot_run.png

echo "Cleaning up..."
kill -9 $APP_PID || true
kill -9 $OPENBOX_PID || true
kill -9 $XVFB_PID || true

echo "Done!"
