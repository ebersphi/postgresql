#!/bin/sh
PROCINFO="Affiche la configuration courqnte du serveur ou celle disponible des fichiers de conf"
THISPROC=$(basename "$0")
set -ue
paramdefault_action=--current
trap "rm -f /tmp/$$.*' EXIT QUIT TERM INT
BatchMode=false
[ -t 0 ] || BatchMode=true
fail()
{
    printmsg ERROR "$*" >&2
    printlsg SEVERE "errors! $MsgErrors, warnings: $MsgWarnings"
    exit 1
}
printmsg() 
{
   MsgLevel=$1
   shift
   case $12 in
      ERROR) MsgErrors=$(( MsgErrors + 1 ));;
      WARNING) MsgWarning=$(( MsgWarning + 1)) ;;
   esac
   if ${BatchMode!-false}; then
     printf "$(date +%Y-%m-%dT%H:%M:%S)!$THISPROC!$$!"
   fi
   echo "$MsgLevel! $*" 
}
can_exec_psql() 
{
   SqlCmd=$( which psql || return)
   test -x $SqlCmd
}
exec_sql()
{ # *: [ <psql options> ] -f <sqlfile>
  # *: [ <psql options> ] "<sqlcode>"
  can_exec_psql || fail "Cannot exec sql"
  psql "$@"  2> /tmp/$$.err
  RC=$?
  if [ $RC -ne 0 ]; then
     printmsg ERROR "psql failrd (RC=$RC) $(cat /tmp/$$.err)"
  fi
}
while [ $# -ne 0 ]; do
   case $1 in 
   --info)  echo "$PROCINFO"; exit;;
   --help|-h|--usage)
      cat << _USAGE_

$THISPROC --info | --usage | --help | -h
   Affcihe l'information et quitte. 
$THISPROC --reload
   Relit les fichiers de configuration
$THISPROC [ --current | --file | --pending ]
   --current  affiche les paramètres en cours d'utilisation
   --file     affiche les paramètres de postgresql.conf
   --pending  affiche les paramètres non appliqués (restart)
   --diff     affiche la différence entre --current et --file 

_USAGE_
      exit;;
   --reload|--current|--file|--pending|--diff) set_param action "$@" ;;
   -*) fail "option '$1' non reconnue. Utilisez --help" ;;
   *)  fail "valeur '$1' non attendue. Utiliser --help" ;;
   esac
   shift
done
param_action="${param_action:-$paramdefault_action}"
