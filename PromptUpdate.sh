#!/bin/sh
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

# Enable automatic updates
/usr/bin/defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticCheckEnabled -bool TRUE
/usr/bin/defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticDownload -bool TRUE
/usr/bin/defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticallyInstallMacOSUpdates -bool TRUE
/usr/bin/defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist ConfigDataInstall -bool TRUE
/usr/bin/defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist CriticalUpdateInstall -bool TRUE
/usr/bin/defaults write /Library/Preferences/com.apple.commerce.plist AutoUpdate -bool TRUE

sleep 2

/bin/launchctl kickstart -k system/com.apple.softwareupdated

sleep 6

# Check if a user is logged in
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
if [ -z "$currentUser" -o "$currentUser" = "loginwindow" -o "$currentUser" = "_mbsetupuser" ]; then
  echo "no user logged in, cannot proceed"
  exit 1
fi

# Run as logged-in user function
uid=$(id -u "$currentUser")
runAsUser() {  
  if [ "$currentUser" != "loginwindow" ]; then
    launchctl asuser "$uid" sudo -u "$currentUser" "$@"
  else
    echo "no user logged in"
	exit 1
  fi
}

MAX_DAYS=7

# Uptime >7 days, please reboot for system stability.
uptimeDays=$(uptime| grep -Eo '([0-9]+) day' | cut -d ' ' -f 1)
if [ -z "$uptimeDays" ]; then
        uptimeHours=$(uptime | sed 's/.*up \([^,]*\), .*/\1/')
        echo "up for $uptimeHours (updated at `date`)"
	runAsUser osascript -e 'display dialog "This computer has not rebooted in '${uptimeDays}' days, which could impact pending updates or stability. To keep this computer running optimally, a system reboot is recommended." with title "Computer Uptime Warning" buttons {"Got it!"} default button 1'
fi

if [ "${uptimeDays}" -lt ${MAX_DAYS} ]; then
        echo "$uptimeDays days since last reboot (updated at `date`)"
fi

#Set variable to check update status
updateAvailable=`2>&1 softwareupdate -lr | grep -i "No new software available." | tail -1`

if [[ $updateAvailable == "No new software available." ]]; then
    echo "Kickstarting softwareupdate"
    #Delete bad plists
    /usr/bin/defaults delete /Library/Preferences/com.apple.SoftwareUpdate.plist
    /bin/rm -rf /Library/Preferences/com.apple.SoftwareUpdate.plist
    #Kickstart software update service
    /bin/launchctl kickstart -k system/com.apple.softwareupdated
    sleep 2
    sudo softwareupdate -lr
    exit 1
else
    echo "Updates are available"
    runAsUser osascript -e 'display dialog "Your computer has pending updates. Please Restart at your earliest convenience" with title "An update is available for your Mac" buttons {"Got it!"} default button 1'
    runAsUser open "x-apple.systempreferences:com.apple.preferences.softwareupdate"
    exit 0
fi
