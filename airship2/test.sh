echo "$1"
if [[ "$1" != *+ ]]; then
  echo "no + "
fi

#echo "The ephemeral ISO image has been generated in the /srv/images directory."
#echo "Please copy the image to the web server that you use to host the image before continue."
#echo "Verify that image URL works as defined in manifests/site/{SITE}/ephemeral/bootstrap/remote_direct_configuration.yaml."
#echo "Continue deployment?"
#select yn in "Yes" "No"; do
#  case $yn in
#    Yes ) echo "yeah"; break;;
#    No ) echo "Deployment aborted."; exit;;
#  esac
#done
#echo "Done"
