#!/bin/bash
LATEST_VER=$(curl -s https://api.github.com/repos/perfect-panel/ppanel-web/releases | jq -r '[.[] | select(.prerelease == true)][0].tag_name')
SERVER_URL="https://github.com/perfect-panel/ppanel-web/releases/download/${LATEST_VER}/ppanel-admin-web.tar.gz"
mkdir -p /opt/ppanel
wget -O /opt/ppanel-admin-web.tar.gz $SERVER_URL
tar -xvf /opt/ppanel-admin-web.tar.gz -C /opt/ppanel/