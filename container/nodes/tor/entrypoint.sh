#!/bin/bash

# Ensure correct permissions for tor directory
chmod 750 /var/lib/tor
chown debian-tor:tor-access /var/lib/tor

# Switch to debian-tor user and start tor with the provided arguments
exec runuser -u debian-tor -- "$@"
