pipeline {
    agent {
        label 'agent1'
    }

    triggers {
        githubPush()
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: "100"))
    }   

    environment {
        GITHUB_TOKEN = credentials('GITHUB_TOKEN')
        GITHUB_REPO = 'Sebasignacioespejo/gogs'

        EMAIL_RECIPIENTS = credentials('EMAIL_RECIPIENTS')

        HOSTED_ZONE_ID = credentials('HOSTED_ZONE_ID')

        AWS_ACCESS_KEY_ID       = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY   = credentials('AWS_SECRET_ACCESS_KEY')

        AZURE_STORAGE_ACCOUNT   = credentials('AZURE_STORAGE_ACCOUNT')
        AZURE_STORAGE_KEY       = credentials('AZURE_STORAGE_KEY')

        ARM_CLIENT_ID           = credentials('ARM_CLIENT_ID')
        ARM_CLIENT_SECRET       = credentials('ARM_CLIENT_SECRET')
        ARM_TENANT_ID           = credentials('ARM_TENANT_ID')
        ARM_SUBSCRIPTION_ID     = credentials('ARM_SUBSCRIPTION_ID')
    }

    stages {
        stage('Clone Repo') {
            steps {
                checkout scm
            }
        }

        stage('Validar Jenkinsfile') {
            when {
                not{
                    branch 'main'
                }
            }
            steps {
                script {
                    def result = validate("make validate-jenkinsfiles")
                    sendGitHubComment("**Jenkinsfiles Validations:** ${result}")
                }
            }
        }

        stage('Validar Ansible') {
            when {
                not{
                    branch 'main'
                }
            }
            steps {
                script {
                    def result = validate("make validate-ansible")
                    sendGitHubComment("**Ansible Validations:** ${result}")
                }
            }
        }

        stage('Validar Terraform') {
            when {
                not{
                    branch 'main'
                }
            }
            steps {
                script {
                    def result = validate("make validate-terraform")
                    sendGitHubComment("**Terraform Validations:** ${result}")
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    def result = validate("make docker-build")
                    if (env.BRANCH_NAME != 'main') {
                        sendGitHubComment("**Build Validations:** ${result}")
                    }
                }
            }
        }

        stage("Deploy Gogs in both providers") {
            when {
                branch 'main'
            }
            steps {
                script {
                    parallel(
                        job1: {
                            build job: 'deploy-azure'
                        },
                        job2: {
                            build job: 'deploy-aws'
                        }
                    )
                }
            }
        }

        stage("Configure Route 53") {
            when {
                branch 'main'
            }
            steps {
                sh 'make infra-route-53 HOSTED_ZONE_ID=$HOSTED_ZONE_ID'
            }
        }
    }

    post {
        always {
            echo 'Limpiando espacio'
            sh 'make clean'
            cleanWs()
        }
        failure {
            echo 'Todo mal unu'
            script {
                if (env.BRANCH_NAME == 'main') {
                    emailext(
                        to: "${env.EMAIL_RECIPIENTS}",
                        subject: "❌ Build Fallida - ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                        body: """<p>🔴 La build falló :C</p>
                                <p>Job: <b>${env.JOB_NAME}</b><br>
                                Build: <b>#${env.BUILD_NUMBER}</b></p>
                                <p><a href='${env.BUILD_URL}'>Ver Detalles</a></p>""",
                        mimeType: 'text/html'
                    )
                }
            }
        }
        success {
            echo 'De pana'
            script {
                if (env.BRANCH_NAME == 'main') {
                    emailext(
                        to: "${env.EMAIL_RECIPIENTS}",
                        subject: "✅ Build Exitosa - ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                        body: """<h3>🟢 La build fue exitosa :D</h3>
                                <p>Job: <b>${env.JOB_NAME}</b><br>
                                Build: <b>#${env.BUILD_NUMBER}</b></p>
                                <p><a href='${env.BUILD_URL}'>Ver detalles</a></p>""",
                        mimeType: 'text/html'
                    )
                }
            }
        }
    }
}

def validate(cmd) {
    try {
        sh cmd
        return '✅ OK'
    } catch (Exception e) {
        currentBuild.result = 'FAILURE'
        return '❌ Failure'
    }
}

def sendGitHubComment(String message) {
    sh """
        curl -X POST -H "Authorization: token ${GITHUB_TOKEN}" \
        -d '{"body": "${message}"}' \
        https://api.github.com/repos/${GITHUB_REPO}/issues/${env.CHANGE_ID}/comments
    """
}