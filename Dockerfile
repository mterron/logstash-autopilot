FROM alpine:3.4

# Alpine packages
RUN apk -f -q --progress --no-cache upgrade &&\
	apk -f -q --progress --no-cache add \
		bash \
		curl \
		ca-certificates \
		dnsmasq \
		jq \
		openjdk8-jre-base \
		openssl \
		tzdata 

ENV CONTAINERPILOT_VERSION=2.4.1 \
	CONTAINERPILOT=file:///etc/containerpilot/containerpilot.json \
	CONSUL_VERSION=0.7.0 \
	S6_VERSION=1.18.1.3

WORKDIR /tmp
# RUN echo "Downloading S6 Overlay" &&\
# 	curl -LO# https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-amd64.tar.gz &&\
# 	gunzip -c /tmp/s6-overlay-amd64.tar.gz | tar -xf - -C / &&\
# 	rm -f s6-overlay-amd64.tar.gz &&\
RUN	echo "Downloading Containerpilot" &&\
	curl -LO# https://github.com/joyent/containerpilot/releases/download/${CONTAINERPILOT_VERSION}/containerpilot-${CONTAINERPILOT_VERSION}.tar.gz &&\
	echo "Downloading Containerpilot checksums" &&\
	curl -LO# https://github.com/joyent/containerpilot/releases/download/${CONTAINERPILOT_VERSION}/containerpilot-${CONTAINERPILOT_VERSION}.sha1.txt &&\
	sha1sum -sc containerpilot-${CONTAINERPILOT_VERSION}.sha1.txt &&\
	mkdir -p /opt/containerpilot &&\
	tar xzf containerpilot-${CONTAINERPILOT_VERSION}.tar.gz -C /opt/containerpilot/ &&\
	rm -f containerpilot-${CONTAINERPILOT_VERSION}.* &&\
# Download Consul binary
	echo "Downloading Consul" &&\
	curl -LO# https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip &&\
# Download Consul integrity file
	echo "Downloading Consul checksums" &&\
	curl -LO# https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS &&\
# Check integrity and installs Consul
	grep "linux_amd64.zip" consul_${CONSUL_VERSION}_SHA256SUMS | sha256sum -sc &&\
	unzip -q -o consul_${CONSUL_VERSION}_linux_amd64.zip -d /bin &&\
	rm -f consul_${CONSUL_VERSION}_* &&\
# Consul user
	adduser -D -H -g consul consul &&\
	adduser consul consul &&\
# Create Consul data directory
	mkdir /data &&\
	mkdir -p /etc/consul &&\
	chmod 770 /data &&\
	chown -R consul: /data &&\
	chown -R consul: /etc/consul/ &&\
	chmod +x /bin/*

ENV	LOGSTASH_VERSION=2.4.0 \
	PATH=$PATH:/opt/logstash/bin

EXPOSE 3164 3164/udp 5424 5424/udp 6666 10514 12201 13000 14000 24224 25109 8301

# Copy internal CA certificate bundle.
COPY ca.pem /etc/ssl/private/
# Client certificate to talk to Consul 
# From man curl 
# -E, --cert # <certificate[:password]> (SSL) Tells curl to use the specified
# client certificate file when getting a file with HTTPS, FTPS or another SSL-
# based protocol. The certificate must be in PKCS#12 format if using Secure 
# Transport, or PEM format if using any other engine. If the optional 
# password isn't specified, it will be queried for on the terminal. 
# Note that this option assumes a "certificate" file that is the private key 
# and the private certificate concatenated! See --cert and --key to specify 
# them independently.
COPY client_certificate.* /etc/tls/
# Add our configuration files and scripts
COPY bin/* /usr/local/bin/
COPY containerpilot.json /etc/containerpilot/containerpilot.json
COPY logstash.conf /opt/logstash/config/logstash.conf
COPY etc/ /etc
COPY consul.json /etc/consul/

# If you build on top of this image, please provide this files
# If you are using an internal CA
ONBUILD COPY ca.pem /etc/ssl/private/
ONBUILD COPY containerpilot.json /etc/containerpilot/containerpilot.json
ONBUILD COPY logstash.conf /opt/logstash/config/logstash.conf


# Download Logstash release
RUN	echo "Downloading Logstash" &&\
	curl -LO# https://download.elastic.co/logstash/logstash/logstash-all-plugins-${LOGSTASH_VERSION}.tar.gz &&\
	mkdir -p /opt/logstash/ && \
	tar xzf /tmp/logstash-all-plugins-${LOGSTASH_VERSION}.tar.gz &&\
	mv logstash-${LOGSTASH_VERSION}/* /opt/logstash/ &&\
	rm -rf /tmp/* &&\
# Create and take ownership over required directories, update CA
	adduser -D -g logstash logstash &&\
	adduser logstash logstash &&\
	mkdir -p /opt/logstash/config &&\
	mkdir -p /opt/logstash/log &&\
	mkdir -p /etc/containerpilot &&\
	chmod -R g+w /etc/containerpilot &&\
	chown -R logstash:logstash /opt &&\
	chown -R logstash:logstash /etc/containerpilot &&\
	cat /etc/ssl/private/ca.pem >> /etc/ssl/certs/ca-certificates.crt

# Put Consul data on a separate volume to avoid filesystem performance issues with Docker image layers
VOLUME ["/data"]

ENTRYPOINT ["/init"]
