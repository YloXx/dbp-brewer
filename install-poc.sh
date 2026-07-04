#! /bin/bash
# ===========================================================================
# DEPRECATED — dit is de oude proof-of-concept installer.
# Gebruik in plaats hiervan de modulaire, geharde installer: ./install.sh
# Dit bestand blijft alleen voor referentie/historie en wordt niet onderhouden.
# ===========================================================================
echo "[DEPRECATED] Gebruik ./install.sh — deze POC wordt niet meer onderhouden." >&2

echo "grntly-brewer ¯\\\_(ツ)_/¯ Alpha V0.1.1.25 \r\r"
echo ""
echo "You are going to install the grntly-brewer for the following system!"
array=$( system_profiler SPSoftwareDataType )

for i in "${array[@]}"; do
    echo "- $i"
done

sleep 2
osascript -e 'tell application "System Preferences" to quit'
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo -ne "#                         (1%)\r"
sleep 2
echo -ne "##############            (56%)\r"
sleep 1
echo -ne "##################        (73%)\r"
sleep 1
echo -ne "#######################   (100%)\r"
echo -ne "\n"
echo "Get and install homebrew"
sleep 1

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"'
eval "$(/opt/homebrew/bin/brew shellenv)"

echo "Checking Homebrew"
echo -ne "##                        (4%)\r"
sleep 1
echo -ne "##################        (73%)\r"
sleep 1
echo -ne "#######################   (100%)\r"
echo -ne "\n"
echo "Checking installed brew version"
brew -v
sleep 3

brew install tree
sleep 1
echo $(whoami)
echo "[CONFIG] installation for $USER"
echo "Please enter the e-mailaddress of the current employee?"
read email_employee
echo "We are creating config files for: $email_employee on MacOS"
echo "Please enter the employee initials, example: Name is John Doe, fill in JD"
read computerName
echo "Fill in Macbook follownumber"
read iterationNumber

if [ "$computerName" != "" ] ;then
	$(sudo scutil --set ComputerName "PWRSTAFF-MBP-$(date +%y)"$iterationNumber"-"$computerName)
	$(sudo scutil --set LocalHostName "PWRSTAFF-MBP-$(date +%y)"$iterationNumber"-"$computerName)
fi

echo "Do you want to add an default Admin account, select (y/n)?"
read default_admin

if [ "$default_admin" != "${default_admin#[Yy]}" ] ; then
	
	adminpass=
	echo "Fill in a password for the default Admin"
	while [[ $adminpass == "" ]]; do
		read adminpass
	done

	if [ "$adminpass" != "" ] ; then
		$(sudo dscl . -create /Users/beheer)
		$(sudo dscl . -create /Users/beheer UserShell /bin/bash)
		$(sudo dscl . -create /Users/beheer RealName Beheer)
		$(sudo dscl . -create /Users/beheer UniqueID 1337)
		$(sudo dscl . -create /Users/beheer PrimaryGroupID 1000)
		$(sudo dscl . -create /Users/beheer NFSHomeDirectory /Users/beheer)
		$(sudo dscl . -passwd /Users/beheer "$adminpass")
		$(sudo dscl . -append /Groups/admin GroupMembership beheer)	
		
	fi
	
	echo "Admin succesfully created"
fi

echo  "Do you want to install default PWRSTAFF / HSL / GRNTLY applications $email_employee select (y/n)?"
read answer

if [ "$answer" != "${answer#[Yy]}" ] ; then
    echo "Hold your seat..! \n"
    echo -ne 'Prepare: Google Chrome, Drive, Chat, teamviewer, Spotify and many more...\n'
    sleep 2
    echo -ne '#                         (2%)\r'
    sleep 1
    echo -ne '#############             (66%)\r'
    sleep 1
    echo -ne '#######################   (100%)\r'
    echo -ne '\n'
    brew install --cask google-chrome
    brew install --cask google-drive
    brew install --cask google-chat
    brew install --cask teamviewer
    brew install --cask spotify
    brew install --cask vlc

    echo -ne '#############             (66%)\r'
    sleep 1
    echo -ne '#######################   (100%)\r'
    echo -ne '\n'

sleep 1

echo  "Do you want to install dockitems? select (y/n)"
read dock_items

if [ "$dock_items" != "${dock_items#[Yy]}" ] ; then

	LOGGED_USER=`stat -f%Su /dev/console` 
	sudo su $LOGGED_USER -c 'defaults delete com.apple.dock persistent-apps' 

	dock_item() { 
	    printf "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>%s</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>", "$1" 
	} 

	chrome=$(dock_item /Applications/Google Docs.app) 
	docs=$(dock_item /Applications/Google Docs.app)
	sheets=$(dock_item /Applications/Google Sheets.app) 
	slides=$(dock_item /Applications/Google Slides.app) 
	drive=$(dock_item /Applications/Google Drive.app) 
	teamviewer=$(dock_item /Applications/TeamViewer.app)
	spotify=$(dock_item /Applications/Spotify.app)

	sudo su $LOGGED_USER -c "defaults write com.apple.dock persistent-apps -array-add '$chrome' '$docs' '$sheets' '$slides' '$drive' '$teamviewer' '$spotify'"; killall Dock 

else
    echo "Dont forget to add dockitems manual"
fi

echo "Preparing system essentials\n"
sleep 1
echo "Turn on firewall\n"
sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1 

echo -ne 'Closing installer and prepare to work\n'
sleep 2
killall Terminal
fi
