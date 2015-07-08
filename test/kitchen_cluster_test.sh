#!/bin/bash -x

instances=(`kitchen list | awk '{ print $1 }' | sed -e '1d'`)

docker_prebuild() {
  kitchen diagnose ${1} | ruby -e "require 'yaml'; require 'erb'; YAML.load($<.read)['instances'][\"${1}\"]['driver'].each do |key, value|; instance_variable_set('@' + key.to_s, value); end; template = IO.read(File.expand_path(\"${2}.erb\")); print ERB.new(template).result(binding) " > ${2}

  docker_context=`dirname ${2}`

  docker_image=`kitchen diagnose ${1} | ruby -e "require 'yaml'; print YAML.load($<.read)['instances'][\"${1}\"]['driver']['image']"`

  docker build -t ${docker_image} ${docker_context}
}

func_prebuild() {

  docker_prebuild ${instances[0]} ./test/platforms/centos-6/prebuild/Dockerfile

}

func_create() {
  func_prebuild || exit $?

  kitchen create || exit $?

  containers=($(kitchen diagnose | ruby -e "require 'yaml'; YAML.load($<.read)['instances'].each do |key, instance|; puts \"#{instance['state_file']['container_id']}\"; end "))

  db_primary_ip=`docker inspect ${containers[0]} | jq -r '.[] | .NetworkSettings.IPAddress'`
  export db_primary_ip

  db_standby_ip=`docker inspect ${containers[1]} | jq -r '.[] | .NetworkSettings.IPAddress'`
  export db_standby_ip

  ap_node_ip=`docker inspect ${containers[2]} | jq -r '.[] | .NetworkSettings.IPAddress'`
  export ap_node_ip

  front_node_ip=`docker inspect ${containers[3]} | jq -r '.[] | .NetworkSettings.IPAddress'`
  export front_node_ip

  cat .kitchen.yml | ruby -e "require 'erb'; print ERB.new($<.read).result" > .kitchen.local.yml

  func_preconfig
}

func_destroy() {
  if [ -f .kitchen.local.yml ] ; then
    rm .kitchen.local.yml
  fi

  kitchen destroy || exit $?
}

func_optional() {
  yum_include_only=`kitchen diagnose ${1} | ruby -e "begin; require 'yaml'; print YAML.load($<.read)['instances'][\"${1}\"]['driver']['yum_conf']['include_only']; rescue NoMethodError ;end"`

  if [ "${yum_include_only}" != "" ] ; then
    kitchen exec ${1} -c "sudo sed -ie '/include_only=${yum_include_only}/d' /etc/yum/pluginconf.d/fastestmirror.conf"
  fi
}

func_preconfig() {
  join_addr=${db_primary_ip}
  kitchen exec -c "sudo /tmp/bootstrap/consul_join.sh ${join_addr}" || exit $?

  kitchen exec -c 'sudo /root/startup.sh echo' || exit $?

}

func_converge() {

  if kitchen list | grep '<Not Created>' ; then
    func_create
  fi

  kitchen converge || exit $?
}

func_setup() {

  if kitchen list | grep '<Not Created>' ; then
    func_create
  fi

  kitchen setup || exit $?
}

func_verify() {

  if kitchen list | grep '<Not Created>' ; then
    func_create
  fi

  kitchen verify || exit $?
}

func_test() {
  func_destroy

  func_create

  func_verify

  func_destroy
}

case $1 in
  pre_build) func_prebuild;;
  create) func_create ;;
  pre_config) func_preconfig ;;
  converge) func_converge;;
  setup) func_setup;;
  verify) func_verify;;
  destroy) func_destroy;;
  test) func_test;;
  *) func_test;;
esac
