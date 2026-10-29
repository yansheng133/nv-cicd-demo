#!/bin/bash
# Print "<number> <result|RUNNING> <description>" for recent builds of a job (default nv-cicd-demo).
printf '%s' "def j = jenkins.model.Jenkins.get().getItemByFullName('${1:-nv-cicd-demo}')
j.builds.limit(${2:-5}).each { b -> println \"#\${b.number} \${b.building ? 'RUNNING' : b.result} \${b.description ?: ''}\" }" \
  | /opt/nv-cicd/bin/jcli.sh groovy =
