#!/usr/bin/env sh
VERSION="0.3"
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
            -l|--start)
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
        a=$(curl -s https://fill.papermc.io/v3/projects/${PROJECT}/versions/${MINECRAFT_VERSION}/builds | \
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
        a=$(curl -s https://fill.papermc.io/v3/projects/${PROJECT}/versions/${MINECRAFT_VERSION}/builds | \
                jq '.builds | map(select(.channel == "'${TYPE}'") | .downloads | .application | .sha256) |.[-1]')
        b=${a#'"'}
        BUILD_SHA256=${b%'"'}
        echo $BUILD_SHA256
}

buildCheck(){
        BUILD=$(curl -s https://fill.papermc.io/v3/projects/${PROJECT}/versions/${MINECRAFT_VERSION}/builds | \
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
        LINK="https://fill.papermc.io/v3/projects/${PROJECT}/versions/${MINECRAFT_VERSION}/builds/$LATEST_BUILD/downloads/$BUILD_NAME"
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
# ------------------------------------

check(){
        # Fetch builds
        BUILDS_JSON=$(curl -s -H "User-Agent: $USER_AGENT" \
          "https://fill.papermc.io/v3/projects/${PROJECT}/versions/${VERSION}/builds")
        
        # Extract latest per channel
        LATEST_ALPHA=$(echo "$BUILDS_JSON" | jq '[.[] | select(.channel=="ALPHA")] | first | .id')
        LATEST_BETA=$(echo  "$BUILDS_JSON" | jq '[.[] | select(.channel=="BETA")]  | first | .id')
        LATEST_STABLE=$(echo "$BUILDS_JSON" | jq '[.[] | select(.channel=="STABLE")]| first | .id')
        
        echo "Current: $CURRENT_CHANNEL build $CURRENT_BUILD"
        echo "Latest:  alpha=$LATEST_ALPHA beta=$LATEST_BETA stable=$LATEST_STABLE"

        # ---------------------------
        # DETERMINE BEST CHANNEL
        # ---------------------------
        
        target_channel=""
        target_build=""
        
        if [[ "$LATEST_STABLE" != "null" ]]; then
            target_channel="STABLE"
            target_build="$LATEST_STABLE"
        
        elif [[ "$LATEST_BETA" != "null" ]]; then
            target_channel="BETA"
            target_build="$LATEST_BETA"
        
        elif [[ "$LATEST_ALPHA" != "null" ]]; then
            target_channel="ALPHA"
            target_build="$LATEST_ALPHA"
        fi
        
        # ---------------------------
        # DECIDE UPGRADE
        # ---------------------------
        
        upgrade_available=false
        
        if [[ -n "$target_build" && "$target_build" != "null" ]]; then
            if [[ "$CURRENT_BUILD" -lt "$target_build" ]]; then
                upgrade_available=true
            fi
        fi
        
        # ---------------------------
        # OUTPUT / ACTION
        # ---------------------------
        
        echo "Current: $CURRENT_CHANNEL build $CURRENT_BUILD"
        echo "Best available: $target_channel build $target_build"
        
        if [[ "$upgrade_available" == true ]]; then
            if [[ "$AUTO_UPGRADE" == "true" ]]; then
                echo "Auto-upgrading → $target_channel build $target_build"
                # perform update
            else
                echo "Upgrade available → $target_channel build $target_build"
                echo "Proceed? (y/n)"
                read -r ans
                [[ "$ans" == "y" ]] && echo "Updating..."
            fi
        else
            echo "✅ Already up to date"
        fi
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
        echo "test"
}

version(){
        echo "$VERSION"
}

get_opts $*
