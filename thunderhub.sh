# install service
    echo "*** Install ThundeHub systemd for ${network} on ${chain} ***"
    cat > /home/admin/thunderhub.service <<EOF
# Systemd unit for thunderhub
# /etc/systemd/system/thunderhub.service

[Unit]
Description=ThunderHub daemon
Wants=lnd.service
After=lnd.service

[Service]
WorkingDirectory=/home/thunderhub/thunderhub
ExecStart=/usr/bin/npm run start -- -p 3010
User=thunderhub
Restart=always
TimeoutSec=120
RestartSec=30
StandardOutput=null
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    sudo mv /home/admin/thunderhub.service /etc/systemd/system/thunderhub.service 
    sudo chown root:root /etc/systemd/system/thunderhub.service
    sudo systemctl enable thunderhub
    echo "OK - the ThunderHub service is now enabled"
 
 sudo systemctl start thunderhub
