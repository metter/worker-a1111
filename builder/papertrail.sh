#!/bin/sh

# Start remote_syslog with the desired configuration
remote_syslog \
  -p 27472 --tls \
  -d logs2.papertrailapp.com \
  --pid-file=/var/run/remote_syslog.pid \
  /var/log/runpod_handler.log
