
certificates.create_self_signed() {
  ## Creates a new self-signed certificate CA and certififcate.
  # $1 - Output dir.
  # $2 - Service host name.
  local _out_dir=$1
  local _site=$2

  local _root_ca_key="${_out_dir}/root_ca.key"
  local _root_ca_csr="${_out_dir}/root_ca.csr"
  local _root_ca_crt="${_out_dir}/root_ca.crt"
  local _root_ca_cnf="${_out_dir}/root_ca.cnf"

  local _site_key="${_out_dir}/${_site}.key"
  local _site_csr="${_out_dir}/keys/${_site}.csr"
  local _site_crt="${_out_dir}/${_site}.crt"
  local _site_cnf="${_out_dir}/${_site}.cnf"

  util.log "Creating a self-signed TLS certificate for ${_site}"
  util.log "Generate a root CA key"
  mkdir -p "${_root_ca_key%/*}"
  openssl genrsa -out "${_root_ca_key}" 4096

  util.log "Generate a root CA CSR"
  mkdir -p "${_root_ca_csr%/*}"
  openssl req -new -key "${_root_ca_key}" \
    -out "${_root_ca_csr}" -sha256 \
    -subj '/C=US/ST=CA/L=San Jose/O=Dev and Ops/CN=Trust No One CA'

  util.log "Configure the root CA"
  # Constrains the root CA to only be able to sign leaf certificates and not intermediate CAs.
  mkdir -p "${_root_ca_cnf%/*}"
  cat >"${_root_ca_cnf}" <<EOF
[root_ca]
basicConstraints = critical,CA:TRUE,pathlen:1
keyUsage = critical, nonRepudiation, cRLSign, keyCertSign
subjectKeyIdentifier=hash
EOF

  util.log "Sign the root CA certificate"
  mkdir -p "${_root_ca_crt%/*}"
  openssl x509 -req -days 3650 \
    -in "${_root_ca_csr}" -signkey "${_root_ca_key}" -sha256 \
    -out "${_root_ca_crt}" -extfile "${_root_ca_cnf}" -extensions root_ca

  util.log "Generate the site key"
  mkdir -p "${_site_key%/*}"
  openssl genrsa -out "${_site_key}" 4096

  util.log "Generate the site certificate"
  mkdir -p "${_site_csr%/*}"
  openssl req -new -key "${_site_key}" \
    -out "${_site_csr}" -sha256 \
    -subj '/C=US/ST=CA/L=San Jose/O=Dev and Ops/CN=localhost'

  util.log "Configure the site certificate"
  # Constrain the site certificate so that it can only be used to authenticate a server and can’t be used to sign certificates.
  mkdir -p "${_site_cnf%/*}"
  cat >"${_site_cnf}" <<EOF
[server]
authorityKeyIdentifier=keyid,issuer
basicConstraints = critical,CA:FALSE
extendedKeyUsage=serverAuth
keyUsage = critical, digitalSignature, keyEncipherment
subjectAltName = DNS:localhost, IP:127.0.0.1, DNS: ${_site}
subjectKeyIdentifier=hash
EOF

  util.log "Sign the site certificate"
  mkdir -p "${_site_crt%/*}"
  openssl x509 -req -days 750 \
    -in "${_site_csr}" -sha256 \
    -CA "${_root_ca_crt}" -CAkey "${_root_ca_key}" -CAcreateserial \
    -out "${_site_crt}" -extfile "${_site_cnf}" -extensions server
  # The site.csr and site.cnf files are needed for generating certificates for
  # another site. Protect the root-ca.key file!
}

certificates.setup_letsencrypt() {
  # Setup Nginx with Let's Encrypt certificate.
  # $1 - Site admin email.
  # $2 - Output dir.
  # $3-$n - Site domain(s).
  local _admin_email=$1; shift
  local _out_dir=$1; shift
  local _sites=($@)

  if [ ! -f "${HOME}/.lego/certificates/${_sites[0]}.crt" ] || \
     [ ! -f "${HOME}/.lego/certificates/${_sites[0]}.key" ]; then
    util.log_error "Run '$0 le-cert' to create Let's Encrypt Site certificates."
    exit 1
  fi

  mkdir -p "${_out_dir}"
  cp -v "${HOME}/.lego/certificates/${_sites[0]}".{crt,key} "${_out_dir}"
}

certificates.create_letsencrypt() {
  # Generates Let's Encrypt TLS certificate.
  # Requires sudo permission and localhost:443 port be available.
  # TODO: Check exisiting certificate expiration date to avoid rate limit lockout
  # https://letsencrypt.org/docs/rate-limits/
  # $1 - admin email
  # $2-$n - Domain list. Certificate filename will reflect the first domain.
  local _admin_email=$1
  shift
  local _sites=($@)

  install_lego() {
    ## Installs a lego release
    # $1 - lego release semver
    local _semver=$1
    cleanup() { rm -rf "${tmp_dir}"; }
    tmp_dir=$(mktemp -d)
    mkdir -p "${tmp_dir}"
    trap cleanup EXIT
    (
      cd "${tmp_dir}" || exit 1
      curl -sLS -o 'lego.zip' \
        "https://github.com/xenolf/lego/releases/download/v${_semver}/lego_darwin_amd64.zip"
      unzip lego.zip
      mv 'lego_darwin_amd64' '/usr/local/bin/lego'
      chmod +x '/usr/local/bin/lego'
    )
  }

  # Check lego, install if missing.
  lego --version 2>/dev/null 2>&1 || install_lego '0.4.0'
  if [ -f "${HOME}/.lego/certificates/${_sites[0]}.crt" ]; then
    util.log "Renewing Let's Encrypt site certificate '${HOME}/.lego/certificates/${_sites[0]}.crt'"
    util.log "Running: sudo lego ${_sites[@]/#/--domains } --email '${_admin_email}'" \
      "--accept-tos --path '${HOME}/.lego' --tls :443 renew"
    sudo lego ${_sites[@]/#/--domains } --email "${_admin_email}" --accept-tos \
      --path "${HOME}/.lego" --tls :443 renew
  else
    util.log "Generating Let's Encrypt site certificate"
    util.log "Running: sudo lego ${_sites[@]/#/--domains } --email '${_admin_email}'" \
      "--accept-tos --path '${HOME}/.lego' --tls :443 run"
    sudo lego ${_sites[@]/#/--domains } --email "${_admin_email}" --accept-tos \
      --path "${HOME}/.lego" --tls :443 run
  fi
  sudo chown -R "${USER}" "${HOME}/.lego"
}
