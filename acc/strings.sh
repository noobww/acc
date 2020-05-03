# 简体中文 (zh-cs)

print_already_running() {
  echo "(i) acc守护进程已在运行中"
}

print_started() {
  echo "(i) acc守护进程已启动"
}

print_stopped() {
  echo "(i) acc守护进程已停止"
}

print_not_running() {
  echo "(i) acc守护进程没有运行"
}

print_restarted() {
  echo "(i) acc守护进程已重启"
}

print_is_running() {
  echo "(i) acc守护进程 $1 正在运行 $2"
}

print_config_reset() {
  echo "(i) 配置重置"
}

print_known_switches() {
  echo "(i) 已知充电开关"
}

print_switch_fails() {
  echo "(!) [${chargingSwitch[@]}] 不起作用"
}

print_invalid_switch() {
  echo "(!) 无效的充电开关 [${chargingSwitch[@]}]"
}

print_charging_disabled_until() {
  echo "(i) 已禁止充电，直到电量水平 <= $1"
}

print_charging_disabled_for() {
  echo "(i) 禁止充电 $1"
}

print_charging_disabled() {
  echo "(i) 已禁止充电"
}

print_charging_enabled_until() {
  echo "(i) 已允许充电，直到电量水平 >= $1"
}

print_charging_enabled_for() {
  echo "(i) 充电 $1"
}

print_charging_enabled() {
  echo "(i) 已允许充电"
}

print_unplugged() {
  echo "(!) 电池必须处于充电中才能继续……"
}

print_switch_works() {
  echo "(i) [$@] 有效"
}

print_switch_fails() {
  echo "(!) [$@] 不起作用"
}

print_no_ctrl_file() {
  echo "(!) 未找到任何控制文件"
}

print_not_found() {
  echo "(!) 未找到 $1"
}


print_help() {
  cat << EOF
Usage

  acc   Wizard

  accd   Start/restart accd

  accd.   Stop acc/daemon

  accd,   Print acc/daemon status (running or not)

  acc [pause_capacity resume_capacity]   e.g., acc 75 70

  acc [options] [args]   Refer to the list of options below

  /sbin/acca [options] [args]   acc optimized for front-ends

  accs   acc foreground service, works exactly as accd, but attached to the terminal by default

  A custom config path can be specified as first parameter.
  If the file doesn't exist, the current config is cloned.
    e.g.,
      acc /data/acc-night-config.txt --set pause_capacity=45 resume_capacity=43
      acc /data/acc-night-config.txt --set --current 500
      accd /data/acc-night-config.txt


Options

  -c|--config [editor] [editor_opts]   Edit config (default editor: nano/vim/vi)
    e.g.,
      acc -c (edit w/ nano/vim/vi)
      acc -c less
      acc -c cat

  -d|--disable [#%, #s, #m or #h (optional)]   Disable charging
    e.g.,
      acc -d 70% (do not recharge until capacity <= 70%)
      acc -d 1h (do not recharge until 1 hour has passed)

  -D|--daemon   Print daemon status, (and if running) version and PID
    e.g., acc -D (alias: "accd,")

  -D|--daemon [start|stop|restart]   Manage daemon
    e.g.,
      acc -D start (alias: accd)
      acc -D restart (alias: accd)
      accd -D stop (alias: "accd.")

  -e|--enable [#%, #s, #m or #h (optional)]   Enable charging
    e.g.,
      acc -e 75% (recharge to 75%)
      acc -e 30m (recharge for 30 minutes)

  -f|--force|--full [capacity]   Charge once to a given capacity (default: 100), without restrictions
    e.g.,
      acc -f 95 (charge to 95%)
      acc -f (charge to 100%)

  -F|--flash ["zip_file"]   Flash any zip files whose update-binary is a shell script
    e.g.,
      acc -F (lauches a zip flashing wizard)
      acc -F "file1" "file2" "fileN" ... (install multiple zips)
      acc -F "/sdcard/Download/Magisk-v20.0(20000).zip"

  -i|--info [case insentive egrep regex (default: ".")]   Show battery info
    e.g.,
      acc -i
      acc -i volt
      acc -i 'volt\|curr'

  -l|--log [-a|--acc] [editor] [editor_opts]   Print/edit accd log (default) or acc log (-a|--acc)
    e.g.,
      acc -l (same as acc -l less)
      acc -l rm
      acc -l -a cat
      acc -l grep ': ' (show explicit errors only)

  -la   Same as -l -a

  -l|--log -e|--export   Export all logs to /sdcard/acc-logs-\$deviceName.tar.gz
    e.g., acc -l -e

  -le   Same as -l -e

  -r|--readme [editor] [editor_opts]   Print/edit README.md
    e.g.,
      acc -r (same as acc -r less)
      acc -r cat

  -R|--resetbs   Reset battery stats
    e.g., acc -R

  -s|--set   Print current config
    e.g., acc -s

  -s|--set prop1=value "prop2=value1 value2"   Set [multiple] properties
    e.g.,
      acc -s charging_switch=
      acc -s pause_capacity=60 resume_capacity=55 (shortcuts: acc -s pc=60 rc=55, acc 60 55)
      acc -s "charging_switch=battery/charging_enabled 1 0" resume_capacity=55 pause_capacity=60
    Note: all properties have short aliases for faster typing; run "acc -c cat" to see these

  -s|--set c|--current [-]   Set/print/restore_default max charging current (range: 0-9999$(print_mA))
    e.g.,
      acc -s c (print)
      acc -s c 500 (set)
      acc -s c - (restore default)

  -s|--set l|--lang   Change language
    e.g., acc -s l

  -s|--set d|--print-default [egrep regex (default: ".")]   Print default config without blank lines
    e.g.,
      acc -s d (print entire defaul config)
      acc -s d cap (print only entries matching "cap")

  -s|--set p|--print [egrep regex (default: ".")]   Print current config without blank lines (refer to previous examples)

  -s|--set r|--reset   Restore default config
    e.g.,
      acc -s r
      rm /data/adb/acc-data/config.txt (failsafe)

  -s|--set s|charging_switch   Enforce a specific charging switch
    e.g., acc -s s

  -s|--set s:|chargingSwitch:   List known charging switches
    e.g., acc -s s:

  -s|--set v|--voltage [-] [--exit]   Set/print/restore_default max charging voltage (range: 3700-4200$(print_mV))
    e.g.,
      acc -s v (print)
      acc -s v 3920 (set)
      acc -s v - (restore default)
      acc -s v 3920 --exit (stop the daemon after applying settings)

  -t|--test [ctrl_file1 on off [ctrl_file2 on off]]   Test custom charging switches
    e.g.,
      acc -t battery/charging_enabled 1 0
      acc -t /proc/mtk_battery_cmd/current_cmd 0::0 0::1 /proc/mtk_battery_cmd/en_power_path 1 0 ("::" == " ")

  -t|--test [file]   Test charging switches from a file (default: $TMPDIR/charging-switches)
    This will also report whether "battery idle" mode is supported
    e.g.,
      acc -t (test known switches)
      acc -t /sdcard/experimental_switches.txt (test custom/foreign switches)

  -T|--logtail   Monitor accd log (tail -F)
    e.g., acc -T

  -u|--upgrade [-c|--changelog] [-f|--force] [-k|--insecure] [-n|--non-interactive]   Online upgrade/downgrade (requires curl)
    e.g.,
      acc -u beta (upgrade to the latest beta version)
      acc -u (latest version from the current branch)
      acc -u stable^1 -f (previous stable release)
      acc -u -f beta^2 (two dev versions below the latest beta)
      acc -u v2020.4.8-beta --force (force upgrade/downgrade to v2020.4.8-beta)
      acc -u -c -n (if update is available, prints version code (integer) and changelog link)
      acc -u -c (same as above, but with install prompt)

  -U|--uninstall   Completelly remove acc and AccA
    e.g., acc -U

  -v|--version   Print acc version and version code
    e.g., acc -v

  -w#|--watch#   Monitor battery uevent
    e.g.,
      acc -w (update info every 3 seconds)
      acc -w0.5 (update info every half a second)
      acc -w0 (no extra delay)


Exit Codes

  0. True/success
  1. False or general failure
  2. Incorrect command syntax
  3. Missing busybox binary
  4. Not running as root
  5. Update available ("--upgrade")
  6. No update available ("--upgrade")
  7. Couldn't disable charging
  8. Daemon already running ("--daemon start")
  9. Daemon not running ("--daemon" and "--daemon stop")
  10. "--test" failed
  11. Current (mA) out of range
  12. install.sh failed to initialize acc or start accd

  Logs are exported automatically ("--log --export") on exit codes 1, 2, 7 and 10.


Tips

  Commands can be chained for extended functionality.
    e.g., acc -e 30m && acc -d 6h && acc -e 85 && accd (recharge for 30 minutes, halt charging for 6 hours, recharge to 85% capacity and restart the daemon)

  Programming charging before going to sleep...
    acc 45 43 && acc -s c 500 && sleep \$((60*60*7)) && acc 80 75 && acc -s c -
      - "Keep battery capacity bouncing between 43-45% and limit charging current to 500 mA for 7 hours. Restore regular charging settings afterwards."
      - For convenience, this can be written to a file and ran as "sh /path/to/file".
      - If the kernel supports custom max charging voltage, it's best to use that feature over the above chain, like so: "acc -s v 3920 && sleep \$((60*60*7)) && acc -s v -".

  Run acc -r (or --readme) to see the full documentation.
EOF
}


print_exit() {
  echo "退出"
}

print_choice_prompt() {
  echo "(?) 选择并输入: "
}

print_auto() {
  echo "自动"
}

print_default() {
 echo "默认"
}

print_quit() {
  echo "(i) Press $1 to abort/quit"
  [ -z "${2-}" ] || echo "- 或 $2 以保存并退出"
}

print_curr_restored() {
  echo "(i) Default max charging current restored"
}

print_volt_restored() {
  echo "(i) Default max charging voltage restored"
}

print_read_curr() {
  echo "(i) Need to read default max charging current value(s) first"
}

print_curr_set() {
  echo "(i) Max charging current set to $1$(print_mA)"
}

print_volt_set() {
  echo "(i) Max charging voltage set to $1$(print_mV)"
}

print_wip() {
  echo "(i) Work in progress"
  echo "- Run acc -h or -r for help"
}

print_press_enter() {
  echo -n "(i) Press [enter] to continue..."
}

print_lang() {
  echo "Language"
}

print_doc() {
  echo "Documentation"
}

print_cmds() {
  echo "All commands"
}

print_re_start_daemon() {
  echo "Start/restart daemon"
}

print_stop_daemon() {
  echo "Stop daemon"
}

print_export_logs() {
  echo "Export logs"
}

print_1shot() {
  echo "Charge once to a given capacity (default: 100%), without restrictions"
}

print_charge_once() {
  echo "Charge once to #%"
}

print_mA() {
  echo " Milliamps"
}

print_mV() {
  echo " Millivolts"
}

print_uninstall() {
  echo "Uninstall"
}

print_edit() {
  echo "Edit $1"
}

print_flash_zips() {
  echo "Flash zips"
}

print_reset_bs() {
  echo "Reset battery stats"
}

print_test_cs() {
  echo "Test charging switches"
}

print_update() {
  echo "Check for update"
}

print_W() {
  echo " Watts"
}

print_V() {
  echo " Volts"
}

print_available() {
  echo "(i) $@ is available"
}

print_install_prompt() {
  echo -n "- Should I download and install it ([enter]: yes, CTRL-C: no)? "
}

print_no_update() {
  echo "(i) No update available"
}

print_A() {
  echo " Amps"
}

print_only() {
  echo "only"
}

print_m_mode() {
  echo "(i) Manual mode"
}

print_wait() {
  echo "(i) Alright, this may take a minute or so..."
}
