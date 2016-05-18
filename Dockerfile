FROM alpine:3.3

# Alpine packages
RUN echo http://dl-6.alpinelinux.org/alpine/v3.3/community >> /etc/apk/repositories &&\
	apk upgrade --update &&\
	apk -f -q --no-progress --no-cache add \
		curl \
		bash \
		ca-certificates \
		jq \
		libcap \
		openjdk8-jre-base \
		openssl \
		su-exec \
		tzdata

# We don't need to expose these ports in order for other containers on Triton
# to reach this container in the default networking environment, but if we
# leave this here then we get the ports as well-known environment variables
# for purposes of linking.
EXPOSE 3164 3164/udp 4000 5424 5424/udp 12201 25109

WORKDIR /tmp
# Add Containerpilot and set its configuration path
ENV CONTAINERPILOT_VERSION=2.1.2 \
	CONTAINERPILOT=file:///etc/containerpilot/containerpilot.json
ADD https://github.com/joyent/containerpilot/releases/download/${CONTAINERPILOT_VERSION}/containerpilot-${CONTAINERPILOT_VERSION}.tar.gz /tmp/
ADD	https://github.com/joyent/containerpilot/releases/download/${CONTAINERPILOT_VERSION}/containerpilot-${CONTAINERPILOT_VERSION}.sha1.txt /tmp/
RUN	sha1sum -sc containerpilot-${CONTAINERPILOT_VERSION}.sha1.txt &&\
	mkdir -p /opt/containerpilot &&\
	tar xzf containerpilot-${CONTAINERPILOT_VERSION}.tar.gz -C /opt/containerpilot/ &&\
	rm -f containerpilot-${CONTAINERPILOT_VERSION}.*

# get Logstash release
ENV LOGSTASH_VERSION=2.3.2
ADD	https://download.elastic.co/logstash/logstash/logstash-${LOGSTASH_VERSION}.tar.gz /tmp/
RUN mkdir -p /opt && \
	tar xzf /tmp/logstash-${LOGSTASH_VERSION}.tar.gz &&\
	mv -f logstash-${LOGSTASH_VERSION}/ /opt/logstash &&\
	rm -f logstash-${LOGSTASH_VERSION}.tar.gz

# Create and take ownership over required directories
# Copy internal CA certificate bundle.
COPY ca.pem /etc/ssl/private/
# Create and take ownership over required directories, update CA
RUN adduser -D -H -g logstash logstash &&\
	adduser logstash logstash &&\
	mkdir -p /opt/logstash/config &&\
	chown -R logstash:logstash /opt &&\
	mkdir -p /etc/containerpilot &&\
	chmod -R g+w /etc/containerpilot &&\
	chown -R logstash:logstash /etc/containerpilot &&\
	$(cat /etc/ssl/private/ca.pem >> /etc/ssl/certs/ca-certificates.crt;exit 0)

#USER logstash
ENV PATH=$PATH:/opt/logstash/bin
# Add our configuration files and scripts
COPY bin/* /usr/local/bin/
COPY containerpilot.json /etc/containerpilot/containerpilot.json
COPY logstash.conf /opt/logstash/config/logstash.conf

CMD ["/usr/local/bin/startup.sh"]
