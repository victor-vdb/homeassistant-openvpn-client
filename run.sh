#!/bin/bash
#
# Start the web server and setup the VPN connection

declare -r REQUIRED_FILES="client.crt client.key ca.crt"
declare -r CLIENT_CONFIG_LOCATION=/share/openvpnclient

########################################################################################################################
# Initialize the tun interface for OpenVPN if not already available
# Arguments:
#   None
# Returns:
#   None
########################################################################################################################
function init_tun_interface(){
    # create the tunnel for the openvpn client

    mkdir -p /dev/net
    if [ ! -c /dev/net/tun ]; then
        mknod /dev/net/tun c 10 200
    fi
}

########################################################################################################################
# Read the user OpenVPN configuration and save it into the directory defined by CLIENT_CONFIG_LOCATION
# Globals:
#   CLIENT_CONFIG_LOCATION
# Arguments:
#   None
# Returns:
#   None
########################################################################################################################
function setup_openvpn_config(){

    # split up the entries in the config option into lines and write to the client configuration file
    cat /options.json | jq --raw-output '.options | .config[]' > ${CLIENT_CONFIG_LOCATION}/client.ovpn

    chmod 777 ${CLIENT_CONFIG_LOCATION}/client.ovpn

}

########################################################################################################################
# Start our Flask-based web server using the virtual environment setup by the Dockerfile.
# Globals:
#   NAME
# Arguments:
#   None
# Returns:
#   None
########################################################################################################################
function start_webserver(){

    # The python virtual environment is inside the directory defined by $NAME in /
    source /${NAME}/venv/bin/activate

    # now we the the entry point defined by the app
    openvpnclient

}

########################################################################################################################
# Wait until the user has uploaded all required certificates and keys in order to setup the VPN connection.
# Globals:
#   REQUIRED_FILES
#   CLIENT_CONFIG_LOCATION
# Arguments:
#   None
# Returns:
#   None
########################################################################################################################
function wait_configuration(){
    # therefore, wait until the user upload the required certification files
    while true; do

        failed=0
        for file in ${REQUIRED_FILES}
        do
            if [[ ! -f ${CLIENT_CONFIG_LOCATION}/${file} ]]
            then
                failed=1
                break
            fi
        done

        if [[ ${failed} == 0 ]]
        then
            break
        fi

        sleep 5
    done
}

init_tun_interface

# create the config directory if it does not exist
if [[ ! -d ${CLIENT_CONFIG_LOCATION} ]]
then
    mkdir -p ${CLIENT_CONFIG_LOCATION}
fi

setup_openvpn_config

# start the web server as background task
nohup start_webserver &

# wait until the use uploaded the configuration files
wait_configuration

# try to connect to the server using the used defined configuration
openvpn --config ${CLIENT_CONFIG_LOCATION}/client.ovpn