#!/bin/bash
# Create or replace a global Jenkins credential. The secret value is read from stdin only.
# usage: sudo /opt/nv-cicd/bin/put-credential.sh <id> secret            < value
#        sudo /opt/nv-cicd/bin/put-credential.sh <id> userpass <user>   < password
#        sudo /opt/nv-cicd/bin/put-credential.sh <id> sshkey <user>     < private key
set -euo pipefail
ID=$1; KIND=$2; USERNAME=${3:-}
XML=$(python3 -I -c '
import sys, html
id_, kind, user = sys.argv[1], sys.argv[2], sys.argv[3]
v = sys.stdin.read()
e = lambda s: html.escape(s, quote=True)
if kind == "secret":
    print(f"<org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl><scope>GLOBAL</scope><id>{e(id_)}</id><description>{e(id_)}</description><secret>{e(v.strip())}</secret></org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl>")
elif kind == "userpass":
    print(f"<com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl><scope>GLOBAL</scope><id>{e(id_)}</id><description>{e(id_)}</description><username>{e(user)}</username><password>{e(v.strip())}</password></com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>")
elif kind == "sshkey":
    print(f"<com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey><scope>GLOBAL</scope><id>{e(id_)}</id><description>{e(id_)}</description><username>{e(user)}</username><privateKeySource class=\"com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey$DirectEntryPrivateKeySource\"><privateKey>{e(v)}</privateKey></privateKeySource></com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey>")
else:
    sys.exit("unknown kind")
' "$ID" "$KIND" "$USERNAME")
J=/opt/nv-cicd/bin/jcli.sh
if $J get-credentials-as-xml system::system::jenkins _ "$ID" >/dev/null 2>&1; then
  printf '%s' "$XML" | $J update-credentials-by-xml system::system::jenkins _ "$ID"
else
  printf '%s' "$XML" | $J create-credentials-by-xml system::system::jenkins _
fi
unset XML
echo "credential $ID ($KIND) stored"
