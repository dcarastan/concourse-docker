docker_compose.setup() {
  util.log "Generate docker-compose.yml"
  # Define shell template variables.
  if [ -f "${deployments_dir}/secrets.sh" ]; then
    util.log "Using ${deployments_dir}/secrets.sh"
  else
    cat >"${deployments_dir}/secrets.sh" <<EOF
ci_username='admin'
ci_password='$(util.mkpasswd 8)'
db_username='concourse'
db_password='$(util.mkpasswd 16)'
ghost_password='$(util.mkpasswd 8)'
EOF
  fi
  # shellcheck disable=SC1090
  source "${deployments_dir}/secrets.sh"

  cat >"${script_dir}/docker-compose.yml" <<EOF
# Concourse CI docker compose cluster
#
# Deploy using:  docker-compose up -d
#
# Note: Docker swarm doesn't support privileged containers. Deploy using
# docker-compose until Docker solves the following blocking issues:
#   https://github.com/docker/swarmkit/issues/1030
#   https://github.com/moby/moby/issues/24862
version: '3.1'

networks:
  blog:
    driver: bridge
  ci:
    driver: bridge

services:
  nginx:
    # An Alpine Nginx build is required. Regular Nginx container Debian builds
    # are not only bigger, but fail to decrypt docker registry's Bcrypt encoded
    # htpasswd content.
    # https://github.com/nginxinc/docker-nginx/issues/29#issuecomment-194817391
    # https://stackoverflow.com/questions/39636750/docker-registry-v2-with-tls-and-basic-auth-behind-nginx-authentication-error
    image: nginx:alpine
    ports:
    - 443:443
    networks:
    - ci
    - blog
    links:
    - ghost
    - registry
    - web
    volumes:
    - ./deployments/nginx/config:/etc/nginx/conf.d
    - ./deployments/nginx/secrets:/run/nginx/secrets:ro
    - ./deployments/registry/secrets:/run/registry/secrets:ro

  registry:
    image: registry:2
    restart: always
    ports:
    - 5000:5000
    networks:
    - ci
    environment:
      REGISTRY_AUTH: htpasswd
      REGISTRY_AUTH_HTPASSWD_PATH: /run/registry/secrets/htpasswd
      REGISTRY_AUTH_HTPASSWD_REALM: Registry Realm
    volumes:
    - ./deployments/registry/secrets:/run/registry/secrets:ro
    - ./deployments/registry/data:/var/lib/registry

  web:
    image: concourse/concourse
    networks:
    - ci
    depends_on:
    - db
    links:
    - db
    command: web
    ports:
    - 8080:8080
    volumes:
    - ./deployments/web:/concourse-keys
    # Service will retry until conocurse-db comes up.
    restart: unless-stopped
    environment:
      CONCOURSE_BASIC_AUTH_USERNAME: "${ci_username}"
      CONCOURSE_BASIC_AUTH_PASSWORD: "${ci_password}"
      CONCOURSE_EXTERNAL_URL: "${host_url}"
      CONCOURSE_POSTGRES_HOST: db
      CONCOURSE_POSTGRES_DATABASE: concourse
      CONCOURSE_POSTGRES_USER: "${db_username}"
      CONCOURSE_POSTGRES_PASSWORD: "${db_password}"

  worker:
    image: concourse/concourse
    networks:
    - ci
    # Swarming not possible as workers need to spin out job containers.
    privileged: true
    depends_on:
    - web
    links:
    - web
    volumes:
    - ./deployments/worker:/concourse-keys:ro
    environment:
      CONCOURSE_TSA_HOST: web
    command: worker
    
  db:
    # 9.5-alpine
    image: postgres:9.5
    volumes:
    - ./deployments/db/data:/data
    networks:
    - ci
    environment:
      POSTGRES_DB: concourse
      PGDATA: /data
      POSTGRES_USER: "${db_username}"
      POSTGRES_PASSWORD: "${db_password}"

  ghost:
    image: ghost:alpine
    restart: always
    networks:
    - blog
    volumes:
    - ./ghost:/var/lib/ghost/content
    ports:
    - 2368:2368
    environment:
      GHOST_CONTENT: /var/lib/ghost/content
      url: https://ci.carastan.com/blog/
      NODE_ENV: production

EOF
}
