pipeline {
  agent any

  options { disableConcurrentBuilds() }

  parameters {
    booleanParam(name: 'BUILD_ALL', defaultValue: false,
                 description: 'Build and deploy all four tools, not only changed ones')
  }

  triggers { githubPush() }

  environment {
    ACR_NAME = 'sriramacr2026'                 // <- your registry name
    ACR      = 'sriramacr2026.azurecr.io'      // <- your registry name
    RG       = 'rg-app-dev'
    SERVICES = 'grafana,prometheus,loki,tempo' // folder = compose service = Container App
  }

  stages {

    stage('Detect changes') {
      steps {
        script {
          env.TAG = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
          def all = env.SERVICES.split(',') as List
          def selected = []
          if (params.BUILD_ALL || !env.GIT_PREVIOUS_SUCCESSFUL_COMMIT) {
            selected = all
          } else {
            def files = sh(script: "git diff --name-only ${env.GIT_PREVIOUS_SUCCESSFUL_COMMIT} HEAD",
                           returnStdout: true).trim()
            for (s in all) {
              if (files.contains("${s}/") || files.contains('docker-compose')) { selected << s }
            }
          }
          env.CHANGED = selected.join(',')
          echo "Version tag: ${env.TAG}"
          echo "Tools to deploy: ${env.CHANGED ?: 'none'}"
        }
      }
    }

    stage('Build & push images') {
      when { expression { return env.CHANGED != '' } }
      steps {
        sh 'az login --identity --output none'
        sh 'az extension add -n containerapp --upgrade --only-show-errors'
        sh 'az acr login -n $ACR_NAME'
        script {
          def svcs = env.CHANGED.replace(',', ' ')
          sh "REGISTRY=${env.ACR} TAG=${env.TAG} docker compose build --pull ${svcs}"
          sh "REGISTRY=${env.ACR} TAG=${env.TAG} docker compose push ${svcs}"
        }
      }
    }

    stage('Deploy to Azure') {
      when { expression { return env.CHANGED != '' } }
      steps {
        script {
          for (s in env.CHANGED.split(',')) {
            sh "az containerapp update -n ${s} -g ${env.RG} --image ${env.ACR}/${s}:${env.TAG} --output none"
            echo "Deployed ${s}:${env.TAG}"
          }
        }
      }
    }
  }

  post {
    always { sh 'docker image prune -f || true' }
  }
}
