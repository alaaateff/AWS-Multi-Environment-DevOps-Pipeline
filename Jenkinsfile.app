pipeline {
agent {
    label 'app'
}

environment {
    RDS_HOSTNAME = credentials('rds-hostname')
    RDS_USERNAME = credentials('rds-username')
    RDS_PASSWORD = credentials('rds-password')
    RDS_PORT = credentials('rds-port')
    REDIS_HOSTNAME = credentials('redis-hostname')
    REDIS_PORT = credentials('redis-port')
}

stages {

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
          dir('app/nodeapp') {
          sh '''
          pm2 delete nodeapp || true
          pm2 start app.js --name nodeapp
          pm2 save
          '''
        }
        }
    }

    stage('Verify Deployment') {
        steps {
              sh '''
              pm2 list
              curl http://localhost:3000/db
              curl http://localhost:3000/redis
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
