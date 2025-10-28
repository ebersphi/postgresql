#!/bin/sh
PROCINFO="Affiche la configuration courante du serveur ou celle disponible des fichiers de conf"
THISPROC=$(basename "$0")
set -ue
env_dbName="INSTANCENAME"
env_dbPort="INSTANCEPORT"
env_dbConf="INSTANCECONF"
env_dbSocket="INSTANCESOCK"
# --------------------------------------------------------
paramdefault_action=--current
param_dbName="template1" # cnx db, default 'template1'
param_dbHost="" # localhost / socket
param_dbPort="" # default '5432'
param_dbUser="" # 'postgres'
param_dbConf="" # full path to postgresql.conf
trap 'rm -f /tmp/$$.*' EXIT QUIT TERM 
# -------------------------------------
fail()
{
    echo "ERROR!$THISPROC! $*" >&2
    exit 1
}
# -------------------------------------
printmsg() 
{
   MsgLevel=$1
   shift
   case $1 in
      ERROR) MsgErrors=$(( MsgErrors + 1 ));;
      WARNING) MsgWarning=$(( MsgWarning + 1)) ;;
   esac
   if ${BatchMode!-false}; then
     printf "$(date +%Y-%m-%dT%H:%M:%S)!$THISPROC!$$!"
   fi
   echo "$MsgLevel! $*" 
}
# -------------------------------------
set_db_params()
{
   if  [ -z "${param_dbConf:-*}" ]; then
      if [ -n "${env_dbConf:-}" ]; then
         eval param_dbConf="'${$env_dbConf}'"
      elif [ -n "${PGDATA:-}" ]; then
         if [ -r "$PGDATA/postgresql.conf" ]; then
            param_dbConf="$PGDATA/postgresql.conf"
         fi
      fi
   fi
   cd
}
# -------------------------------------
read_parameters_from_files()
{  # file: /tmp/$$.fromfiles /tmp/$$.allfromfiles
   [ -s "$param_dbConf" ] || fail "File not found or empty '$param_dbConf'" 
   [ -r "$param_dbConf" ] || fail "Cannot read file '$param_dbConf'"
}
# -------------------------------------
read_parameters_from_db()
{  # file: /tmp/$$.fromdb
   [ -n "$param_dbCnx" ] || fail "Cannot connect to database"
   exec_sql "SELECT  FROM pg_settings" > /tmp/$$.DbSettings
   awk -F ";" -v fmod="/tmp/$$.currentFromDb" -v fall="/tmp/$$.allFromDb"  '
{  print Name, Value > fall;
   if ( 0 != IsModified) print Name, Value > fmod;
}' /tmp/$$.DbSettings 
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
# -------------------------------------
set_param()
{  # *: <name> -s $@
   # *: <name> -p $@
   # set: param_name="param_<name>"
   # set: param_old="${<param_name>}"
   # set: param_arg="$3"
   # set: param_value=${3%--} if -s and $4 if -p
   # set: {param_name}='{param_value}'
   # fail: Cannot apply <param_arg>, para
   meter <name> already set to '<param_value>' 
   param_name=param_$1
   shift
   param_arg="$2"
   case $1 in
      -s) shift; param_value="${1%--}";;
      -p) shift; param_value="$2";;
      *)  fail "expected -s or -p, invalid option: set_param $param_name $*";;
   esac
   eval param_old="${$param_name:-}"
   if [ -n "$param_old" ] && [ "$param_value" != "$param_old" ]; then
      fail "parameter ${param_name%param_} is already set to '${param_old}', cannot set '${param_value} from ${param_arg}"
   fi
   eval "$param_name"="'${param_value}'"
}
# -------------------------------------
while [ $# -ne 0 ]; do
   case $1 in 
   --info)  echo "$PROCINFO"; exit;;
   --help|-h|--usage)
      cat << _USAGE_

$THISPROC --info | --usage | --help | -h
   Affiche l'information et quitte. 
$THISPROC --reload
   Relit TOUS les fichiers de configuration, postgresql.conf, pg_hba.conf, etc.
$THISPROC  --pending [ restart | reload ]
   --pending  affiche les paramètres non appliqués qui requièrent restart ou reload
$THISPROC  --current | --file | --diff  [ --all | --grep "ERE" ]
   --current  affiche les paramètres modifiés en cours d'utilisation
   --file     affiche les paramètres de postgresql.conf et conf.d/*.conf
   --diff     affiche la différence entre --file et les paramètres courants
   --all      affiche tous les paramètres
   --grep "ERE"
      Filtre les lignes de résultat, dans ce cas 
      --current retourne tous les paramètres
      --diff retourne toutes les lignes  
    
_USAGE_
      exit;;
   --reload|--current|--file|--pending|--diff) set_param action -s "$@" ;;
   --grep)   set_param grep -p "$@";;
   -*) fail "option '$1' non reconnue. Utilisez --help" ;;
   *)  fail "valeur '$1' non attendue. Utilisez --help" ;;
   esac
   shift
done
param_action="${param_action:-${paramdefault_action%--}}"
case $param_action in 
   file)  read_parameters_from_files;;
   current) read_parameters_from_db;;
   pending|diff) read_parameters_from_both;;
   reload)  do_reloadconf;;
esac
show_parameters 
