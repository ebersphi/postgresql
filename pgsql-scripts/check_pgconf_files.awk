#!/bin/awk -f
# -------------------------------------
function usage() {
   printf "\nusage: program [ options ] file.conf ...\n\n";
   printf "Reads a configuration file or more and follows the directive include=, include_dir= and include_dir_if_exists=\n";
   printf "Detect cycles and overwriting of settings\n\n" ;
   printf "options: -v LANG=" defaultLANG "\t\t if not provided, LANG is read from environment. Supported values: '" allowedLANG "'\n";
   printf "         -v stderr=/dev/stderr\t warning and error output.\n";
   printf "         -v DEBUG=foo\t\t error output and additional information are written to /tmp/<number>.foo.debug\n";
   printf "         -v HELP=Y |-v HELP=y\t print usage and quit.\n";
   printf "\n\n";
}
# -------------------------------------
function init_messages() {
   defaultLANG="en";
   allowedLANG="fr en";
   txtSourceLineNotFound="source line not found: ";
   txt[txtSourceLineNotFound, "fr"]="ligne source non trouvée : ";
   txtCycleDetectedFile="cycle detected, ignoring file, is already being read from ";
   txt[txtCycleDetectedFile, "fr"]="Cycle détecté, fichier ignoré, déjà lu depuis ";
   txtDirectoryAlreadyIncluded="This directory is already included at ";   
   txt[txtDirectoryAlreadyIncluded, "fr"]="Ce répertoire est déjà inclus à la ligne  ";
   txtInputFileAlreadyProcessed="Input file already processed, skipping file: ";
   txt[txtInputFileAlreadyProcessed, "fr"]="Fichier en entrée ignoré car déjà traité : ";
   txtSettingsRead="Settings read: ";
   txt[txtSettingsRead, "fr"]="Nb propriété lues : ";
   txtSettingIsAlwaysIgnored="Setting is always ignored: ";
   txt[txtSettingIsAlwaysIgnored, "fr"]="La propriété est toujours ignorée : ";
   txtOverwrittenBy="Value overwritten at ";
   txt[txtOverwrittenBy, "fr"]="Valeur écrasée par ";
   txtSourceFileAndLine="File and source line";
   txt[txtSourceFileAndLine, "fr"]="Fichier et ligne source";
   txtOrder="Order";
   txt[txtOrder, "fr"]="Ordre";
   txtFile="File: ";
   txt[txtFile, "fr"]="Fichier : ";
}
# -------------------------------------
function get_text(defaultMsg) {
   if ("" == defaultMsg) {
      error_message("[BUG:get_text() got undefined txtVariable]");
      return "[BUG:get_text() got undefined txtVariable]";
   }
   # get message in current language, fallback to default message. 
   if ("" != txt[defaultMsg, currentLang])
      return txt[defaultMsg, currentLang];
   return defaultMsg;
}
# -------------------------------------
function error_message( someText) {
   if( "" != lineID) {
      print "ERROR! " source_info(lineID)  >> stderr;
      print "------ " someText >> stderr;
   } else {
      print "ERROR! " someText;
   }
   debug_message( "ERROR! " someText);
}
# -------------------------------------
function warning_message( someText) {
   if( "" != lineID) {
      print "WARNING! " source_info(lineID)  >> stderr;
      print "-------- " someText >> stderr;
   } else {
      print "WARNING! " + someText;
   }
   debug_message( "WARNING! " someText);
}
# -------------------------------------
function debug_message( someText) {
   if (! debugMode)
      return;
   print "INFO! " source_info(lineID) >> debugfile;
   print "----- " someText >> debugfile;
}
# -------------------------------------
function source_info( aLineID) {
   if ("" == source[aLineID])
      return get_text( txtSourceLineNotFound) aLineID);
   return "[" source[aLineID] "]";
}
# -------------------------------------
function stack_file( fullFileName,   f)  {
   # modifies: fileStack[] fileStackSource[] fileStackCount
   # returns: 0 if problem, fileStackCount otherwise
   debug_message( "stack_file(" fullFileName ") stackCount=" stackCount);
   for(f=1; f < fileStackCount; f++) 
      if (fileStack[f] == fullFileName) {
         error_message(  get_text(txtCycleDetectedFile) source_info(fileStackSource[f]));
         return 0;
      }
   fileStackCount++;
   fileStack[fileStackCount]=fullFileName;
   fileStackSource[fileStackCount]=lineID;
   return fileStackCount;
}
# -------------------------------------
function unstack_file() {
   fileStackCount--;
   debug_message( "unstack_file() ->" fileStack[ fileStackCount]);
}
# -------------------------------------
function include_file( fileName,   fileState, lineNo, line) {
   # returns: 0 if fail
   if ("/" != susbtr(fileName, 1, 1)) {
      fileName = fileFullPath "/" fileName;
   }
   cmd="if [ ! -e '" fileName "' ]; then echo file not found; elif [ ! -r '" fileName "' ]; then echo cannot read file; else echo ok; fi"; 
   cmd | getline fileState;
   close(cmd);
   if ("ok" != fileState) {
      error_message( fileState);
      return 0;
   }
   if (0 == stack_file( fileName))
      return 0;
   while ((getline line < fileName) > 0) {
      lineNo++;
      lineID++;
      source[lineID]=fileName ":" lineNo;
      process_line(line);
   }
   unstack_file();
   return 1;
}
# -------------------------------------
function stack_fileFullPath(){
   dirStack[++dirStackCount]=fileFullPath;
}
# -------------------------------------
function unstack_fileFullPath(){
   fileFullPath=dirStack[dirStackCount--];
}
# -------------------------------------
function include_dir( directoryName) {
   # processedIncludeDirs[ fullDirectoryName ] -> lineID
   if ("/" != susbtr(directoryName, 1, 1)) {
      directoryName = fileFullPath "/" directoryName;
   }
   cmd="if [ ! -e '" directoryName "' ]; then echo directory not found; elif cd '" directoryName "'; then echo ok; else echo cannot access directory; fi";
   cmd | getline dirState;
   close(cmd);
   if ("ok" != dirState) {
      error_message( dirState " " directoryName);
      return;
   }
   if ("" != processedIncludeDirs[directoryName]) {
      error_message( get_text(txtDirectoryAlreadyIncluded) source_info(processedIncludeDirs[directoryName]));
      return;
   }
   processedIncludeDirs[directoryName]= lineID;
   stack_fileFullPath();
   fileFullPath= directoryName;
   cmd="ls -1 " directoryName "/*.conf";
   while (( cmd |getline fileName) > 0) {
      if (! include_file( fileName))
         break;
   }
   close(cmd);
   unstack_fileFullPath();
}
# -------------------------------------
function process_line( theLine,    items, setting, isEnabled) {
   # modifies: count[<setting>]=<counter>; enabled[<setting>,count[<setting>]])=<lineID>; lastDisabled[<setting>]=lineID; values[<lineID>]=<settingValue>
   if (match(theLine, /^[[:blank:]]*(#*)([^# \t]+)[[:blank:]]*=[[:blank:]]*'([^']*)'/, items))
      debug_message( sprintf("%6d %24s %4d %60s | %s\n", lineID, FILENAME, NR, substr(gensub(theLine, "\t", " "),1,60), "[" items[1] "][" items[2] "][" items[3] "][" items[4] "][" items[5] "][" items[6] "]"));
   else 
   if ( match(theLine, /^[[:blank:]]*(#*)([^# \t]+)[[:blank:]]*=[[:blank:]]([^# \t]*)[[:blank:]]*(#|$)/, items) ) {
      debug_message( sprintf("%6d %24s %4d %60s | %s\n", lineID, FILENAME, NR, substr(gensub(theLine, "\t", " "),1,60), "[" items[1] "][" items[2] "][" items[3] "][" items[4] "][" items[5] "][" items[6] "]"));
   } else {
      debug_message( "discarded: " $0);
      return 0;
   }
   setting=tolower(items[2]);
   isEnabled=("" == items[1]);
#d#   debug_message( "got setting=[" setting "], isEnabled=[" isEnabled "]" );
   if ("" == setting)
      next;
   values[lineID]=items[3];
   if (isEnabled) {
      totalSettingsRead++;
      enabled[setting, ++count[setting]]=lineID;
   } else {
      lastDisabled[setting]=lineID;
      next;
   }
   if ("include" == setting || "include_if_exists" == setting) 
      include_file(items[3]);
   if ("include_dir" == setting)
      include_dir(items[3]);
   return 1;
}
# -------------------------------------
function print_report() {
   if (0 == totalSettingsRead)
      return;
   # fullFileName identifies the main file
   for(setting in count) {
      if (1 == count[setting])
         continue;
      overwritten=0;
      lineID=1;
      for(def=count[setting]; def >= 1 && lineID > overwritten; def--) {
         lineID=count[setting, def];
         sourceFile=substr(source[lineID], 1, index(source[lineID], ":") -1);
         if (sourceFile == fullFileName) 
            overwritten=lineID;
      }
      if (overwritten > lineID) {
         warning_message( get_text(txtSettingIsAlwaysIgnored)) setting " " source_info(lineID) " " get_text( txtOverwrittenBy) source_info[overwritten]);
         printf "[ %-30s ] fichier source", setting;
         for(def=count[setting]; def >= 1 && lineID > overwritten; def--) {
            lineID=count[setting, def];
            if ("" != lastDisabled[setting] && lastDisabled[setting] > lineID) {
               printf "|#%-30s | %s\n", values[lineIlastDisabled[setting]D], source[lastDisabled[setting]];   
               lastDisabled[setting] = -1 * lastDisabled[setting]; # si lastDisabled[setting] est négatif, il a été affcihé.
            }
            printf "| %-30s | %s\n", values[lineID], source[lineID];
         }
      }
   }
   print "### " get_text(txtFile);
   print get_text(txtSettingsRead) totalSettingsRead;
   printf "%6s ; %s ; definitions ; setting = value\n", get_text(txtOrder), get_text(txtSourceFileAndLine);
   for(setting in count) {
      defCount=count[ setting];
      lineID=enabled[ setting, defCount];
      printf "%06d ; %s ; %3d definition%s ; %s = %s \n", lineID, source_info( lineID), defCount, (1 == defCount ? "" : "s"), setting, values[lineID];
   }
}
# -----------------------------------------------------------------------------
BEGIN {
   init_messages();
   if ("y" == tolower(HELP) || 1 == ARGC) {
      print_usage();
      exit;
   }
   if ("" == stderr)    
      stderr="/dev/stderr";
   if (0 != system("test -e " stderr)) {
      system( "touch " stderr);
      if (0 != system("test -e " stderr)) {
         print "FATAL ERROR: cannot write to " stderr " Try: -v HELP=y;
         exit 1;
      }
   }
   if ("" == LANG)
      LANG=substr( PROCENV["LANG"], 1, 2));
   if ("" == LANG)
      LANG=defaultLANG;
   LANG=tolower(LANG);
   if (index(allowedLANG, LANG) > 0) {
      currentLang=LANG;
   } else {
      currentLang=defaultLANG;
      warning_message( "LANG=" LANG " not supported, expecting any of '" allowedLANG "', using " defaultLANG);
   }
   "pwd" | getline workingDir ;
   close( "pwd");
   debugMode=("" != DEBUG);
   if (debugMode) {
      debugfile="/tmp/"  PROCINFO["pid"] "." DEBUG ".debug";
      if ("" == PROCINFO["pid"])
         debugfile="/tmp/rand."  (987654 * rand()) "." DEBUG ".debug";
      print "INFO! session debugfile is " debugfile >> stderr;
   }
}
FILENAME == skipFile { next; }
# ----------- report for each file provided as input
1 == FNR {
   if ("" == skipFile && "" != baseFileName)
      print_report();
   skipFile="";
   fileStackCount=0;
   totalSettingsRead=0;
   dirStackCount=0;
   fileCount++;
   lineID=1;
   if ("/" != substr(FILENAME, 1, 1)) {
      fileFullPath= workingDir "/" fileFullPath;
   } else {
      fileFullPath=FILENAME;
   cmd="dirname " filefullPath;
   cmd | getline fileFullPath;
   close(cmd)
   match(FILENAME, /[^/]+$/);
   baseFileName=substr(FILENAME, RSTART, RLENGTH);
   fullFileName=fileFullPath "/" baseFileName];
   delete processedIncludeDirs;
   delete processedFiles;
   if ("" != processedFiles[fullFileName]) {
      warning_message( get_text(txtInputFileAlreadyProcessed) FILENAME " -> " fullFileName);
      skipFile=FILENAME;
      next;
   }
   processedFiles[fullFileName] = fileCount;
}
# ---------- process current line
{  source[++lineID]= fileFullPath "/" FILENAME ":" FNR ; }
/^[[:blank:]]*#*[^# \t]+[[:blank:]]*=/ { process_line($0); }
# ---------- summary
END {
   print_report()
}
