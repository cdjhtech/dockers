#!/usr/bin/env bash

source $PWD/env.ini

if [ "x$NETWORK" = "x" ]; then
    echo "Missing docker user-defined network property."
    exit -1
fi

if [ "x$WORKSPACES" = "x" ]; then
    echo "Missing WORKSPACES property."
    exit -1
fi

if [ "x$PROJECT_NAME" != "x" ]; then
    PREFIX=$PROJECT_NAME
fi

case $1 in
    '')
        echo "Please enter the mode. Such as:"
        echo "env , for running env environment"
        echo "ide , for running IDE environment"
        echo "ide -debug, for debugging running."
        ;;
    env[0-999]*)
        _INPUT="$1"
        _INPUT=${_INPUT#*env}
        echo "Input is environment $_INPUT"
        for _KEY in "${!DEPENDENCIES[@]}" ; do
            KEY1=${_KEY%,*}
            KEY2=${_KEY#*,}
            if [ x"$_INPUT" = x"$KEY1" ]; then
                DOCKER_IMAGE=$KEY2
                DOCKER_ALIAS="${DEPENDENCIES["$_KEY"]}"
                _DOCKER_ALIAS="${DOCKER_ALIAS//\./_}"
                _DOCKER_COMMANDS="${_DOCKER_ALIAS^^}_COMMANDS"
                if [ "x${!_DOCKER_COMMANDS}" != "x" ]; then
                    DOCKER_COMMANDS="${!_DOCKER_COMMANDS}"
                else
                    DOCKER_COMMANDS=
                fi
                    _DOCKER_EXTEND_COMMANDS="${_DOCKER_ALIAS^^}_EXTEND_COMMANDS"
                if [ "x${!_DOCKER_EXTEND_COMMANDS}" != "x" ]; then
                   DOCKER_EXTEND_COMMANDS="${!_DOCKER_EXTEND_COMMANDS}"
                else
                   DOCKER_EXTEND_COMMANDS=
                fi
                if [ -n $PREFIX ]; then
                   DOCKER_ALIAS="${PREFIX}-${_INPUT}-${DOCKER_ALIAS}"
                fi
                echo " " > $PWD/${DOCKER_ALIAS}.out
                while [ "x$(docker ps -a | grep \"$DOCKER_ALIAS\")" != "x" ]; do
                    docker stop $DOCKER_ALIAS > /dev/null 2>&1
                    docker rm -v $DOCKER_ALIAS > /dev/null 2>&1
                done
                echo "Creating $DOCKER_ALIAS container."
                echo "*********************************"
                echo "docker run --network $NETWORK --name $DOCKER_ALIAS -h $DOCKER_ALIAS $DOCKER_COMMANDS $DOCKER_IMAGE $DOCKER_EXTEND_COMMANDS"
                echo "*********************************"
                echo
                nohup docker run --network $NETWORK --name $DOCKER_ALIAS -h $DOCKER_ALIAS $DOCKER_COMMANDS $DOCKER_IMAGE $DOCKER_EXTEND_COMMANDS >> $PWD/${DOCKER_ALIAS}.out 2>&1 &
            fi
        done

        shutdown(){
            for _KEY in "${!DEPENDENCIES[@]}" ; do
                KEY1=${_KEY%,*}
                KEY2=${_KEY#*,}
                if [ x"$_INPUT" = x"$KEY1" ]; then
                    DOCKER_IMAGE=$KEY2
                    DOCKER_ALIAS="${DEPENDENCIES["$_KEY"]}"
                    if [ -n $PREFIX ]; then
                        DOCKER_ALIAS="${PREFIX}-${_INPUT}-${DOCKER_ALIAS}"
                    fi
                    echo "Stopping and removing $DOCKER_ALIAS container."
                    docker stop $DOCKER_ALIAS > /dev/null 2>&1
                    docker rm -v $DOCKER_ALIAS > /dev/null 2>&1
                fi
            done
            END=1
        }

        trap "shutdown" INT TERM

        echo "$1 have been started. Please using CTRL+C to quit."

        while [ "x$END" = "x" ]; do
            sleep 1
        done
        ;;
    *)
        _PREFIX="$1"
        if [ "$3" = "-debug" ]; then
            echo "Prefix is ${_PREFIX}"
        fi

        _CONTAINER="${_PREFIX^^}_CONTAINER"
        if [ "x${!_CONTAINER}" = "x" ]; then
            echo "Please provide docker image name for running."
            exit -1
        fi

        _VOLUMES_FROMS="${_PREFIX^^}_VOLUMES_FROMS"
        if [ "x${!_VOLUMES_FROMS})" != "x" ]; then
            for _volumes_from in ${!_VOLUMES_FROMS} ; do
                if [ -n ${PREFIX} ]; then
                    _volumes_from="${PREFIX}-${_volumes_from}"
                fi
                VOLUMES_FROM="$VOLUMES_FROM --volumes-from $_volumes_from"
            done
        fi
        DOCKER_ALIAS="${PREFIX}-${_PREFIX}"

        _COMMANDS="${_PREFIX^^}_COMMANDS"
        _EXTEND_COMMANDS="${_PREFIX^^}_EXTEND_COMMANDS"

        if [ "x$2" != "x" ]; then
            _EXTEND_COMMANDS="$2"
        else
            _EXTEND_COMMANDS="${!_EXTEND_COMMANDS}"
        fi

        _FINAL_COMMANDS="run --network $NETWORK --name $DOCKER_ALIAS -h $DOCKER_ALIAS --rm ${!_COMMANDS} ${VOLUMES_FROM} ${!_CONTAINER} ${_EXTEND_COMMANDS}"

        echo "Excuting following command: $_FINAL_COMMANDS"
        docker ${_FINAL_COMMANDS}
        ;;
esac
