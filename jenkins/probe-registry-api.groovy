// Can the Jenkins API key (role ciops) read NeuVector registry scan results? Prints status and field names only.
import com.cloudbees.plugins.credentials.CredentialsProvider
import org.jenkinsci.plugins.plaincredentials.StringCredentials
import javax.net.ssl.*
import jenkins.model.Jenkins
import java.security.cert.X509Certificate
def key = CredentialsProvider.lookupCredentials(StringCredentials, Jenkins.instance, null, null).find { it.id == 'neuvector-apikey' }.secret.plainText
def trustAll = [getAcceptedIssuers: { null }, checkClientTrusted: { a, b -> }, checkServerTrusted: { a, b -> }] as X509TrustManager
def ctx = SSLContext.getInstance('TLS'); ctx.init(null, [trustAll] as TrustManager[], null)
def get = { path ->
  def c = new URL("https://127.0.0.1:10443${path}").openConnection()
  c.SSLSocketFactory = ctx.socketFactory; c.hostnameVerifier = { h, s -> true } as HostnameVerifier
  c.setRequestProperty('X-Auth-Apikey', key)
  def code = c.responseCode
  [code, code < 400 ? c.inputStream.text : c.errorStream?.text]
}
def (code, body) = get('/v1/scan/registry/nv-cicd-demo/images')
println "GET /v1/scan/registry/nv-cicd-demo/images -> ${code}"
if (code == 200) {
  def j = new groovy.json.JsonSlurper().parseText(body)
  println "top keys: ${j.keySet()}"
  def imgs = j.images ?: []
  println "image keys: ${imgs ? imgs[0].keySet() : '-'}"
  imgs.each { println "${it.repository}:${it.tag} status=${it.status} high=${it.high} critical=${it.critical} medium=${it.medium}" }
} else { println body?.take(200) }
