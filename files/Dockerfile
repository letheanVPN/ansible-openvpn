# Use Ubuntu as the build image.
FROM lthn/ubuntu-build:20.04 as build

RUN apt-get update && apt-get install -y openvpn openssl

WORKDIR /home/lthn/openvpn

# Copy source files
COPY . .

# Add Image Authors
LABEL org.opencontainers.image.authors="darbs@lethean.io,snider@lethean.io"

# Copy all helper shell script files locally.
COPY --chmod=0777 ./*.sh /usr/local/bin/

# Expose the OpenVPN port
EXPOSE 1194/udp

# Set environment variables
ENV SCRIPT=""

# Run a specified  script (if provided), or run OpenVPN server if none is provided.
CMD ["/bin/bash", "-c", "if [ -f \"$SCRIPT\" ]; then \"$SCRIPT\"; else /bin/bash startup.sh; fi"]
