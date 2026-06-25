pipeline {
agent {
    label 'app'
}

parameters {
    choice(
        name: 'ENVIRONMENT',
        choices: ['dev', 'prod'],
        description: 'Select environment'
    )
}

stages {
    stage('Set Environment') { 
      steps { 
         script { 
            if (params.ENVIRONMENT == 'dev') 
            {
               env.RDS_HOSTNAME = 'rds-hostname' 
               env.RDS_USERNAME = 'rds-username' 
               env.RDS_PASSWORD = 'rds-password' 
               env.RDS_PORT = 'rds-port' 
               env.REDIS_HOSTNAME = 'redis-hostname' 
               env.REDIS_PORT = 'redis-port' 
               }
          else 
             { 
              env.RDS_HOSTNAME = 'rds-hostname-prod' 
              env.RDS_USERNAME = 'rds-username-prod' 
              env.RDS_PASSWORD = 'rds-password-prod' 
              env.RDS_PORT = 'rds-port-prod' 
              env.REDIS_HOSTNAME = 'redis-hostname-prod' 
              env.REDIS_PORT = 'redis-port-prod' 
              }
            }
         }
     }

    stage('Checkout Application') {
        steps {
            dir('app'){
            git branch: 'rds_redis', 
                url: 'https://github.com/mahmoud254/jenkins_nodejs_example.git'
        }
      }
    }

    stage('Install Dependencies') {
        steps {
            dir('app/nodeapp') {
            sh 'npm install'
        }
        }
    }

    stage('Deploy Application') {
        steps {
            withCredentials([ 
                string(credentialsId: env.RDS_HOSTNAME, variable: 'RDS_HOSTNAME'), 
                string(credentialsId: env.RDS_USERNAME, variable: 'RDS_USERNAME'), 
                string(credentialsId: env.RDS_PASSWORD, variable: 'RDS_PASSWORD'), 
                string(credentialsId: env.RDS_PORT, variable: 'RDS_PORT'), 
                string(credentialsId: env.REDIS_HOSTNAME, variable: 'REDIS_HOSTNAME'), 
                string(credentialsId: env.REDIS_PORT, variable: 'REDIS_PORT') ]) 
        {
          dir('app/nodeapp') {
          sh '''
          pm2 delete nodeapp || true
          pm2 start app.js --name nodeapp
          pm2 save
          '''
        }
        }
        }
    }

    stage('Verify Deployment') {
        steps {
              sh '''
              pm2 list
              curl -s http://localhost:3000/db | grep "successful"
              curl -s http://localhost:3000/redis | grep "successful"
              '''
        }
    }
}

post {

    success {
        echo 'processing succeeded'
    }

    failure {
        echo 'processing failed'
    }
}
}
