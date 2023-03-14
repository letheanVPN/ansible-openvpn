#!/usr/bin/env bash

echo "client-connect: common_name=$common_name, username=$username"

if [ "$common_name" == "$username" ]; then
  echo "Client certificate common_name matches username. Allow connection."
  # Get the IP address of the connected client
  CLIENT_IPv4=$trusted_ip

  # Add an iptables rule to block the client from accessing the openvpn server
  # however permit routing of everything else.
  iptables -I INPUT -s $CLIENT_IPv4 -d 127.0.0.1 -j DROP
  #iptables -I INPUT -s $CLIENT_IPv4 -d 10.8.0.1 -j DROP
  exit 0
else
  echo "Client certificate common_name does not match username. Reject connection."
  exit 1
fi
