#!/bin/sh

# ROS Environnemt Manager
ROSENV_DIR=$HOME/.rosenv
rosenv() {
    if [ $# -lt 1 ]; then
        rosenv help
        return
    fi
    case $1 in
        "help")
            echo
            echo "ROS Environment Manager"
            echo
            echo "Usage:"
            echo "    rosenv help"
            echo "       Show this message"
            echo "    rosenv register|add <nickname> <path> <distro>"
            echo "       Register an existing ros workspace."
            echo "    rosenv remove|rm|unregister <nickname>"
            echo "       Remove a workspace from rosenv."
            echo "    rosenv list"
            echo "       List all the workspaces"
            echo "    rosenv use <nickname> [--devel|--install]"
            echo "       Switch to the workspace specifid by the nickname."
            echo "       If that environment is catkin workspace, you can"
            echo "       sppecify which setup file to use devel or install."
            echo "    rosenv use --install"
            echo "       Use install setup script with the current workspace."
            echo "    rosenv use --devel"
            echo "       Use devel setup script with the current workspace."
            echo "    rosenv update [<nickname>] [-jJOB_NUM]"
            echo "       Run \`rosws update\` or \`wstool update\` on the"
            echo "       current workspace. You can specify other workspace by"
            echo "       --env option."
            echo "    rosenv install <nickname> <path> <distro> \
<rosinstall-file> [<rosinstall-file> <rosinstall-file> ...]"
            echo "       Checkout several repositories speicfied by the"
            echo "       rosinstall files and register that workspace to rosenv."
            echo "    rosenv get-version <nickname>"
            echo "       Show the version of the workspace"
            echo "    rosenv get-path <nickname>"
            echo "       Get the path of the workspace"
            echo "    rosenv list-nicknames"
            echo "       List all the workspaces's nickname"
            echo "    rosenv is-catkin <nickname>"
            echo "       return yes if the workspace is catkin workspace."
            echo "    rosenv distros"
            echo "       return a list of distribution supported by rosenv"
            echo
            echo "Example:"
            echo "    rosenv install jsk.hydro ~/ros/hydro hydro https://raw.github.com/jsk-ros-pkg/jsk_common/master/jsk.rosinstall"
            echo "    rosenv install jsk.groovy ~/ros/groovy groovy https://raw.github.com/jsk-ros-pkg/jsk_common/master/jsk.rosinstall"
            echo "    rosenv update --env jsk.hydro"
            echo "    rosenv update --env jsk.groovy"
            echo "    rosenv use jsk.hydro"
            ;;
        "distros")              # internal API
            echo "groovy hydro indigo"
            ;;
        "register" | "add")
            # nickname path version
            if [ $# -lt 4 ]; then
                rosenv help
                return
            fi
            local nickname
            local ws_path
            local version
            nickname=$2
            ws_path=$3
            version=$4
            echo "  register $ws_path($version) as $nickname"
            # use node to read/write json file
            node <<EOF
var path = require('path');
var fs = require('fs');
if (!fs.existsSync("$ROSENV_DIR")) {
  fs.mkdirSync("$ROSENV_DIR");
}
var config = {};
if (fs.existsSync("$ROSENV_DIR/config.json")) {
  config = JSON.parse(fs.readFileSync("$ROSENV_DIR/config.json", "utf-8"));
}
config["$nickname"] = {
  path: "$ws_path",
  version: "$version"
};
fs.writeFileSync("$ROSENV_DIR/config.json", JSON.stringify(config, null, 4) + '\n');
EOF
            ;;
        "list")
            node <<EOF
var path = require('path');
var fs = require('fs');
var util = require('util');
if (fs.existsSync("$ROSENV_DIR/config.json")) {
  config = JSON.parse(fs.readFileSync("$ROSENV_DIR/config.json", "utf-8"));
  for (var key in config) {
    if (key.toString() == "$ROSENV_CURRENT".toString()) {
      console.log(util.format('* %s (%s) %s', key, config[key].version, config[key].path));
    }
    else {
      console.log(util.format('  %s (%s) %s', key, config[key].version, config[key].path));
    }
  }
}
else {
  console.log("no env is registered");
}
EOF
            ;;
        "list-nicknames")       # internal command
            local onelinep
            if [ "$1" = "--oneline" ]; then
                onelinep=true
            else
                onelinep=false
            fi
            node <<EOF
var path = require('path');
var fs = require('fs');
if (fs.existsSync("$ROSENV_DIR/config.json")) {
  config = JSON.parse(fs.readFileSync("$ROSENV_DIR/config.json", "utf-8"));
  var split = ' ';
  if ($onelinep) {
    split = '\n';
  }
  var strs = [];
  for (var key in config) {
    strs.push(key);
  }
  console.log(strs.join(split));
}
EOF
            ;;
        "get-path")             # internal command
            local nickname
            nickname=$2
            node <<EOF
var path = require('path');
var fs = require('fs');
if (fs.existsSync("$ROSENV_DIR/config.json")) {
  config = JSON.parse(fs.readFileSync("$ROSENV_DIR/config.json", "utf-8"));
  if (config.hasOwnProperty("$nickname")) {
    console.log(config["$nickname"].path);
  }
}
EOF
            ;;
        "get-version")             # internal command
            local nickname
            nickname=$2
            node <<EOF
var path = require('path');
var fs = require('fs');
if (fs.existsSync("$ROSENV_DIR/config.json")) {
  config = JSON.parse(fs.readFileSync("$ROSENV_DIR/config.json", "utf-8"));
  if (config.hasOwnProperty("$nickname")) {
    console.log(config["$nickname"].version);
  }
}
EOF
            ;;
        "rm" | "remove" | "unregister")
            local nickname
            nickname=$2
            node <<EOF
var path = require('path');
var fs = require('fs');
if (fs.existsSync("$ROSENV_DIR/config.json")) {
  config = JSON.parse(fs.readFileSync("$ROSENV_DIR/config.json", "utf-8"));
  delete config["$nickname"];
fs.writeFileSync("$ROSENV_DIR/config.json", JSON.stringify(config, null, 4) + '\n');
}
EOF
            ;;
        "is-catkin")
            local ws_path
            local nickname
            nickname=$2
            ws_path=$(rosenv get-path $nickname)
            if [ -e $ws_path/src -a -e $ws_path/src/CMakeLists.txt ]; then
                echo yes
            fi
            ;;
        "use")
            local nickname
            local develp
            local installp
            # parsing argument
            nickname=$ROSENV_CURRENT
            shift               # dispose 'use' argument
            while [ $# -gt 0 ]; do
                case "$1" in 
                    "--install") installp=true;;
                    "--devel") develp=true;;
                    *) nickname=$1;;
                esac
                shift
            done
            if [ "`rosenv get-version $nickname`" = "" ]; then
                echo $nickname is not registered yet
                return 1
            else
                local ws_path
                ws_path=$(rosenv get-path $nickname)
                if [ -e $ws_path/src -a -e $ws_path/src/CMakeLists.txt ]; then
                    # catkin
                    if [ "$installp" = "true" ]; then
                        echo switching to $nickname:install
                        source $ws_path/install/setup.`basename $SHELL`
                    else
                        echo switching to $nickname:devel
                        source $ws_path/devel/setup.`basename $SHELL`
                    fi
                    export ROSENV_CURRENT=$nickname
                    export ROS_WORKSPACE=$ws_path
                else
                    # rosbuild
                    echo switching to $nickname
                    source $ws_path/setup.`basename $SHELL`
                    export ROSENV_CURRENT=$nickname
                fi
                        
            fi
            ;;
        "update")
            # update [nickname] [-jJOB_NUM]
            local nickname
            local pjobs
            if [ $# != 2 -a $# != 3 ]; then
                rosenv help
                return 2
            fi
            shift               # dispose 'update'
            nickname=$ROSENV_CURRENT
            while [ $# -gt 0 ]; do
                case "$1" in
                    -j*) pjobs=$1;;
                    *) nickname=$1
                esac
                shift
            done
            if [ "$(rosenv is-catkin $nickname)" = "yes" ] ; then
                (cd $(rosenv get-path $nickname)/src && rosenv use $nickname && wstool update $pjobs);
            else
                (cd $(rosenv get-path $nickname) && rosenv use $nickname && rosws update $pjobs);
            fi
            ;;
        "install")
            # install nickname path distro rosinstall-file [rosinstall-file2 rosinstall-file3 ...]
            # parse argument
            local nickname
            local directory
            local rosinstall_files
            local distro
            local wscmd
            wscmd=wstool
            if [ $# -lt 5 ]; then
                rosenv help
                return 1
            fi
            nickname=$2
            directory=$3
            distro=$4
            shift; shift; shift; shift;
            while [ $# -gt 0 ]; do
                case "$1" in
                    "--rosbuild") wstool=rosws;;
                    *) rosinstall_files="$1 $rosinstall_files";;
                esac
                shift
            done
            mkdir -p $directory
            (cd $directory && $wscmd init)
            if [ $wscmd = rosws ]; then
                (cd $directory && $wscmd merge /opt/ros/$distro/.rosinstall)
            fi
            for rosinstall_file in `echo $rosinstall_files`
            do
                if [ -e $rosinstall_file ]; then
                    local abspath
                    abspath=$(cd $(dirname $rosinstall_file) && pwd)/$(basename $rosinstall_file)
                    (cd $directory && $wscmd merge file://$abspath)
                else
                    (cd $directory && $wscmd merge $rosinstall_file)
                fi
            done
            rosenv register $nickname $directory $distro
            ;;
    esac
}

# completion
if [ $(basename $SHELL) = "zsh" ]; then
    _rosenv() {
        local _1st_arguments
        _1st_arguments=(
            "help":"show help"
            "register":"register a workspace"
            "list":"list of the workspaces"
            "list-nicknames":"only list up the nicknames of the workspaces"
            "get-path":"get the path to the workspace"
            "get-version":"get the ROS distro version of the workspace"
            "remove":"remove the workspace"
            "is-catkin":"return yes if the workspace is catkin"
            "use":"switch the workspace"
            "update":"update the workspace"
        )
        _arguments '*:: :->command'
        if ((CURRENT == 1)); then
            _describe -t commands "rosenv commands" _1st_arguments;
            return
        fi
        local _command_args
        case "$words[1]" in
            "register" | "add")
                if ((CURRENT == 3)); then
                    _files
                elif ((CURRENT == 4)); then
                    _values "distros" $(rosenv distros)
                fi
                ;;
            "remove" | "rm" | "unregister")
                if ((CURRENT == 2)); then
                    _values "workspaces" $(rosenv list-nicknames)
                fi
                ;;
            "list")
                # do nothing
                ;;
            "use")
                _values "workspaces" $(rosenv list-nicknames) --install --devel
                ;;
            "update")
                _values "workspaces" $(rosenv list-nicknames)
                ;;
            "install")
                if ((CURRENT == 3)); then
                    _files
                elif ((CURRENT == 4)); then
                    _values "distro" $(rosenv distros)
                elif ((CURRENT != 2)); then
                    _files
                fi
                ;;
            "get-path" | "get-version")
                _command_args=$(rosenv list-nicknames)
                _values "args" `echo $_command_args`
                ;;
            
        esac
        
    }
    compdef _rosenv rosenv
fi
