pipeline {
    agent any

    parameters {
    choice(
        name: 'ENV',
        choices: ['dev', 'prod'],
        description: 'Choose environment'
    )
}

    stages {
        stage('Cleanup Workspace') {
            steps {
                cleanWs()
                sh 'echo "Cleaned Up Workspace"'
            }
        }
        stage('Terraform init') {
            steps {
              withCredentials([
                   [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']
        ]) {
            sh 'terraform init'
         }
            }
        }
        stage('Terraform workspace') {
            steps {
            sh """
              terraform workspace select ${params.ENV}
              if [ \$? -ne 0 ]; then
              terraform workspace new ${params.ENV}
              fi
              """
            }
        }
        stage('Terraform plan') {
            steps {
                withCredentials([
                   [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']
        ]){
              sh 'terraform plan -var-file=${params.ENV}.tfvars'
            }
            }
        }
        stage('Terraform apply') {
            steps {
                withCredentials([
                   [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']
        ]){
              sh 'terraform apply -var-file=${params.ENV}.tfvars -auto-approve'
            }
            }
        }
        

    }
}