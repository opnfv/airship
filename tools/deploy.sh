#!/bin/bash

set -ex

export OS_USERNAME=${OS_USERNAME:-shipyard}
export OS_PASSWORD=${OS_PASSWORD:-password123}

export IPMI_USER=${IPMI_USER:-root}
export IPMI_PASS=${IPMI_PASS:-root}

export GERRIT_REFSPEC=${GERRIT_REFSPEC:-master}

export TERM_OPTS=${TERM_OPTS:-" "}

## Source Environment Variables.

help() {
  echo "Usage: deploy.sh <site_name> <deploy_site|update_site|update_software>"
}

if [[ $# -lt 2 ]]
  then
    help
    exit 1
fi

source $(dirname "$(realpath $0)")/../site/$1/$1.env

if [ -z "$AS_HOME" ]; then
  WORK_DIR=$(mktemp -d)
  trap "{ sudo rm -rf $WORK_DIR; }" EXIT
else
  WORK_DIR=$AS_HOME
fi

cd ${WORK_DIR}

AIRSHIP_CMD=treasuremap/tools/airship

## Deps

pkg_check() {
  for pkg in $@; do
    sudo dpkg -s $pkg &> /dev/null || sudo apt -y install $pkg
  done
}

pkg_check docker.io git ipmitool python3-yaml


## Cleanup

genesis_cleanup() {

  # reset bare-metal servers
  ALL_NODES="${GEN_IPMI} ${NODES_IPMI}"
  for node in $ALL_NODES; do
    ipmitool -I lanplus -H $node -U $IPMI_USER -P $IPMI_PASS chassis power off
  done

  sleep 11 # wait for genesis node to power-off
  ipmitool -I lanplus -H $GEN_IPMI -U $IPMI_USER -P $IPMI_PASS chassis power on

  while ! ssh $GEN_SSH hostname; do :; done

  scp $WORK_DIR/airship/tools/clean-genesis.sh $GEN_SSH:
  ssh $GEN_SSH chmod a+x clean-genesis.sh
  ssh $GEN_SSH sudo ./clean-genesis.sh -fk 

  # cleanup previous k8s/airship install

#  ssh $GEN_SSH rm -rf promenade genesis.sh
#  ssh $GEN_SSH git clone https://review.opendev.org/airship/promenade
#  ssh $GEN_SSH 'sudo promenade/tools/cleanup.sh -f > /dev/null' || true
}


## Repos

read_yaml() {
  python3 -c "import yaml;print(yaml.load(open('$1'))$2)"
}

git_checkout() {
  git clone $1
  cd ${1##*/}

  # check refs for patchsets
  if [[ $2 == *"refs"* ]]; then
    git fetch origin $2
    git checkout FETCH_HEAD
  else
    git checkout $2
  fi

  git log -1
}

clone_repos() {
  if [ -d "airship" ]; then
    echo "Found existing airship folder. Skip repo clone."
  else
    # clone/checkout site manifests
    git_checkout 'https://gerrit.opnfv.org/gerrit/airship' $GERRIT_REFSPEC
  fi

  if [ -d "treasuremap" ]; then
    echo "Found existing treasuremap folder in the working directory. Skip repo clone."
  else
    # clone treasuremap (only required for tools/airship)
    # match treasuremap to global from site-definition
    SITE_DEF_KEY="['data']['repositories']['global']['revision']"
    TREASUREMAP_REF=$(read_yaml $SITE_DEF "$SITE_DEF_KEY")
    echo "TREASUREMAP_REF $TREASUREMAP_REF"
    git_checkout 'https://review.opendev.org/airship/treasuremap' $TREASUREMAP_REF
  fi

  rm -rf $WORK_DIR/treasuremap/site/$SITE_NAME
  cp -r $WORK_DIR/airship/site/$SITE_NAME $WORK_DIR/treasuremap/site
}

## Deployment

pegleg_collect() {
  if [ -d "collect/${SITE_NAME}" ]; then
    sudo rm -rf collect/${SITE_NAME}
  fi
  sudo mkdir -p collect/${SITE_NAME}
  sudo -E ${AIRSHIP_CMD} pegleg site -r /target/treasuremap collect -s collect/${SITE_NAME} $SITE_NAME

  sudo mkdir -p render/${SITE_NAME}
  sudo -E ${AIRSHIP_CMD} pegleg site -r /target/treasuremap render $SITE_NAME \
    -s /target/render/${SITE_NAME}/manifest.yaml
}

pre_genesis() {
  
  scp $WORK_DIR/airship/tools/files/seccomp_default $GEN_SSH:
  ssh $GEN_SSH 'sudo mkdir -p /var/lib/kubelet/seccomp'
  ssh $GEN_SSH 'sudo chown root:root /var/lib/kubelet/seccomp'
  ssh $GEN_SSH 'sudo chown root:root ~/seccomp_default'
  ssh $GEN_SSH 'sudo mv ~/seccomp_default /var/lib/kubelet/seccomp'

  scp $WORK_DIR/airship/tools/files/sources.list $GEN_SSH:

  ssh $GEN_SSH 'sudo cp -n /etc/apt/sources.list /etc/apt/sources.list.orig'
  ssh $GEN_SSH 'sudo chown root:root ~/sources.list'
  ssh $GEN_SSH 'sudo mv ~/sources.list /etc/apt/sources.list'

  ssh $GEN_SSH 'wget -qO - http://mirror.mirantis.com/testing/kubernetes-extra/bionic/archive-kubernetes-extra.key | sudo apt-key add -'
  # thsi fails but appaerntly not required.
  # ssh $GEN_SSH 'wget -qO - http://linux.dell.com/repo/community/openmanage/930/bionic/dists/bionic/Release.gpg | sudo apt-key add -'
  ssh $GEN_SSH 'sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3B4FE6ACC0B21F32'
  ssh $GEN_SSH 'sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 1285491434D8786F'

  if [ -d "render/${SITE_NAME}" ]; then
    sudo rm -rf render/${SITE_NAME}
  fi

  ssh $GEN_SSH 'sudo cp /etc/default/grub /etc/default/grub.orig'
  ssh $GEN_SSH 'sudo sed -i "/GRUB_CMDLINE_LINUX=\"/c GRUB_CMDLINE_LINUX=\"hugepagesz=1G hugepages=12 transparent_hugepage=never default_hugepagesz=1G dpdk-socket-mem=4096,4096 iommu=pt intel_iommu=on amd_iommu=on cgroup_disable=hugetlb console=ttyS1,115200n8\"" /etc/default/grub'
  ssh $GEN_SSH 'sudo update-grub'

#  sudo mkdir -p render/${SITE_NAME}
#  sudo -E ${AIRSHIP_CMD} pegleg site -r /target/treasuremap render $SITE_NAME \
#    -s /target/render/${SITE_NAME}/manifest.yaml
  # pre-geneis needs more testing for now
  # sudo -E treasuremap/tools/genesis-setup/pre-genesis.sh render/${SITE_NAME}/manifest.yaml
}

generate_certs() {
  # create certificates based on PKI catalogs

  if [ -d "certs/${SITE_NAME}" ]; then
    sudo rm -rf certs/${SITE_NAME}
  fi
  sudo mkdir -p certs/${SITE_NAME}

  sudo -E ${AIRSHIP_CMD} promenade generate-certs -o /target/certs/${SITE_NAME} collect/${SITE_NAME}/*.yaml

  # copy certs
  mkdir -p airship/site/${SITE_NAME}/secrets/certificates
  sudo cp certs/${SITE_NAME}/certificates.yaml \
    airship/site/${SITE_NAME}/secrets/certificates/certificates.yaml
}

promenade_bundle() {

  if [ -d "bundle/${SITE_NAME}" ]; then
    sudo rm -rf bundle/${SITE_NAME}
  fi
  sudo mkdir -p bundle/${SITE_NAME}

  PROMENADE_KEY=$(sudo -E ${AIRSHIP_CMD} promenade build-all \
    --validators -o /target/bundle/${SITE_NAME} /target/collect/${SITE_NAME}/*.yaml | \
    sed -n '/Copy this decryption key for use during script execution:/{n;p;d;}; x')
}

genesis_deploy() {
  scp bundle/${SITE_NAME}/genesis.sh $GEN_SSH:
  ssh $GEN_SSH PROMENADE_ENCRYPTION_KEY=$PROMENADE_KEY sudo -E ./genesis.sh
}

site_action() {

  # Site deployment with Shipyard, see more details here
  # https://airship-treasuremap.readthedocs.io/en/latest/authoring_and_deployment.html#deploy-site-with-shipyard

  sudo -E ${AIRSHIP_CMD} shipyard create configdocs \
    $SITE_NAME --directory=/target/collect/$SITE_NAME --replace
  sudo -E ${AIRSHIP_CMD} shipyard commit configdocs

  sudo -E ${AIRSHIP_CMD} shipyard create action \
    --allow-intermediate-commits $1

  sudo -E treasuremap/tools/gate/wait-for-shipyard.sh
}

shipyard_action() {

  # Site deployment with Shipyard, see more details here
  # https://airship-treasuremap.readthedocs.io/en/latest/authoring_and_deployment.html#deploy-site-with-shipyard

  sudo -E ${AIRSHIP_CMD} shipyard $1 $2 $3
}


create_public_network() {
  export OS_AUTH_URL=${OS_AUTH_URL_IDENTITY}
  sudo -E treasuremap/tools/openstack stack create --wait \
    -t /target/../airship/tools/files/heat-public-net-deployment-$SITE_NAME.yaml \
    public-network
}

case "$2" in
'pre_genesis')
  pre_genesis
  ;;
'deploy_site')
  read -n 1 -p "This script will clean up the genesis node. Continue (Y/N) ?" input
  case $input in
    [Yy] ) break;;
    [Nn] ) exit 1;;
      * ) echo "Please answer yes or no."; exit 1;
  esac

  genesis_cleanup
  pre_genesis
  clone_repos
  pegleg_collect
  promenade_bundle
  genesis_deploy
  site_action $2
  create_public_network
  ;;
'update_site')
  clone_repos
  pegleg_collect
  site_action $2
  ;;
'update_software')
  clone_repos
  pegleg_collect
  site_action $2
  ;;
'generate_certs')
  clone_repos
  pegleg_collect
  generate_certs
  ;;
'shipyard')
  shipyard_action $3 $4 $5
  ;;
*) help
   echo "*** $2"
   exit 1
  ;;
esac

