pipeline {
    agent {
        label 'agent1'
    }

    triggers {
        githubPush()
    }

    environment {
        GITHUB_TOKEN = credentials('GITHUB_TOKEN')
        GITHUB_REPO = 'Sebasignacioespejo/gogs'

        EMAIL_RECIPIENTS = credentials('EMAIL_RECIPIENTS')
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
                    sendGitHubComment("**Validación Ansible**: ${result}")
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
                    sendGitHubComment("**Validación Ansible**: ${result}")
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
                    sendGitHubComment("**Validación Terraform**: ${result}")
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    def result = validate("make docker-build")
                    if (env.BRANCH_NAME != 'main') {
                        sendGitHubComment("**Validación Build**: ${result}")
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
        return '✅ Éxito'
    } catch (Exception e) {
        return '❌ Fallo'
    }
}

def sendGitHubComment(String message) {
    sh """
        curl -X POST -H "Authorization: token ${GITHUB_TOKEN}" \
        -d '{"body": "${message}"}' \
        https://api.github.com/repos/${GITHUB_REPO}/issues/${env.CHANGE_ID}/comments
    """
}