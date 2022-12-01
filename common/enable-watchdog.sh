#!/bin/sh

# Re-enables the piaware watchdog config
# if it was temporarily disabled in postinst

if [ -f /etc/systemd/system/piaware.service.d/disable-watchdog.conf ]
then
    rm -f /etc/systemd/system/piaware.service.d/disable-watchdog.conf
    systemctl daemon-reload
fi

exit 0
