#!/bin/bash


#SSHID=/home/admin/.ssh/id_ecdsa
#DDRUSER=sysadmin
#DDRHOST=ddve-01
#SSIDS=4075921287

usage () {
  echo
  echo Usage: $0 --all --sshid ssh_id_file --user DD_User [--ddr DD_Host] [--listonly] [--debug]
  echo
  echo Usage: $0 --all --client client_name --sshid ssh_id_file --user DD_User [--ddr DD_Host] [--listonly] [--debug]
  echo
  echo Usage: $0 --ssid save_set_id [--ssid save_set_id ...] --sshid ssh_id_file --user DD_User [--ddr DD_Host] [--listonly] [--debug]
  echo
  echo Usage: $0 -?\|-h\|--help 
  echo
  echo "--all                          Recall all backups for the client if --client is specified."
  echo "                               Otherwise recall all files for the Data Domain specified by --ddr."
  echo "                               Otherwise recall all files for all Data Domains if --ddr is not specified."
  echo "                                 NOTE: --all only works with out --ddr for DDBoost devices. CIFS or NFS"
  echo "                                       mounted devices require that --ddr be specified"
  echo "--ddr DD_Host                  Limit the scope to the Data Domain specified by DD_Host."
  echo "--listonly                     Only lists files to be recalled on the Data Domain. No recall occurs."
  echo "--client client_name           Specifies the name, as defined in Networker, of the client being recalled. "
  echo "--sshid ssh_id_file            Specifies the full path to the sshid file to use with Admin Access "
  echo "                               for the Data Domain"
  echo "                                 NOTE: It is required to specify the sshid file otherwise the "
  echo "                                       server may inspect a local one that requires a password. The "
  echo "                                       ssh ID file is the one generated for Admin Access to work on "
  echo "                                       the Data Domain. See the README.MD file for more details."
  echo "--ssid save_set_id             Recall a single backup based on the save set id number specified by"
  echo "                               save set id. --ssid may be specfied multiple times to recall more than"
  echo "                               one save set."
  echo "                                 NOTE: Consult the README.MD file for instructions on how to lookup "
  echo "                                       save set ids."
  echo "--user DD_User                 Specifies the name of the user on the Data Domain with which to"
  echo "                               execute commnads. This user must be an admin user."
  echo "-?\|-h\|--help                 Display this help message."
  echo
}

ALL=FALSE

while [ $# -gt 0 ]; do 
  case "$1" in
    --all)
      ALL=TRUE
      ;;
    --debug)
      DEBUG=Y
      ;;
    --ddr)
      DDRHOSTS="$2"
      shift
      ;;
    --listonly)
      LISTONLY=TRUE
      ;;
    --client)
      CLIENT="$2"
      shift
      ;;
    --sshid)
      SSHID="$2"
      shift
      ;;
    --ssid)
      SSIDS=$SSIDS" "$2
      shift
      ;;
    --user)
      DDRUSER="$2"
      shift
      ;;
    -?|-h|--help)
      usage
      exit
      ;; 
    *)
      echo "ERROR: $1 is not a valid option."
      usage
      exit 1
      ;;
  esac
  shift
done

if [ "$ALL" == "TRUE" ] && [ "$SSIDS" != "" ]; then
  echo
  echo ERROR: Conflicting options specified. --all and --ssid save_set_id not allowed in the same command. 
  usage
  exit 1
elif [ "$ALL" == "FALSE" ] && [[ "$SSIDS" == ""  || "$SSIDS" == " " ]]; then 
  echo
  echo ERROR: One of --all or --ssid save_set_id must be specified.
  usage
  exit 1
elif [ "$SSHID" == "" ]; then
  echo
  echo ERROR: --sshid ss_id_file must be specified
  usage
  exit 1
elif [ "$DDRUSER" == "" ]; then
  echo
  echo ERROR: --user DD_User must be specified
  usage
  exit 1
fi

if [ "$ALL" == "TRUE" ]; then
  echo About to recall all backups for a client or Data Domain\(s\).
  echo This operation may take significant time and space.
  echo It may also incur additional charges from public cloud providers.
  echo Are you sure you want to proceed? \(YES/[NO]\)
  read ANSWER
  if [ "$ANSWER" != "YES" ]; then
    echo Canceling...
    exit 2
  fi
fi

echo Searching for backup files to recall...

if [ "$ALL" == "TRUE" ] && [ "$CLIENT" != "" ]; then
  LONGSSIDS=($(mminfo -a -q client=$CLIENT -r 'ssid(60)'))
  RC=$?
  if [ "$DEBUG" == "Y" ]; then echo Error Code is: $RC; fi
  if [ $RC -gt 0 ]; then
    echo ERROR: The mminfo query field. Most likely client $CLIENT does not exist.
    exit 1
  fi
  if [ ${#LONGSSIDS[@]} -lt 1 ]; then
    echo No backup files to recall. All backup files may be on the Active tier.
    echo Exiting...
    exit 3
  fi
  echo About to recall all backups for client $CLIENT from ${#LONGSSIDS[@]} save sets.
  echo Are you really sure you want to proceed? \(YES/[NO]\)
  read ANSWER
  if [ "$ANSWER" != "YES" ]; then
    echo Canceling...
    exit 2
  fi
  if [ "$DDRHOSTS" == "" ] || [ "$DDRHOSTS" == " " ];then 
    VOLUMES=$(mminfo -q client=$CLIENT -r 'volume')
    for VOLUME in $VOLUMES; do 
      DDRHOSTS=$(echo "print type:NSR device; volume name: $VOLUME" | nsradmin -i - | grep "information" | awk -F \" '{print $2}' | awk -F \: '{print $1}')
    done
  fi
elif [ "$ALL" == "TRUE" ];then
  if [ "$DDRHOSTS" == "" ] || [ "$DDRHOSTS" == " " ];then 
    DDRHOSTS=$(echo "print type:NSR device; media type: Data Domain" | nsradmin -i - | grep "information" | awk -F \" '{print $2}' | awk -F \: '{print $1}' | sort | uniq)
  fi
  LONGSSIDS=()
  for DDRHOST in $DDRHOSTS; do 
    LONGSSIDS+=($(echo "print type:NSR device; media type: Data Domain" | nsradmin -i - | grep "information" | grep $DDRHOST | awk -F : '{print $3}' | awk -F \" '{print $1}'))
  done
  if [ ${#LONGSSIDS[@]} -lt 1 ]; then
    echo No backup files to recall. All backup files may be on the Active tier.
    echo Exiting...
    exit 3
  fi
  echo About to recall all backups for Data Domain $DDRHOST from ${#LONGSSIDS[@]} save sets.
  echo Are you really sure you want to proceed? \(YES/[NO]\)
  read ANSWER
  if [ "$ANSWER" != "YES" ]; then
    echo Canceling...
    exit 2
  fi
else
  LONGSSIDS=()
  for SSID in $SSIDS; do 
    LONGSSIDS+=($(mminfo -q ssid=$SSID -r 'ssid(60)'))
    RC=$?
    if [ "$DEBUG" == "Y" ]; then echo Error Code is: $RC; fi
    if [ $RC -gt 0 ]; then
      echo ERROR: The mminfo query failed. Most likely save set id $SSID does not exist.
      exit 1
    fi
  done  
  if  [[ "$DDRHOSTS" == "" || "$DDRHOSTS" == " " ]]; then
    for SSID in $LONGSSIDS; do
      for VOLUME in $(mminfo -q ssid=$SSID -r 'volume'); do
        DDRHOSTS=$DDRHOSTS" "$(echo "print type:NSR device; volume name: $VOLUME" | nsradmin -i - | grep "information" | awk -F \" '{print $2}' | awk -F \: '{print $1}')
      done
    done
  fi
fi


let REPEAT=1
DDRHOSTS=$(echo $DDRHOSTS | sort | uniq)
if [ "$DEBUG" == "Y" ]; then echo DDRHOSTS is $DDRHOSTS; fi
for DDRHOST in $DDRHOSTS; do
  if [ "$DEBUG" == "Y" ]; then echo REPEAT is $REPEAT; fi
  let REPEAT=1
  echo Operating on Data Domain $DDRHOST
  while [ $REPEAT -ne 0 ]; do 
    let REPEAT=0
    ALLFILES=($(ssh -i $SSHID $DDRUSER@$DDRHOST filesys report generate file-location | grep -v Active| awk '{$NF=""}1'))
    RC=$?
    if [ "$DEBUG" == "Y" ]; then echo Error Code is: $RC; fi
    if [ $RC -gt 0 ]; then
      echo ERROR: Unable to ssh to $DDRHOST using user $DDDRUSER with key $SSHID.
      echo "      Check credentials and try again."
      exit 1
    fi
    let NUMSSIDS=${#LONGSSIDS[@]}
    let CURRSSID=0
    FILES=()
    echo
    for SSID in ${LONGSSIDS[*]}; do
      let CURRSSID=$CURRSSID+1
      for FILE in ${ALLFILES[*]}; do
#        printf .
#          echo -n "Looking for save set: $SSID"; echo -en "\e[1A"  ; echo -e "\e[0K\r Looking for save set: $SSID"
        echo -en "\e[1A"  ; echo -e "\e[0K\r"; echo -n "Looking for save set $CURRSSID of $NUMSSIDS"
#        echo -n "Looking for save set $CURRSSID of $NUMSSIDS"; echo -en "\e[1A"  ; echo -e "\e[0K\r"
        FILES+=($(echo $FILE | grep $SSID))
      done
    done
    echo 
    if [ ${#FILES[@]} -lt 1 ]; then
      echo No backup files to recall. All backup files may be on the Active tier.
      echo Exiting...
      exit 3
    fi
    echo Listing or recalling ${#LONGSSIDS[@]} save sets from ${#FILES[@]} backup files.

    for ((FILE=0; FILE<${#FILES[@]}; FILE++)); do
      if [ "$LISTONLY" == "TRUE" ]; then
        echo "${FILES[$FILE]}"
      else
        let CURFILENUM=$FILE+1
        echo Recalling backup file $CURFILENUM of ${#FILES[@]}...
        ssh -i $SSHID $DDRUSER@$DDRHOST data-movement recall path "${FILES[$FILE]}"
      fi
      RC=$?
      if [ "$DEBUG" == "Y" ]; then echo Error Code is: $RC; fi
      if [ $RC -gt 0 ]; then 
        let REPEAT=$REPEAT+1
      fi
      if [ "$DEBUG" == "Y" ]; then echo REPEAT is: $REPEAT; fi
    done
    let STATUS=1
    while [ "$LISTONLY" != "TRUE" ] && [ $STATUS -gt 0 ]; do
      if [ $REPEAT -gt 0 ]; then
        echo $REPEAT files were not recalled. Any files not recalled will be tried again.
        break
      fi
      ssh -i $SSHID $DDRUSER@$DDRHOST data-movement status | tee /dev/tty | grep -q "No recall"
      let RC=$?
      if [ "$DEBUG" == "Y" ]; then echo Error Code is: $RC; fi
      if [ $REPEAT -gt 0 ]; then
        echo $REPEAT files were not recalled. Any files not recalled will be tried again.
        break
      fi
      if [ $RC -gt 0 ]; then
        echo Backup files are still recalling. Waiting 5 seconds...
        sleep 5
      else 
        let STATUS=0
      fi
    done
  done 
done


