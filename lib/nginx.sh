nginx.setup() {
  local _site_conf="${nginx_dir}/config/site.conf"

  util.log "Setup Nginx"
  mkdir -p "${_site_conf%/*}"

  util.log "Create Nginx configuration file"
  # nginx.conf content inlined to leverage shell's undefined variable checking.
  # Native nginx variables need to be escaped.
  cat >"${_site_conf}" <<EOF
access_log off;

log_format apm
  '"\$time_iso8601" host=\$host '
  'user=\$remote_user client=\$remote_addr '
  'server_name=\$server_name upstream_addr=\$upstream_addr '
  'method=\$request_method request="\$request" '
  'request_length=\$request_length '
  'status=\$status bytes_sent=\$bytes_sent '
  'body_bytes_sent=\$body_bytes_sent '
  'referer=\$http_referer '
  'user_agent="\$http_user_agent" '
  'upstream_addr=\$upstream_addr '
  'upstream_status=\$upstream_status '
  'request_time=\$request_time '
  'upstream_response_time=\$upstream_response_time '
  'upstream_connect_time=\$upstream_connect_time '
  'upstream_header_time=\$upstream_header_time';

gzip_types
  text/plain text/css application/json application/x-javascript text/xml
  application/xml application/xml+rss text/javascript;

# Apply fix for very long server names
server_names_hash_bucket_size 128;

# Turn off nginx version number reporting in server header and error pages.
server_tokens off;

# Add nosniff header (https://www.owasp.org/index.php/List_of_useful_HTTP_headers)
add_header X-Content-Type-Options nosniff;

# Set appropriate X-Forwarded-Ssl header
map \$scheme \$proxy_x_forwarded_ssl {
  default off;
  https on;
}

# If we receive X-Forwarded-Proto, pass it through; otherwise, pass along the
# scheme used to connect to this server
map \$http_x_forwarded_proto \$proxy_x_forwarded_proto {
  default \$http_x_forwarded_proto;
  '' \$scheme;
}
# If we receive X-Forwarded-Port, pass it through; otherwise, pass along the
# server port the client connected to
map \$http_x_forwarded_port \$proxy_x_forwarded_port {
  default \$http_x_forwarded_port;
  '' \$server_port;
}
# If we receive Upgrade, set Connection to "upgrade"; otherwise, delete any
# connection header that may have been passed to this server.
# https://www.nginx.com/blog/websocket-nginx/
map \$http_upgrade \$proxy_connection {
  default upgrade;
  '' close;
}

# Set a variable to help decide if we need to add the
# 'Docker-Distribution-Api-Version' header. The registry always sets this header.
# In the case of nginx performing auth, the header will be unset since nginx is
# auth-ing before proxying.
# https://docs.docker.com/registry/recipes/nginx/#setting-things-up
map \$upstream_http_docker_distribution_api_version \$docker_distribution_api_version {
'' 'registry/2.0';
}

proxy_http_version 1.1;
proxy_set_header Host \$http_host;   # Required for Docker client's sake.
proxy_set_header Connection \$proxy_connection;
proxy_set_header Upgrade \$http_upgrade;
proxy_set_header X-Real-IP \$remote_addr; # pass on real client's IP
proxy_set_header X-Original-URI \$request_uri;
proxy_set_header X-Forwarded-Proto \$scheme;
proxy_set_header X-Forwarded-Ssl \$proxy_x_forwarded_ssl;
proxy_set_header X-Forwarded-Port \$proxy_x_forwarded_port;
proxy_set_header X-Forwarded-Host \$server_name;
proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

# Mitigate httpoxy attacks.
proxy_set_header Proxy "";
server {
	server_name _; # An invalid value which will never trigger on a real hostname.
	listen 80;
	access_log /var/log/nginx/access.log apm;
	return 503;
}

#-------------------------------------------------------------------------------
upstream blog {
  server ghost:2368;
}
upstream registry {
  server registry:5000;
}
upstream web {
  server web:8080;
}

server {
  server_name _;
  return 444;
}
server {
  server_name ${host_fqdn} ci.${host_fqdn} blog.${host_fqdn};
  # Practice with 302
  return 301 https://\$host\$request_uri;
}

server {
  server_name ${host_fqdn};
  listen 443 ssl http2 default_server;
  access_log /var/log/nginx/access.log apm;

  ssl_certificate /run/nginx/secrets/${host_fqdn}.crt;
  ssl_certificate_key /run/nginx/secrets/${host_fqdn}.key;

  # Speed up performance with SSL session caching.
  ssl_session_timeout 5m;
  ssl_session_cache shared:SSL:10m;
  keepalive_timeout 70;

  # Turn on OCSP Stapling for added SSL speed and privacy.
  # https://scotthelme.co.uk/ocsp-stapling-speeding-up-ssl/
  ssl_stapling on;
  ssl_stapling_verify on;
  ssl_trusted_certificate /run/nginx/secrets/${host_fqdn}.crt;
  resolver 8.8.8.8 8.8.4.4 valid=300s;
  resolver_timeout 10s;

  # Skip on SSL protocols due to SSLv3 poodle vulnerability.
  # https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html
  # https://scotthelme.co.uk/a-plus-rating-qualys-ssl-test/
  # http://www.howtoforge.com/ssl-perfect-forward-secrecy-in-nginx-webserver
  # https://github.com/ssllabs/research/wiki/SSL-and-TLS-Deployment-Best-Practices
  ssl_protocols TLSv1.1 TLSv1.2;
  # A modern and secure cipher set.
  # ssl_ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:AES256+EECDH:AES256+EDH:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS:!eNULL:!EXPORT:!DES:!RC4:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SH:!3DES:;
  # These ciphers matches the Let's Encrypt Certificate. Insecures ciphers
  # always listed to ensure that these will never, ever be activated.
  ssl_ciphers AES256+EECDH:AES256+EDH:!aNULL:!MD5:!DSS:!eNULL:!EXPORT:!DES:!RC4:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SH:!3DES:;
  ssl_prefer_server_ciphers on;

  # Diffie-Hellman parameters for DHE ciphers.
  ssl_dhparam /run/nginx/secrets/dh.pem;

  # Disable transfer limits to avoid HTTP 413 for large image uploads.
  client_max_body_size 0;

  # Avoid HTTP 411: see Issue #1486 (https://github.com/moby/moby/issues/1486)
  chunked_transfer_encoding on;

  # https://www.nginx.com/blog/http-strict-transport-security-hsts-and-nginx/
  add_header Strict-Transport-Security "max-age=31536000; includeSubdomains";

  location / {
    proxy_pass http://web;
    proxy_buffering off;
  }

  location /blog/ {
    proxy_pass http://blog;
    proxy_buffering off;
  }

  location /v2/ {
    proxy_pass http://registry;
    proxy_read_timeout 900;

    auth_basic "Registry realm";
    auth_basic_user_file /run/registry/secrets/htpasswd;

    # Add Docker-Distribution-Api-Version header if missing. See map directive above.
    add_header 'Docker-Distribution-Api-Version' \$docker_distribution_api_version always;

    # Reject connections from docker 1.5 and earlier. Docker 1.6.0 and earlier
    # releases did not properly set the user agent on ping. Check for "Go ".
    if (\$http_user_agent ~ "^(docker\/1\.(3|4|5(?!\.[0-9]-dev))|Go ).*\$" ) {
      return 404;
    }
  }
}

EOF

  local dh_key
  dh_key="${nginx_dir}/secrets/dh.pem"
  if [ -f "${dh_key}" ]; then
    util.log "Using existing Diffie-Hellman file ${dh_key}"
  else
    util.log "Generating Diffie-Hellman parameters"
    time openssl dhparam -out "${dh_key}" 2048
  fi
}
