FROM eclipse-temurin:8-jdk-alpine

LABEL maintainer="sharky <sharky@doffish.com>"

RUN apk add --update --no-cache ttf-dejavu fontconfig libgcc curl \
    && mkdir -p /opt/maven \
    && curl -fsSL https://archive.apache.org/dist/maven/maven-3/3.9.5/binaries/apache-maven-3.9.5-bin.tar.gz \
       | tar -xz -C /opt/maven --strip-components=1 \
    && ln -s /opt/maven/bin/mvn /usr/bin/mvn \
    && rm -rf /var/cache/apk/*

WORKDIR /app

RUN cat > /start.sh << 'EOF'
#!/bin/sh

handle_exit() {
    echo "SIGTERM received, exiting..."
    exit 0
}

trap 'handle_exit' SIGTERM SIGINT
sleep infinity

EOF

RUN chmod +x /start.sh

CMD ["sh", "-c", "exec /start.sh"]
