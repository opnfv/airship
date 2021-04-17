source ${HOME}/.airship/airship.env

setup() {
  pushd .
  cd ${AIRSHIP_CONFIG_MANIFEST_DIRECTORY}/airshipctl
  ./tools/deployment/10_install_essentials.sh
  # Recommend to add the user to the docker group
  sudo usermod -aG docker $USER
  ./tools/deployment/21_systemwide_executable.sh
  popd
}

init_site() {
  pushd .
  cd ${AIRSHIP_CONFIG_MANIFEST_DIRECTORY}/airshipctl
  ./tools/init_site.sh
  if [ "$REDFISH_INSECURE" = true ] ; then
    airshipctl config set-management-config default --insecure
  fi
  touch ~/.airship/kubeconfig
  popd
}

gen_secrets() {
  pushd .
  cd ${AIRSHIP_CONFIG_MANIFEST_DIRECTORY}/treasuremap
  ./tools/deployment/23_generate_secrets.sh
  popd
}

valdiate_site() {
  export MANIFEST_ROOT=${AIRSHIP_CONFIG_MANIFEST_DIRECTORY}/${PROJECT}/manifests
  export SITE_ROOT=${AIRSHIP_CONFIG_MANIFEST_DIRECTORY}/${PROJECT}/manifests/site
  pushd .
  cd ${AIRSHIP_CONFIG_MANIFEST_DIRECTORY}/airshipctl
  ctl && ./tools/document/validate_site_docs.sh
  popd
}

deploy_ephemeral() {
  pushd .
  cd ${AIRSHIP_CONFIG_MANIFEST_DIRECTORY}/treasuremap
  ./tools/deployment/24_build_images.sh
  if [ -z ${EPHEMERAL_IMAGE_DESTINATION} ] ;
  then
    sudo cp /srv/images/ephemeral.iso ${EPHEMERAL_IMAGE_DESTINATION}
  else
    echo "The ephemeral ISO image has been generated in the /srv/images directory."
    echo "Please copy the image to the web server that you use to host the image before continue."
    echo "Verify that image URL works as defined in manifests/site/{SITE}/ephemeral/bootstrap/remote_direct_configuration.yaml."
    while true; do
      read -p "Continue deployment (Y/N)?" yn
      case $yn in
        Y ) break;;
        N ) echo "Deployment aborted."; exit;;
	* ) echo "Please enter 'Y' or 'N' only."
      esac
    done
  fi
  ./tools/deployment/25_deploy_ephemeral_node.sh
  ./tools/deployment/26_deploy_capi_ephemeral_node.sh
  popd
}

if [ ! -z "$1" ] 
if [[ "$1" != *+ ]]; then

if [ "$1" == *+
case $1
  all )
  init-site )
  gen-secrets )
  deploy-ephemeral )
  deploy-target )
  deploy-worker )
  deploy-workload )
esac
if [ "$INIT_SITE" = true ] ; then
fi

if [ "$GEN_SECRETS" = true ] ; then
fi

if [ "$DEPLOY_EPHEMERAL" = true ] ; then
fi
