#!/bin/bash
set -e

: ${PDI_MAX_LOG_LINES:="10000"}
: ${PDI_MAX_LOG_TIMEOUT:="1440"}
: ${PDI_MAX_OBJ_TIMEOUT:="240"}

: ${SERVER_NAME:="pdi-server"}
: ${SERVER_HOST:="`hostname`"}
: ${SERVER_PORT:="8080"}
: ${SERVER_USER:="admin"}
: ${SERVER_PASSWD:=""}

: ${MASTER_NAME:="pdi-master"}
: ${MASTER_HOST:="localhost"}
: ${MASTER_PORT:="8080"}
: ${MASTER_CONTEXT:="pentaho"}
: ${MASTER_USER:="admin"}
: ${MASTER_PASSWD:="password"}

_gen_password() {
	echo "Generating encrypted password..."
	if [[ "$SERVER_PASSWD" == "" ]]; then
		_ADMIN_PWD="$(dd if=/dev/urandom bs=255 count=1 | tr -dc 'a-zA-Z0-9' | fold -w $((96 + RANDOM % 32)) | head -n 1)"
	else
		_ADMIN_PWD="$SERVER_PASSWD"
	fi

	[[ "$DEBUG" ]] && echo "=> [$_ADMIN_PWD]"

	_ADMIN_PWD=""
}

gen_rest_conf() {
	# unset doesn't work
	echo "Clean up sensitive environment variabiles..."
	SERVER_PASSWD=""
	MASTER_PASSWD=""
	export SERVER_PASSWD MASTER_PASSWD

	if [ ! -f .kettle/kettle.properties ]; then
		echo "Generating kettle.properties..."
		mkdir -p .kettle
		cat <<< "# This file was generated by Pentaho Data Integration.
#
# Here are a few examples of variables to set:
#
# PRODUCTION_SERVER = hercules
# TEST_SERVER = zeus
# DEVELOPMENT_SERVER = thor
#
# Note: lines like these with a # in front of it are comments
#
# Read more at https://github.com/pentaho/pentaho-kettle/blob/6.1.0.1-R/engine/src/kettle-variables.xml
KETTLE_REDIRECT_STDERR=Y
KETTLE_REDIRECT_STDOUT=Y

# Less memory consumption, hopefully
KETTLE_STEP_PERFORMANCE_SNAPSHOT_LIMIT=1

" > .kettle/kettle.properties
	fi

}

gen_slave_config() {
	# check if configuration file exists
	if [ ! -f pwd/slave.xml ]; then
		echo "Generating slave server configuration..."
		_gen_password

		if [[ ! $MASTER_PASSWD == Encrypted* ]]; then
			MASTER_PASSWD=$(./encr.sh -kettle $MASTER_PASSWD | tail -1)
		fi

		# this is tricky as encr.sh will generate kettle.properties without required configuration
		rm -f .kettle/kettle.properties
		
		cat <<< "<slave_config>
    <masters>
        <slaveserver>
            <name>${MASTER_NAME}</name>
            <hostname>${MASTER_HOST}</hostname>
            <port>${MASTER_PORT}</port>
            <webAppName>${MASTER_CONTEXT}</webAppName>
            <username>${MASTER_USER}</username>
            <password>${MASTER_PASSWD}</password>
            <master>Y</master>
        </slaveserver>
    </masters>
    <report_to_masters>Y</report_to_masters>
    <slaveserver>
        <name>${SERVER_NAME}</name>
        <hostname>${SERVER_HOST}</hostname>
        <port>${SERVER_PORT}</port>
        <username>${SERVER_USER}</username>
        <password>${SERVER_PASSWD}</password>
        <master>N</master>
        <get_properties_from_master>Master</get_properties_from_master>
        <override_existing_properties>Y</override_existing_properties>
    </slaveserver>

    <max_log_lines>${PDI_MAX_LOG_LINES}</max_log_lines>
    <max_log_timeout_minutes>${PDI_MAX_LOG_TIMEOUT}</max_log_timeout_minutes>
    <object_timeout_minutes>${PDI_MAX_OBJ_TIMEOUT}</object_timeout_minutes>
</slave_config>" > pwd/slave.xml
	fi
}

gen_master_config() {
	# check if configuration file exists
	if [ ! -f pwd/master.xml ]; then
		echo "Generating master server configuration..."
		_gen_password

		rm -f .kettle/kettle.properties

		cat <<< "<slave_config>
        <slaveserver>
            <name>${SERVER_NAME}</name>
            <hostname>${SERVER_HOST}</hostname>
            <port>${SERVER_PORT}</port>
            <username>${SERVER_USER}</username>
            <password>${SERVER_PASSWD}</password>
            <master>Y</master>
        </slaveserver>

        <max_log_lines>${PDI_MAX_LOG_LINES}</max_log_lines>
        <max_log_timeout_minutes>${PDI_MAX_LOG_TIMEOUT}</max_log_timeout_minutes>
        <object_timeout_minutes>${PDI_MAX_OBJ_TIMEOUT}</object_timeout_minutes>
</slave_config>" > pwd/master.xml
	fi
}

# run as slave server
if [ "$1" = 'slave' ]; then
	gen_slave_config
	gen_rest_conf
	
	# update configuration based on environment variables
	# send log output to stdout
	sed -i 's/^\(.*rootLogger.*\), *out *,/\1, stdout,/' system/karaf/etc/org.ops4j.pax.logging.cfg
	#sed -i -e 's|.*\(runtimeFeatures=\).*|\1'"ssh,http,war,kar,cxf"'|' system/karaf/etc-carte/org.pentaho.features.cfg 

	# now start the PDI server
	echo "Starting Carte as slave server..."
	exec $KETTLE_HOME/carte.sh $KETTLE_HOME/pwd/slave.xml
elif [ "$1" = 'master' ]; then
	gen_master_config
	gen_rest_conf

	# now start the PDI server
	echo "Starting Carte as master server(it's better use BA server instead)..."
	exec $KETTLE_HOME/carte.sh $KETTLE_HOME/pwd/master.xml
fi

exec "$@"
