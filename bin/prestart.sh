#!/bin/bash
log() {
	printf "[INFO] preStart: %s\n" "$@"
}
loge() {
	printf "[ERROR] preStart: %s\n" "$@"
}

# update logstash URL configuration
configure() {
	ES=$(curl -Ls --fail "${CONSUL_HTTP_ADDR}/v1/health/service/elasticsearch-data?passing" | jq -c -e -r '[.[].Service.Address+":9200"]')
	log "Elasticsearch data node(s): $ES"
	REPLACEMENT=$(printf 's/hosts\s*=> \[.*\]/hosts\t=>%s/' "$ES")
	sed -i "$REPLACEMENT" /opt/logstash/config/logstash.conf
}
#------------------------------------------------------------------------------
# Check that CONSUL_HTTP_ADDR environment variable exists
if [[ -z ${CONSUL_HTTP_ADDR} ]]; then
	loge "Missing CONSUL_HTTP_ADDR environment variable"
	exit 1
fi

# Wait up to 2 minutes for Consul to be available
log "Waiting for Consul availability..."
n=0
until [ $n -ge 120 ]||(curl -fsL --connect-timeout 1 "${CONSUL_HTTP_ADDR}/v1/status/leader" &> /dev/null); do
	sleep 2
	n=$((n+2))
done
if [ $n -ge 120 ]; then {
	loge "Consul unavailable, aborting"
	exit 1
}
fi

log "Consul is now available [${n}s], starting up Logstash"
# Wait till Elasticsearch is available
log "Waiting for Elasticsearch data node..."
until (curl -Ls --fail "${CONSUL_HTTP_ADDR}/v1/health/service/elasticsearch-data?passing" | jq -e -r '.[0].Service.Address' >/dev/null); do
	sleep 2
done

log "Elasticsearch is now available, configuring Logstash"
configure
# if logstash -t -f /opt/logstash/config/logstash.conf; then
#     exit 0
# else
#     loge "Invalid Logstash configuration file"
#     exit 1
# fi
exit 0
