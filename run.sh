#!/bin/bash

###########################
### INITIALISE DEFAULTS ###
###########################
set -e

: ${SLAVE_NUMBER:="0"}
: ${MASTER_NUMBER:="1"}

: ${PDI_MAX_LOG_LINES:="10000"}
: ${PDI_MAX_LOG_TIMEOUT:="1440"}
: ${PDI_MAX_OBJ_TIMEOUT:="240"}

: ${SERVER_NAME:="pdi-server"}
: ${SERVER_HOST:="localhost"}
: ${SERVER_PORT:="8080"}
: ${SERVER_USER:="admin"}
: ${SERVER_PASSWD:="admin"}

: ${MASTER_NAME:="pdi-master"}
: ${MASTER_HOST:="localhost"}
: ${MASTER_PORT:="8080"}
: ${MASTER_USER:="admin"}
: ${MASTER_PASSWD:="admin"}
: ${CPU_LIMIT_SLAVE:="0.5"}
: ${CPU_LIMIT_MASTER:="0.5"}

###########################
####### LOAD CONFIG #######
###########################
 
while [ $# -gt 0 ]; do
        case $1 in
                -c)
                        CONFIG_FILE_PATH="$2"
                        shift 2
                        ;;
                *)
                        ${ECHO} "Unknown Option \"$1\"" 1>&2
                        exit 2
                        ;;
        esac
done
 
if [ -z $CONFIG_FILE_PATH ] ; then
        SCRIPTPATH=$(cd ${0%/*} && pwd -P)
        CONFIG_FILE_PATH="${SCRIPTPATH}/pentaho.conf"
fi
 
if [ ! -r ${CONFIG_FILE_PATH} ] ; then
        echo "Could not load config file from ${CONFIG_FILE_PATH}" 1>&2
        exit 1
fi
 
source "${CONFIG_FILE_PATH}"

############################
### GENERATORS functions ###
############################


gen_volumes() {
    if [ ! -d log ]; then
	echo -e "Generating future volumes for server.. \n"
	mkdir -p log/tmp
	mkdir -p log/pdi
	chown -R :1000 log/
	chmod -R 775 log/
    else 
	echo -e "${FUNCNAME[ 0 ]} Already done..skipping..\r"
    fi
}

gen_master() {
if [ ! -f docker-compose.yml ]; then
    echo -e "Generating docker-compose file for MASTER...\n"
    cat <<< "version: '2.2'

services:
  pdi-srv:
    build: .
    container_name: pentaho-${MASTER_NAME}_$1
    command: 'master'
    network_mode: host
    volumes:
      - ./log/tmp:/tmp:rw
      - ./log/pdi:/home/pdi/data-integration/logs:rw
    environment:
      # uncomment below if you want to see the generated admin password
      #DEBUG: Y
      PENTAHO_DI_JAVA_OPTIONS: '${PENTAHO_DI_JAVA_OPTIONS_MASTER}'
      PDI_MAX_LOG_LINES: ${PDI_MAX_LOG_LINES}
      PDI_MAX_LOG_TIMEOUT: ${PDI_MAX_LOG_TIMEOUT}
      PDI_MAX_OBJ_TIMEOUT: ${PDI_MAX_OBJ_TIMEOUT}
      SERVER_NAME: ${MASTER_NAME}
      SERVER_HOST: ${SERVER_HOST}
      SERVER_PORT: ${FINAL_PORT}
      SERVER_USER: ${SERVER_USER}
      SERVER_PASSWD: ${SERVER_PASSWD}
    restart: always
    cpus: ${CPU_LIMIT_MASTER}" > docker-compose.yml
else 
	echo -e "${FUNCNAME[ 0 ]} Already done..skipping..\r"

fi
}

gen_slave() {

if [ ! -f docker-compose.yml ]; then
    echo -e "Generating docker-compose file for SLAVE...\n"
    cat <<< "version: '2.2'

services:
  pdi-srv:
    build: .
    container_name: pentaho-${SERVER_NAME}_$1
    command: 'slave'
    network_mode: host
    volumes:
      - ./log/tmp:/tmp:rw
      - ./log/pdi:/home/pdi/data-integration/logs:rw
    environment:
      PENTAHO_DI_JAVA_OPTIONS: '${PENTAHO_DI_JAVA_OPTIONS_SLAVE}'
      PDI_MAX_LOG_LINES: ${PDI_MAX_LOG_LINES}
      PDI_MAX_LOG_TIMEOUT: ${PDI_MAX_LOG_TIMEOUT}
      PDI_MAX_OBJ_TIMEOUT: ${PDI_MAX_OBJ_TIMEOUT}
      SERVER_NAME: ${SERVER_NAME}_$1
      SERVER_HOST: ${SERVER_HOST}
      SERVER_PORT: ${FINAL_PORT}
      SERVER_USER: ${SERVER_USER}
      SERVER_PASSWD: ${SERVER_PASSWD}
      MASTER_NAME: ${MASTER_NAME}
      MASTER_HOST: ${MASTER_HOST}
      MASTER_PORT: ${MASTER_PORT}
      MASTER_USER: ${MASTER_USER}
      MASTER_PASSWD: ${MASTER_PASSWD}
    restart: always
    cpus: ${CPU_LIMIT_SLAVE}" > docker-compose.yml
else 
	echo -e "${FUNCNAME[ 0 ]} Already done..skipping..\r"

fi
}

run_server() {

    cur_srv=${PWD##*/}

    if [ -z "$(docker ps | grep $cur_srv)" ]; then
	echo -e "Running the server $cur_srv ... \n"
	docker-compose up -d > /dev/null
    else 
	echo -e "${FUNCNAME[ 0 ]} Already done..skipping..\r"

    fi
}

port_open_check() {
    echo "Check ports:"
    while [ $(curl -s -o /dev/null -w "%{http_code}" ${SERVER_HOST}:${FINAL_PORT}) -ne 401 ]
    do
	echo -ne "Port ${FINAL_PORT} is not open.. waiting\r"
    done

echo "Pentaho PDI server $cur_srv is up and running on port ${FINAL_PORT}"
}


####################################
### MAKE AND RUN MASTER OR SLAVE ###
####################################
copy_files=`ls | grep -iv run.sh | grep -iv pentaho.conf | grep -iv "^master\|^slave" `

echo  "Start to prepare and run all services"

if [ $MASTER_NUMBER -ge 1 ]; then

    FINAL_PORT=$SERVER_PORT
    echo -e "\n### ...GENERATE MASTERS... ###"

    for i in $(seq 1 $MASTER_NUMBER)
    do
    echo -e "..Start to create master_$i directories and files.."
	if [ ! -d ${MASTER_NAME}_$i ]; then
	    echo "Making dir for ${MASTER_NAME}_$i."
	    mkdir ${MASTER_NAME}_$i
	    echo "Copy files to ${MASTER_NAME}_$i."
	    cp -r $copy_files ${MASTER_NAME}_$i/
	else 
	    echo -e "Dirs already created..skipping..\r"
	fi
	cd ${MASTER_NAME}_$i
	    gen_master $i
	    gen_volumes
	    run_server
	    port_open_check
	cd ..
	((FINAL_PORT++))
    done
else 
	echo -e "Already done..skipping..\r"
fi


if [ $SLAVE_NUMBER -ge 1 ]; then 

	echo -e "\n### ...GENERATE SALVES... ###\n"

        for i in $(seq 1 $SLAVE_NUMBER)
	do
	    if [ ! -d ${SERVER_NAME}_$i ]; then
		echo "Making dir for ${SERVER_NAME}_$i."
		mkdir ${SERVER_NAME}_$i
		echo "Copy files to ${SERVER_NAME}_$i."
		cp -r $copy_files ${SERVER_NAME}_$i/
	    fi
	    cd ${SERVER_NAME}_$i
		gen_slave $i
		gen_volumes
		run_server
		port_open_check
	    cd ..
	    ((FINAL_PORT++))
	done
else 
	echo -e "Already done..skipping..\r"
fi
