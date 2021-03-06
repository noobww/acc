# Advanced Charging Controller Power Supply Logger
# Copyright (c) 2019-2020, VR25 (xda-developers)
# License: GPLv3+

gather_ps_data() {
  local target="" target2=""
  for target in $(ls -1 $1 | grep -Ev '^[0-9]|^block$|^dev$|^fs$|^ram$'); do
    if [ -f $1/$target ]; then
      echo $1/$target | grep -Ev 'logg|(/|_|-)log' | grep -Eq 'batt|charg|power_supply' && {
        echo $1/$target
        { cat -v $1/$target | sed 's#^#  #'; } 2>/dev/null
        echo
      }
    elif [ -d $1/$target ]; then
      for target2 in $(find $1/$target \( \( -type f -o -type d \) \
        -a \( -ipath '*batt*' -o -ipath '*charg*' -o -ipath '*power_supply*' \) \) \
        -print 2>/dev/null | grep -Ev 'logg|(/|_|-)log')
      do
        [ -f $target2 ] && {
          echo $target2
          { cat -v $target2 | sed 's#^#  #'; } 2>/dev/null
          echo
        }
      done
    fi
  done
}

# log
umask 0077
exec 2>/data/adb/${id}-data/logs/power-supply-logger.sh.log
set -x

{
  date
  echo accVerCode=$1
  echo
  echo
  cat /proc/version 2>/dev/null && {
    echo
    echo
  }
  getprop | grep product
  echo
  getprop | grep version
  echo
  echo
  gather_ps_data /sys
  echo
  gather_ps_data /proc
} > /sbin/.acc/acc-power_supply-$(getprop ro.product.device | grep .. || getprop ro.build.product).log

exit 0
