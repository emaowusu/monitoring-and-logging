#!/bin/bash
#=============================================================
#  Node Setup Script for Monitoring Lecture Environment
#=============================================================

set -e

#-------------------------------------------------------------
# 1. Basic System Setup
#-------------------------------------------------------------
echo "===== [1/7] Basic system setup ====="

echo "web01" > /etc/hostname
hostname web01

apt update -y && apt upgrade -y
apt install -y zip unzip curl git stress stress-ng

#-------------------------------------------------------------
# 2. Install and Configure Node Exporter
#-------------------------------------------------------------
echo "===== [2/7] Installing Prometheus Node Exporter ====="

NODE_EXPORTER_VERSION="1.10.2"
mkdir -p /tmp/exporter && cd /tmp/exporter

wget -q https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
tar xzf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz

mkdir -p /var/lib/node
mv node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /var/lib/node/

groupadd --system prometheus || true
useradd --system -g prometheus -s /sbin/nologin prometheus || true
chown -R prometheus:prometheus /var/lib/node

cat <<EOF > /etc/systemd/system/node-exporter.service
[Unit]
Description=Prometheus Node Exporter
After=network-online.target

[Service]
User=prometheus
Group=prometheus
ExecStart=/var/lib/node/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now node-exporter

#-------------------------------------------------------------
# 3. Install Node.js & PostgreSQL
#-------------------------------------------------------------
echo "===== [3/7] Installing Node.js & PostgreSQL ====="

# Node.js LTS
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# PostgreSQL
apt install -y postgresql postgresql-contrib

systemctl enable --now postgresql

# 4. Create DB, user, password
sudo -u postgres psql <<EOF
CREATE DATABASE quizdb;
CREATE USER quizuser WITH PASSWORD 'quizpass';
GRANT ALL PRIVILEGES ON DATABASE quizdb TO quizuser;

EOF

echo "✅ PostgreSQL configured"

sudo -u postgres psql quizdb <<EOF
CREATE TABLE IF NOT EXISTS quiz (
    id SERIAL PRIMARY KEY,
    questions TEXT NOT NULL,
    answers TEXT NOT NULL
);

INSERT INTO quiz (questions, answers) VALUES
('What is the capital city of Japan?', 'Tokyo'),
('Which planet is known as the Red Planet?', 'Mars'),
('What is the largest mammal on Earth?', 'Blue Whale'),
('Who painted the Mona Lisa?', 'Leonardo da Vinci'),
('What is the smallest country in the world?', 'Vatican City'),
('What is the chemical symbol for Gold?', 'Au'),
('How many days are there in a leap year?', '366'),
('Which continent is the Sahara Desert located in?', 'Africa'),
('What is the fastest land animal?', 'Cheetah'),
('In which country did the Olympic Games originate?', 'Greece'),
('Who wrote “Romeo and Juliet”?', 'William Shakespeare'),
('What is the hardest natural substance on Earth?', 'Diamond'),
('How many continents are there?', 'Seven'),
('What is the largest ocean in the world?', 'Pacific Ocean'),
('What gas do plants absorb from the atmosphere?', 'Carbon Dioxide'),
('What is the tallest mountain in the world?', 'Mount Everest'),
('What currency is used in the United Kingdom?', 'Pound Sterling'),
('Which animal is known as the King of the Jungle?', 'Lion'),
('What is H2O commonly known as?', 'Water'),
('Who invented the telephone?', 'Alexander Graham Bell');

EOF

echo "✅ Quiz table created and sample questions inserted"

#-------------------------------------------------------------
# 5. Deploy Quiz App (Node.js + Express)
#-------------------------------------------------------------
echo "===== [4/7] Deploying Quiz App ====="

mkdir -p /tmp/project
cd /tmp/project

git clone https://github.com/emaowusu/monitoring-and-logging.git
cd monitoring-and-logging

mkdir -p /opt/quiz
mv quiz/* /opt/quiz
cd /opt/quiz

npm install --production

# Create log directory
mkdir -p /var/log/quiz
chown www-data:www-data /var/log/quiz
chmod 755 /var/log/quiz

#-------------------------------------------------------------
# 6. Create systemd Service for Quiz App
#-------------------------------------------------------------
echo "===== [5/7] Creating Quiz systemd service ====="

cat <<EOF > /etc/systemd/system/quiz.service
[Unit]
Description=Quiz Node.js Application
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/quiz
ExecStart=/usr/bin/node app.js
Restart=always
RestartSec=5

Environment=NODE_ENV=production
Environment=PORT=3000
Environment=DB_HOST=localhost
Environment=DB_PORT=5432
Environment=DB_NAME=quizdb
Environment=DB_USER=quizuser
Environment=DB_PASSWORD=quizpass

StandardOutput=append:/var/log/quiz/quiz.log
StandardError=append:/var/log/quiz/quiz.log

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now quiz
systemctl status quiz --no-pager

echo "✅ Quiz app running under systemd"

#-------------------------------------------------------------
# 7. Load Generation Scripts
#-------------------------------------------------------------
echo "===== [4/6] Setting up load generation scripts ====="
apt install -y stress

echo "Downloading load scripts..."
wget -q -P /usr/local/bin/ https://raw.githubusercontent.com/hkhcoder/vprofile-project/refs/heads/monitoring/load.sh
wget -q -P /usr/local/bin/ https://raw.githubusercontent.com/hkhcoder/vprofile-project/refs/heads/monitoring/generate_multi_logs.sh

chmod +x /usr/local/bin/load.sh /usr/local/bin/generate_multi_logs.sh

echo "Starting load generation in background..."
nohup /usr/local/bin/load.sh > /dev/null 2>&1 &
nohup /usr/local/bin/generate_multi_logs.sh > /dev/null 2>&1 &

echo "✅ Load generation setup completed."

#-------------------------------------------------------------
# 8. Install and Configure Alloy
#-------------------------------------------------------------
echo "===== [6/7] Installing Grafana Alloy ====="

apt install -y gpg
mkdir -p /etc/apt/keyrings/

wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor > /etc/apt/keyrings/grafana.gpg
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
  > /etc/apt/sources.list.d/grafana.list

apt update && apt install -y alloy

cat <<EOF > /etc/alloy/config.alloy
prometheus.remote_write "default" {
  endpoint {
    url = "http://PrometheusIP:9090/api/v1/write"
  }
}

prometheus.scrape "quiz_metrics" {
  targets = [{
    __address__ = "localhost:3000",
    __metrics_path__ = "/metrics",
  }]
  forward_to = [prometheus.remote_write.default.receiver]
}

local.file_match "quiz_logs" {
  path_targets = [{
    __path__ = "/var/log/quiz/*.log",
    job      = "quiz",
    hostname = constants.hostname,
  }]
}

loki.source.file "quiz_log_scrape" {
  targets    = local.file_match.quiz_logs.targets
  forward_to = [loki.write.loki.receiver]
}

loki.write "loki" {
  endpoint {
    url = "http://LokiIP:3100/loki/api/v1/push"
  }
}
EOF

systemctl enable alloy
systemctl restart alloy

#-------------------------------------------------------------
# 9. Firewall Configuration
#-------------------------------------------------------------
echo "===== [7/7] Configuring firewall ====="

apt install -y ufw

ufw allow 22/tcp
ufw allow 3000/tcp
ufw allow 9100/tcp
ufw allow 3100/tcp
ufw allow 12345/tcp

echo "y" | ufw enable
ufw status verbose

#-------------------------------------------------------------
# Final Summary
#-------------------------------------------------------------
echo "============================================================="
echo "🎉 Setup completed successfully!"
echo "-------------------------------------------------------------"
echo " Quiz App        : http://$(hostname -I | awk '{print $1}'):3000"
echo " PostgreSQL DB   : quizdb (user: quizuser)"
echo " Node Exporter  : :9100"
echo " Alloy UI       : :12345"
echo "============================================================="
