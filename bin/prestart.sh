#!/bin/bash
log() {
    printf "[INFO] preStart: %s\n" "$@"
}
loge() {
    printf "[ERROR] preStart: %s\n" "$@"
}

# update elasticsearch URL configuration
configure() {    
    REPLACEMENT=$(printf 's/hosts\s*=> \[.*\]/hosts\t=>%s/' "$ES")
	sed -i "$REPLACEMENT" /opt/logstash/config/logstash.conf
}
###################################################################################################

# If we are starting up for the first time, install plugins. 
# logstash process name is "java"
if ! (pgrep java >/dev/null 2>&1); then { 
	log "Installing plugins"
	logstash-plugin install logstash-input-relp
	logstash-plugin install logstash-codec-nmap
	#logstash-plugin update
	log "plugins installed"
}
fi

# Wait till Elasticsearch is available
log "Waiting for Elasticsearch data node..."
until (curl -Ls --fail "${CONSUL}/v1/health/service/elasticsearch-data?passing" | jq -e -r '.[0].Service.Address' >/dev/null); do
    sleep 10
done

log "Elasticsearch is now available, configuring Logstash"
ES=$(curl -Ls --fail "${CONSUL}/v1/health/service/elasticsearch-data?passing" | jq -e -r '[.[].Service.Address]' | tr -d ' \r\n' | sed 's/",/:9200",/g'| sed 's/"]/:9200"]/')
log "Elasticsearch data node(s): $ES"
configure
# if logstash -t -f /opt/logstash/config/logstash.conf; then 
#     exit 0
# else
#     loge "Invalid Logstash configuration file"
#     exit 1
# fi
exit 0


