## Create required cerificates.

On Linux:

  You have 2 options:

  a) Generate your CA, server and one client certificate automatically (default key passwords). Including generating a client VPN profile for the default client name which is "Lethean_VPN_Client".
```
  chmod +x generate_certs.sh
  chmod +x generate_client_profile.sh
  ./generate_certs.sh --defaults
  ./generate_client_profile.sh Lethean_VPN_Client <your-server-public-dns>
```
  NOTE: Generated profile resides in the "profile" folder.

  OR

  b) Generate your own certificates. Recommended for better validation, control and security through entering your own private key passwords.
```
  chmod +x generate_certs.sh
  chmod +x generate_client_profile.sh
  ./generate_certs.sh --ca --with-capass <your-capass> --with-cacn <cacn>
  ./generate_certs.sh --server --with-capass <your-capass> --with-serverpass <your-serverpass> --with-servercn <your-server-dns>
  ./generate_certs.sh --client --with-capass <your-capass> --with-clientpass <clientpass> --with-clientcn <clientcn>
  ./generate_client_profile.sh <clientcn> <your-server-public-dns>
```
  NOTE: Generated profile resides in "profile" folder.


#### Below was tested on a factory defaulted Raspberry Pi2. Iptables already permitted all required incoming connections.

On Linux:

Forward traffic through desired interfaces. Below is an example. Replace eth0 with your local adapter.
```
	iptables -A FORWARD -i tun+ -j ACCEPT
	iptables -A FORWARD -i tun+ -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
	iptables -A FORWARD -i eth0 -o tun+ -m state --state RELATED,ESTABLISHED -j ACCEPT
```
Setup iptables to source NAT vpn client address space when egressing the openvpn server.
A destination or egress interface should be specified in the statement where appropriate. Single homed systems shouldn't need an interface specified.
This is optional in environments where visibility and you understand what routing changes are required in your environment.
The below subnet is the openvpn conf file default. Change to your requirements.
```
	iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j MASQUERADE
```
NOTE: On a PI used for testing the MASQUERADE syntax may not be possible. You can use the command "sudo update-alternatives --config iptables" to change iptables to "iptables-legacy", which will then allow the above to be executed.

## Enable ip forwarding and promiscious mode on in-path interfaces.

Enable IP Forwarding

On Linux:
```
	echo 1 > /proc/sys/net/ipv4/ip_forward
```
On OS X:
```
	sudo sysctl -w net.inet.ip.forwarding=1
```
Set NIC to promiscious mode

On Linux:

Example, set based on the interface which will be used for routing VPN clients.
```
	sudo ip link set eth0 promisc on
	sudo ip link set wlan0 promisc on
```
## Run your openvpn server.
   Run in daemon mode if desired with the "--daemon" option.
   Config file "client-cert-ftm.conf" is a working sample for ease of use and setup.
   Ensure all certificates/keys are in the paths stated within "client-cert-ftm.conf" or updated accordingly. Paths can be overriden during command execution.

   Client certificate authentication in full tunnel mode.
```
	openvpn --config client-cert-ftm.conf
```
## Share the openvpn client profile with your user.

  Enjoy!

*************************************************************************

# DOCKER USAGE

  Generate certificates:

  LINUX
```
    mkdir openvpn && cd openvpn
    docker run --rm -v $(pwd)/etc:/home/lthn/openvpn/etc lthn/openvpn generate_certs.sh --defaults
```
    OR
```
    docker run -v $(pwd)/etc:/home/lthn/openvpn/etc --rm lthn/openvpn generate_certs.sh --ca --with-capass <your-capass> --with-cacn <cacn>
    docker run -v $(pwd)/etc:/home/lthn/openvpn/etc --rm lthn/openvpn generate_certs.sh --with-capass <your-capass> --server --with-serverpass <your-serverpass> --with-servercn <your-server-dns>
    docker run -v $(pwd)/etc:/home/lthn/openvpn/etc --rm lthn/openvpn generate_certs.sh --client --with-capass <your-capass> --with-clientpass <clientpass> --with-clientcn <clientcn>
```
  WINDOWS (powershell)
```
    mkdir openvpn && cd openvpn
    docker run --rm -v ${pwd}/etc:/home/lthn/openvpn/etc lthn/openvpn generate_certs.sh --defaults
```
    OR
```
    docker run -v ${pwd}/etc:/home/lthn/openvpn/etc --rm lthn/openvpn generate_certs.sh --ca --with-capass <your-capass> --with-cacn <cacn>
    docker run -v ${pwd}/etc:/home/lthn/openvpn/etc --rm lthn/openvpn generate_certs.sh --with-capass <your-capass> --server --with-serverpass <your-serverpass> --with-servercn <your-server-dns>
    docker run -v ${pwd}/etc:/home/lthn/openvpn/etc --rm lthn/openvpn generate_certs.sh --client --with-capass <your-capass> --with-clientpass <clientpass> --with-clientcn <clientcn>
```
  Generate client profile:

  LINUX

    (Defaults profile)
```
    docker run -v $(pwd)/etc:/home/lthn/openvpn/etc -v $(pwd)/profile:/home/lthn/openvpn/profile --rm lthn/openvpn generate_client_profile.sh Lethean_VPN_Client <your-server-public-dns>
```
    OR
```
    docker run -v $(pwd)/etc:/home/lthn/openvpn/etc -v $(pwd)/profile:/home/lthn/openvpn/profile --rm lthn/openvpn generate_client_profile.sh <client-cert-cn> <your-server-public-dns>
```
  WINDOWS (powershell)

    (Defaults profile)
```
    docker run -v ${pwd}/etc:/home/lthn/openvpn/etc -v $(pwd)/profile:/home/lthn/openvpn/profile --rm lthn/openvpn generate_client_profile.sh Lethean_VPN_Client <your-server-public-dns>
```
    OR
```
    docker run -v ${pwd}/etc:/home/lthn/openvpn/etc -v $(pwd)/profile:/home/lthn/openvpn/profile --rm lthn/openvpn generate_client_profile.sh <client-cert-cn> <your-server-public-dns>
```
  Run openvpn server:

  Give your local host user running docker rights to access the TUN interface, then run the container.
  Container is assuming you already have a local "etc" folder containing your certificates generated earlier. This ensures openvpn server can bind an already created certificate.
  Container is also assuming you already have a local "profile" folder. This ensures client vpn profiles can be generated and served to localhost for easy access.

  LINUX
```
    docker run -p 1194:1194/udp --name lthn-openvpn --device=/dev/net/tun --cap-add=NET_ADMIN -v $(pwd)/etc:/home/lthn/openvpn/etc -v $(pwd)/profile:/home/lthn/openvpn/profile lthn/openvpn
```
  WINDOWS (powershell)
```
    docker run -p 1194:1194/udp --name lthn-openvpn --device=/dev/net/tun --cap-add=NET_ADMIN -v ${pwd}/etc:/home/lthn/openvpn/etc -v ${pwd}/profile:/home/lthn/openvpn/profile lthn/openvpn
```

  Generating additional client certficates or profiles from the live running container.
  
  LINUX / WINDOWS (powershell)
```
    docker exec lthn-openvpn generate_certs.sh --client --with-capass <your-capass> --with-clientpass <clientpass> --with-clientcn <clientcn>

    docker exec lthn-openvpn generate_client_profile.sh <clientcn> <your-server-public-dns>
```
  