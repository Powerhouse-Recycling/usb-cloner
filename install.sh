#!/usr/bin/env bash
# Install or update the USB cloner on this machine. Run as root from the repo dir.
set -euo pipefail
cd "$(dirname "$0")"
[[ $EUID -eq 0 ]] || { echo "run as root: sudo ./install.sh" >&2; exit 1; }

apt-get install -y --no-install-recommends pv

if dpkg -s udisks2 >/dev/null 2>&1; then
    echo "WARNING: udisks2 is installed. It can auto-mount inserted drives, which" >&2
    echo "         makes the cloner skip them. Remove it: apt-get purge udisks2" >&2
fi

install -m 755 bin/usb-cloner bin/usb-cloner-map /usr/local/bin/
install -d -m 755 /etc/usb-cloner /var/log/usb-cloner
[[ -e /etc/usb-cloner/cloner.conf ]] || install -m 644 cloner.conf.example /etc/usb-cloner/cloner.conf
install -m 644 systemd/usb-cloner.service /etc/systemd/system/usb-cloner.service

systemctl daemon-reload
systemctl enable usb-cloner.service

echo
echo "Installed. Next: systemctl start usb-cloner (or reboot)."
echo "On first start the screen asks you to insert one drive into the master socket."
