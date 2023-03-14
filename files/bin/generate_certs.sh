#!/usr/bin/env bash

# set PATH to find all binaries
PATH=$PATH:/home/lthn/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin
export TOPDIR=$(realpath $(dirname $0))

# Static defaults
LTHN_PREFIX=/home/lthn/openvpn

# General usage help
usage() {
  echo
  echo "To generate root CA"
  echo $0 "--ca [--with-cacn commonname --with-capass pass] [--generate-dh] [--generate-tls-auth]"
  echo
  echo "To generate server certificate"
  echo $0 "--server [--with-servercn commonname --with-serverpass pass] [--generate-dh] [--generate-tls-auth]"
  echo
  echo "To generate client certificate"
  echo $0 "--client [--with-clientcn commonname --with-capass pass] [--generate-dh] [--generate-tls-auth]"
  echo
  echo "To generate root CA, one server and one client certificate using defaults"
  echo $0 "--defaults"
  echo
  exit
}

# Find command or report error. If env is already set, only test availability
# $1 - cmd
# $2 - env to get/set
# $3 - optional
findcmd() {
  local cmd="$1"
  local env="$2"
  eval "bin=\$$env"

  if [ -z "$bin" ]; then
    bin=$(PATH=$PATH:/usr/sbin which $cmd)
  fi

  if [ -z "$3" ]; then
    if [ -z "$bin" ]; then
      echo "Missing $cmd!"
    fi
  else
    if [ -z "$bin" ]; then
      echo "Not found $cmd"
    fi
  fi
  eval "$env=$bin"
}

defaults() {
  findcmd openvpn OPENVPN_BIN optional
  findcmd openssl OPENSSL_BIN
  findcmd sudo SUDO_BIN optional

}

summary() {
  echo
  if [ -z "$OPENSSL_BIN" ]; then
    echo "Missing openssl. Exiting."
    usage
    exit 1
  fi

  echo "Lethean certificate(s) and/or key(s) generated."
  echo
  echo "sudo bin:     $SUDO_BIN"
  echo "Openssl bin:  $OPENSSL_BIN"
  echo "Openvpn bin:  $OPENVPN_BIN"
  echo "Prefix:       $LTHN_PREFIX"
  echo "Conf dir:     $sysconf_dir"
  echo "CA dir:       $ca_dir"
  echo
}

# Specify configuration for local root CA and how it is generated
generate_ca() {
  local prefix="$1"
  local cn="$2"
  echo "Generating CA Certificate (cn=$cn) to $prefix/private/ca.key.pem"
  cd "$prefix" || exit 2
  mkdir -p "$prefix"/private/client "$prefix"/certs/client "$prefix"/csr/client "$prefix"/newcerts || exit 2
  touch "$prefix"/index.txt
  echo -n 00 >"$prefix"/serial
  "${OPENSSL_BIN}" genrsa -aes256 -out "$prefix"/private/ca.key.pem -passout pass:$ca_pass 4096
  chmod 400 "$prefix"/private/ca.key.pem
  "${OPENSSL_BIN}" req -config $LTHN_PREFIX/conf/ca.cfg -batch -subj "/CN=$cn" -passin pass:$ca_pass \
    -key "$prefix"/private/ca.key.pem \
    -new -x509 -days 7300 -sha256 -extensions v3_ca \
    -out "$prefix"/certs/ca.cert.pem
  if ! [ -f "$prefix"/certs/ca.cert.pem ]; then
    echo "Error generating CA! See messages above."
    exit 2
  fi
}

# Specify how server keys are generated and signed with local CA
generate_server() {
  local prefix="$1"
  local cn="$2"
  echo "Generating Server Certificate (cn=$cn)"
  cd "$prefix" || exit 2
  "${OPENSSL_BIN}" genrsa -aes256 \
    -out "$prefix"/private/"$cn".key.pem -passout pass:$server_pass 4096
  chmod 400 "$prefix"/private/"$cn".key.pem
  "${OPENSSL_BIN}" req -config $LTHN_PREFIX/conf/ca.cfg -batch -subj "/CN=$cn" -passin "pass:$server_pass" \
    -key "$prefix"/private/"$cn".key.pem \
    -new -sha256 -out "$prefix"/csr/"$cn".csr.pem
  "${OPENSSL_BIN}" ca -batch -config $LTHN_PREFIX/conf/ca.cfg -subj "/CN=$cn" -passin "pass:$server_pass" \
    -extensions server_cert -days 375 -notext -md sha256 \
    -in "$prefix"/csr/"$cn".csr.pem \
    -out "$prefix"/certs/"$cn".cert.pem
  (
    cat "$prefix"/certs/ca.cert.pem "$prefix"/certs/"$cn".cert.pem
    openssl rsa -passin "pass:$server_pass" -text <"$prefix"/private/"$cn".key.pem
  ) >"$prefix"/certs/"$cn".all.pem
  (
    cat "$prefix"/certs/"$cn".cert.pem
    openssl rsa -passin "pass:$server_pass" -text <"$prefix"/private/"$cn".key.pem
  ) >"$prefix"/certs/"$cn".both.pem
  if ! [ -f "$prefix"/certs/"$cn".cert.pem ]; then
    echo "Error generating cert $cn! See messages above."
    exit 2
  fi
}

# Specify how client keys are generated and signed with local CA
generate_client() {
  local prefix="$1"
  local cn="$2"
  echo "Generating Client Certificate (cn=$cn)"
  cd "$prefix" || exit 2
  "${OPENSSL_BIN}" genrsa -aes256 \
    -out "$prefix"/private/client/"$cn".key.pem -passout pass:$client_pass 2048
  chmod 400 "$prefix"/private/client/"$cn".key.pem
  "${OPENSSL_BIN}" req -config $LTHN_PREFIX/conf/ca.cfg -batch -subj "/CN=$cn" -passin "pass:$client_pass" \
    -key "$prefix"/private/client/"$cn".key.pem \
    -new -sha256 -out "$prefix"/csr/client/"$cn".csr.pem
  "${OPENSSL_BIN}" ca -batch -config $LTHN_PREFIX/conf/ca.cfg -subj "/CN=$cn" -passin "pass:$client_pass" \
    -extensions usr_cert -days 375 -notext -md sha256 \
    -in "$prefix"/csr/client/"$cn".csr.pem \
    -out "$prefix"/certs/client/"$cn".cert.pem
  (
    cat "$prefix"/certs/ca.cert.pem "$prefix"/certs/client/"$cn".cert.pem
    openssl rsa -passin "pass:$client_pass" -text <"$prefix"/private/client/"$cn".key.pem
  ) >"$prefix"/certs/client/"$cn".all.pem
  (
    cat "$prefix"/certs/client/"$cn".cert.pem
    openssl rsa -passin "pass:$client_pass" -text <"$prefix"/private/client/"$cn".key.pem
  ) >"$prefix"/certs/client/"$cn".both.pem
  if ! [ -f "$prefix"/certs/client/"$cn".cert.pem ]; then
    echo "Error generating cert $cn! See messages above."
    exit 2
  fi
}

generate_env() {
  cat <<EOF
LTHN_PREFIX=$LTHN_PREFIX
OPENVPN_BIN=$OPENVPN_BIN
SUDO_BIN=$SUDO_BIN
OPENSSL_BIN=$OPENSSL_BIN

EOF
}

defaults

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
  -h | --help)
    usage
    ;;
  --prefix)
    LTHN_PREFIX="$2"
    shift
    shift
    ;;
  --openssl-bin)
    OPENSSL_BIN="$2"
    shift
    shift
    ;;
  --sudo-bin)
    SUDO_BIN="$2"
    shift
    shift
    ;;
  --with-capass)
    ca_pass="$2"
    shift
    shift
    ;;
  --with-cacn)
    ca_cn="$2"
    shift
    shift
    ;;
  --with-serverpass)
    server_pass="$2"
    shift
    shift
    ;;
  --with-servercn)
    server_cn="$2"
    shift
    shift
    ;;
  --with-clientpass)
    client_pass="$2"
    shift
    shift
    ;;
  --with-clientcn)
    client_cn="$2"
    shift
    shift
    ;;
  --generate-dh)
    generate_dh=1
    shift
    ;;
  --generate-tls-auth)
    generate_tls_auth=1
    shift
    ;;
  --ca)
    generate_ca=1
    shift
    ;;
  --server)
    generate_server=1
    shift
    ;;
  --client)
    generate_client=1
    shift
    ;;
  --defaults)
    ca_pass="1234"
    ca_cn="Lethean Exit Node Root CA"
    server_pass="1234"
    server_cn="Lethean_VPN_Server"
    client_pass="1234"
    client_cn="Lethean_VPN_Client"
    generate_ca=1
    generate_server=1
    generate_client=1
    generate_dh=1
    generate_tls_auth=1
    shift
    ;;
  *)
    echo "Unknown option $1"
    usage
    exit 1
    ;;
  esac
done

# Make directories for creation and moving generate keys
mkdir -p $LTHN_PREFIX/etc/ca/certs
mkdir -p $LTHN_PREFIX/etc/ca/private
mkdir -p $LTHN_PREFIX/etc/ca/certs/client
mkdir -p $LTHN_PREFIX/etc/ca/private/client

# Where files will eventually live
sysconf_dir=${LTHN_PREFIX}/etc
ca_dir=${LTHN_PREFIX}/etc/ca

# Abort Root CA certificate creation if already exists.
if [ -n "$generate_ca" ] && [ -f $LTHN_PREFIX/etc/ca/index.txt ]; then
  echo "CA already exists. Skipping."
fi

# Generate CA and place into desired folder
if [ -n "$generate_ca" ] && ! [ -f $LTHN_PREFIX/etc/ca/index.txt ]; then
  export ca_pass ca_cn
  if [ -z "$ca_pass" ] || [ -z "$ca_cn" ]; then
    echo "You must specify --with-capass yourpassword --with_cacn CN!"
    exit 2
  fi
  if [ "$ca_pass" = "1234" ]; then
    echo "Generating with default password!"
  fi
  (
    generate_ca $LTHN_PREFIX/etc/ca "$ca_cn"
  )
fi

# Abort server certificate creation if duplicate CN certificate already exists.
if [ -n "$generate_server" ] && [ -f $LTHN_PREFIX/etc/ca/certs/"$server_cn".cert.pem ]; then
  echo "Server certificate "$server_cn" already exists. Skipping."
fi

# Generate server certificate using our local CA and copy into desired folder
if [ -n "$generate_server" ] && ! [ -f $LTHN_PREFIX/etc/ca/certs/"$server_cn".cert.pem ]; then
  export server_pass server_cn
  if [ -z "$server_pass" ] || [ -z "$server_cn" ]; then
    echo "You must specify --with-serverpass yourpassword --with_servercn CN!"
    exit 2
  fi
  if [ "$server_pass" = "1234" ]; then
    echo "Generating with default password!"
  fi
  (
    generate_server $LTHN_PREFIX/etc/ca "$server_cn"
  )
    cp $LTHN_PREFIX/etc/ca/certs/"$server_cn".cert.pem $LTHN_PREFIX/etc/ca/certs/openvpn.cert.pem
    cp $LTHN_PREFIX/etc/ca/private/"$server_cn".key.pem $LTHN_PREFIX/etc/ca/private/openvpn.key.pem
fi

# Skip client certificate creation if duplicate CN certificate already exists.
if [ -n "$generate_client" ] && [ -f $LTHN_PREFIX/etc/ca/certs/client/$client_cn.cert.pem ]; then
  echo "Client certificate "$client_cn" already exists. Skipping."
fi

# Generate client certificate using our local CA and copy into desired folder
if [ -n "$generate_client" ] && ! [ -f $LTHN_PREFIX/etc/ca/certs/client/$client_cn.cert.pem ]; then
  export client_pass client_cn
  if [ -z "$client_pass" ] || [ -z "$client_cn" ]; then
    echo "You must specify --with-clientpass yourpassword --with_clientcn CN!"
    exit 2
  fi
  if [ "$client_pass" = "1234" ]; then
    echo "Generating with default password!"
  fi
  (
    generate_client $LTHN_PREFIX/etc/ca "$client_cn"
  )
fi

# Generate and copy DH key to desired folder
if [ -n "$generate_dh" ] && [ -f $LTHN_PREFIX/etc/dhparam.pem ]; then
  echo "DH key already exists. Skipping."
fi
if [ -n "$generate_dh" ] && ! [ -f $LTHN_PREFIX/etc/dhparam.pem ]; then
  if ! [ -f $LTHN_PREFIX/build/etc/dhparam.pem ]; then
    "$OPENSSL_BIN" dhparam -out $LTHN_PREFIX/etc/dhparam.pem 2048
  fi
fi


# Abort tls-auth key creation if already exists.
if [ -n "$generate_tls_auth" ] && [ -f $LTHN_PREFIX/etc/ta.key ]; then
  echo "TLS Auth key already exists. Skipping."
fi
if [ -n "$generate_tls_auth" ] && [ ! -f $LTHN_PREFIX/etc/ta.key ]; then
    "$OPENVPN_BIN" --genkey --secret $LTHN_PREFIX/etc/ta.key
fi


generate_env >env.mk
summary
