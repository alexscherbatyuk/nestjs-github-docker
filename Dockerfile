FROM centos:8
LABEL maintainer="a.scherbatyuk@gmail.com"
WORKDIR /usr/share/nestjs/main
COPY . .
RUN <<EOF
sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
yum update -y
curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
yum install -y nodejs
yum install -y gcc-c++ make
yum install -y cronie && yum clean all
yum install -y nano
yum install -y nc
mkdir -p /usr/share/nestjs/main
npm install pm2@latest -g
pm2 install pm2-logrotate
pm2 set pm2-logrotate:retain 7
pm2 set pm2-logrotate:max_size 10M
pm2 set pm2-logrotate:compress true
pm2 set pm2-logrotate:workerInterval 1800

# Create startup script for PM2
cat > /usr/local/bin/start-pm2.sh << 'EOL'
#!/bin/bash
# Start PM2 daemon
pm2 resurrect
# Keep container running
tail -f /dev/null
EOL

chmod +x /usr/local/bin/start-pm2.sh

mkdir -p /usr/share/temp/log
mkdir -p /usr/share/temp/tmp
mkdir -p /usr/share/temp/public
chmod 775 -R /usr/share/temp/
cd /usr/share/nestjs/main
npm install
npm run build

# Enable PM2 monitoring
pm2 install pm2-server-monit
pm2 set pm2-server-monit:threshold 80

# Start the application with PM2 and wait for it to initialize
pm2 start dist/main.js --name nestjs-app --instances max --max-memory-restart 1G --env production --log /usr/share/temp/log/nestjs-app.log
# Add a small delay to ensure PM2 is ready
sleep 5
# Save the PM2 configuration
pm2 save
EOF
VOLUME ["/temp"]
CMD ["/usr/local/bin/start-pm2.sh"]
