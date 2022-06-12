###########################################
# Author : Rukiye AKINCI
# Date : 12/06/2022
# Subject : Shell Script for Docker
###########################################

#!/bin/bash

# The features required for the script were defined in the Help function.

Help()
{
	echo
	echo "Usage:"
	echo "	--mode              Select mode <build|deploy|template> and --image-name  Docker image name-   and -image-tag  Docker image tag"
	echo "	--memory            Container memory limit"
	echo "	--cpu               Container cpu limit"
    echo "	--container-name    Container name"
    echo "	--registery         DocherHub or GitLab Image registery"
    echo "	--application-name  Run mysql or mongo server"
	echo
}

docker_command() {
    command="docker-compose -f docker-compose.yml "

    if [ ${ENV} = "PROD" ]
    then
        file_prefix="prod"
    elif [ ${ENV} = "STAGING" ]
    then
        file_prefix="staging"
    else
        file_prefix="dev"
    fi

    command+="-f docker-compose.${file_prefix}.yml ${@}"
    echo -e "${BLUE}    Command: ${NORMAL}${command}"
    echo -e ""
    eval ${command}
}

build() {
    docker_command build
}

status() {
    docker_command ps
}

start() {
    docker_command up -d
}

stop() {
    docker_command stop
}

if [ -z ${1} ]
then
    print_help
else
    case ${ENV} in
        "PROD")
            env_str="production"
            ;;
        "STAGING")
            env_str="staging"
            ;;
        *)
            env_str="development"
            ;;
    esac
    echo -e "${BLUE}Environment:${NORMAL} ${env_str}"
    ${@}
fi

mode() {
    PARENT_DIR=$(basename "${PWD%/*}")
    CURRENT_DIR="${PWD##*/}"
    IMAGE_NAME="$PARENT_DIR/$CURRENT_DIR"
    TAG="${1}"

    REGISTRY="hub.docker.com"

    docker build -t ${REGISTRY}/${IMAGE_NAME}:${TAG} .
    docker tag ${REGISTRY}/${IMAGE_NAME}:${TAG} ${REGISTRY}/${IMAGE_NAME}:latest
    docker push ${REGISTRY}/${IMAGE_NAME}
    docker tag ${REGISTRY}/${IMAGE_NAME}:latest ${REGISTRY}/${IMAGE_NAME}:${TAG}
    docker push ${REGISTRY}/${IMAGE_NAME}
}

registery () {

    dir=$1
    prefix=$2

    # remote registries should adhere to the pattern "<host>:<port>(</path>)?"
    regex="^[[:graph:]]+\:[[:digit:]]+(/[[:graph:]]+)?/?$"

    if [ "$dir" == "" ] || [ ! -d "$dir" ] || [ "$prefix" == "" ] || ! [[ $prefix =~ $regex ]]; then
            echo "Usage:
        $0 <docker-dir> <registry-prefix> [<tag name>]
    where
        <docker-dir> is the directory containing the dockerfile to build;
        <registry-prefix> is the prefix of the *remote* docker registry, for example '10.0.1.1:5000/'
        <tag name> is optional and defaults to the directory name (the first argument).
    "
            exit 1
    fi

    # determine the names we should use for the docker-registry...
    dir=$(echo "$dir" | sed -r 's#/$##g')
    name=${3:-$dir}
    name=$(echo "$name" | sed -r 's#/$##g')
    remote_name=$(echo "$prefix/$name" | sed -r 's#/+#/#g')

    if [[ $EUID -ne 0 ]]; then
        echo "This script might need root permissions to run..."
    fi

    id=$(echo $(docker build --quiet=true $dir 2>/dev/null) | awk '{print $NF}')
    docker tag $id $dir
    docker tag $id "$remote_name"
    docker push "$remote_name"
}
