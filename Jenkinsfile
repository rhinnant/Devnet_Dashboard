pipeline {                     
    agent any  // run on any available agent

    stages {
        stage('Build') {  // build stage
            steps {
                sh 'echo Building Project'
            }
        }

        stage('Test') {  // test stage
            steps {
                sh 'echo Running Tests'
            }
        }

        stage('Deploy') {  // deploy stage
            steps {
                sh 'echo Deploying Application'
            }
        }
    }
}
