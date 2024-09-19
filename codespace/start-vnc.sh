#!/bin/bash

# Check if VNC server is already running
if pgrep Xtightvnc > /dev/null; then
    echo "VNC server already running, attempting to restart..."
    vncserver -kill :1
    rm -f /tmp/.X1-lock
fi

# Start VNC server on display :1
vncserver :1 -geometry 1280x800 -depth 24 &

# Start noVNC
/usr/share/novnc/utils/launch.sh --vnc localhost:5901 --listen 6080 &

echo "VNC server started on port 5901"
echo "noVNC started on port 6080"