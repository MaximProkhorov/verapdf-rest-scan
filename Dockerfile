# See https://docs.docker.com/engine/userguide/eng-image/multistage-build/

FROM maven as builder

ARG ssh_prv_key
ARG ssh_pub_key

# Authorize SSH Host
RUN mkdir -p /root/.ssh && \
    chmod 0700 /root/.ssh && \
    ssh-keyscan gitlab.akb-it.ru > /root/.ssh/known_hosts

# Add the keys and set permissions
RUN echo "$ssh_prv_key" > /root/.ssh/id_rsa && \
    echo "$ssh_pub_key" > /root/.ssh/id_rsa.pub && \
    chmod 600 /root/.ssh/id_rsa && \
    chmod 600 /root/.ssh/id_rsa.pub

WORKDIR /build

RUN git clone git@gitlab.akb-it.ru:esd-mvd-ext/verapdf/verapdf-library.git
RUN cd verapdf-library && git checkout rel/1.20 && mvn clean install

RUN git clone git@gitlab.akb-it.ru:esd-mvd-ext/verapdf/verapdf-framework.git
RUN cd verapdf-framework && git checkout master && mvn clean install

RUN git clone git@gitlab.akb-it.ru:esd-mvd-ext/verapdf/verapdf-parser.git
RUN cd verapdf-parser && git checkout rel/1.20 && mvn clean install

RUN git clone git@gitlab.akb-it.ru:esd-mvd-ext/verapdf/verapdf-validation.git
RUN cd verapdf-validation && git checkout rel/1.20 && mvn clean install

RUN git clone git@gitlab.akb-it.ru:esd-mvd-ext/verapdf/verapdf-rest.git
RUN cd verapdf-rest && git checkout rel/1.20 && mvn clean package

# Remove SSH keys
RUN rm -rf /root/.ssh/


FROM openjdk:8-jre-alpine

ENV VERAPDF_REST_VERSION=0.1.0-SNAPSHOT-mvd

# Since this is a running network service we'll create an unprivileged account
# which will be used to perform the rest of the work and run the actual service:

# Debian:
# RUN useradd --system --user-group --home-dir=/opt/verapdf-rest verapdf-rest
# Alpine / Busybox:
RUN install -d -o root -g root -m 755 /opt && adduser -h /opt/verapdf-rest -S verapdf-rest
USER verapdf-rest
WORKDIR /opt/verapdf-rest

COPY --from=builder /build/verapdf-rest/target/verapdf-rest-${VERAPDF_REST_VERSION}.jar /opt/verapdf-rest/
COPY --from=builder /build/verapdf-rest/server.yml /opt/verapdf-rest/

EXPOSE 8080
ENTRYPOINT java -jar /opt/verapdf-rest/verapdf-rest-${VERAPDF_REST_VERSION}.jar server server.yml