#!/bin/ash
# Sets the system timezone based on the TZ environment variable
log() {
    printf "[INFO] set-timezone: %s\n" "$@"
}

if [ "$TZ" ]
then
    ln -snf /usr/share/zoneinfo/$"TZ" /etc/localtime &&\
    echo "$TZ" > /etc/timezone &&\
    log "Timezone set to $TZ"
else
	log "No timezone defined! Use host system time"
fi
