#!/usr/bin/env bash
# OpenMultiSeat - web UI on http://localhost:3100
# Today the seats are built on Windows + WSL (usbipd-win): on Windows use start.bat (asks for administrator rights).
# On Linux / inside WSL this starts the same UI; the Linux-side seat itself is run by seat.sh (see README).
set -e
cd "$(dirname "$0")"
command -v node >/dev/null || { echo "Install Node.js 18+ first (https://nodejs.org)."; exit 1; }
[ -d node_modules/express ] || npm install --no-fund --no-audit
URL=http://localhost:3100
( sleep 2; command -v xdg-open >/dev/null && xdg-open "$URL" >/dev/null 2>&1 || command -v open >/dev/null && open "$URL" >/dev/null 2>&1 || true ) &
echo "OpenMultiSeat: $URL"
exec node app.js
