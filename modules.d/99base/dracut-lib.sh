getarg() {
    set +x
    local o line
    if [ -z "$CMDLINE" ]; then
	[ -e /etc/cmdline ] && read CMDLINE_ETC </etc/cmdline;
	read CMDLINE </proc/cmdline;
	CMDLINE="$CMDLINE $CMDLINE_ETC"
    fi
    for o in $CMDLINE; do
	[ "$o" = "$1" ] && return 0
	[ "${o%%=*}" = "${1%=}" ] && { echo ${o#*=}; setdebug; return 0; }
    done
    setdebug
    return 1
}

setdebug() {
    if [ -z "$RDDEBUG" ]; then
        if [ -e /proc/cmdline ]; then
            RDDEBUG=no
	    if getarg rdinitdebug; then
                RDDEBUG=yes 
            fi
        fi
    fi
    [ "$RDDEBUG" = "yes" ] && set -x 
}

setdebug

getargs() {
    set +x
    local o line found
    if [ -z "$CMDLINE" ]; then
	[ -e /etc/cmdline ] && read CMDLINE_ETC </etc/cmdline;
	read CMDLINE </proc/cmdline;
	CMDLINE="$CMDLINE $CMDLINE_ETC"
    fi
    for o in $CMDLINE; do
	[ "$o" = "$1" ] && return 0
	if [ "${o%%=*}" = "${1%=}" ]; then
	    echo -n "${o#*=} "; 
	    found=1;
	fi
    done
    [ -n "$found" ] && { setdebug; return 0;}
    setdebug
    return 1
}

source_all() {
    local f
    [ "$1" ] && [  -d "/$1" ] || return
    for f in "/$1"/*.sh; do [ -e "$f" ] && . "$f"; done
}

check_finished() {
    local f
    for f in /initqueue-finished/*.sh; do { [ -e "$f" ] && ( . "$f" ) ; } || return 1 ; done
    return 0
}

source_conf() {
    local f
    [ "$1" ] && [  -d "/$1" ] || return
    for f in "/$1"/*.conf; do [ -e "$f" ] && . "$f"; done
}

die() {
    {
        echo "<1>dracut: FATAL: $@";
        echo "<1>dracut: Refusing to continue";
    } > /dev/kmsg

    { 
        echo "dracut: FATAL: $@";
        echo "dracut: Refusing to continue";
    } >&2
    
    exit 1
}

warn() {
    echo "<4>dracut Warning: $@" > /dev/kmsg
    echo "dracut Warning: $@" >&2
}

info() {
    if [ -z "$DRACUT_QUIET" ]; then
	DRACUT_QUIET="no"
	getarg quiet && DRACUT_QUIET="yes"
	getarg rdinfo && DRACUT_QUIET="no"
    fi
    echo "<6>dracut: $@" > /dev/kmsg
    [ "$DRACUT_QUIET" != "yes" ] && \
	echo "dracut: $@" 
}

vinfo() {
    while read line; do 
        info $line;
    done
}

check_occurances() {
    # Count the number of times the character $ch occurs in $str
    # Return 0 if the count matches the expected number, 1 otherwise
    local str="$1"
    local ch="$2"
    local expected="$3"
    local count=0

    while [ "${str#*$ch}" != "${str}" ]; do
	str="${str#*$ch}"
	count=$(( $count + 1 ))
    done

    [ $count -eq $expected ]
}

incol2() {
    local dummy check;
    local file="$1";
    local str="$2";

    [ -z "$file" ] && return;
    [ -z "$str"  ] && return;

    while read dummy check restofline; do
	[ "$check" = "$str" ] && return 0
    done < $file
    return 1
}

udevsettle() {
    [ -z "$UDEVVERSION" ] && UDEVVERSION=$(udevadm --version)

    if [ $UDEVVERSION -ge 143 ]; then
        udevadm settle --exit-if-exists=/initqueue/work $settle_exit_if_exists
    else
        udevadm settle --timeout=30
    fi
}

udevproperty() {
    [ -z "$UDEVVERSION" ] && UDEVVERSION=$(udevadm --version)

    if [ $UDEVVERSION -ge 143 ]; then
	for i in "$@"; do udevadm control --property=$i; done
    else
	for i in "$@"; do udevadm control --env=$i; done
    fi
}


