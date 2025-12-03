# n8n-auto-installer
One-command automated installer for n8n with Docker, Nginx, and SSL
# n8n Auto Installer

One-command automated installation of n8n with Docker, Nginx reverse proxy, and free SSL certificate from Let's Encrypt.

## Features

- ✅ Fully automated installation
- ✅ Docker & Docker Compose setup
- ✅ Nginx reverse proxy with SSL/TLS
- ✅ Free SSL certificate from Let's Encrypt
- ✅ Automatic certificate renewal
- ✅ WebSocket support
- ✅ Security headers configured
- ✅ Firewall configuration (UFW)
- ✅ Interactive setup with validation
- ✅ IPv4 and IPv6 support

## Requirements

- Ubuntu 20.04+ (tested on Ubuntu 22.04/24.04)
- Root access
- Domain name with DNS configured
- Minimum 1GB RAM (2GB recommended)
- Ports 80 and 443 available

## Pre-Installation

Before running the installer, make sure:

1. **DNS Configuration**: Create an A record (or AAAA for IPv6) pointing your domain to your server's IP
2. **Cloudflare Users**: If using Cloudflare, set DNS to "DNS only" (gray cloud) during installation
3. **Firewall**: Ensure ports 80 and 443 are accessible from the internet

## Installation

### One-Line Install

```bash
wget -qO- https://raw.githubusercontent.com/yourusername/n8n-installer/main/install-n8n.sh | sudo bash
```

### Manual Installation

```bash
# Download the installer
wget https://raw.githubusercontent.com/yourusername/n8n-installer/main/install-n8n.sh

# Make it executable
chmod +x install-n8n.sh

# Run the installer
sudo ./install-n8n.sh
```

## Installation Process

The script will:

1. Ask for your domain name
2. Ask for your email (for SSL certificate notifications)
3. Confirm DNS is configured
4. Update system packages
5. Install Docker and Docker Compose
6. Create n8n configuration files
7. Obtain SSL certificate from Let's Encrypt
8. Start n8n, Nginx, and Certbot containers
9. Configure firewall rules

Installation typically takes 3-5 minutes.

## Post-Installation

After successful installation:

1. Visit `https://yourdomain.com` in your browser
2. Create your admin account
3. **(For Cloudflare users)** Enable Cloudflare Proxy (orange cloud) in DNS settings
4. **(For Cloudflare users)** Set SSL/TLS mode to "Full (strict)"

## Usage

### View Logs

```bash
cd /opt/n8n
docker compose logs -f
```

### Restart Services

```bash
cd /opt/n8n
docker compose restart
```

### Stop Services

```bash
cd /opt/n8n
docker compose down
```

### Update n8n

```bash
cd /opt/n8n
docker compose pull
docker compose up -d
```

### Check Container Status

```bash
cd /opt/n8n
docker compose ps
```

## File Locations

- **Installation directory**: `/opt/n8n`
- **Docker Compose file**: `/opt/n8n/docker-compose.yml`
- **Nginx configuration**: `/opt/n8n/nginx.conf`
- **SSL certificates**: `/opt/n8n/certbot_certs`
- **n8n data**: Docker volume `n8n_data`

## Troubleshooting

### SSL Certificate Failed

If SSL certificate obtainment fails:

1. Verify DNS is correctly configured: `dig yourdomain.com`
2. Ensure port 80 is accessible: `nc -zv yourdomain.com 80`
3. Check if Cloudflare Proxy is disabled (gray cloud)
4. Try again: The script is idempotent and can be re-run

### Container Not Starting

Check logs for errors:

```bash
cd /opt/n8n
docker compose logs n8n
docker compose logs nginx
```

### Port Already in Use

Stop any service using ports 80 or 443:

```bash
sudo systemctl stop nginx
sudo systemctl stop apache2
# Then run the installer again
```

## Security Recommendations

1. **Firewall**: The script configures UFW automatically
2. **Strong Password**: Use a strong password for your n8n admin account
3. **Updates**: Regularly update n8n and Docker images
4. **Backups**: Backup `/opt/n8n` and the `n8n_data` Docker volume regularly

## Backup & Restore

### Backup

```bash
# Backup configuration and SSL certificates
sudo tar -czf n8n-backup-$(date +%Y%m%d).tar.gz /opt/n8n

# Backup n8n data
docker run --rm -v n8n_data:/data -v $(pwd):/backup alpine tar czf /backup/n8n-data-$(date +%Y%m%d).tar.gz -C /data .
```

### Restore

```bash
# Restore configuration
sudo tar -xzf n8n-backup-YYYYMMDD.tar.gz -C /

# Restore n8n data
docker run --rm -v n8n_data:/data -v $(pwd):/backup alpine tar xzf /backup/n8n-data-YYYYMMDD.tar.gz -C /data

# Restart services
cd /opt/n8n
docker compose up -d
```

## Uninstall

To completely remove n8n:

```bash
# Stop and remove containers
cd /opt/n8n
docker compose down -v

# Remove installation directory
sudo rm -rf /opt/n8n

# Remove Docker (optional)
sudo apt remove --purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
```

## Support

- **n8n Documentation**: https://docs.n8n.io/
- **n8n Community**: https://community.n8n.io/
- **Issues**: Open an issue on this repository

## License

MIT License - feel free to use and modify as needed.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Credits

- n8n: https://n8n.io/
- Docker: https://www.docker.com/
- Let's Encrypt: https://letsencrypt.org/
- Nginx: https://nginx.org/

---

**Note**: This installer is provided as-is. Always review scripts before running them with root privileges.
