// Point the NeuVector plugin at the controller (reverse tunnel on 127.0.0.1:<port>) with the API key
// from credential 'neuvector-apikey', and register Docker Hub as an anonymous registry (public repo).
// usage: sudo /opt/nv-cicd/bin/jcli.sh groovy = <port> < configure-neuvector.groovy
import com.cloudbees.plugins.credentials.CredentialsProvider
import org.jenkinsci.plugins.plaincredentials.StringCredentials
import hudson.util.Secret
import io.jenkins.plugins.neuvector.*

def port = args[0]
def j = jenkins.model.Jenkins.get()
def key = CredentialsProvider.lookupCredentialsInItemGroup(StringCredentials, j, hudson.security.ACL.SYSTEM2, [])
            .find { it.id == 'neuvector-apikey' }?.secret
if (key == null) { println 'credential neuvector-apikey not found'; return }
def d = j.getDescriptorByType(NeuVectorBuilder.DescriptorImpl)
// (nickname, url, user, password, disableTLSCertVerification, disableAPIKeyVerification, serverCertificate, timeout, serverApiKey)
def c = new ControllerEndpointUrl('nv-home-lab', "https://127.0.0.1:${port}", '', Secret.fromString(''), true, false, '', 0, key)
d.setControllerEndpointUrls([c])
d.setRegistries([new Registry('dockerhub', 'https://registry.hub.docker.com', '', Secret.fromString(''))])
d.save()
println "controllers=${d.getControllerEndpointUrls()*.nickname} registries=${d.getRegistries()*.nickname}"
