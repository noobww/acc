#!/system/bin/sh
# Advanced Charging Controller
# Copyright (c) 2017-2020, VR25 (xda-developers)
# License: GPLv3+


daemon_ctrl() {

  local isRunning=true pid=$$

  pid="$(pgrep -f '/ac(c|ca) (-|--)(test|[deft])|/accd\.sh' | sed /$pid/d)" || :

  [[ "$pid" == *[0-9]* ]] || isRunning=false

  case "${1-}" in

    start)
      if $isRunning; then
        print_already_running
        return 8
      else
        print_started
        /sbin/accd $config
        return 0
      fi
    ;;

    stop)
      if $isRunning; then
        set +euo pipefail
        echo "$pid" | xargs kill $2 2>/dev/null
        sleep 0.2
        pid=$$
        while [ -n "$(pgrep -f '/ac(c|ca) (-|--)(test|[deft])|/accd\.sh' | sed /$pid/d)" ]; do
          sleep 0.2
        done
        print_stopped
        return 0
      else
        print_not_running
        return 9
      fi
    ;;

    restart)
      if $isRunning; then
        print_restarted
      else
        print_started
      fi
      /sbin/accd $config
    ;;

    *)
      if $isRunning; then
        print_is_running "$accVer ($accVerCode)" "(PID $pid)"
        return 0
      else
        print_not_running
        return 9
      fi
    ;;
  esac
}


edit() {
  local file="$1"
  shift
  if [ -n "${1-}" ]; then
    eval "$@ $file"
  else
    ! ${verbose:-true} || {
      case $file in
        *.txt)
          if which nano > /dev/null; then
            print_quit CTRL-X
          else
            print_quit "[esc] :q [enter]" "[esc] :wq [enter]"
          fi
        ;;
        *.log|*.md|*.help)
          print_quit q
        ;;
      esac
      sleep 2
      echo
    }
    case $file in
     *.txt) nano -$ $file || vim $file || vi $file;;
     *.log|*.md|*.help) less $file;;
    esac 2>/dev/null
  fi
}


get_prop() { sed -n "s|^$1=||p" ${2:-$config}; }


test_charging_switch() {

  local failed=false switchDelay=7

  chmod u+w $1 ${4-} \
    && echo "${3//::/ }" > $1 \
    && echo "${6//::/ }" > ${4:-/dev/null} \
    && sleep $switchDelay

  ! not_charging && failed=true || {
    eval "${chargDisabledNotifCmd[@]-}"
    grep -iq 'not' $batt/status \
      && battIdleMode=true \
      || battIdleMode=false
  }

  if ! $failed && echo "${2//::/ }" > $1 \
    && echo "${5//::/ }" > ${4:-/dev/null} \
    && sleep $switchDelay && ! not_charging && eval "${chargEnabledNotifCmd[@]-}"
  then
    print_switch_works "$@"
    echo "- battIdleMode=$battIdleMode"
    return 0
  else
    print_switch_fails "$@"
    { echo "${2//::/ }" > $1
    echo "${5//::/ }" > ${4:-/dev/null}; } 2>/dev/null
    return 1
  fi
}


exxit() {
  local exitCode=$?
  set +euxo pipefail 2>/dev/null
  ! ${noEcho:-false} && ${verbose:-true} && echo
  [[ $exitCode == [05689] ]] || {
    [[ $exitCode == [127] || $exitCode == 10 ]] && {
      logf --export
      eval "${errorAlertCmd[@]-}"
    }
    echo
  }
  rm /dev/.acc-config 2>/dev/null
  exit $exitCode
}


! ${verbose:-true} || echo
isAccd=false
modPath=/sbin/.acc/acc
defaultConfig=$modPath/default-config.txt

# load generic functions
. $modPath/logf.sh
. $modPath/misc-functions.sh

log=$TMPDIR/acc-${device}.log


# verbose
if ${verbose:-true} && [[ "${1-}" != *-w* ]]; then
    touch $log
    [ $(du -m $log | cut -f 1) -ge 2 ] && : > $log
    echo "###$(date)###" >> $log
    echo "versionCode=$(sed -n s/versionCode=//p $modPath/module.prop 2>/dev/null)" >> $log
    set -x 2>>$log
fi


accVer=$(get_prop version $modPath/module.prop)
accVerCode=$(get_prop versionCode $modPath/module.prop)

unset -f get_prop


misc_stuff "${1-}"
[[ "${1-}" != */* ]] || shift
config__=$config


# reset broken/obsolete config
(set +x; . $config) > /dev/null 2>&1 || cp -f $modPath/default-config.txt $config

. $config


# load default language (English)
. $modPath/strings.sh

# load translations
if ${verbose:-true} && [ -f $modPath/translations/$language/strings.sh ]; then
  . $modPath/translations/$language/strings.sh
fi
grep -q .. $modPath/translations/$language/README.md 2>/dev/null \
  && readMe=$modPath/translations/$language/README.md \
  || readMe=${config%/*}/info/README.md


# aliases/shortcuts
# daemon_ctrl status (acc -D|--daemon): "accd,"
# daemon_ctrl stop (acc -D|--daemon stop): "accd."
[[ $0 != *accd* ]] || {
  case $0 in
    *accd.) daemon_ctrl stop;;
    *) daemon_ctrl;;
  esac
  exit $?
}


case "${1-}" in

  "")
    . $modPath/wizard.sh
    wizard
  ;;

  [0-9]*)
    capacity[2]=$2
    capacity[3]=$1
    . $modPath/write-config.sh
  ;;

  -c|--config)
    shift; edit $config "$@"
  ;;

  -d|--disable)
    shift
    print_m_mode
    ! daemon_ctrl stop > /dev/null || print_stopped
    disable_charging "$@"
  ;;

  -D|--daemon)
    shift; daemon_ctrl "$@"
  ;;

  -e|--enable)
    shift
    print_m_mode
    ! daemon_ctrl stop > /dev/null || print_stopped
    enable_charging "$@"
  ;;

  -f|--force|--full)
    daemon_ctrl stop > /dev/null && daemonWasUp=true || daemonWasUp=false
    print_charging_enabled_until ${2:-100}%
    (enable_charging ${2:-100}% noap
    ! $daemonWasUp || /sbin/accd $config &) > /dev/null 2>&1 &
  ;;

  -F|--flash)
    shift
    set +euxo pipefail 2>/dev/null
    trap - EXIT
    $modPath/flash-zips.sh "$@"
  ;;


  -i|--info)

    dsys="$(dumpsys battery)"

    { if [[ "$dsys" == *reset* ]] > /dev/null; then
      status=$(echo "$dsys" | sed -n 's/^  status: //p')
      level=$(echo "$dsys" | sed -n 's/^  level: //p')
      powered=$(echo "$dsys" | grep ' powered: true' > /dev/null && echo true || echo false)
      dumpsys battery reset
      dumpsys battery
      dumpsys battery set status $status
      dumpsys battery set level $level
      if $powered; then
        dumpsys battery set ac 1
      else
        dumpsys battery unplug
      fi
    else
      echo "$dsys"
    fi \
      | grep -Ei "${2-.*}" \
      | sed -e '1s/.*/dumpsys battery/' && echo; } || :

    . $modPath/batt-info.sh
    echo "/sys/class/power_supply/$batt/uevent"
    batt_info "${2-}" | sed 's/^/  /'
  ;;


  -la)
    shift
    logf --acc "$@"
  ;;

  -le)
    logf --export
  ;;

  -l|--log)
    shift
    logf "$@"
  ;;

  -T|--logtail)
    ! ${verbose:-true} || {
      print_quit CTRL-C
      sleep 1.5
    }
    tail -F $TMPDIR/accd-*.log
  ;;

  -r|--readme)
    shift; edit $readMe "$@"
  ;;

  -R|--resetbs)
    dumpsys batterystats --reset || :
    rm /data/system/batterystats* 2>/dev/null || :
  ;;

  -s|--set)
    shift
    . $modPath/set-prop.sh
    set_prop "$@"
  ;;


  -t|--test)

    shift
    print_unplugged
    daemon_ctrl stop > /dev/null && daemonWasUp=true || daemonWasUp=false
    cp $config /dev/.acc-config
    config=/dev/.acc-config
    forceVibrations=true
    exec 3>&1

    set +eo pipefail 2>/dev/null
    trap '$daemonWasUp && /sbin/accd $config__' EXIT

    not_charging && enable_charging > /dev/null
    not_charging && {
      (print_wait_plug
      while not_charging; do
        sleep 1
        set +x
      done)
    }

    print_wait

    case "${2-}" in
      "")
        exitCode=10
        while read chargingSwitch; do
          [ -f "$(echo "$chargingSwitch" | cut -d ' ' -f 1)" ] && {
            echo
            test_charging_switch $chargingSwitch
          }
          [ $? -eq 0 ] && exitCode=0
        done < ${1-$TMPDIR/ch-switches}
        echo
      ;;
      *)
        test_charging_switch "$@"
      ;;
    esac

    : ${exitCode=$?}
    exit $exitCode
  ;;


  -u|--upgrade)
    shift
    local reference=""

    case "$@" in
      *beta*|*dev*|*rc\ *|*\ rc*)
        reference=dev
      ;;
      *master*|*stable*)
        reference=master
      ;;
      *)
        grep -Eq '^version=.*-(beta|rc)' $modPath/module.prop \
          && reference=dev \
          || reference=master
      ;;
    esac

    case "$@" in
      *--insecure*|*-k*) insecure=--insecure;;
      *) insecure=;;
    esac

    curl $insecure -Lo $TMPDIR/install-online.sh https://raw.githubusercontent.com/VR-25/acc/$reference/install-online.sh
    trap - EXIT
    set +euo pipefail 2>/dev/null
    installDir=$(readlink -f $modPath)
    installDir=${installDir%/*}
    . $TMPDIR/install-online.sh "$@" %$installDir% $reference
  ;;

  -U|--uninstall)
    set +euo pipefail 2>/dev/null
    $modPath/uninstall.sh
  ;;

  -v|--version)
    echo "$accVer ($accVerCode)"
  ;;

  -w*|--watch*)
    sleepSeconds=${1#*h}
    sleepSeconds=${sleepSeconds#*w}
    : ${sleepSeconds:=3}
    . $modPath/batt-info.sh
    print_quit CTRL-C
    sleep 1.5
    while :; do
      clear
      batt_info "${2-}"
      sleep $sleepSeconds
      set +x
    done
  ;;

  *)
    shift
    . $modPath/print-help.sh
    print_help_
  ;;

esac

exit 0
