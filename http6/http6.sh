#!/bin/bash

    BBHTAG=ipv6-http
    COLUMN=http6

    LC_ALL=C
    LANG=C
    LANGUAGE=C

    CURLCMD="/usr/bin/curl"
    CURL="${CURLCMD} --config ${XYMONTMP}/curlrc"
    #
    # XYMONNETWORK must be set.
    if [ -z ${XYMONNETWORK} ]
    then
        echo "No XYMONNETWORK set. Exit."
        exit 0
    fi
    if [ "${XYMONNETWORK}" = "CENTRAL" ]
    then
        # We are a central Server. Test all hosts with ntpd tag except other locations.
        HOSTLIST=$(${BBHOME}/bin/xymongrep --net --test-untagged ${BBHTAG}*)
    else
        # Wa are distributed test-agent. Test only hosts with my XYMONNETWORK tag.
        HOSTLIST=$(${BBHOME}/bin/xymongrep --net ${BBHTAG}*)
    fi
    if [ "${HOSTLIST}" = "" ]
    then
        #echo "No hosts with ${BBHTAG} tag found in ${BBHOME}/etc/bb-hosts"
        exit 0
    fi

    if [ ! -x ${CURLCMD} ]
    then
	COLOR="clear"
        echo "${CURLCMD} not found"
        MSG=$(echo -e "\n${CURLCMD} not found\n")
        ${BB} ${BBDISP} "status ${MACHINE}.${COLUMN}-plugin ${COLOR} `date` ${MSG}"
        exit 0
    fi

    echo "user-agent = \"Mozilla/4.0 (compatible; MSIE 66.0; Windows NT 5.1; SV1)\"" > ${XYMONTMP}/curlrc

ORIGIFS=${IFS}; IFS=$'\n'
for LINE in ${HOSTLIST}
do
        IFS=${ORIGIFS}
        #echo "==${LINE}=="
	read HOSTIP MACHINE dummy1 TAG DIALUP dummy <<< $LINE

        MSG=""
        COLOR="green"
        TIMETOTAL=0
        #echo "HOSTIP=${HOSTIP} MACHINE=${MACHINE} TAG=${TAG} DIALUP=${DIALUP}"

        #echo "${TAG}"
        URL=${TAG#*ipv6-}
        #echo "${URL}"

	CURLOUTPUT=$(${CURL} --connect-timeout 10 -m 10 -6 -v -w 'time_total=%{time_total}\nhttp_code=%{http_code}\n' --url ${URL} 2>&1)
	EXITCODE=$?
	TRYINGSTRING=$(echo "${CURLOUTPUT}" | ${GREP} "Trying")

	case ${EXITCODE}
	in
	0)
	    # OK
	    COLOR="green"
	    TIMESTRING=$(echo "${CURLOUTPUT}" | ${GREP} "^time_total=")
	    TIMETOTAL=${TIMESTRING#*time_total=}
	    HTTP_CODE_STRING=$(echo "${CURLOUTPUT}" | ${GREP} "^http_code=")
	    HTTP_CODE=${HTTP_CODE_STRING#*http_code=}
	;;
	6)
	    # Couldn't resolve host.
	    COLOR="red"
	    MSG="&red Couldn't resolve host ${MACHINE}"
	;;
	7)
	    # Failed to connect to host.
	    COLOR="red"
	;;
	*)
	    COLOR="red"
	    # Other error
	;;
	esac
	

if [ "${TIMETOTAL}" = "" ]; then TIMETOTAL=0; fi
    
if [ "${COLOR}" = "green" ]
then
    MSG=$(echo -e "${MSG}\n${TRYINGSTRING}\nhttp_code=${HTTP_CODE}\n\n&${COLOR} ${MACHINE} OK\n\nSeconds: ${TIMETOTAL}")
else
    if [ "${DIALUP}" = "dialup" -o "${TAG:0:1}" = "?" ]
    then
        COLOR="clear"
	MSG=$(echo -e "${MSG}\n${TRYINGSTRING}\n\n&${COLOR} ${MACHINE} not OK = dialup or ? prefix host\n\nSeconds: ${TIMETOTAL}")
    else
	MSG=$(echo -e "${MSG}\n${TRYINGSTRING}\n\n&${COLOR} ${MACHINE} not OK\n\nSeconds: ${TIMETOTAL}")
    fi
fi

echo "${BBHTAG} ${URL} EXITCODE=${EXITCODE} ${COLOR}"

${BB} ${BBDISP} "status ${MACHINE}.${COLUMN} ${COLOR} `date`
${MSG}
"

#debug:
#echo "${MACHINE} = ${TAG} = ${COLOR}"
#echo "${BB} ${BBDISP} status ${MACHINE}.${COLUMN} ${COLOR}"
#echo "${MSG}"
done

