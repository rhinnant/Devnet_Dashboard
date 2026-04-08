pipeline {
    agent any

    stages {
        stage('Hello') {
            steps {
                echo 'Hello, DevOps world!'
            }
        }

        stage('Git Checkout') {
            steps {
                git 'https://github.com/rhinnant/Devnet_Dashboard.git'
            }
        }

        stage('Build') {
            steps {
                echo 'Build stage running...'
                // You can add commands like "python manage.py check" if you want
            }
        }

        stage('Test') {
            steps {
                echo 'Test stage running...'
                // Placeholder for tests later
            }
        }
    }
}
