#!/bin/bash
log() {
    printf "[INFO] preStart: %s\n" "$@"
}
loge() {
    printf "[ERROR] preStart: %s\n" "$@"
}

# update elasticsearch URL configuration
configure() {
    REPLACEMENT=$(printf 's/hosts => [],/hosts =>%s,/' "$ES")
	sed -i "$REPLACEMENT" /opt/logstash/config/logstash.conf
}
###################################################################################################

# Wait till Elasticsearch is available
log "Waiting for Elasticsearch data node..."
until (curl -Ls --fail "${CONSUL}/v1/health/service/elasticsearch-data?passing" | jq -e -r '.[0].ServiceAddress' >/dev/null); do
    sleep 10
done

log "Elasticsearch is now available, configuring Logstash"
ES=$(curl -Ls --fail "${CONSUL}/v1/health/service/elasticsearch-data?passing" | jq -e -r '[.[].ServiceAddress]' | tr -d ' \r\n' | sed 's/",/:9200",/g'| sed 's/"]/:9200" ]/')
configure
exit 0

log "Installing plugins"
#/opt/logstash/bin/logstash-plugin update
if /opt/logstash/bin/logstash -t /opt/logstash/config/logstash.conf; then 
    exit 0
else
    loge "Invalid Logstash configuration file"
    exit 1
fi
