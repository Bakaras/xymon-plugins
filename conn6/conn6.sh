#!/bin/bash

# To enable IPv6 connectivity tests, add the "conn6" tag to bb-hosts.

    # XYMONNETWORK must be set.
    if [ -z ${XYMONNETWORK} ]
    then
        echo "No XYMONNETWORK set. Exit."
        exit 0
    fi
    if [ "${XYMONNETWORK}" = "CENTRAL" ]
    then
        # We are a central Server. Test all hosts with ntpd tag except other locations.
	HOSTLIST=$(${XYMONCLIENTHOME}/bin/xymongrep --net --test-untagged conn6 | ${CUT} -d ' ' -f 2)
    else
        # Wa are distributed test-agent. Test only hosts with my XYMONNETWORK tag.
	HOSTLIST=$(${XYMONCLIENTHOME}/bin/xymongrep --net conn6 | ${CUT} -d ' ' -f 2)
    fi
    if [ "${HOSTLIST}" = "" ]
    then
        echo "No hosts with conn6 tag found in ${BBHOME}/etc/bb-hosts"
        exit 0
    fi

#echo "${HOSTLIST}"

for HOST in ${HOSTLIST}; do
    #echo "conn6 ${HOST}"
    MSGDATE=$(date)
    PINGLINE=$(fping6 -e ${HOST})
    if [ "${PINGLINE}" = "" ]; then PINGLINE=$(fping6 -e ${HOST} 2>&1); fi
    #echo "${PINGLINE}"
    read dummy LINE <<< ${PINGLINE}
	TIME=0
	case $LINE in
		is?alive*) COLOR="green"
		TIME=`echo "$LINE" | perl -ne 'if (/\(([\d.]+) ?us/) { printf "%f", $1/1000000 }
						elsif (/\(([\d.]+) ?ms/) { printf "%f", $1/1000 }
						elsif (/\(([\d.]+)/) { print $1 }'`
		;;
		*not?known) COLOR="blue"
		;;
		*) COLOR="red"
		if ${XYMONCLIENTHOME}/bin/xymongrep conn6 | grep ${HOST} | grep -q dialup ; then
			COLOR="clear"
		fi
		;;
	esac

#echo "conn6 ${HOST} =${LINE}= ${COLOR}"
IP6=$(host -t AAAA ${HOST})
MSG=$(echo -e "status ${HOST}.conn6 ${COLOR} ${MSGDATE}\n${IP6}\n\n&${COLOR} ${HOST} ${LINE}\nSeconds: ${TIME}")

#echo "${MSG}"
echo "${MSG}" | ${XYMON} $BBDISP @

#	( echo "status $host.conn6 $COLOR `date`"#
#	  host -t AAAA $host
#	  echo
#	  echo "&$COLOR $host $line"
#	  echo "Seconds: $TIME"
#	) | ${XYMON} $BBDISP @


done

exit 0

${XYMONCLIENTHOME}/bin/xymongrep conn6 | cut -d ' ' -f 2 | fping6 -e | while read host line ; do
        echo "$host $line"
	TIME=0
	case $line in
		is?alive*) color="green"
		TIME=`echo "$line" | perl -ne 'if (/\(([\d.]+) ?us/) { printf "%f", $1/1000000 }
						elsif (/\(([\d.]+) ?ms/) { printf "%f", $1/1000 }
						elsif (/\(([\d.]+)/) { print $1 }'`
		;;
		*) color="red"
		if ${XYMONCLIENTHOME}/bin/xymongrep conn6 | grep $host | grep -q dialup ; then
			color="clear"
		fi
		;;
	esac
	( echo "status $host.conn6 $color `date`"
	  host -t AAAA $host
	  echo
	  echo "&$color $host $line"
	  echo "Seconds: $TIME"
	) | ${XYMON} $BBDISP @
done
