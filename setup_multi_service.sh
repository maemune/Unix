#!/bin/bash
# =========================================================
# Multi-service Apache + SSL + Reverse Proxy Setup Script
# =========================================================

sudo a2enmod proxy proxy_http proxy_wstunnel ssl headers rewrite

echo "=============================================="
echo "Apache vhost configuration script"
echo "=============================================="

while true; do
    read -p "Service Name: " SERVICENAME
    read -p "Subdomain: " SUBDOMAIN
    read -p "Internal IP: " SERVICE_IP
    read -p "Port: " SERVICE_PORT
    read -p "WebSocket? (y/n): " USE_WS

    VHOST_FILE="/etc/apache2/sites-available/${SERVICENAME}.conf"

    # Step 1: Create temporary HTTP config for Certbot validation
    sudo tee $VHOST_FILE > /dev/null <<EOF
<VirtualHost *:80>
    ServerName $SUBDOMAIN
    DocumentRoot /var/www/html
</VirtualHost>
EOF

    sudo a2ensite ${SERVICENAME}.conf
    sudo systemctl reload apache2

    # Step 2: Obtain SSL Certificate
    sudo certbot certonly --apache -d $SUBDOMAIN

    # Step 3: Create final configuration with SSL
    sudo tee $VHOST_FILE > /dev/null <<EOF
<VirtualHost *:80>
    ServerName $SUBDOMAIN
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^/?(.*) https://%{SERVER_NAME}/\$1 [R=301,L]
</VirtualHost>

<VirtualHost *:443>
    ServerName $SUBDOMAIN

    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/$SUBDOMAIN/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/$SUBDOMAIN/privkey.pem
    Include /etc/letsencrypt/options-ssl-apache.conf
    
    SSLUseStapling on
    Header always set Strict-Transport-Security "max-age=31536000"

    ProxyPreserveHost On
    ProxyRequests Off

    RequestHeader set X-Forwarded-Proto "https"
    RequestHeader set X-Forwarded-Port "443"
EOF

    if [[ "$USE_WS" == "y" || "$USE_WS" == "Y" ]]; then
        sudo tee -a $VHOST_FILE > /dev/null <<EOF

    # WebSocket Support
    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} =websocket [NC]
    RewriteCond %{HTTP:Connection} upgrade [NC]
    RewriteRule /(.*) ws://$SERVICE_IP:$SERVICE_PORT/\$1 [P,L]
EOF
    fi

    sudo tee -a $VHOST_FILE > /dev/null <<EOF

    ProxyPass "/" "http://$SERVICE_IP:$SERVICE_PORT/"
    ProxyPassReverse "/" "http://$SERVICE_IP:$SERVICE_PORT/"

    ErrorLog \${APACHE_LOG_DIR}/${SERVICENAME}_error.log
    CustomLog \${APACHE_LOG_DIR}/${SERVICENAME}_access.log combined
</VirtualHost>
EOF

    # Step 4: Final Reload
    sudo systemctl reload apache2

    echo "=============================================="
    echo "Setup finished for $SERVICENAME: https://$SUBDOMAIN/"
    echo "=============================================="

    read -p "Add another service? (y/n): " MORE
    if [[ "$MORE" != "y" && "$MORE" != "Y" ]]; then
        break
    fi
done

echo "=============================================="
echo "All services configured successfully."
echo "=============================================="
