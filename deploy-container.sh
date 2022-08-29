#!/bin/bash

# This is an scripts managing lxd container
#
# Copyright 2022 Valentin LEFEBVRE
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

#######################################################################
#                           GLOBAL VARIABLES                          #
#######################################################################

unset CONFIG_PATH
unset DISTRO_BASED
unset DISTRO_REDHAT_BASED 
unset DISTRO_SUSE_BASED
unset DISTRO_MANDRAKE_BASED
unset DISTRO_DEBIAN_BASED
unset DISTRO_UBUNTU_BASED
unset FORCE
unset INTERFACE

DISTRO_REDHAT_BASED="RedHat"
DISTRO_SUSE_BASED="Suse"
DISTRO_MANDRAKE_BASED="MANDRAKE"
DISTRO_UBUNTU_BASED="Ubuntu"

CONTAINER_DISTRO_ALPINE="alpine"
CONTAINER_DISTRO_CENTOS="centos"
CONTAINER_DISTRO_DEBIAN="debian"
CONTAINER_DISTRO_FEDORA="fedora"
CONTAINER_DISTRO_SUSE="opensuse"
CONTAINER_DISTRO_UBUNTU="ubuntu"

FORCE=0
INTERFACE="lxdbr0"
TIME_INIT_SEC=3

#######################################################################
#                           UTILS FUCNTION                            #
#######################################################################

###
# Print a warning message
# ARGUMENTS:
#   1 - message to print
# OUTPUTS:
#   warning message
###
function echo_warning() {
    local color_orange="\033[0;33m"
    local color_light_orange="\033[1;33m"
    local color_none="\033[0m"
    echo -e "$color_orange[WARNING] ${FUNCNAME[1]} $color_light_orange$1$color_none"
}

###
# Print a error message
# ARGUMENTS:
#   1 - message to print
# OUTPUTS:
#   error message
###
function echo_error() {
    local color_red="\033[0;31m"
    local color_light_red="\033[1;31m"
    local color_none="\033[0m"
    echo -e "$color_red[ERROR] ${FUNCNAME[1]} -- $color_light_red$1$color_none"
}

###
# Print a info message
# ARGUMENTS:
#   1 - message to print
# OUTPUTS:
#   info message
###
function echo_info() {
    local color_green="\033[0;32m"
    local color_light_green="\033[1;32m"
    local color_none="\033[0m"
    echo -e "$color_green[INFO] $color_light_green$1$color_none"
}

#######################################################################
#                           LXD FUCNTION                              #
#######################################################################
###
# Get the global ip of the interface
# GLOBALS:
#   INTERFACE
# ARGUMENTS:
#   none
# OUTPUTS:
#   print the ipv4 address
# RETURN:
#   0
###
function get_interface_ip() {
    lxc network info $INTERFACE | grep inet | awk '{print $2}'
}

###
# Get the container ipv4
# GLOBALS:
#   CONTAINER_NAME
# ARGUMENTS:
#   1. container name
# OUTPUTS:
#   none
# RETURN:
#   0 if installed, exit otherwise
###
function get_container_ip() {
    if [ ! $# -eq 1 ]; then
        echo_error "Wrong number of arguments"
        return 1;
    fi
    lxc list | grep $1 | awk '{print $6}'
}

###
# Generate a randome ip address in the scope of the interface addresses and store into ADDR
# GLOBALS:
#   RANDOM
#   INTERFACE
#   ADDR
# RETURN:
#   0 if installed, exit otherwise
###
function generate_ipv4_addr() {
    local rand=$((1+$RANDOM % 254))
    local addr=$(lxc network info $INTERFACE | grep inet | awk '{print $2}' | sed 's/\.[^.]*$/./')
    ADDR="$addr$rand"
}

###
# Check if container already is already installed
# ARGUMENTS:
#   1- name container
# RETURN:
#   0 if installed, 1 if installed
###
function container_installed() {
    if [ ! $# -eq 1 ]; then
        echo_error "Wrong number of arguments"
        return 1;
    fi
    lxc info $1 > /dev/null 2>&1
    [ $? -ne 0 ] || return 1 && return 0
}

###
# Delete a container if it is installed
# GLOBALS:
#   FORCE
# ARGUMENTS:
#   1. container name
# OUTPUTS:
#   status 
# RETURN:
#   exit 0 in success, 1 otherwise
###
function delete_container() {
    if [ ! $# -eq 1 ]; then
        echo_error "Wrong number of arguments"
        return 1;
    fi
    local cmd="lxc delete $container_name"
    container_installed $container_name
    [ ! $? -ne 0 ] && echo_warning "$container_name is not installed yet" && exit 0
    [ $FORCE -ne 0 ] && cmd="$cmd --force"
    $cmd
    echo_info "Container '$container_name' has been removed"
}

###
# Install a container if it is not installed (can be forced)
# GLOBALS:
#   FORCE
# ARGUMENTS:
#   1. container name
#   2. distribution name
#   3. release name
#   4. architecture name
# OUTPUTS:
#   status 
# RETURN:
#   exit 0 in success, 1 otherwise
###
function container_lxd_install() {
    if [ ! $# -eq 4 ]; then
        echo_error "Wrong number of arguments"
        return 1;
    fi
    local container_name="$1"
    local distro="$2"
    local release="$3"
    local arch="$4"

    container_installed $container_name
    if [ $? -ne 0 ]; then
        if [ ${FORCE} -ne 0 ]; then
            echo_info "Container $container_name has already been installed - Removing"
            delete_container $container_name
        else
            echo_warning "Container $container_name has already been installed, Using '--force' to reinstall it"
            exit 0
        fi
    fi
    lxc launch images:$distro/$release/$arch $container_name -c security.nesting=true -c security.privileged=true
    lxc config set $container_name boot.autostart false
}

###
# Install packages in containers from lsit
# ARGUMENTS:
#   1. container name
#   2. distribution name
#   x. List of packages
# OUTPUTS:
#   status 
# RETURN:
#   exit 0 in success, 1 otherwise
###
function container_install_packages() {
    if [ $# -lt 2 ]; then
        echo_error "Wrong number of arguments"
        return 1;
    fi
    local container_name="$1"
    local index=0
    for package in $@;
    do
        if [ $index -ge 2 ];
        then
            case "$2" in
                $CONTAINER_DISTRO_SUSE)
                    # Install on opensuse
                    lxc exec $container_name -- zypper install --no-confirm $package
                    ;;
                $CONTAINER_DISTRO_DEBIAN | $CONTAINER_DISTRO_UBUNTU)
                    lxc exec $container_name -- apt install -y $package
                    ;;
                $CONTAINER_DISTRO_CENTOS | $CONTAINER_DISTRO_FEDORA)
                    lxc exec $container_name -- dnf install -y $package
                    ;;
                *)
                    echo_error "Unknown distro to install packages"
                    ;;
            esac
        fi
        ((index+=1))
    done
}

# Execute one of the sript in tasks.d
# ARGUMENTS:
#   1. container name
#   2. script name
# OUTPUTS:
#   status 
# RETURN:
#   exit 0 in success, 1 otherwise
###
function container_exec_script() {
    if [ $# -ne 2 ]; then
        echo_error "Wrong number of arguments"
        return 1;
    fi
    local container_name="$1"
    local script="$2.sh"
    local script_path="$(dirname -- "$0")/tasks.d/$script"
    echo "execute script: $script_path"
    if [ -f $script_path ]; then
        . $script_path $container_name
    else 
        echo_error "Script file missing ($script_path)"
    fi
}

# function container_lxd_init() {
#     # Installing openssh
#     lxc exec ${CONTAINER_NAME} -- zypper install --no-confirm openssh vim
#     lxc exec ${CONTAINER_NAME} -- systemctl start sshd
#     lxc exec ${CONTAINER_NAME} -- systemctl enable sshd

#     # Creating group whell and add sudoers rules
#     lxc exec ${CONTAINER_NAME} -- sh -c "echo \"%wheel ALL=(ALL:ALL) ALL\" > /etc/sudoers.d/wheel"
#     lxc exec ${CONTAINER_NAME} -- sed -i 's/Defaults targetpw   # ask for the password of the target user i.e. root/#Defaults targetpw/g' /etc/sudoers
#     lxc exec ${CONTAINER_NAME} -- sed -i 's/ALL   ALL=(ALL) ALL   # WARNING! Only use this together with^*/#ALL   ALL=(ALL) ALL/g' /etc/sudoers
#     lxc exec ${CONTAINER_NAME} -- groupadd wheel
#     # Create user devel
#     local user_id=$(id -u)
#     lxc exec ${CONTAINER_NAME} -- useradd --create-home --uid $user_id --password devel devel
#     lxc exec ${CONTAINER_NAME} -- usermod -aG wheel devel
#     lxc exec ${CONTAINER_NAME} -- sh -c "echo -e \"devel\ndevel\" | passwd devel"

#     echo "You can now connect to the container thanks: 'ssh devel@$(get_container_ip)'"
# }

#######################################################################
#                           FUNCTIONS                                 #
#######################################################################

###
# Print the usage help
# OUTPUTS:
#   Write helper to stdout
# RETURN:
#   2 at this end
###
function usage() {
    echo -e "$0 [-c | --config] [ -h | --help ]

- config: Path to the config file
- force: force the installation or removing process

example:
    $0 --config=./test.json --force"
    exit 2
}

###
# Parse os-release to get distro OS
# GLOBALS:
#   DISTRO_BASED
# OUTPUTS:
#   status
###
function get_os_name() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_BASED=$NAME
    else
        echo_warning "Cannot read 'os-release', unknown linux distribution"
    fi
}

###
# Parse config and deplay each define container
# GLOBALS:
#   CONFIG_PATH
# ARGUMENTS:
#   none
# OUTPUTS:
#   none
# RETURN:
#   0 in cusses, 1 otherwise
###
function parse_config_file() {
    local result=0
    local containers_length=$(jq ".containers | length" $CONFIG_PATH)
    for ((index=0; index<$containers_length; index++))
    do
        local container_name=$(jq ".containers[$index].name" $CONFIG_PATH | tr -d '"')
        local container_storage=$(jq ".containers[$index].storage" $CONFIG_PATH | tr -d '"')
        local container_distro=$(jq ".containers[$index].distro" $CONFIG_PATH | tr -d '"')
        local container_release=$(jq ".containers[$index].release" $CONFIG_PATH | tr -d '"')
        local container_arch=$(jq ".containers[$index].arch" $CONFIG_PATH | tr -d '"')
        local container_packages=$(jq -r  ".containers[$index].packages[]" $CONFIG_PATH | tr -d '"')
        local container_cmds=$(jq -r  ".containers[$index].commands[]" $CONFIG_PATH)
        echo_info "Deploying container $container_name (storage=$container_storage) ..."
        container_lxd_install $container_name $container_distro $container_release $container_arch
        result=$?
        if [ $result -eq 1 ]; then
            echo_error "Failled to create container '$container_name'. Aborted"
            exit 1
        else
            echo_info "Container '$container_name' has been created"
            # Wait the container to be well initialized
            sleep $TIME_INIT_SEC
            # Installing packages
            container_install_packages $container_name $container_distro $container_packages
            [ $? -eq 1 ] && echo_warning "Some packets are not installed"
            # Run commands
            local commands_length=$(jq ".containers[$index].commands | length" $CONFIG_PATH)
            for ((cmd_index=0; cmd_index<$commands_length; cmd_index++))
            do
                local cmd="$(jq ".containers[$index].commands[$cmd_index]" $CONFIG_PATH)"
                cmd=${cmd:1:-1} # Remove firt and last '"'
                container_exec_script $container_name "$cmd"
            done

        fi
    done
}

###
# Check if lxd is installed on the system
# GLOBALS:
#   none
# ARGUMENTS:
#   none
# OUTPUTS:
#   none
# RETURN:
#   0 if installed, exit otherwise
###
function check_lxd_installed() {
    local is_installed=1;
    if [ -z $DISTRO_BASED ]; then 
        echo_warning "Cannot check if tools are installed because of unknown distro"
    else
        case "$DISTRO_BASED" in
            "$DISTRO_UBUNTU_BASED")
                [ $(dpkg-query -W -f='${Status}' nano 2>/dev/null | grep -c "ok installed") -eq 0 ] || is_installed=0
                ;;
            "$DISTRO_SUSE_BASED" | "$DISTRO_REDHAT_BASED")
                rpm -q lxd > /dev/null 2>&1
                [ $? -ne 0 ] && is_installed=0
                ;;
            *)
                echo_error "Unknown distro to check installed packages"
                exit1
                ;;  
        esac
    fi
    [ -z is_installed ] && echo "you must install lxd to run this script..." && exit 1
}


#######################################################################
#                           ENTRY POINT                               #
#######################################################################

# Check if tools are installed
get_os_name
echo_info "Running script on distro $DISTRO_BASED"
check_lxd_installed

# Get arguments
[[ -z $@ ]] && echo_error "Missing arguments" && usage
PARSED_ARGUMENTS=$(getopt -a -n manage-container -o c:fh --long config:,force,help -- "$@")
[ $? != "0" ] && usage

eval set -- "$PARSED_ARGUMENTS"
while :
do
  case "$1" in
    -c | --config)      CONFIG_PATH="$2"            ; shift 2 ;;
    -f | --force)       FORCE=1                     ; shift 1 ;;
    -h | --help)        usage                       ; shift   ;;
    --)                 shift                       ; break   ;;
    *)                  echo "Unexpected option: $1"; usage   ;;
  esac
done

# Deploy containers
[ -z ${CONFIG_PATH} ] && echo "Missing config file path" && usage

parse_config_file