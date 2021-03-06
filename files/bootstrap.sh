#!/bin/bash

#### This script is copied to the newly minted EC2 instance and used to install everything else
#### Ideally, this would be Puppet or Chef instead for anything even mildly more complicated.

### DANGER
### this will remove ALL firewall rules: 
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -F
sudo iptables -X
### 

sudo apt update -y 
sudo apt install python3-pip  -y 
sudo apt install emacs -y 
sudo apt install ffmpeg -y 
sudo apt install supervisor -y 

python3 -m pip install pipenv

PROCESSOR_DIR=$HOME/processor 
rm -rf $PROCESSOR_DIR
git clone https://github.com/joshlong/podcast-production-pipeline-ffmpeg.git $PROCESSOR_DIR
cd $PROCESSOR_DIR 
source $HOME/env.sh
python3 -m pipenv install
python3 -m pipenv run python ${PROCESSOR_DIR}/config_aws.py $HOME/.aws/
 

SVC_DIR=${PROCESSOR_DIR}/service
SVC_ENV=${PROCESSOR_DIR}/service/processor-environment.sh
SVC_INIT=${PROCESSOR_DIR}/service/processor-service.sh

cat $HOME/env.sh >> ${SVC_ENV}


${SVC_DIR}/install.sh