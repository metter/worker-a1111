sudo remote_syslog \
  -p 27472 --tls \
  -d logs2.papertrailapp.com \
  --pid-file=/var/run/remote_syslog.pid \
  /path/to/your/file.log