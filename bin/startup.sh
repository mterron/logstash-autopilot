#!/bin/ash
log() {
    printf "%s\n" "$@"|awk '{print strftime("%Y/%m/%d %T",systime()),"[INFO] startup.sh:",$0}'
}
loge() {
    printf "%s\n" "$@"|awk '{print strftime("%Y/%m/%d %T",systime()),"[ERROR] startup.sh:",$0}'
}
###################################################################################################

if [[ -z ${CONSUL} ]]; then
    loge "Missing CONSUL environment variable"
    exit 1
fi

/usr/local/bin/set-timezone.sh "$TZ"

# Wait 2 minutes for Consul to be available
log "Waiting for Consul availability..."
n=0
until [ $n -ge 120 ]; do
	until (curl -fsL --connect-timeout 1 "${CONSUL}/v1/status/leader" &> /dev/null); do
		sleep 2
		n=$((n+2))
	done
	log "Consul is now available [${n}s], starting up Logstash"
	su-exec logstash:logstash /opt/containerpilot/containerpilot /opt/logstash/bin/logstash agent -f /opt/logstash/config/logstash.conf
done
loge "Consul unavailable, aborting"
exit 1
