// Jenkinsfile (Declarative Pipeline) — Multibranch friendly
pipeline {
  agent { label 'docker' } // or use 'k8s' label for k8s agent; provide appropriate agent template
  environment {
    // set defaults; override in Jenkins credentials bindings or pipeline params
    APP_NAME = "sample-app"
    REPO = "bitteswar/${APP_NAME}"
    // Choose registry: dockerhub, ghcr, or ECR
    REGISTRY = "dockerhub" // options: dockerhub | ghcr | ecr
    DOCKERHUB_CRED = "dockerhub-creds"
    GHCR_TOKEN = credentials('ghcr-token') // secret text
    AWS_CREDS = 'aws-creds'
    KUBECONFIG_CREDENTIAL_ID = 'kubeconfig-dev'
    SONAR_TOKEN = credentials('sonar-token')
    // build tag using commit sha
    GIT_SHORT = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
    IMAGE_TAG = "${GIT_SHORT}"
  }

  options {
    ansiColor('xterm')
    skipDefaultCheckout(false)
    timeout(time: 60, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
        sh 'git rev-parse --abbrev-ref HEAD > .branch || true'
        echo "Building branch: ${env.BRANCH_NAME}"
      }
    }

    stage('Unit Tests & Build JAR') {
      agent { label 'maven' } // optional: run on a Maven-enabled agent
      steps {
        sh 'mvn -B -DskipTests=false clean package'
        junit '**/target/surefire-reports/*.xml'
        stash includes: 'target/*.jar', name: 'app-jar'
      }
    }

    stage('Static Analysis (SonarQube)') {
      when { expression { return fileExists('pom.xml') } }
      steps {
        withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
          // Adjust sonar scanner command as per your SonarQube setup
          sh '''
            mvn -B sonar:sonar \
              -Dsonar.projectKey=sample-app \
              -Dsonar.host.url=${SONAR_HOST_URL} \
              -Dsonar.login=${SONAR_TOKEN}
          '''
        }
      }
    }

    stage('Build Docker Image') {
      agent { label 'docker' } // agent where docker/Buildx available
      steps {
        // Unstash JAR if you built separately
        unstash 'app-jar' // if produced earlier
        sh 'export DOCKER_BUILDKIT=1 || true'
        script {
          // Use Buildx for multi-arch optionally
          def imageName = "${REPO}:${IMAGE_TAG}"
          sh "docker build -f Dockerfile.local -t ${imageName} ."
          // tag latest too
          sh "docker tag ${imageName} ${REPO}:latest"
          // save image-info
          sh "echo ${imageName} > image-info.txt"
          archiveArtifacts artifacts: 'image-info.txt', fingerprint: true
        }
      }
    }

    stage('Image Scan & SBOM') {
      agent { label 'docker' }
      steps {
        script {
          def imageName = "${REPO}:${IMAGE_TAG}"
          // Trivy security scan (allow non-zero exit but mark in junit/console)
          sh '''
            trivy image --severity HIGH,CRITICAL --no-progress --format table ${IMAGE} || true
          '''.replace('${IMAGE}', imageName)
          // Generate SBOM with syft
          sh "syft ${imageName} -o json > sbom-${IMAGE_TAG}.json"
          archiveArtifacts artifacts: "sbom-${IMAGE_TAG}.json, trivy-*.json", fingerprint: true
        }
      }
    }

    stage('Push Image to Registry') {
      agent { label 'docker' }
      steps {
        script {
          if (env.REGISTRY == 'dockerhub') {
            withCredentials([usernamePassword(credentialsId: env.DOCKERHUB_CRED, usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
              sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin'
              sh "docker push ${REPO}:${IMAGE_TAG}"
              sh "docker push ${REPO}:latest"
            }
          } else if (env.REGISTRY == 'ghcr') {
            sh 'echo ${GHCR_TOKEN} | docker login ghcr.io -u ${GITHUB_USER} --password-stdin'
            sh "docker tag ${REPO}:${IMAGE_TAG} ghcr.io/${GITHUB_USER}/${APP_NAME}:${IMAGE_TAG}"
            sh "docker push ghcr.io/${GITHUB_USER}/${APP_NAME}:${IMAGE_TAG}"
          } else if (env.REGISTRY == 'ecr') {
            // Using AWS credentials binding
            withAWS(credentials: env.AWS_CREDS, region: 'ap-south-1') {
              sh '''
                ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
                ECR_URI=${ACCOUNT_ID}.dkr.ecr.ap-south-1.amazonaws.com/${APP_NAME}
                aws ecr create-repository --repository-name ${APP_NAME} --region ap-south-1 || true
                aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.ap-south-1.amazonaws.com
                docker tag ${REPO}:${IMAGE_TAG} ${ECR_URI}:${IMAGE_TAG}
                docker push ${ECR_URI}:${IMAGE_TAG}
              '''
            }
          }
          sh "docker images --format '{{.Repository}}:{{.Tag}}\\t{{.Size}}' | tee docker-images.txt"
          archiveArtifacts artifacts: 'docker-images.txt', fingerprint: true
        }
      }
    }

    stage('Deploy to Dev (Helm)') {
      agent { label 'kubectl' } // agent where kubectl + helm are available
      steps {
        withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIAL_ID, variable: 'KUBECONFIG')]) {
          sh '''
            export KUBECONFIG=${KUBECONFIG}
            helm upgrade --install ${APP_NAME} ./helm/sample-app \
              --namespace dev --create-namespace \
              --set image.repository=${REPO} \
              --set image.tag=${IMAGE_TAG} \
              --wait --timeout 120s
          '''
        }
      }
    }

    stage('Smoke Tests') {
      agent { label 'docker' }
      steps {
        sh './scripts/smoke-test.sh http://localhost:8080/api/hello || exit 1'
      }
    }

    stage('Promote to Staging') {
      when { branch 'main' }
      input {
        message "Approve promotion to staging?"
        submitter "admin"
      }
      steps {
        // promote to staging using helm (same as deploy)
        withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIAL_ID, variable: 'KUBECONFIG')]) {
          sh '''
            export KUBECONFIG=${KUBECONFIG}
            helm upgrade --install ${APP_NAME} ./helm/sample-app \
                --namespace staging --create-namespace \
                --set image.repository=${REPO} \
                --set image.tag=${IMAGE_TAG} \
                --wait --timeout 120s
          '''
        }
      }
    }
  } // stages

  post {
    success {
      echo "Build and deploy succeeded: ${env.BUILD_URL}"
      // notify or Slack integration here
    }
    failure {
      echo "Pipeline failed: ${env.BUILD_URL}"
      // email or Slack notifications
    }
    always {
      cleanWs()
    }
  }
}
