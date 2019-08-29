#!/bin/bash

set -x

: ${OS_AUTH_URL='http://iam-airship.intel-pod17.opnfv.org:80/v3'}


## Genesis Cleanup

ssh pod17 sudo systemctl disable kubelet
ssh pod17 sudo systemctl disable docker
ssh pod17 sudo touch /forcefsck

ipmitool -I lanplus -H 10.10.170.10 -U root -P root chassis power off
ipmitool -I lanplus -H 10.10.170.11 -U root -P root chassis power off
ipmitool -I lanplus -H 10.10.170.12 -U root -P root chassis power off
ipmitool -I lanplus -H 10.10.170.13 -U root -P root chassis power off
ipmitool -I lanplus -H 10.10.170.14 -U root -P root chassis power off
ipmitool -I lanplus -H 10.10.170.15 -U root -P root chassis power off
sleep 15

ipmitool -I lanplus -H 10.10.170.10 -U root -P root chassis power on
sleep 180

ssh pod17 rm -rf promenade genesis.sh
ssh pod17 git clone https://review.opendev.org/airship/promenade
ssh pod17 sudo promenade/tools/cleanup.sh -f > /dev/null

ssh pod17 sudo parted -s /dev/sdb mklabel gpt
ssh pod17 sudo rm -rf /var/lib/ceph
ssh pod17 sudo rm -rf /var/lib/docker


## Repos

TMP_DIR=$(mktemp -d)
trap "{ sudo rm -rf $TMP_DIR; }" EXIT

cd $TMP_DIR

# fixme: implement clone of tags/references
git clone https://gerrit.opnfv.org/gerrit/airship
git clone https://review.opendev.org/airship/treasuremap
cd treasuremap && git checkout v1.3 && cd -


## Deployment

# Build site documents, see more details here
# https://airship-treasuremap.readthedocs.io/en/latest/authoring_and_deployment.html#building-site-documents

sudo -E treasuremap/tools/airship pegleg site \
  -r /target/airship collect -s collect intel-pod17

mkdir bundle
sudo -E treasuremap/tools/airship promenade build-all \
  --validators -o /target/bundle /target/collect/*.yaml

# Genesis bootstrap, see more details here
#https://airship-treasuremap.readthedocs.io/en/latest/authoring_and_deployment.html#genesis-node

scp bundle/genesis.sh pod17:
ssh pod17 'sudo ./genesis.sh'


# Site deployment with Shipyard, see more details here
# https://airship-treasuremap.readthedocs.io/en/latest/authoring_and_deployment.html#deploy-site-with-shipyard

sudo -E treasuremap/tools/airship shipyard create configdocs design --directory=/target/collect
sudo -E treasuremap/tools/airship shipyard commit configdocs

sudo -E treasuremap/tools/airship shipyard create action deploy_site

