#!/bin/bash

# Start VNC server
vncserver :1 -geometry 1280x800 -depth 24 &

# Start noVNC
/usr/share/novnc/utils/launch.sh --vnc localhost:5901 --listen 6080 &

echo "VNC server started on port 5901"
echo "noVNC started on port 6080"