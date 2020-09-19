#!/bin/bash

TAG=smtp6
COLUMN=smtp6

LC_ALL=C
LANG=C
LANGUAGE=C

# newline
NL=$'\n'

function debug () {
    if [ "${DEBUG}" = "YES" ]; then echo "DEBUG: $@"; fi
}

function sendmsg {
 local MSG_TIME=$(${DATE})
 ${XYMON} ${XYMSRV} "status+50 ${HOST}.${COLUMN} ${COLOR} ${MSG_TIME} ${MSG}"
 debug "MSG:${NL}status+50 ${HOST}.${COLUMN} ${COLOR} ${MSG_TIME} ${MSG}"
}

# netcat
NCCMD="/bin/nc.openbsd"
NCTIMEOUT=15

# XYMONNETWORK must be set.
if [ -z ${XYMONNETWORK} ]; then debug "No XYMONNETWORK set. Exit."; exit 0; fi
# We are distributed test-agent. Test only hosts with my XYMONNETWORK tag.
HOSTLIST=$(${XYMONCLIENTHOME}/bin/xymongrep --net ${TAG})

if [ "${HOSTLIST}" = "" ]
then
    debug "No hosts with ${TAG} tag found in hosts.cfg"
    exit 0
fi

ORIGIFS=${IFS}; IFS=$'\n'
for LINE in ${HOSTLIST}
do
    IFS=${ORIGIFS}
    debug "=${LINE}="
    read HOSTIP HOST dummy1 TAG DIALUP dummy <<< ${LINE}

    MSG=""
    COLOR="clear"

    if [ ! -x ${NCCMD} ]
    then
     COLOR="blue"
     debug "IPv6 smtp check not possible : ${NCCMD} not found"
     MSG="${NL}&${COLOR} IPv6 smtp check not possible : ${NCCMD} not found${NL}${NL}"
     MSG+="please install netcat-openbsd${NL}${NL}"
     MSG+="CLIENTHOSTNAME=${CLIENTHOSTNAME}${NL}"
     MSG+="XYMONNETWORK=${XYMONNETWORK}${NL}"
     sendmsg
     continue
    fi

    TIMETOTAL=0
    debug "HOSTIP=${HOSTIP} HOST=${HOST} TAG=${TAG} DIALUP=${DIALUP}"
    echo -n "${HOST}... "

    STARTTIME=$(${DATE} +%s.%N)
    NCOUTPUT=$(echo "QUIT" | ${NCCMD} -v -6 -w ${NCTIMEOUT} ${HOST} 25 2>&1)
    EXITCODE=$?
    ENDTIME=$(${DATE} +%s.%N)
    RUNTIME=$(echo "${STARTTIME} ${ENDTIME}" | ${AWK} '{print $2 - $1}')
    debug "${ENDTIME} - ${STARTTIME} = ${RUNTIME}"

    debug "${NCOUTPUT}"
    debug "EXITCODE=${EXITCODE}"

    case ${EXITCODE}
    in
    0)
	# OK
	COLOR="green"
	MSG="${NL}&${COLOR} IPv6 SMTP onnn ${HOST} OK${NL}"
    ;;
    1)
	# error
	COLOR="red"
	MSG="${NL}&${COLOR} IPv6 SMTP on ${HOST} NOT OK${NL}"
    ;;
    *)
	# other error?
	COLOR="yellow"
	MSG="${NL}&${COLOR} error ${EXITCODE} while IPv6 connect to SMTP on ${HOST}${NL}${NL}"
    ;;
    esac

    MSG+="${NL}${NCOUTPUT}${NL}"

    if [ "${COLOR}" != "green" ]
    then
     if [ "${DIALUP}" = "dialup" -o "${TAG}" = "?${COLUMN}" ] ; then
      # if dialup host or ? prefix, set color to clear
      COLOR="clear"
      MSG+="&${COLOR} dialup host or test ? prefixed${NL}"
     fi
    fi

    MSG+="${NL}Seconds: ${RUNTIME}${NL}"
    sendmsg
    echo "${COLOR}"


    debug "."
done
exit 0
