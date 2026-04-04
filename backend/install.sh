#!/bin/bash
set -e
echo "=== WAIDBLICK Backend Install ==="
apt-get update -qq && apt-get install -y python3-pip python3-venv 2>/dev/null
mkdir -p /opt/waidblick
curl -fsSL https://raw.githubusercontent.com/Alexturi-lgtm/Waidblick-App/main/backend/main.py -o /opt/waidblick/main.py
cd /opt/waidblick
python3 -m venv venv
./venv/bin/pip install -q fastapi uvicorn python-multipart pillow google-generativeai python-dotenv openai slowapi httpx PyJWT
printf 'GEMINI_API_KEY=AIzaSyDfRrB08ur9TKPudCuHkFFI9lGzhwdg6mU\n' > .env
printf '[Unit]\nDescription=WAIDBLICK API\nAfter=network.target\n[Service]\nWorkingDirectory=/opt/waidblick\nEnvironmentFile=/opt/waidblick/.env\nExecStart=/opt/waidblick/venv/bin/uvicorn main:app --host 0.0.0.0 --port 80\nRestart=always\nRestartSec=5\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/waidblick.service
systemctl daemon-reload && systemctl enable waidblick && systemctl start waidblick
sleep 3
curl -s localhost/health && echo "" && echo "=== DEPLOY_COMPLETE ==="
