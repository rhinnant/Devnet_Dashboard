pipeline {
    agent any

    environment {
        IMAGE_NAME = "devnet-dashboard"
        TAG = "latest"
    }

    stages {

        stage('Clone') {
            steps {
                git 'https://github.com/rhinnant/Devnet_Dashboard.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t $IMAGE_NAME:$TAG .'
            }
        }

        stage('Run Container (Test)') {
            steps {
                sh 'docker run -d -p 8000:8000 $IMAGE_NAME:$TAG || true'
            }
        }

        stage('Verify App') {
            steps {
                sh 'curl -f http://localhost:8000 || exit 1'
            }
        }
    }
}
