#syntax=docker/dockerfile:1@sha256:93bfd3b68c109427185cd78b4779fc82b484b0b7618e36d0f104d4d801e66d25
ARG TARGET_PLATFORM=linux/arm64
FROM --platform=$TARGET_PLATFORM python:3.13-alpine@sha256:323a717dc4a010fee21e3f1aac738ee10bb485de4e7593ce242b36ee48d6b352 AS builder
# install dependencies for building package
RUN apk add -U -l -u bsd-compat-headers cargo gcc git libffi-dev musl-dev openssl-dev
# install dns_exporter
RUN --mount=type=bind,readwrite,source=/,target=/src pip install --user /src
# cleanup
RUN find / | grep -E "(\/.cache$|\/__pycache__$|\.pyc$|\.pyo$)" | xargs rm -rf

FROM --platform=$TARGET_PLATFORM python:3.13-alpine@sha256:323a717dc4a010fee21e3f1aac738ee10bb485de4e7593ce242b36ee48d6b352 AS runtime
RUN \
--mount=type=bind,from=builder,source=/root/.local,target=/tmp/.local \
--mount=type=bind,source=/src/dns_exporter/dns_exporter_example.yml,target=/tmp/dns_exporter.yml \
<<EOF
# Create app directory
mkdir -p /app
# Copy files from mounts
cp -r /tmp/.local /app/.local
cp /tmp/dns_exporter.yml /app/dns_exporter.yml
# Set permissions for OpenShift compatibility
chgrp -R 0 /app && \
chmod -R g=u /app
EOF
# expose dns_exporter default port
EXPOSE 15353
# Set the working directory
WORKDIR /app
# Use an arbitrary user ID for OpenShift compatibility
USER 1001

ENV PYTHONUSERBASE=/app/.local
ENV PATH="/app/.local/bin:$PATH"

ENTRYPOINT [ "/app/.local/bin/dns_exporter" ]
CMD [ "-L", "0.0.0.0", "-c", "/app/dns_exporter.yml" ]
