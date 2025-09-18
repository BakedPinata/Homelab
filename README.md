# 🏠 Homelab - Complete Home Automation & Self-Hosted Services Stack

A comprehensive Docker Compose setup for home automation and self-hosted services, featuring Home Assistant as the core with extensive integrations and supporting services.

## 📋 Table of Contents
- [Services Overview](#-services-overview)
- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Service Details](#-service-details)
- [Security Considerations](#-security-considerations)
- [Backup Strategy](#-backup-strategy)
- [Troubleshooting](#-troubleshooting)

## 🚀 Services Overview

### Core Infrastructure
- **Nginx Proxy Manager** - Reverse proxy with SSL certificate management
- **Portainer** - Docker container management GUI
- **Tailscale** - Secure VPN mesh networking

### Home Automation
- **Home Assistant** - Central home automation platform
- **Zigbee2MQTT** - Zigbee device integration
- **Mosquitto** - MQTT broker for IoT communication
- **Node-RED** - Flow-based automation programming
- **ESPHome** - ESP8266/ESP32 device management
- **Matter Server** - Matter protocol support

### Data & Monitoring
- **MariaDB** (x2) - Database for Home Assistant and BookStack
- **InfluxDB** - Time-series database for metrics
- **Grafana** - Data visualization and monitoring dashboards

### Productivity & Tools
- **BookStack** - Documentation and wiki platform
- **Vaultwarden** - Self-hosted Bitwarden password manager
- **Code-Server** - VS Code in the browser
- **PlantUML Server** - Diagram generation service

### Network Services
- **UniFi Network Application** - Network management
- **AdGuard Home** - Network-wide ad blocking and DNS
- **OpenSpeedTest** - Network speed testing

### Media & Downloads
- **qBittorrent** - Torrent client with VPN integration

### Backup
- **Duplicati** - Automated backup solution

## 🔧 Prerequisites

### Hardware Requirements
- **Minimum RAM**: 8GB (16GB recommended)
- **Storage**: 100GB+ (depending on data retention)
- **CPU**: 4+ cores recommended
- **Zigbee Dongle**: Sonoff Zigbee 3.0 USB Dongle Plus (or compatible)

### Software Requirements
- Docker Engine 20.10+
- Docker Compose v2.0+
- Git
- Linux-based OS (Ubuntu Server 20.04+ recommended)

### Network Requirements
- Static IP for the host machine
- Port forwarding capabilities on router (for external access)
- Domain name (optional, for external access)

## 📦 Installation

### 1. Clone the Repository
```bash
git clone https://github.com/BakedPinata/Homelab.git
cd Homelab
```

### 2. Create Environment File
```bash
cp .env.example .env
```

### 3. Configure Environment Variables
Edit `.env` file with your settings:
```bash
nano .env
```

Required variables to configure:
```env
# Installation Path
INSTALL_PATH=/opt/homelab

# Time Zone
TIME_ZONE=America/New_York

# Port Configuration
NGINX_HTTP_PORT=80
NGINX_HTTPS_PORT=443
NGINX_ADMIN_PORT=81
PORTAINER_PORT=9000
HOMEASSISTANT_PORT=8123
# ... (configure all other ports)

# Database Passwords
HOMEASSISTANT_MARIADB_ROOT_PASSWORD=your_secure_password
HOMEASSISTANT_MARIADB_PASSWORD=your_secure_password
BOOKSTACK_MARIADB_ROOT_PASSWORD=your_secure_password
# ... (set all other passwords)

# Service-Specific Configuration
VAULTWARDEN_DOMAIN=https://vault.yourdomain.com
BOOKSTACK_APP_URL=https://docs.yourdomain.com
TAILSCALE_AUTHKEY=tskey-xxxxx
QBITTORRENT_VPN_USERNAME=your_vpn_user
# ... (configure remaining services)
```

### 4. Create Directory Structure
```bash
# Run the setup script (if provided) or manually create directories:
sudo mkdir -p $INSTALL_PATH/{nginx,portainer,homeassistant,bookstack,vaultwarden,duplicati,mosquitto,code-server,nodered,zigbee2mqtt,unifi,grafana,tailscale,qbittorrent,adguard,matter,esphome}
sudo chown -R 1000:1000 $INSTALL_PATH
```

### 5. Configure Zigbee Dongle
Find your Zigbee dongle:
```bash
ls -la /dev/serial/by-id/
```
Update the device path in `docker-compose.yml`

### 6. Initialize Required Configurations

#### Mosquitto Configuration
```bash
mkdir -p $INSTALL_PATH/mosquitto/config
cat > $INSTALL_PATH/mosquitto/config/mosquitto.conf << EOF
persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/log/mosquitto.log
listener 1883
allow_anonymous false
password_file /mosquitto/config/password.txt
EOF

# Create Mosquitto users
docker run -it --rm -v $INSTALL_PATH/mosquitto:/mosquitto eclipse-mosquitto mosquitto_passwd -c /mosquitto/config/password.txt homeassistant
```

#### UniFi MongoDB Initialization
Create `$INSTALL_PATH/unifi/mongodb/init-mongo.js`:
```javascript
db.getSiblingDB("unifi").createUser({
  user: "unifi",
  pwd: "your_password_here",
  roles: [{role: "readWrite", db: "unifi"}]
});
```

### 7. Start the Stack
```bash
# Start all services
docker compose up -d

# Or start specific services
docker compose up -d nginx portainer
docker compose up -d homeassistant
```

## ⚙️ Configuration

### Initial Service Setup

#### 1. Nginx Proxy Manager
- Access at: `http://your-ip:81`
- Default login: `admin@example.com` / `changeme`
- Change password immediately
- Configure SSL certificates and proxy hosts

#### 2. Home Assistant
- Access at: `http://your-ip:8123`
- Follow the onboarding wizard
- Configure database connection:
```yaml
# configuration.yaml
recorder:
  db_url: mysql://user:password@homeassistant_mariadb/homeassistant?charset=utf8mb4
```

#### 3. Zigbee2MQTT
- Access at: `http://your-ip:8080`
- Configure in `$INSTALL_PATH/zigbee2mqtt/data/configuration.yaml`
- Set permit_join to true to add devices

#### 4. Grafana
- Access at: `http://your-ip:3000`
- Login with configured admin credentials
- Add InfluxDB as data source

#### 5. BookStack
- Access at: `http://your-ip:6875`
- Complete installation wizard
- Configure SMTP for email notifications

## 🔐 Security Considerations

### Essential Security Steps

1. **Use Strong Passwords**: Generate unique, strong passwords for all services
2. **Enable 2FA**: Where available (Vaultwarden, Home Assistant, etc.)
3. **Configure Firewall**: Only expose necessary ports
4. **SSL Certificates**: Use Let's Encrypt via Nginx Proxy Manager
5. **Regular Updates**: Keep all containers updated
6. **Network Segmentation**: Consider VLANs for IoT devices

### Firewall Rules (UFW Example)
```bash
# Allow SSH
sudo ufw allow 22/tcp

# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow Home Assistant
sudo ufw allow 8123/tcp

# Enable firewall
sudo ufw enable
```

### Secrets Management
Never commit sensitive data:
- Add `.env` to `.gitignore`
- Use Docker secrets for production
- Rotate passwords regularly

## 💾 Backup Strategy

### Automated Backups with Duplicati
- Access at: `http://your-ip:8200`
- Configure backup jobs for:
  - Home Assistant configuration
  - Database dumps
  - Service configurations
  - SSL certificates

### Manual Backup Commands
```bash
# Backup all data
tar -czf homelab-backup-$(date +%Y%m%d).tar.gz $INSTALL_PATH

# Backup databases
docker exec homeassistant_mariadb mysqldump -u root -p homeassistant > homeassistant_db_$(date +%Y%m%d).sql
docker exec bookstack_mariadb mysqldump -u root -p bookstack > bookstack_db_$(date +%Y%m%d).sql
```

## 🛠️ Useful Commands

### Docker Management
```bash
# View all containers
docker compose ps

# View logs
docker compose logs -f [service_name]

# Restart a service
docker compose restart [service_name]

# Update all services
docker compose pull
docker compose up -d

# Clean up unused resources
docker system prune -a
```

### Service Health Checks
```bash
# Check Home Assistant
curl http://localhost:8123/api/

# Check InfluxDB
curl http://localhost:8086/health

# Check Mosquitto
docker exec mosquitto mosquitto_sub -t '#' -v
```

## 🐛 Troubleshooting

### Common Issues

#### Container Won't Start
```bash
# Check logs
docker compose logs [service_name]

# Check resources
docker system df
df -h
free -h
```

#### Permission Issues
```bash
# Fix ownership
sudo chown -R 1000:1000 $INSTALL_PATH/[service]

# Fix permissions
sudo chmod -R 755 $INSTALL_PATH/[service]
```

#### Network Issues
```bash
# Check network
docker network ls
docker network inspect homelab_frontend
docker network inspect homelab_backend

# Recreate networks
docker compose down
docker network prune
docker compose up -d
```

## 📊 Performance Optimization

### Docker Compose Optimizations
- Use `restart: unless-stopped` instead of `always`
- Implement health checks for critical services
- Use volume mounts efficiently

### System Optimizations
```bash
# Increase file descriptors
echo "fs.file-max = 100000" | sudo tee -a /etc/sysctl.conf

# Docker daemon configuration
sudo nano /etc/docker/daemon.json
```
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

## 🤝 Contributing
Feel free to submit issues and pull requests.

## 📄 License
This project is provided as-is for educational purposes.

## ⚠️ Disclaimer
This setup is intended for home/lab use. Ensure proper security measures before exposing any services to the internet.

## 🙏 Acknowledgments
- Home Assistant Community
- Docker Community
- All the amazing open-source projects included in this stack
