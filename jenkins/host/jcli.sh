#!/bin/bash
# Jenkins CLI inside the controller container; auth comes from a file in Jenkins' secrets dir (never argv).
# usage: sudo /opt/nv-cicd/bin/jcli.sh <command> [args...]   (stdin is passed through)
exec docker exec -i jenkins java -jar /var/jenkins_home/jenkins-cli.jar -s http://localhost:8080/ \
  -auth @/var/jenkins_home/secrets/cli-auth -webSocket "$@"
