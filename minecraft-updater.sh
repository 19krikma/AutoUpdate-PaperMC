#!/usr/bin/env sh
VERSION="0.2"
source config.ini

get_opts()
{
    while [[ $# -gt 0 ]]
    do
        key="$1"
        case $key in
            -c|--check)
                check
                exit
                ;;
            -d|--download)
                download
                exit
                ;;
            -e|--stop)
                shift
                stop
                shift
                ;;
            -h|--help)
                help
                exit
                ;;
            -i|--info)
                info
                exit
                ;;
            -l|--launch)
                shift
                start
                shift
                ;;
            -u|--update)
                update
                exit
                ;;
            -t|--test)
                test
                exit
                ;;
            -v|--version)
                version
                exit
                ;;
        esac
    done
}
# Seprete Functions  -----------------

buildName(){
        a=$(curl -s https://api.papermc.io/v2/projects/${PROJECT}/versions/${MINECRAFT_VERSION}/builds | \
                jq '.builds | map(select(.channel == "'${TYPE}'") | .downloads | .application | .name) |.[-1]')
        b=${a#'"'}
        BUILD_NAME=${b%'"'}
        echo $BUILD_NAME
}

getPID(){
        pid=$(pgrep -f $1-$PROJECT)
        echo $pid
}

getCheckSum(){
        a=$(curl -s https://api.papermc.io/v2/projects/${PROJECT}/versions/${MINECRAFT_VERSION}/builds | \
                jq '.builds | map(select(.channel == "'${TYPE}'") | .downloads | .application | .sha256) |.[-1]')
        b=${a#'"'}
        BUILD_SHA256=${b%'"'}
        echo $BUILD_SHA256
}

buildCheck(){
        BUILD=$(curl -s https://api.papermc.io/v2/projects/${PROJECT}/versions/${MINECRAFT_VERSION}/builds | \
                jq '.builds | map(select(.channel == "'$1'") | .build) |.[-1]')
        echo $BUILD
}

updateConf(){
        sed -i "s/^\($1=\).*/\1$2/" config.ini
}

checkSHA256(){
        local BUILD_NAME=$(buildName)
        checksum=0
        if [ $1 != "null" ]; then
                checksum=$(sha256sum "$1" | awk '{print $1}')
        else
                checksum=$(sha256sum "$BUILD_NAME" | awk '{print $1}')
        fi
        if [ $checksum == $(getCheckSum) ]; then
                echo True
        else
                echo False
        fi
}

wgetLink(){
        local BUILD_NAME=$(buildName)
        LINK="https://api.papermc.io/v2/projects/${PROJECT}/versions/${MINECRAFT_VERSION}/builds/$LATEST_BUILD/downloads/$BUILD_NAME"
        SHA256_RESULT=""
        (if [ $1 != "null" ]; then
                wget -O $1 $LINK
                if [ $SHA256 ]; then
                        SHA256_RESULT=$(checkSHA256 $1)
                fi
                if [ $SHA256_RESULT ]; then
                        echo "Passed"
                else
                        echo "Failed"
                fi
                exit
        else
                wget $LINK
                if [ $SHA256 ]; then
                        SHA256_RESULT=$(checkSHA256)
                fi
                if [ $SHA256_RESULT ]; then
                        echo "Passed"
                else
                        echo "Failed"
                fi
        fi)
}

upToDate(){
        #Up to Date True or False
        if [[ $LATEST_BUILD -eq $CURRENT_BUILD ]]; then
                return 0
        else
                return 1
        fi
}
# ------------------------------------



check(){
        #Check if Default is Available
        default="default"
        experimental="experimental"
        BUILD_CHECK_DEF=$(buildCheck $default)
        BUILD_CHECK_EXP=$(buildCheck $experimental)
        (if [ $TYPE == "default" ] && [ $BUILD_CHECK_DEF != "null" ]; then
                echo "Released 'Stable' $MINECRAFT_VERSION Build# $BUILD_CHECK_DEF"
                echo "Running 'Stable' $MINECRAFT_VERSION Build# $CURRENT_BUILD"
                updateConf "LATEST_BUILD" $BUILD_CHECK_DEF
                TEMP_BUILD=$BUILD_CHECK_DEF
                exit
        elif [ $TYPE == "default" ] && [ $BUILD_CHECK_DEF == "null" ]; then
                read -p "Didn't find Stable Version! Do you want to check 'experimental'? [yes | no] :" -r switch
                if [ $switch == "yes" ]; then
                        if [ $BUILD_CHECK_EXP != "null" ]; then
                                read -p "Found 'experimental'. Want to switch? [yes | no] :" -r switch2
                                if [ $switch2 == "yes" ]; then
                                        updateConf "TYPE" $experimental
                                        updateConf "LATEST_BUILD" $BUILD_CHECK_EXP
                                        TEMP_BUILD=$BUILD_CHECK_EXP
                                        echo "Switched to 'experimental'"
                                        exit
                                else
                                        exit
                                fi
                        elif [ $BUILD_CHECK_EXP == "null" ]; then
                                echo "Didn't find 'experimental'"
                                echo "Check what Version you entered"
                                exit
                        fi
                else
                        exit
                fi

        elif [ $TYPE == "experimental" ] && [ $BUILD_CHECK_DEF != "null" ]; then
                read -p "Found Stable Version! Do you want to switch? [yes | no] :" -r switch
                if [ $switch == "yes" ]; then
                        updateConf "TYPE" $default
                        updateConf "LATEST_BUILD" $BUILD_CHECK_DEF
                        TEMP_BUILD=$BUILD_CHECK_DEF
                        echo "Switched to 'stable'"
                else
                        exit
                fi

        elif [ $TYPE == "experimental" ] && [ $BUILD_CHECK_EXP != "null" ]; then
                echo "Released 'Experimental' $MINECRAFT_VERSION Build# $BUILD_CHECK_EXP"
                echo "Running 'Experimental' $MINECRAFT_VERSION Build# $CURRENT_BUILD"
                updateConf "LATEST_BUILD" $BUILD_CHECK_EXP
                TEMP_BUILD=$BUILD_CHECK_EXP
                exit
        fi)

}

download(){
        local BUILD_NAME=$(buildName)
        for i in "${!SERVER[@]}"
        do
                NAME="${SERVER[$i]}"
                DIR="${SERVER_DIR[$i]}"
                FULL_DIR="$DIR$NAME-$BUILD_NAME"
                wgetLink $FULL_DIR
        done

}

help(){
        echo "Help. List of available options."
        echo " -c,--check    Check what is the latest default/experimental version available"
        echo " -d,--download Donwload Latest Build to Server folder or local"
        echo " -e,--stop     Stop server and terminate screen session"
        echo " -h,--help     List all commands and provide information regarding the commands or script in general"
        echo " -l,--start    Start's screen session and launches PaperMC server"
        echo " -u,--update   Checks for latest Build and Updates Servers if update is availabel"
        echo " -v,--version  Current Version of the script"
}

info(){
        echo "Version '$MINECRAFT_VERSION'"
        echo "TYPE '$TYPE'"
        echo "Latest build '$LATEST_BUILD'"
}

start(){
        local BUILD_NAME=$(buildName)
        echo "-------- Starting Servers -----"
        for i in "${!SERVER[@]}"
        do
                NAME="${SERVER[$i]}"
                DIR="${SERVER_DIR[$i]}"
                FULL="$NAME-$PROJECT-$MINECRAFT_VERSION-$CURRENT_BUILD.jar"
                screen -dmS $NAME
                screen -S $NAME -X stuff 'cd '$DIR'\n'
                screen -S $NAME -X stuff 'java -jar '$FULL'\n'
                echo "$NAME Started"
        done
}

stop(){
        local BUILD_NAME=$(buildName)
        echo "-------- Stopping Servers -----"
        for i in "${!SERVER[@]}"
        do
                NAME="${SERVER[$i]}"
                screen -S $NAME -X stuff 'stop\n'
                PID=$(getPID $NAME)
                tail --pid=$PID -f /dev/null
                screen -S $NAME -X stuff 'exit\n'
                echo "$NAME Stopped"
        done
}

update(){
        if upToDate; then
                echo "Up to date."
                exit
        else
                echo "Starting Update Process..."
                local BUILD_NAME=$(buildName)
                #Announce the UPDATE
                echo "-------- Update Notify --------"
                for i in "${!SERVER[@]}"
                do
                        echo "Notified ${SERVER[$i]}"
                        NAME="${SERVER[$i]}"
                        screen -S $NAME -X stuff 'say SERVER WILL BE UPDATED IN 5 MINUTES - PLEASE DISCONNECT\n'
                done
                echo "-------- Waiting 5m -----------"
                sleep 5m
                #Disconnect
                echo "-------- Kick Users -----------"
                for i in "${!SERVER[@]}"
                do
                        echo "Kicked Users at ${SERVER[$i]}"
                        NAME="${SERVER[$i]}"
                        screen -S $NAME -X stuff 'kick @a\n'
                        sleep 2
                        echo "Shutting Down ${SERVER[$i]}"
                        screen -S $NAME -X stuff 'stop\n'
                        PID=$(getPID $NAME)
                        tail --pid=$PID -f /dev/null
                        echo "${SERVER[$i]} STOPPED"
                done
                #Update and Start
                echo "-------- Downloading Update ---"
                for i in "${!SERVER[@]}"
                do
                        NAME="${SERVER[$i]}"
                        DIR="${SERVER_DIR[$i]}"
                        FULL_DIR="$DIR$NAME-$BUILD_NAME"
                        wgetLink $FULL_DIR
                        sleep 20
                        echo "Start ${SERVER[$i]}"
                        screen -S $NAME -X stuff 'cd '$DIR'\n'
                        screen -S $NAME -X stuff 'java -jar '$FULL'\n'
                done
                updateConf "CURRENT_BUILD" $LATEST_BUILD
        fi
}

test(){
        local BUILD_NAME=$(buildName)
        echo $BUILD_NAME

        getPID "survival"
}

version(){
        echo "$VERSION"
}

get_opts $*
