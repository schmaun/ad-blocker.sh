#!/bin/sh
#================================================================================
# (C)2013 dMajo
# Title       : ad-blocker.sh
# Version     : V1.02.0018
# Author      : dMajo (http://forum.synology.com/enu/memberlist.php?mode=viewprofile&u=69661)
# Description : Script to block add-banner servers, dns based
# Dependencies: Syno DNSServer package, sed, wget
# Usage       : sh ad-blocker.sh
#================================================================================
# Version history:
# 2013.09.01 - 1.00.0001: Initial release
# 2013.09.08 - 1.00.0004: Fix: changed include target to support views
# 2013.09.12 - 1.00.0005: Added automatic zone file generation and some basic error handling
# 2014.03.29 - 1.01.0013: Added dependencies check
# 2014.03.30 - 1.02.0017: Script reorganized
# 2014.04.06 - 1.02.0018: Fix: fixed serial number in zone file generation
#================================================================================

# Define dirs
RootDir="/var/packages/DNSServer/target"
ZoneDir="${RootDir}/named/etc/zone"
ZoneDataDir="${ZoneDir}/data"
ZoneMasterDir="${ZoneDir}/master"

cd ${ZoneDataDir}

# Check if needed dependencies exists
   Dependencies="chown date grep mv rm sed wget"
   MissingDep=0
   for NeededDep in $Dependencies; do
      if ! hash "$NeededDep" >/dev/null 2>&1; then
         printf "Command not found in PATH: %s\n" "$NeededDep" >&2
         MissingDep=$((MissingDep+1))
      fi
   done
   if [ $MissingDep -gt 0 ]; then
      printf "Minimum %d commands are missing in PATH, aborting\n" "$MissingDep" >&2
      exit 1
   fi

# Download the "blacklist" from "http://pgl.yoyo.org"
   wget "http://pgl.yoyo.org/as/serverlist.php?hostformat=bindconfig&showintro=0&mimetype=plaintext"

# Modify Zone file path from "null.zone.file" to "/etc/zone/master/null.zone.file" in order to comply with Synology bind implementation
   rm -f ad-blocker.new
   sed -e 's/null.zone.file/\/etc\/zone\/master\/null.zone.file/g' "serverlist.php?hostformat=bindconfig&showintro=0&mimetype=plaintext" > ad-blocker.new
   rm "serverlist.php?hostformat=bindconfig&showintro=0&mimetype=plaintext"
   chown -R nobody:nobody ad-blocker.new
   if [ -f ad-blocker.new ] ; then
      rm -f ad-blocker.db
      mv ad-blocker.new ad-blocker.db
   fi

# Include the new zone data
   if [ -f ad-blocker.db ] && [ -f null.zone.file ]; then
      grep -q 'include "/etc/zone/data/ad-blocker.db";' null.zone.file || echo 'include "/etc/zone/data/ad-blocker.db";' >> null.zone.file

      # Rebuild master null.zone.file
      cd ${ZoneMasterDir}
      rm -f null.zone.file
      Now=$(date +"%Y%m%d")
      echo '$TTL 86400         ; one day'         >> null.zone.file
      echo '@ IN    SOA   ns.null.zone.file. mail.null.zone.file. (' >> null.zone.file
#      echo '      2013091200   ; serial number YYYYMMDDNN'      >> null.zone.file
      echo '      '${Now}'00   ; serial number YYYYMMDDNN'      >> null.zone.file
      echo '      86400      ; refresh   1 day'         >> null.zone.file
      echo '      7200      ; retry   2 hours'      >> null.zone.file
      echo '      864000      ; expire   10 days'      >> null.zone.file
      echo '      86400 )   ; min ttl   1 day'         >> null.zone.file
      echo '   NS   ns.null.zone.file.'               >> null.zone.file
      echo '   A   127.0.0.1'                  >> null.zone.file
      echo '* IN   A   127.0.0.1'               >> null.zone.file
   fi

# Reload the server config after modifications
   ${RootDir}/script/reload.sh

exit 0
