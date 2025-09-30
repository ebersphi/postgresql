#!/bin/bash90
thisREVISION=250904
thisAUTHOR=PEB
#tab:3
set -e
set -u
THISPROC=$(basename "$0")
verbosity=terse
reloadConfig=false
untilDateTime=""
validate=false
tailOutput=false
untilOP=""
configDirFullPath=""
fileOP=""
defaultLogFile="${THISPROC}_$(date +%Y%m%dT%H%M%S).log"
logFileRetentionInDays=90
msgWarningCount=0  # incremented by printmsg WARNING
msgErrorCount=0   # incremented by printmsg ERROR
#---------------------------------------
write_log()
{
   [ -n "${logfile}" ] || return
   if ! [ -w "${logfile}" ]; then
      echo SQL*Plus command line history completion (Doc ID 460591.1)
}
#---------------------------------------
printmsg()
{  # 1: level  2: message 
   msgLevel="$1"
   shift
   msgText="${msgLevel}!$(date +%Y%m%dT%H%M%S)! $*"
   write_log "${msgText}"
   case ${msgLevel}:${verbosity} in 
      INFO:terse) return;
      ERROR:*)    msgErrorCount=$((msgErrorCount +1));;
      WARNING:*)  msgWarningCount=$((msgWarningCount +1));;
   esac
   echo "${msgText}"c
}
#---------------------------------------
fail()
{  # *: [ -# | --## ] [error message]
   if [ $# -eq 0 ]; then
      RC=1
   else
      case $1 in
         -[0-9]+) RC=${1#-}; shift ;;
         --[0-9]+) RC=${1#--}; shift ;;
         *) RC=1;;
      esac
   fi
   case "$#:$RC" in
      0:*) true;;
      *:0) printmsg NOTICE "$*" >&2 ;;
      *)   printmsg ERROR  "$*" >&2 ;;
   esac
   echo "Abandon (RC=$RC) with errors: ${msgErrorCount:-0}, warnings: ${msgWarningCount:-0}"
   exit "$RC"
}
#--------------------------------------- trap exit 
exit_handler()
{  # -
   err=$?
   trap "" EXIT INT QUIT TERM
   do_disable_files_if_any
   do_reload_as_needed
   rm -f /tmp/$$.* 2>/dev/null
   return $err
}
trap "exit_handler" EXIT INT TERM QUIT
#---------------------------------------
not_yet_done()
{  # *: what is not yet done
   echo "todo: $*"
}
#---------------------------------------
do_help()
{  # -
   cat << _HELP_

Manage configuration files located into postgresql.conf::include_dir. 
Reconfigure logging temporarly, for some duration, to capture more information.
Requires PGDATA to be set.

Syntax:
${THISPROC} [ -v ] -l | --list | --status | --cleanup | --reload
${THISPROC} [ -v ] --enable  filemask ... [ --reload | --validate ]
${THISPROC} [ -v ] --disable filemask ... [ --reload | --validate ]
${THISPROC} [ -v ] --delete  filemask ... [ --reload | --validate ]
${THISPROC} [ -v ] --<duration> -f filemask ... [ options ]
${THISPROC} [ -v ] --<time> -f filemask ... [ options ]
   -v or --verbose  shows more messages (INFO)
   --list     lists available configuration files
   --status   shows active vs pending parameters
   --cleanup  cleans up the configuration directory, does disable or enable files 
   --reload   does reload the pg server configuration, applying the enabled parameter files
   --enable   permanently enables the file, if manually disabled, --cleanup resets it
   --<duration> --[0-9]*h or --[0-9]*m  feed the logs for an amount of hours or minutes
   --<time>   --[00..12][00-59] 
options are --validate, --verbose | -v, --reload | --continue-trace , --tail [ -E '<ere>' ]
   --validate prevents any execution
   --verbose  also shows log file usage while tracking
   --continue-trace does not reload the config and continues logging with current parameters until next restart or reload command
   --tail     will tail -f the log file, but does not follow logfile rotation
   -E 'ere'   an extended regular expression applied to the --tail

NOTA: each config file may have several hard links
   f.conf           file is currently in use
   f.conf.disabled  file is not currently in use
   .f.conf.enable  file should be in use, takes precedence
   .f.conf.disable  file should be disabled (is temporarly active)
   Postgresql will read and process all files ending with .conf in the directory, in lexicographical order

_HELP_
}
#---------------------------------------
get_if_already_in_use()
{  # 1: message level
   # true: when already in use
   msgLevel="$1"
   alreadyInUse=false
   ps -ef -o pid= -o user= -o bsdstart= -o args= | grep "${THISPROC}" | grep -v "^$$[^0-9]" > /tmp/$$.pids
   while read -r psPID psUser psStart psCommand; do 
      printf "%s process %s by %s since %s : %s\n"  "${msgLevel}" "${psPID}" "${psUser}" "${psStart}" "${psCommand}"
   done < /tmp/$$.pids
   if [ -s /tmp/$$.pids ]; then
      alreadyInUse=true
   fi
   test "${alreadyInUse}" = true
}
#---------------------------------------
assert_pgconfig_access()
{  # fail if cannot access configuration files
   # fail if user is not 'root' or the owner of $PGDATA dir
   # quit if no include_dir directive in postgresql.conf
   # quit if no configuration files in the last include_dir found
   [ -n "${PGDATA:-}" ]  || fail -2 "PGDATA is not set"
   [ -r "${PGDATA}/postgresql.conf" ] || fail -2 "cannot read '${PGDATA}/postgresql.conf'"
   pgUser=$(cd "${PGDATA}" && ls -ld .|awk '{print $3}')
   currentUser=$(id -un)
   if [ -z "${pgUser}" ]; then
      fail -2 "Cannot get name of directory owner for '${PGDATA}'"
   fi
   if [ 0 = "$(id -u)" ]; then
      su "${pgUser}" 
   else
      fail -2 "current user is '${currentUser}', must be '${pgUser}' or 'root'"
   fi
   lastinclude_dir=$( grep -E '^include_dir[[:space:]]*=' "${PGDATA}/postgresql.conf" | tail -n 1 )
   [ -n "${lastinclude_dir}" ] || fail -0 "No include_dir directive in '${PGDATA}/postgresql.conf'"
   configDirFullPath="${lastinclude_dir%%#*}"
   [ "${configDirFullPath#/}" != "${configDirFullPath}" ] || configDirFullPath="${PGDATA}/${configDirFullPath}"
   [ -d "${configDirFullPath}" ] || fail -2 "Cannot access directory '${configDirFullPath}' specified by include_dir=${lastinclude_dir}"
   ( 
      cd "${configDirFullPath}" || fail -2 "Cannot change to directory '${configDirFullPath}'"
      nbConf=$(ls -1 ./.*.conf | wc -l | awk '{print $1}')
      nbDisabled=$(ls -1 ./*.conf.disabled | wc -l | awk '{print $1}')
      if [ "${nbconf}${nbDisabled}" = 00 ]; then
         fail -0 "No configuration files found in ${configDirFullPath}"
      fi
   )
}
#---------------------------------------
handle_always_enabled()
{  # 1: configFilename
   # true: .enable was found and .conf is there
   # false: otherwise  
   configFilename="$1"
   disabledFilename="$1.disabled"
   [ -e "./.${configFilename}.enable" ] || return
   printmsg NOTICE "File '${configFilename}' is always enabled"
   [ -e "./${configFilename}" ] || ln "./.${configFilename}.enable" "${configFilename}" 
   [ -e "./${configFilename}" ] || printmsg ERROR "Could not create '${configFilename}'"
   if [ -e "./${disabledFilename}" ]; then
      printmsg NOTICE "Removing obsolete file ${disabledFilename}"
      if ! unlink "./${disabledFilename}"; then
         printmsg SEVERE "Could not remove file '${disabledFilename}'"
      fi
      if [ -e "./.${disabledFilename%d}" ]; then # .*.conf.disable
         unlink "./.${disabledFilename%d}"
      fi
   fi
   test -e "./${configFilename}"
}
do_disable_file()
{  # 1: configFilename
   # true: .conf.disabled is there and  there is no .conf
   # false: otherwise  
   configFilename="$1"
   disabledFilename="$1.disabled"
   if [ ! -s "${configFilename}" ] \
   && [ ! -s "${disabledFilename}" ] \
   && [ ! -s "./.${configFilename}.disable" ] \
   && [ ! -s "./.${configFilename}.enable" ]; then
      printmsg ERROR "No .conf, no .conf.disabled files found for '${configFilename}'"
      return 1
   fi
   for doDisableFile in "${configFilename}" "./.${configFilename}.disable" "./.${configFilename}.enable"; do
      if [ ! -s "${disabledFilename}" ] && [ -s "${doDisableFile}" ] ]; then
         ln "${doDisableFile}" "${disabledFilename}"
      fi
   done
   if [ -s "${disabledFilename}" ]; then # cleanup work files
      for doDisableFile in "${configFilename}" "./.${configFilename}.disable" "./.${configFilename}.enable"; do
         if [ -e "${doDisableFile}" ]; then
            if ! unlink "${doDisableFile}"; then
               printmsg INFO "failed to unlink '${doDisableFile}'"
            fi
         fi
      done
   fi
   doDisableFile=0
   if ! [ -e "${disabledFilename}" ]; then
      printmsg ERROR "Could not create '${disabledFilename}'"
      doDisableFile=1
   fi
   if [ -e "${configFilename}" ]; then
      printmsg ERROR "Could not remove '${configFilename}'"
      doDisableFile=1
   fi
   return $doDisableFile
}
#---------------------------------------
do_disable_files_if_any()
{  # -
   if ${validate}; then
      echo "NOTICE! reset/disabling of configuration files prevented by --validate"
      return
   fi
   cd "${configDirFullPath}" || fail -5 "Cannot cleanup '${configDirFullPath}' on exit, use ${THISPROC} --cleanup"
    ls -1 .*.conf.disable | cut -c2-260 > /tmp/$$.fileToDisable
	for f in /tmp/$$.fileToDisable; do
      configFilename="${f%.disable}"
      if handle_always_enabled "${configFilename}"; then
         continue
      fi
      do_disable_file "${configFilename}"
	done
   cd /tmp
}
#---------------------------------------
do_reload_as_needed()
{  # -
   ${reloadConfig:-false} || return
   if ${validate}; then
      printmsg NOTICE "configuration reload prevented by --validate"
      return
   fi
   not_yet_done reload pg config
}
#---------------------------------------
do_cleanup()
{
   get_if_already_in_use ERROR
   assert_pgconfig_access
   if ${alreadyInUse}; then
      validate=true
      printmsg NOTICE "Validate configuration instead of cleanup"
   fi
   reset_config_files_state
}
#---------------------------------------
enable_file()
{  # 1: filename.conf
   fconf="$1"
   if [ ! -e "${fconf}" ]; then
      # we collect all files, most recent first, should all be links, but you never now 
      ls -ltr ./${fconf}.disabled ./.${fconf}.enable ./.${fconf}.disable > /tmp/$$.processorder
      for flink in /tmp/$$.processorder; do
         if [ -s "${fconf}" ]; then
            break
         fi
         if [ -s "$flink" ]; then
            ln "$flink" "${fconf}"
         fi
      done
   fi
   if [ -e "${fconf}" ]; then
      [ -e ".${fconf}.enable" ] || ln "${fconf}" ".${fconf}.enable"
      [ ! -e "${fconf}.disabled" ] || unlink "${fconf}.disabled"
      [ ! -e ".${fconf}.disable" ] || unlink ".${fconf}.disable"
   fi
   [ -e "${fconf}" ]            || printmsg ERROR "Enabling: ${fconf} failed to create .conf"
   [ -e ".${fconf}.enable" ]    || printmsg ERROR "Enabling: ${fconf} failed to create .enable link"
   [ ! -e "${fconf}.disabled" ] || printmsg ERROR "Enabling: ${fconf} failed to remove .disabled link"
   [ ! -e ".${fconf}.disable" ] || printmsg ERROR "Enabling: ${fconf} failed to remove .disable link"
}
#---------------------------------------
disable_file()
{  # 1: filename.conf
   # 
   fconf="$1"
   # we collect all files, most recent first, should all be links, but you never now 
   ls -ltr ./${fconf} ./${fconf}.disabled ./.${fconf}.enable ./.${fconf}.disable > /tmp/$$.processorder
   for flink in /tmp/$$.processorder; do
         if [ -s "${fconf}.disabled" ]; then
            break
         fi
         if [ -s "$flink" ]; then
            ln "$flink" "${fconf}.disabled"
         fi
      done
   fi
   if [ -e "${fconf}.disabled" ]; then
      [ ! -e "${fconf}" ]          || unlink "${fconf}"
      [ ! -e ".${fconf}.enable" ]  || unlink ".${fconf}.enable"
      [ ! -e ".${fconf}.disable" ] || unlink ".${fconf}.disable"
   fi
   [ -e "${fconf}.disabled" ]      || printmsg ERROR "Disabling: ${filename} failed to create .conf.disabled"
   [ ! -e "${fconf}" ]             || printmsg ERROR "Disabling: ${filename} failed to remove .conf link"
   [ ! -e "${filename}.disabled" ] || printmsg ERROR "Disabling: ${filename} failed to remove .disabled link"
   [ ! -e ".${filename}.disable" ] || printmsg ERROR "Disabling: ${filename} failed to remove .disable link"
}
#---------------------------------------
reset_config_files_state()
{  # -
   # enable or disable accordingly
   # .enable has precedence, resolve any pending .disable
   # remove unneeded links
   cd "${configDirFullPath}"  || fail -5 "Cannot change to directory '${configDirFullPath}'"
   ls -1 ./.*.conf.enable  | cut -c2-260 > /tmp/$$.shouldBeEnabled
   ls -1 ./.*.conf.disable | cut -c2-260 > /tmp/$$.shouldBeDisabled
   for toDisable in /tmp/$$.shouldBeDisabled; do
      filename="${toDisable%.disable}"
      if grep -F "${filename}.enable" /tmp/$$.shouldBeEnabled; then
         printmsg INFO "Discarding: disable operation for enabled file ${filename}"
         handle_always_enabled "${filename}"
      else
         do_disable_file "${filename}"
      fi
   done
   for toEnable in /tmp/$$.shouldBeEnabled; do
      filename="${toDisable%.enable}"
      handle_always_enabled  "${filename}"
   done
   cd /tmp
}
#---------------------------------------
do_list()
{
   get_if_already_in_use NOTICE
   assert_pgconfig_access
   show_configuration
   show_config_files list
}
#---------------------------------------
do_show_status()
{  # -
   get_if_already_in_use NOTICE
   assert_pgconfig_access
   show_configuration
   show_config_files enabled
}
#---------------------------------------
show_configuration()
{  # -
   not_yet_done show_configuration
}
#---------------------------------------
show_config_files()
{  # -
   cd "${configDirFullPath}"
   ls -1 ./*.conf ./*.conf.disabled ./.*.enable ./.*.disable | awk '
{ $1=substr($1,3); print NR,$0;}   
/^[.].*.enable/ { f=substr($1,2,length($1)-length("..enable")); 
   defaultstate[f]="enabled";
   if(""==state[f])state[f]="inactive"; 
   files[f]=f; next;}
/^[.].*.disable/ { f=substr($1,2,length($1)-length("..disable")); 
   if(""==defaultstate[f]) defaultstate[f]="disabled";
   if(""==state[f]) state[f]="inactive"; 
   files[f]=f; next;}
/.*.disabled/ { f=substr($1,1,length($1)-length(".disabled")); 
   if(""==defaultstate[f]) defaultstate[f]="disabled";
   if(""==state[f])state[f]="-"; 
   files[f]=f; next;}
/.*.conf/ { f=$1; state[f]="in use"; files[f]=f; next;}
{ print "ERRROR! file \"" $1 "\" not expected"}
 END{ 
   print ""
   printf "%8s %9s %s\n", "default", "currently", "file"
   printf "%8s %9s %s\n", "--------", "---------", "------------------------------------------------"
   n=asort(files)
   for(i=1; i <=n; i++) {
      f=files[i];
      printf "%8s %8s  %s\n", defaultstate[f], state[f] ,f;
   }
 }  '

}
#---------------------------------------
get_filenames()
{  # *: <parameterFileOP> <filename start or filename> ...
   # sets: {paramCount} the amount of parameter consumed
   fileCount=0
   [ "${fileOP:-$1}" = "$1" ] || fail -2 "Cannot mix $1 and ${fileOP}"
   fileOP="$1"
   shift
   paramCount=1
   cd "${configDirFullPath}" || fail -5 "Cannot change to '${configDirFullPath}'"
   while [ $# -ne 0 ] && [ "${1#-}" = "$1" ]; do
      paramCount=$((paramCount +1))
      filemask="$1"
      shift
      foundFiles=false
      for ext in "" .conf .conf.disabled ; do
         if [ -f "./${filemask}${ext}" ]; then
            ls -1 "./${filemask}" >> /tmp/$$.files
            foundFiles=true
            break
         fi
      done
      if ! ${foundFiles}; then
         if ls -1 "./${filemask}*.conf"  2>/dev/null >> /tmp/$$.files; then
            foundFiles=true
         fi
         if ls -1 "./${filemask}*.conf.disabled"  2>/dev/null >> /tmp/$$.files; then
            foundFiles=true
         fi
      fi
      if ! ${foundFiles}; then
         printmsg WARNING "No files match parameter '${filemask}'"
      fi
      shift
      [ "${1#-}" != "$1" ] || break # next parameter is an -option or --option
   done
   cd /tmp
}
#---------------------------------------
collect_files()
{ # 1: --disable | --enable | -f
  # *: filemak
   get_filenames "$@"
   if [ -s /tmp/$$.files ]; then
      sort -u 
   fileCount=$(awk 'END{print NR}' /tmp/$$.files)
   return "${paramCount}"
}
#---------------------------------------
set_until_time()
{  # 1: HHMI
   [ -z "${untilDateTime}" ] || fail -2 "Cannot specify multiple durations, got --$1 and --${untilOP}"
   untilOP="$1"
   YYYYmmdd=$(date +%Y%m%d)
   nowHHMI=$(date +%H%M)
   if [ "$1" -lt "$nowHHMI" ]; then
      YYYYmmdd=$(date --date="1 day" +%Y%m%d)
   fi   
   untilDateTime="${YYYYmmdd}$1"
   touch -t "${untilDateTime}" /tmp/$$.untilDateTime
}
#---------------------------------------
set_duration()
{  # 1: [0-9]+[m|h]
   untilOP="$1"
   YYYYmmddHHMI=$(date +%Y%m%d%H%M)
   d=$(echo "$1"|awk '{printf "%d ",substr($1,1,length($1)-1)}/*h/{print "hours";exit}{print "minutes"}')
   untilDateTime=$( date --date="$d"+%Y%m%d%H%M)
   touch -t "${untilDateTime}" /tmp/$$.untilDateTime
}
#---------------------------------------
manage_files()
{
   echo "About to ${configAction} :"
   echo "${filesToEnable:-}${filesToDisable:-}" | awk -v RS=" " '{print}'
   if ${validate}; then
      fail -0 "--validate prevents modifications"
   fi
   cd "${configDirFullPath}" || fail -5 "Cannot change to '${configDirFullPath}'"
   case "$fileOP" in
      --enable)
         for f in /tmp/$$.files; do
            enable_file "${f%.disabled}"
         done
         ;;
      --disable)
         for f in /tmp/$$.files; do
            disable_file "${f%.disabled}"
         done
         ;;
      -f)
         for f in /tmp/$$.files; do
            configFilename="${f%.disabled}"
            disabledFilename="${configFilename}.disabled"
            if [ -e "${configFilename}" ]; then
               continue
            fi
            ln "${disabledFilename}" "${configFilename}"
            [ -e "${configFilename}" ] || fail -3 "Could not create '${configFilename}'"
            if [ ! -e ./."${configFilename}.enable" ]; then
               ln "${disabledFilename}" ./."${configFilename}".disable  #-- should be disabled
            fi
            unlink "${disabledFilename}"
            [ ! -e "${disabledFilename}" ] || fail -3 "Could not unlink '${disanledFilename}'"
         done
         ;;
      *) fail -3 "[fileOP=$fileOP] was unexpected" ;;
   esac  
}

#------------------------------------------------------------------------------
# main
#------------------------------------------------------------------------------
while [ $# -ne 0 ]; do
   case $1 in
      -l|--list)  do_list; exit;;
      --status)   do_show_status; exit;;
      -h|--help)  do_help; exit;;
      --cleanup)  do_cleanup; exit;;
      --validate) validate=true; shift;;
      --reload)   reloadConfig=true; shift;;
      -o)         set_output_dir "$@"; shift 2;;
      --enable|--disable|-f|--delete)
                  collect_files "$@"
                  shift $?;;
     --continue-trace)
         reloadConfig=false
         shift;;
      -v|--verbose) 
         verbosity=verbose
         shift;;
      --tail)
         tailOutput=true
         shift
         if [ $# -ge 2 ]; then
            if [ "$1" = "-E" ]; then
              tailERE=$2
              shift 2
            fi
         fi;;
     --[0-2][0-9][0-5][0-9])  # HHMI  [00..23][00..59]
         arg=${1#--}
         [ "${arg%??}" -le 23 ] || fail -2 "Got $1, should be HHMI, [00..23][00..59]. Try --help"
         set_until_time "${1#--}"
         shift;;
     --[0-9]+[mh])
         set_duration "${1#--}"
         shift;;
     -*) fail -2 "unexpected parameter '$1', try --help";;
     *)  fail -2 "unexpected argument '$1', try --help";;
   esac
done
case "${fileOP}" in
   --enable)   configAction=enable;;
   --disable)  configAction=disable;;
   -f)         configAction=apply;;
esac
get_if_already_in_use  WARNING
[ "${fileCount}" -gt 0 ] || fail -2 "No matching files found"
case "${configAction}" in
   enable|disable) manage_files;;
   apply)
      [ -n "${untilDateTimer:-}" ] || fail -2 "A duration or time was not provided with -f"
      if ${alreadyInUse} ; then
         fail -3 "Terminate other process before starting a new one"
      fi
      manage_files
      perform_tracking
      ;;
   *) fail -2 "No matching files found"
      ;;
esac
# post processing is done in exit_handler()
