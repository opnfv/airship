#!/bin/bash

set -x

sudo apt-get install -y docker.io git

export OS_AUTH_URL=${OS_AUTH_URL:-http://iam-airship.intel-pod17.opnfv.org:80/v3}
export OS_USERNAME=${OS_USERNAME:-shipyard}
export OS_PASSWORD=${OS_PASSWORD:-password123}

export GEN_SSH=${GEN_SSH:-pod17}
export SITE_NAME=${SITE_NAME:-intel-pod17}


## Repos

TMP_DIR=$(mktemp -d)
trap "{ sudo rm -rf $TMP_DIR; }" EXIT

cd $TMP_DIR

git clone https://gerrit.opnfv.org/gerrit/airship
git clone https://review.opendev.org/airship/treasuremap
cd treasuremap && git checkout v1.3 && cd -


sudo -E treasuremap/tools/airship pegleg site \
  -r /target/airship collect -s collect $SITE_NAME

sudo -E treasuremap/tools/airship shipyard create configdocs $SITE_NAME --directory=/target/collect
sudo -E treasuremap/tools/airship shipyard commit configdocs

sudo -E treasuremap/tools/airship shipyard create action deploy_site
sudo -E treasuremap/tools/gate/wait-for-shipyard.sh

