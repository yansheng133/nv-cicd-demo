#!/bin/bash
# Print the IDs of global Jenkins credentials, one per line (no secret values).
printf '%s' 'import com.cloudbees.plugins.credentials.CredentialsProvider
import com.cloudbees.plugins.credentials.common.StandardCredentials
CredentialsProvider.lookupCredentialsInItemGroup(StandardCredentials, jenkins.model.Jenkins.get(), hudson.security.ACL.SYSTEM2, []).each { println it.id }' \
  | /opt/nv-cicd/bin/jcli.sh groovy =
