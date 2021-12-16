Log4JS File & Vulnerability Scanner + Local Port Bind Scanner

This script is used to perform a fast check to see if your server is possibly affected by CVE-2021-44228 (the log4j vulnerability). 
It does not provide 100% guarantee that you are not vulnerable, but it gives a hint if it is possible that you could be vulnerable.
 
 Features:
 - Updates apt repositories "sudo apt-get update -y" (Disabled, Uncomment if needed) 
 - Installs Script Dependencies "sudo apt-get install lsof unzip locate mlocate -y" (Disabled, Uncomment if needed) 
 - Updates local locate file index database "sudo updatedb"
 - Uses 'find & locate' to scan for occurrences of Java, Elastics, Solr files
 - Uses 'lsof' to list all ports in a LISTEN state
 - Scans files for occurrences of log4j
 - Checks for packages containing log4j and Solr ElasticSearch
 - Checks if Java is installed
 - Analyzes JAR/WAR/EAR files
 - Option of checking hashes of .class files in archives
 - No system changes happen except for a temp folder which removes it self after script execution
 
Notes:
 - Currently only tested on Ubuntu 18.04 LTS but should work on most Debian\Ubuntu based distributions.
 - Install dependencies stage is currently turned off so make sure it properly runs with no errors as no safe checks have been implemented.
  
# How to use:
## Step 1: Run this script from your home directory ie /home/ubuntu/  
## Change directory to home with:

    cd ~

## Step 2: Execute the below command to perform your check.  
## Run with:

    wget https://raw.githubusercontent.com/rv4l3r3/log4v-vuln-check/main/log4js-vuln-check.sh -q -O - |sudo bash
