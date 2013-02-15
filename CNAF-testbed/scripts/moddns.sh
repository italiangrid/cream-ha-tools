#!/bin/sh
#
# Batch or single insert/delete of pre-configured hosts in the DNS server for 
# the HA testbed
# Andrea Caltroni (andrea.caltroni@pd.infn.it) - v2.0 - 2013-02-14

# ---[ Configuration start ]----------------------------------------------------
# The DNS server
SERVER=''
# The DNS zone
ZONE=''
# The CE alias for the cluster
CE_ALIAS=''
# The Time To Live parameter (e.g. 86400)
TTL='86400'
# the class (A, etc)
CLASS='A'
# SECRET allows execution from any host. Keep secret!!!
SECRET=''

# List of the IPs of the cluster (add/delete as needed)
# ------------------------------
CE_IPS[0]=''
CE_IPS[1]=''
CE_IPS[2]=''
CE_IPS[3]=''
# ------------------------------
# ---[ Configuration end ]----------------------------------------------------

CMD_ADD='add'
CMD_DEL='delete'

cmd=''
# Operate on all? 0 = TRUE
all=1
# Operate on 1 IP with "-m ip-position/ip"
host_ip=""

# ------------------------------------------------------------------------------

function usage() {
    echo "moddns ACTION RANGE"
    echo "  ACTION Options"
    echo "      -h = Help"
    echo "      -a = Add to DNS"
    echo "      -d = Delete from DNS"
    echo "  RANGE Options"
    echo "      -x = Act on all configured IPs (IPs stored in script)"
    echo "      -m ip_position = Act on given IP position"
    echo "      -m ip = Act on given IP"
    echo ""
    echo "      Configured IPs:"
    for (( i = 0 ; i < "${#CE_IPS[@]}" ; i++ )) do
        echo "      $i = ${CE_IPS[$i]}"
    done
    exit 0
}

# ------------------------------------------------------------------------------

# Checks if an IP is valid (in the list) or if an IP position can be converted
# into a valid IP and converts it.
#
# Param: an IP or an IP position
# Result: an IP in the global variable: host_ip
#
function resolveHostIp() {
    # if it contains a dot it's an IP
    if [[ "$1" == *"."* ]]; then
        for (( i = 0 ; i < "${#CE_IPS[@]}" ; i++ )) do
            if [[ "$1" == "${CE_IPS[$i]}" ]]; then
                host_ip="$1"
            fi
        done
        if [[ "${host_ip}" == "" ]]; then
            echo "Invalid IP. Try `basename $0` -h for more information."
            exit 1
        fi
    else
        # it's an IP position
        if [[ "$1" -gt -1 && "${1}" -lt "${#CE_IPS[@]}" ]]; then
            host_ip=${CE_IPS[$1]}
        else
            echo "Invalid IP position. Try `basename $0` -h for more information."
            exit 1
        fi
    fi
}

# ------------------------------------------------------------------------------

#Check to see if at least one argument was specified
if [ "$#" -lt 1 ]; then
    echo "You must specify at least 1 argument. Try \``basename $0`\` -h for more information."
    exit 1
fi

#Process the arguments
# moddns -h | (-a | -d) & (-x | -m (ip_position | ip))
while getopts  "hadxm:" flag
do
    case "$flag" in
        h) usage
           exit 0
           ;;
        a) cmd=${CMD_ADD}
           ;;
        d) cmd=${CMD_DEL}
           ;;
        x) all=0
           ;;
        m) resolveHostIp "${OPTARG}"
           ;;
        \?) usage
            ;;
    esac
done

echo "Starting $CMD operation..."

# Add to DNS
if [[ ${cmd} = ${CMD_ADD} ]]; then
    if [[ ${all} -eq 0 ]]; then
        echo "Adding all..."

        ceList=""
        for (( i = 0 ; i < "${#CE_IPS[@]}" ; i++ )) do
            ceList="${ceList}update ${cmd} ${CE_ALIAS}. ${TTL} ${CLASS} ${CE_IPS[$i]}
"
        done

        tmpfile=$(mktemp)
        cat >${tmpfile} <<END
server $SERVER
zone $ZONE

$ceList
show
send
END

        nsupdate -d -y "$SECRET" $tmpfile
        rm -f ${tmpfile}
        exit 0
    else
        echo "Adding ${host_ip}..."
        tmpfile=$(mktemp)
        cat >${tmpfile} <<END
server $SERVER
zone $ZONE

update ${cmd} ${CE_ALIAS}. ${TTL} ${CLASS} ${host_ip}
show
send
END
        nsupdate -d -y "$SECRET" $tmpfile
        rm -f ${tmpfile}
        exit 0
    fi
else
    # Delete from DNS
    if [[ ${cmd} = ${CMD_DEL} ]]; then
        if [[ ${all} -eq 0 ]]; then
            echo "Deleting all..."

            ceList=""
            for (( i = 0 ; i < "${#CE_IPS[@]}" ; i++ )) do
                ceList="${ceList}update ${cmd} ${CE_ALIAS}. ${TTL} ${CLASS} ${CE_IPS[$i]}
"
            done

            tmpfile=$(mktemp)
            cat >${tmpfile} <<END
server $SERVER
zone $ZONE

${ceList}
show
send
END
            nsupdate -d -y "$SECRET" $tmpfile
            rm -f ${tmpfile}
            exit 0
        else
            echo "Deleting ${host_ip}..."
            tmpfile=$(mktemp)
            cat >${tmpfile} <<END
server $SERVER
zone $ZONE

update ${cmd} ${CE_ALIAS}. ${TTL} ${CLASS} ${host_ip}
show
send
END
            nsupdate -d -y "$SECRET" $tmpfile
            rm -f ${tmpfile}
            exit 0
        fi
    else
        echo "Wrong arguments! Try `basename $0` -h for more information."
        usage;
        exit 0
    fi
fi

exit 0

