#!/bin/bash

set -x

sudo apt-get install -y docker.io git

export OS_AUTH_URL=${OS_AUTH_URL:-http://iam-airship.intel-pod17.opnfv.org:80/v3}
export OS_USERNAME=${OS_USERNAME:-shipyard}
export OS_PASSWORD=${OS_PASSWORD:-password123}

export IPMI_USER=${IPMI_USER:-root}
export IPMI_PASS=${IPMI_PASS:-root}

export GEN_SSH=${GEN_SSH:-pod17}
export SITE_NAME=${SITE_NAME:-intel-pod17}

export GEN_IPMI=${GEN_IPMI:-10.10.170.10}
export NODES_IPMI=${NODES_IPMI:-'10.10.170.11 10.10.170.12 10.10.170.13 10.10.170.14 10.10.170.15'}


## Genesis Cleanup

ssh $GEN_SSH sudo systemctl disable kubelet
ssh $GEN_SSH sudo systemctl disable docker
ssh $GEN_SSH sudo touch /forcefsck

# reset bare-metal servers

ALL_NODES="${GEN_IPMI} ${NODES_IPMI}"
for node in $ALL_NODES; do
  ipmitool -I lanplus -H $node -U $IPMI_USER -P $IPMI_PASS chassis power off
done

ipmitool -I lanplus -H $GEN_IPMI -U $IPMI_USER -P $IPMI_PASS chassis power on

while ! ssh $GEN_SSH hostname; do :; done

# cleanup previous k8s/airship install

ssh $GEN_SSH rm -rf promenade genesis.sh
ssh $GEN_SSH git clone https://review.opendev.org/airship/promenade
ssh $GEN_SSH sudo promenade/tools/cleanup.sh -f > /dev/null

ssh $GEN_SSH sudo parted -s /dev/sdb mklabel gpt
ssh $GEN_SSH sudo rm -rf /var/lib/ceph
ssh $GEN_SSH sudo rm -rf /var/lib/docker


## Repos

TMP_DIR=$(mktemp -d)
trap "{ sudo rm -rf $TMP_DIR; }" EXIT

cd $TMP_DIR

# fixme: implement proper cloning of tags/references
git clone https://gerrit.opnfv.org/gerrit/airship
git clone https://review.opendev.org/airship/treasuremap
cd treasuremap && git checkout v1.3 && cd -


## Deployment

# Build site documents, see more details here
# https://airship-treasuremap.readthedocs.io/en/latest/authoring_and_deployment.html#building-site-documents

sudo -E treasuremap/tools/airship pegleg site \
  -r /target/airship collect -s collect $SITE_NAME

mkdir bundle
sudo -E treasuremap/tools/airship promenade build-all \
  --validators -o /target/bundle /target/collect/*.yaml


# Genesis bootstrap, see more details here
# https://airship-treasuremap.readthedocs.io/en/latest/authoring_and_deployment.html#genesis-node

scp bundle/genesis.sh $GEN_SSH:
ssh $GEN_SSH 'sudo ./genesis.sh'

# Site deployment with Shipyard, see more details here
# https://airship-treasuremap.readthedocs.io/en/latest/authoring_and_deployment.html#deploy-site-with-shipyard

sudo -E treasuremap/tools/airship shipyard create configdocs $SITE_NAME --directory=/target/collect
sudo -E treasuremap/tools/airship shipyard commit configdocs

sudo -E treasuremap/tools/airship shipyard create action deploy_site

