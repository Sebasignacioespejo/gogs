pipeline {
    agent {
        label 'agent1'
    }

    triggers {
        githubPush()
    }

    // environment {
    //     EMAIL_RECIPIENTS = credentials('EMAIL_RECIPIENTS')
    // }

    stages {
        stage('Clone Repo') {
            when {
                not {
                    branch 'main'
                }
            }
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'make docker-build'
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
            // emailext(
            //     to: "${env.EMAIL_RECIPIENTS}",
            //     subject: "❌ Build Fallida - ${env.JOB_NAME} #${env.BUILD_NUMBER}",
            //     body: """<p>🔴 La build falló :C</p>
            //             <p>Job: <b>${env.JOB_NAME}</b><br>
            //             Build: <b>#${env.BUILD_NUMBER}</b></p>
            //             <p><a href='${env.BUILD_URL}'>Ver Detalles</a></p>""",
            //     mimeType: 'text/html'
            // )
        }
        success {
            echo 'De pana'
            // emailext(
            //     to: "${env.EMAIL_RECIPIENTS}",
            //     subject: "✅ Build Exitosa - ${env.JOB_NAME} #${env.BUILD_NUMBER}",
            //     body: """<h3>🟢 La build fue exitosa :D</h3>
            //             <p>Job: <b>${env.JOB_NAME}</b><br>
            //             Build: <b>#${env.BUILD_NUMBER}</b></p>
            //             <p><a href='${env.BUILD_URL}'>Ver detalles</a></p>""",
            //     mimeType: 'text/html'
            // )
        }
    }
}
