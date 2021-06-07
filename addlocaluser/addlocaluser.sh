#!/bin/bash

#**********************************
#* Author: Sione Sevaki           *
#* HW: Add Local User             *
#* Unix Systems                   *
#**********************************

#*****************Function checkLogin*****************
function checkLogin
{
    usedLogins=(`awk -F ':' '{print $1}' /etc/passwd`)

    for usedLogin in "${usedLogins[@]}"
    do
        if [ "$usedLogin" == "$1" ]
        then
            echo "error: user $1 already exists"
            exit 1
        fi
    done
}

#***********Function checkHomeDirectory***************
function checkHomeDirectory
{
    if [ -d "$1" ]
    then
        echo "error: directory '$1' already exist"
        exit 1
    fi
}

#***********Function checkSkelDirectory***************
function checkSkelDirectory
{
    if [ ! -d "$1" ]
    then
        echo "error: skeleton Directory '$1' does not exist."
        exit 1
    fi
}

#***********Function fetchAvailUID********************
function fetchAvailUID
{
    minUID=`cat /etc/login.defs | grep -E "^UID_MIN" | sed 's/\s\+/ /g' | cut -d ' ' -f 2`
    maxUID=`cat /etc/login.defs | grep -E "^UID_MAX" | sed 's/\s\+/ /g' | cut -d ' ' -f 2`
    usedIds=(`awk -F ':' '{print $3}' /etc/passwd`)

    for id in `seq "$minUID" "$maxUID"`
    do
        used="false"
        for usedId in "${usedIds[@]}"
        do
            if [ "$id" -eq "$usedId" ]
            then
                used="true"
            fi
        done

        if [ "$used" == "false" ]
        then
            echo "$id"
            return
        fi
    done

    echo "error: user IDs not available"
    exit 1
}

#***********Function fetchAvailGID********************
function fetchAvailGID
{
    minGID=`cat /etc/login.defs | grep -E "^GID_MIN" | sed 's/\s\+/ /g' | cut -d ' ' -f 2`
    maxGID=`cat /etc/login.defs | grep -E "^GID_MAX" | sed 's/\s\+/ /g' | cut -d ' ' -f 2`
    usedIds=(`awk -F ':' '{print $3}' /etc/group`)

    for id in `seq "$minGID" "$maxGID"`
    do
        used="false"
        for usedId in "${usedIds[@]}"
        do
            if [ "$id" -eq "$usedId" ]
            then
                used="true"
            fi
        done

        if [ "$used" == "false" ]
        then
            echo "$id"
            return
        fi
    done

    echo "error: group id not available"
    exit 1
}

#***********Function helpPrint************************
function helpPrint
{
    echo "usage: $0 command [options]"
    echo "where command is:"
    echo "  help [command]"
    echo "  add name [options]"
    echo "  delete name [options]"
}

#***********Function helpAddPrint*********************
function helpAddPrint
{
    echo "usage: $0 add login [options]"
    echo "where options are:"
    echo "  --home          - set the home directory to 'dir'"
    echo "  --name fullname - set the username to 'fullname'"
    echo "  --shell sh      - set the user shell to 'sh'"
    echo "  --skel dir      - use skeleton directory 'dir' to build user home"
    echo "  --noexec        - does not execute commands, just prints them"
}

#***********Function helpCommandOptions***************
function helpCommandOptions
{
    case "$1" in
        add) helpAddPrint;;
         "") helpPrint;;
          *) echo "error: unknown command $1."
             exit 3;;
    esac
}

#***********Function addCommandOptions****************
function addCommandOptions
{
    if [ -z "$1" ]
    then
        echo "error: Login Name Required"
    	exit 1
	fi

    login=$1; shift


    home="/home/$login"
    name=
    shell="/bin/bash"
    skel="/etc/skel"
    noexec="false"


    while [ ! $# -eq 0 ]
    do
        case "$1" in

            --home) if [ ! -z "$2" ];
                    then
                        home=$2
                    else
                        echo "error: Value for '--home' not set."
                        exit 1
                    fi

                    shift; shift;;
            --name) if [ ! -z "$2" ];
                    then
                        name=$2
                    else
                        echo "error: Value for '--name' not set."
                        exit 1
                    fi

                    shift; shift;;
           --shell) if [ ! -z "$2" ]
                    then
                        shell=$2
                    else
                        echo "error: Value for '--shell' not set."
                        exit 1
                    fi

                    shift; shift;;
            --skel) if [ ! -z "$2" ]
                    then
                        skel=$2
                    else
                        echo "error: Value for '--skel' not set."
                        exit 1
                    fi

                    shift; shift;;
          --noexec) noexec="true"; shift;;

                 *) echo "error: Unknown 'add' option '$1'."
                    shift;;

        esac
    done

    checkLogin $login
    checkHomeDirectory $home
    checkSkelDirectory $skel

    commands=`mktemp /tmp/localuser.XXXXXXXX`

    uid=`fetchAvailUID`
    gid=`fetchAvailGID`

    echo "echo \"$login:x:$uid:$gid:$name:$home:$shell\" >> /etc/passwd" >> $commands
    echo "echo \"$login:!:$((`date +%s`/86400)):0:99999:7:::\" >> /etc/shadow" >> $commands
    echo "echo \"$login:x:$gid:\" >> /etc/group" >> $commands
    echo "echo \"$login:!::\" >> /etc/gshadow" >> $commands
    echo "cp -r $skel $home" >> $commands
    echo "chown -R $login:$login $home" >> $commands

	if [ "$noexec" == "true" ]
    then
		cat "$commands"
	else
		bash "$commands"
	fi

    rm "$commands"
	echo "user $login added"
}

#********************* MAIN ***********************

if [ ! $EUID -eq 0 ]
then
  echo "Permission Denied: Not Administrator to execute '$0'"
  exit 1
fi

case $1 in
    help) helpCommandOptions $2;;
     add) shift; addCommandOptions "$@";;
      "") echo "Invalid Command: try \`$0 help\`";;
       *) echo "Unknown command $1"
          exit 1;;
esac
