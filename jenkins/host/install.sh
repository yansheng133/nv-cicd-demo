#!/bin/bash
# Run on the EC2 host as root: build the Jenkins image, generate the admin password, start Jenkins on 127.0.0.1:8080.
# usage: sudo DOCKERHUB_NAMESPACE=<user> GITOPS_REPO=git@github.com:<user>/nv-cicd-demo.git bash install.sh <dir with jenkins files>
set -euo pipefail
SRC=$1
: "${DOCKERHUB_NAMESPACE:?}" "${GITOPS_REPO:?}"
install -d -m 755 /opt/nv-cicd/bin /opt/nv-cicd/jenkins
install -m 755 "$SRC"/host/*.sh /opt/nv-cicd/bin/
install -m 644 "$SRC"/Dockerfile "$SRC"/plugins.txt "$SRC"/casc.yaml /opt/nv-cicd/jenkins/
export DOCKER_CONFIG=/root/.docker   # SLES sets DOCKER_CONFIG=/etc/containers in the login profile
docker build -q -t nv-cicd-demo/jenkins:2.580.2 /opt/nv-cicd/jenkins
docker volume inspect jenkins_home >/dev/null 2>&1 || docker volume create jenkins_home >/dev/null
# admin password: generated once, kept in Jenkins' own secrets dir (600, uid 1000), never printed
docker run --rm -v jenkins_home:/var/jenkins_home --entrypoint sh nv-cicd-demo/jenkins:2.580.2 -c '
  set -e; umask 077; mkdir -p /var/jenkins_home/secrets
  f=/var/jenkins_home/secrets/nv-admin-password
  [ -s $f ] || head -c 32 /dev/urandom | base64 | tr -dc A-Za-z0-9 | head -c 28 > $f
  printf "admin:%s" "$(cat $f)" > /var/jenkins_home/secrets/cli-auth'
# label=disable: SELinux (enforcing on SLES 16) denies container_t access to docker.sock; this container
# already holds the Docker socket (root-equivalent), so confining it with a label adds nothing.
docker rm -f jenkins >/dev/null 2>&1 || true
docker run -d --name jenkins --restart unless-stopped --network host \
  --security-opt label=disable \
  --group-add "$(stat -c %g /var/run/docker.sock)" \
  -v jenkins_home:/var/jenkins_home -v /var/run/docker.sock:/var/run/docker.sock \
  -e DOCKERHUB_NAMESPACE -e GITOPS_REPO \
  -e JENKINS_OPTS="--httpListenAddress=127.0.0.1 --httpPort=8080" \
  nv-cicd-demo/jenkins:2.580.2 >/dev/null
for i in $(seq 1 90); do curl -sf -o /dev/null http://127.0.0.1:8080/login && break; sleep 2; done
curl -sf -o /dev/null http://127.0.0.1:8080/login || { echo "Jenkins did not come up"; docker logs --tail 50 jenkins; exit 1; }
docker exec jenkins curl -sf -o /var/jenkins_home/jenkins-cli.jar http://127.0.0.1:8080/jnlpJars/jenkins-cli.jar
/opt/nv-cicd/bin/jcli.sh version
