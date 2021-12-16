#!/bin/bash

# How To Run Script "wget https://raw.githubusercontent.com/rv4l3r3/log4v-vuln-check/main/log4js-vuln-check.sh -q -O - |sudo bash"

# This script is used to perform a fast check if your server is possibly affected by CVE-2021-44228 (the log4j vulnerability). 
# It does not give a 100% proof, that you are not vulnerable, but it gives a hint if it is possible, that you could be vulnerable.
# - Scans files for occurrences of log4j
# - Checks for packages containing log4j and Solr ElasticSearch
# - Checks if Java is installed
# - Analyzes JAR/WAR/EAR files
# - Option of checking hashes of .class files in archives

echo '################# Starting Log4JS Vuln Check & File Scanner + Port Bind Script #################'

#echo '################# Updating Aptitude Repositories (Currently Disabled) #################'
#sudo apt-get update

#echo '################# Installing All Denpencies (Status: Disabled) #################'
#sudo apt-get install lsof unzip locate find zip -y
#sudo apt-get install unzip -y

#echo '################# Installing Unzip Dependancy #################'
sudo apt-get install unzip -y

#echo '################# Updating File Index Database #################'
sudo updatedb

echo '################# Finding Anything With Java In Name #################'
sudo find / -name "java"

echo '################# Finding Anything With Elastics In Name #################'
sudo find / -name "elastics"

echo '################# Finding Anything With Solr In Name #################'
sudo find / -name "solr"

echo '################# Server Bound Listening Port #################'
sudo lsof -i -P -n | grep LISTEN

echo '################# Running CVE-2021-44228 Log4JS Vulnerability Check #################'
# regular expression, for which packages to scan for:
PACKAGES='solr\|elastic\|log4j'

export LANG=

RED="\033[0;31m"; GREEN="\033[32m"; YELLOW="\033[1;33m"; ENDCOLOR="\033[0m"
# if you don't want colored output, set the variables to empty strings:
# RED=""; GREEN=""; YELLOW=""; ENDCOLOR=""

function warning() {
  printf "${RED}[WARNING] %s${ENDCOLOR}\n" "$1" >&2
}

function information() {
  printf "${YELLOW}[INFO] %s${ENDCOLOR}\n" "$1"
}

function ok() {
  printf "${GREEN}[INFO] %s${ENDCOLOR}\n" "$1"
}

function locate_log4j() {
  if [ "$(command -v locate)" ]; then
    locate log4j
  else
    find \
      /var /etc /usr /opt /lib* \
      -name "*log4j*" \
      2>&1 \
      | grep -v '^find:.* Permission denied$' \
      | grep -v '^find:.* No such file or directory$'
  fi
}

function find_jar_files() {
  find \
    /var /etc /usr /opt /lib* \
    -name "*.jar" \
    -o -name "*.war" \
    -o -name "*.ear" \
    2>&1 \
    | grep -v '^find:.* Permission denied$' \
    | grep -v '^find:.* No such file or directory$'
}

if [ $USER != root ]; then
  warning "You have no root-rights. Not all files will be found."
fi

# Set this if you have a download for sha256 hashes
download_file=""
dir_temp_hashes=$(mktemp -d)
file_temp_hashes="$dir_temp_hashes/vulnerable.hashes"
ok_hashes=
if [[ -n $download_file && $(command -v wget) ]]; then
        wget  --max-redirect=0 --tries=2 --no-netrc -O "$file_temp_hashes.in" -- "$download_file"
elif [[ -n $download_file && $(command -v curl) ]]; then
        curl --globoff -f "$download_file" -o "$file_temp_hashes.in"
fi
if [[ $? = 0 && -s "$file_temp_hashes.in" ]]; then
        cat "$file_temp_hashes.in" | cut -d" " -f1 | sort | uniq  > "$file_temp_hashes"
        ok_hashes=1
        information "Downloaded vulnerable hashes from ..."
fi

information "Looking for files containing log4j..."
if [ "$(command -v locate)" ]; then
  information "using locate to be sure to have indexed updatedb recently"
fi
OUTPUT="$(locate_log4j | grep -iv log4js | grep -v log4j_checker_beta)"
if [ "$OUTPUT" ]; then
  warning "Maybe vulnerable, those files contain the name:"
  printf "%s\n" "$OUTPUT"
else
  ok "No files containing log4j"
fi

information "Checking installed packages Solr ElasticSearch and packages containing log4j"
if [ "$(command -v yum)" ]; then
  # using yum
  OUTPUT="$(yum list installed | grep -i $PACKAGES | grep -iv log4js)"
  if [ "$OUTPUT" ]; then
    warning "Maybe vulnerable, yum installed packages:"
    printf "%s\n" "$OUTPUT"
  else
    ok "No yum packages found"
  fi
fi
if [ "$(command -v dpkg)" ]; then
  # using dpkg
  OUTPUT="$(dpkg -l | grep -i $PACKAGES | grep -iv log4js)"
  if [ "$OUTPUT" ]; then
    warning "Maybe vulnerable, dpkg installed packages:"
    printf "%s\n" "$OUTPUT"
  else
    ok "No dpkg packages found"
  fi
fi

information "Checking if Java is installed..."
JAVA="$(command -v java)"
if [ "$JAVA" ]; then
  warning "Java is installed"
  printf "     %s\n     %s\n" \
    "Java applications often bundle their libraries inside binary files," \
    "so there could be log4j in such applications."
else
  ok "Java is not installed"
fi

information "Analyzing JAR/WAR/EAR files..."
if [ $ok_hashes ]; then
  information "Also checking hashes"
fi
if [ "$(command -v unzip)" ]; then
  find_jar_files | while read -r jar_file; do
    unzip -l "$jar_file" 2> /dev/null \
      | grep -q -i "log4j" \
      && warning "$jar_file contains log4j files"
    if [ $ok_hashes ]; then
      dir_unzip=$(mktemp -d)
      base_name=$(basename "$jar_file")
      unzip -qq -DD "$jar_file" '*.class' -d "$dir_unzip" \
        && find "$dir_unzip" -type f -not -name "*"$'\n'"*" -name '*.class' -exec sha256sum "{}" \; \
        | cut -d" " -f1 | sort | uniq > "$dir_unzip/$base_name.hashes";
      num_found=$(comm -12 "$file_temp_hashes" "$dir_unzip/$base_name.hashes" | wc -l)
      if [[ -n $num_found && $num_found != 0 ]]; then
        warning "$jar_file contains vulnerable binary classes"
      else
        ok "No .class files with known vulnerable hash found in $jar_file at first level."
      fi
      rm -rf -- "$dir_unzip"
    fi
  done
else
  information "Cannot look for log4j inside JAR/WAR/EAR files (unzip not found)"
fi
[ $ok_hashes ] && rm -rf -- "$dir_temp_hashes"

information "_________________________________________________"
if [ "$JAVA" == "" ]; then
  warning "Some apps bundle the vulnerable library in their own compiled package, so 'java' might not be installed but one such apps could still be vulnerable."
fi
echo
warning "This whole script is not 100% proof you are not vulnerable, but a strong hint"
echo
