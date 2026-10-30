// nv-cicd-demo: build a multi-arch image, scan the candidate tag with NeuVector (Controller & Scanner mode,
// registry scan), and only promote + update the GitOps repo when the High CVE count is below the threshold.
pipeline {
  agent any
  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '30'))
  }
  triggers {
    // Polls main every minute; the job's SCM settings only react to app/ and Jenkinsfile changes,
    // so Jenkins' own deploy/ commits do not start a new build.
    pollSCM('* * * * *')
  }
  parameters {
    string(name: 'HIGH_THRESHOLD', defaultValue: '1', description: 'Fail the build when High + Critical CVEs are at or above this number (0 = no limit)')
  }
  environment {
    IMAGE         = "docker.io/${env.DOCKERHUB_NAMESPACE}/nv-cicd-demo"
    NV_REPOSITORY = "${env.DOCKERHUB_NAMESPACE}/nv-cicd-demo"
    CANDIDATE     = "candidate-${env.BUILD_NUMBER}"
    // per-build Docker config inside the workspace; nothing is left in the Jenkins home
    DOCKER_CONFIG = "${env.WORKSPACE}/.docker"
    BUILDER       = "nv-cicd-demo-${env.BUILD_NUMBER}"
    // NeuVector controller REST API (reverse tunnel on the EC2) and the registry T-B configured for this repo
    NV_API        = 'https://127.0.0.1:10443'
    NV_REGISTRY   = 'nv-cicd-demo'
  }
  stages {
    stage('Build') {
      steps {
        script {
          env.BASE_IMAGE  = readFile('app/base-image.txt').trim()
          env.APP_VERSION = "${readFile('app/VERSION').trim()}.${env.BUILD_NUMBER}"
          currentBuild.description = "${env.APP_VERSION} on ${env.BASE_IMAGE}"
        }
        echo "Version ${env.APP_VERSION}, base image ${env.BASE_IMAGE}"
        sh '''
          docker buildx create --name "$BUILDER" --driver docker-container >/dev/null
          docker buildx build --builder "$BUILDER" --platform linux/amd64,linux/arm64 \
            --provenance=false --sbom=false --build-arg BASE_IMAGE="$BASE_IMAGE" --build-arg VERSION="$APP_VERSION" \
            -t "$IMAGE:$CANDIDATE" app
        '''
      }
    }
    stage('Push candidate') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DH_USER', passwordVariable: 'DH_TOKEN')]) {
          sh '''
            printenv DH_TOKEN | docker login -u "$DH_USER" --password-stdin docker.io >/dev/null
            docker buildx build --builder "$BUILDER" --platform linux/amd64,linux/arm64 \
              --provenance=false --sbom=false --build-arg BASE_IMAGE="$BASE_IMAGE" --build-arg VERSION="$APP_VERSION" \
              -t "$IMAGE:$CANDIDATE" --push app
          '''
        }
        script {
          env.CANDIDATE_DIGEST = sh(returnStdout: true,
            script: 'docker buildx imagetools inspect "$IMAGE:$CANDIDATE" --format "{{json .Manifest}}" | jq -r .digest').trim()
        }
        echo "Pushed ${env.IMAGE}:${env.CANDIDATE} (${env.CANDIDATE_DIGEST})"
      }
    }
    stage('NeuVector scan') {
      steps {
        neuvector controllerEndpointUrlSelection: 'nv-home-lab',
                  registrySelection: 'dockerhub',
                  repository: env.NV_REPOSITORY,
                  tag: env.CANDIDATE,
                  numberOfHighSeverityToFail: params.HIGH_THRESHOLD,
                  scanTimeout: 10
        // The plugin only counts severity "High"; NeuVector 5.6 also reports "Critical", and the cluster's
        // admission rule counts High + Critical. Apply the same rule here so CI and the cluster agree.
        sh '''
          report=$(ls -t NeuVectorReport_${JOB_BASE_NAME}_${BUILD_NUMBER}-*.json | head -1)
          high=$(jq '[.report.vulnerabilities[] | select(.severity == "High")] | length' "$report")
          critical=$(jq '[.report.vulnerabilities[] | select(.severity == "Critical")] | length' "$report")
          echo "NeuVector gate: High $high + Critical $critical = $((high + critical)), threshold $HIGH_THRESHOLD"
          if [ "$HIGH_THRESHOLD" -gt 0 ] && [ $((high + critical)) -ge "$HIGH_THRESHOLD" ]; then
            echo "NeuVector gate: FAILED, High + Critical is at or above the threshold; the candidate is not promoted"
            exit 1
          fi
        '''
      }
    }
    stage('Promote') {
      steps {
        // same digest as the scanned candidate: the manifest list is re-tagged, nothing is rebuilt
        sh '''
          docker buildx imagetools create -t "$IMAGE:$APP_VERSION" "$IMAGE@$CANDIDATE_DIGEST"
          docker buildx imagetools inspect "$IMAGE:$APP_VERSION" | grep -E '^(Name|Digest)|Platform: *linux/(amd64|arm64)'
        '''
      }
    }
    stage('Wait for registry scan') {
      steps {
        // The cluster's admission rule "Image scanned" looks at NeuVector's registry scan, not at the CI scan above.
        // Periodic registry scans are off (Docker Hub anonymous pull limit), so start one for the new tag and
        // wait until it has a finished result before Argo CD can deploy it.
        withCredentials([string(credentialsId: 'neuvector-apikey', variable: 'NV_KEY')]) {
          sh '''
            code=$(printf 'X-Auth-Apikey: %s\\n' "$NV_KEY" | curl -sk --max-time 15 -o /dev/null -w '%{http_code}' -H @- \
              -X POST "$NV_API/v1/scan/registry/$NV_REGISTRY/scan")
            echo "Start registry scan of $NV_REGISTRY: HTTP $code"
            [ "$code" = "200" ] || exit 1
            for i in $(seq 1 40); do
              status=$(printf 'X-Auth-Apikey: %s\\n' "$NV_KEY" | curl -sk --max-time 15 -H @- \
                "$NV_API/v1/scan/registry/$NV_REGISTRY/images" \
                | jq -r --arg tag "$APP_VERSION" '[.images[]? | select(.tag == $tag) | .status] | first // "not listed"')
              echo "Registry scan of $NV_REPOSITORY:$APP_VERSION: $status"
              [ "$status" = "finished" ] && exit 0
              sleep 15
            done
            echo "Registry scan did not finish within 10 minutes; not updating the GitOps repo"
            exit 1
          '''
        }
      }
    }
    stage('Update GitOps repo') {
      steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'github-deploy-key', keyFileVariable: 'DEPLOY_KEY')]) {
          sh '''
            rm -rf gitops
            export GIT_SSH_COMMAND="ssh -i $DEPLOY_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
            git clone -q --depth 1 --branch main "$GITOPS_REPO" gitops
            cd gitops/deploy
            sed -i "s|^\\(    newTag:\\).*|\\1 $APP_VERSION|" kustomization.yaml
            git diff --stat
            git -c user.name="nv-cicd-demo Jenkins" -c user.email="jenkins@nv-cicd-demo.invalid" \
              commit -q -am "deploy: nv-cicd-demo $APP_VERSION (Jenkins build $BUILD_NUMBER)"
            git push -q origin HEAD:main
            git log -1 --format='Pushed %h %s'
          '''
        }
      }
    }
  }
  post {
    always {
      sh 'docker buildx rm "$BUILDER" >/dev/null 2>&1 || true; docker logout docker.io >/dev/null 2>&1 || true; rm -rf "$DOCKER_CONFIG"'
    }
  }
}
