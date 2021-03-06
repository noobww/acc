apply_on_boot() {

  local entry="" file="" value="" default="" arg=${1:-value} exitCmd=false force=false

  [ ${2:-x} != force ] || force=true

  [[ "${applyOnBoot[@]-}${maxChargingVoltage[@]-}" != *--exit* ]] || exitCmd=true

  for entry in "${applyOnBoot[@]-}" "${maxChargingVoltage[@]-}"; do
    [ "$entry" != --exit ] || continue
    set -- ${entry//::/ }
    file=${1-}
    value=${2-}
    { $exitCmd && ! $force; } && default=${2-} || default=${3:-${2-}}
    [ -f "$file" ] && chmod u+w $file && run3x "echo \$$arg > $file" || :
  done

  $exitCmd && [ $arg == value ] && exit 0 || :
}


apply_on_plug() {
  local entry="" file="" value="" default="" arg=${1:-value}
  for entry in "${applyOnPlug[@]-}" "${maxChargingCurrent[@]-}"; do
    set -- ${entry//::/ }
    file=${1-}
    value=${2-}
    default=${3:-${2-}}
    [ -f "$file" ] && chmod u+w $file && run3x "echo \$$arg > $file" || :
  done
}


cycle_switches() {

  local on="" off=""

  while read -A chargingSwitch; do

    [ ! -f ${chargingSwitch[0]} ] || {

      # toggle primary switch
      on="${chargingSwitch[1]//::/ }"
      off="${chargingSwitch[2]//::/ }"
      chmod u+w ${chargingSwitch[0]} \
        && run3x "echo \$$1 > ${chargingSwitch[0]}" \
        || continue

      # toggle secondary switch
      [ ! -f "${chargingSwitch[3]-}" ] || {
        on="${chargingSwitch[4]//::/ }"
        off="${chargingSwitch[5]//::/ }"
        chmod u+w ${chargingSwitch[3]} \
          && run3x "echo \$$1 > ${chargingSwitch[3]}" || :
      }

      [ "$1" != off ] || {
        not_charging ${2-} || {
          sleep $switchDelay
          # find a working switchDelay
          while ! not_charging ${2-}; do
            switchDelay=$(( ${switchDelay%.?} + 2 ))
            sleep $switchDelay
            [ $switchDelay -lt 7 ] || break
          done
        }

        if ! not_charging ${2-}; then
          # reset switch/group that fails to disable charging
          run3x "echo ${chargingSwitch[1]//::/ } > ${chargingSwitch[0]} || :;
            echo ${chargingSwitch[4]//::/ } > ${chargingSwitch[3]:-/dev/null} || :" 2>/dev/null
          switchDelay=1.5
        else
          # enforce working charging switch(es) and switchDelay
          . $modPath/write-config.sh
          break
        fi
      }
    }
  done < $TMPDIR/ch-switches
}


cycle_switches_off() {
  ! $prioritizeBattIdleMode || cycle_switches off not
  not_charging || cycle_switches off
}


disable_charging() {

  if $isAccd; then
    ! not_charging || return 0
  else
    apply_on_boot default
    apply_on_plug default
  fi

  if [[ "${chargingSwitch[0]-}" == */* ]]; then
    if [ -f ${chargingSwitch[0]} ]; then
      # toggle primary switch
      if chmod u+w ${chargingSwitch[0]} && run3x "echo ${chargingSwitch[2]//::/ } > ${chargingSwitch[0]}"; then
        [ ! -f "${chargingSwitch[3]-}" ] || {
          # toggle secondary switch
          chmod u+w ${chargingSwitch[3]} && run3x "echo ${chargingSwitch[5]//::/ } > ${chargingSwitch[3]}" || {
            $isAccd || print_switch_fails
            unset_switch
            cycle_switches_off
          }
        }
        not_charging || sleep ${switchDelay}
        not_charging || {
          unset_switch
          cycle_switches_off
        }
      else
        $isAccd || print_switch_fails
        unset_switch
        cycle_switches_off
      fi
    else
      $isAccd || print_invalid_switch
      unset_switch
      cycle_switches_off
    fi
  else
    cycle_switches_off
  fi

  if not_charging; then
    # if maxTemp is reached, keep charging paused for ${temperature[2]} seconds more
    ! $isAccd || {
      [ ! $(cat $batt/temp 2>/dev/null || cat $batt/batt_temp) -ge $(( ${temperature[1]} * 10 )) ] \
        || sleep ${temperature[2]}
    }
  else
    return 7 # total failure
  fi

  eval "${runCmdOnPause[@]-}"

  ${cooldown-false} || {
    eval "${chargDisabledNotifCmd[@]-}"
  }

  if [ -n "${1-}" ]; then
    case $1 in
      *%)
        print_charging_disabled_until $1
        echo
        (until [ $(( $(cat $batt/capacity) ${capacity[4]} )) -le ${1%\%} ]; do
          sleep ${loopDelay[1]}
          set +x
        done)
        enable_charging
      ;;
      *[hms])
        print_charging_disabled_for $1
        echo
        case $1 in
          *h) sleep $(( ${1%h} * 3600 ));;
          *m) sleep $(( ${1%m} * 60 ));;
          *s) sleep ${1%s};;
        esac
        enable_charging
      ;;
      *)
        print_charging_disabled
      ;;
    esac
  else
    $isAccd || print_charging_disabled
  fi
}


enable_charging() {

  ! $isAccd || not_charging || return 0

  if ! $ghostCharging || { $ghostCharging && [[ "$(cat */online)" == *1* ]]; }; then

    $isAccd || {
      [ "${2-}" == noap ] || apply_on_plug
    }

    chmod u+w ${chargingSwitch[0]-} ${chargingSwitch[3]-} 2>/dev/null \
      && run3x "echo ${chargingSwitch[1]-} > ${chargingSwitch[0]-}
        echo ${chargingSwitch[4]-} > ${chargingSwitch[3]:-/dev/null}" 2>/dev/null \
      || cycle_switches on

    ! not_charging || sleep ${switchDelay}

    # detect and block ghost charging
    if ! $ghostCharging && ! not_charging && [[ "$(cat */online)" != *1* ]]; then
      ghostCharging=true
      disable_charging > /dev/null
      touch $TMPDIR/.ghost-charging
      wait_plug
      return 0
    fi

    ${cooldown-false} || {
      not_charging || eval "${chargEnabledNotifCmd[@]-}"
    }

    if [ -n "${1-}" ]; then
      case $1 in
        *%)
          print_charging_enabled_until $1
          echo
          (until [ $(( $(cat $batt/capacity) ${capacity[4]} )) -ge ${1%\%} ]; do
            sleep ${loopDelay[1]}
            set +x
          done)
          disable_charging
        ;;
        *[hms])
          print_charging_enabled_for $1
          echo
          case $1 in
            *h) sleep $(( ${1%h} * 3600 ));;
            *m) sleep $(( ${1%m} * 60 ));;
            *s) sleep ${1%s};;
          esac
          disable_charging
        ;;
        *)
          print_charging_enabled
        ;;
      esac
    else
      $isAccd || print_charging_enabled
    fi

  else
    wait_plug
  fi
}


misc_stuff() {
  set -euo pipefail 2>/dev/null || :
  mkdir -p ${config%/*}
  [ -f $config ] || cp $modPath/default-config.txt $config

  # config backup
  ! [ -d /data/media/0/?ndroid -a $config -nt /data/media/0/.acc-config-backup.txt ] \
   || cp -f $config /data/media/0/.acc-config-backup.txt

  # custom config path
  case "${1-}" in
    */*)
      [ -f $1 ] || cp $config $1
      config=$1
    ;;
  esac
  unset -f misc_stuff
}


not_charging() { grep -Eiq "${1-dis|not}" $batt/status; }


print_header() {
  echo "Advanced Charging Controller $accVer ($accVerCode)
© 2017-2020, VR25 (patreon.com/vr25)
GPLv3+"
}


print_wait_plug() {
  print_unplugged
  print_quit CTRL-C
}


run3x() {
  local count=0
  while [ $count -lt 3 ]; do
    eval "$@"
    sleep 0.2
    count=$(( count +1 ))
  done
}


unset_switch() {
  chargingSwitch=()
  switchDelay=1.5
  . $modPath/write-config.sh
}


vibrate() {
  [ $1 != "-" -a -z "${noVibrations-}" ] || return 0
  local c=0
  while [ $c -lt $1 ]; do
    ${forceVibrations-false} && echo -en '\a' >&3 || echo -en '\a'
    sleep $2
    c=$(( c + 1 ))
  done
}


wait_plug() {
  $isAccd || {
    echo "(i) ghostCharging=true"
    print_wait_plug
  }
  (while [[ "$(cat */online)" != *1* ]]; do
    sleep ${loopDelay[1]}
    set +x
  done)
  enable_charging "$@"
}


# environment

umask 0077
modPath=/sbin/.acc/acc
export TMPDIR=${modPath%/*}
config=/data/adb/acc-data/config.txt
config_=$config

[ -f $TMPDIR/.ghost-charging ] \
  && ghostCharging=true \
  || ghostCharging=false

trap exxit EXIT

. $modPath/setup-busybox.sh

device=$(getprop ro.product.device | grep .. || getprop ro.build.product)

cd /sys/class/power_supply/

batt=$(echo *attery/capacity | cut -d ' ' -f 1 | sed 's|/capacity||')

[[ $(readlink -f $modPath) != *com.termux* ]] || {
  bin=$(su -c "which dumpsys")
  eval "dumpsys() { su -c $bin; }"
  unset bin
}
