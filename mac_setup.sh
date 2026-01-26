#!/bin/bash

# ----------------------
# Grantly Mac Setup Script v4.10
# Voor Mac Installs M4 staging & onboarding (inclusief rollback optie)
# ----------------------

# Vraag om sudo-rechten op voorhand
sudo -v

# Houd sudo actief tijdens het script
while true; do sudo -n true; sleep 60; done 2>/dev/null &
SUDO_KEEPALIVE_PID="$!"

# === Functie: Rollback uitvoeren ===
perform_rollback() {
  echo "[ROLLBACK] Herstellen van systeem naar pre-installatiestatus..."

  if id "$adminUsername" &>/dev/null; then
    sudo dscl . -delete /Users/$adminUsername
    echo "[ROLLBACK] Adminaccount '$adminUsername' verwijderd."
  fi

  if id "$newUsername" &>/dev/null; then
    sudo dscl . -delete /Users/$newUsername
    echo "[ROLLBACK] Gebruiker '$newUsername' verwijderd."
  fi

  sudo scutil --set ComputerName "Macintosh"
  sudo scutil --set LocalHostName "Macintosh"
  echo "[ROLLBACK] Computernaam hersteld."

  if [[ -d "/opt/homebrew" ]]; then
    echo "[ROLLBACK] Homebrew verwijderen..."
    sudo rm -rf /opt/homebrew
  fi

  if [[ -f "/Library/Desktop Pictures/company-wallpaper.jpg" ]]; then
    sudo rm "/Library/Desktop Pictures/company-wallpaper.jpg"
    echo "[ROLLBACK] Wallpaper verwijderd."
  fi

  dockutil --remove all --no-restart
  killall Dock

  echo "[ROLLBACK] Voltooid."
  exit 0
}

if [[ "$1" == "--rollback" ]]; then
  perform_rollback
fi

# Bash als standaard shell instellen indien nodig
if [[ "$SHELL" != "/bin/bash" ]]; then
  echo "[INFO] Bash wordt ingesteld als standaard shell."
  chsh -s /bin/bash
fi

# === Verder met setup ===
clear
CYAN='\033[1;36m'
NC='\033[0m'

ascii_art='
          _              _           _                   _           _            _    _        _   
         /\ \           /\ \        / /\                /\ \     _  /\ \         _\ \ /\ \     /\_\ 
        /  \ \         /  \ \      / /  \              /  \ \   /\_\\_\ \       /\__ \\ \ \   / / / 
       / /\ \_\       / /\ \ \    / / /\ \            / /\ \ \_/ / //\__ \     / /_ \_\\ \ \_/ / /  
      / / /\/_/      / / /\ \_\  / / /\ \ \          / / /\ \___/ // /_ \ \   / / /\/_/ \ \___/ /   
     / / / ______   / / /_/ / / / / /  \ \ \        / / /  \/____// / /\ \ \ / / /       \ \ \_/    
    / / / /\_____\ / / /__\/ / / / /___/ /\ \      / / /    / / // / /  \/_// / /         \ \ \     
   / / /  \/____ // / /_____/ / / /_____/ /\ \    / / /    / / // / /      / / / ____      \ \ \    
  / / /_____/ / // / /\ \ \  / /_________/\ \ \  / / /    / / //_/ /      /_______/\__\/      \ \_\  
 / / /______\/ // / /  \ \ \/ / /_       __\ \_\/ / /    / / //_/ /      /_______\/           \/_/  
 \/___________/ \/_/    \_\/\_\___\     /____/_/\/_/     \/_/ \_\/       \_______\/           \/_/  
'

# Optioneel: centreren op scherm (vereist terminal breedte)
terminal_width=$(tput cols)
while IFS= read -r line; do
    padding=$(( (terminal_width - ${#line}) / 2 ))
    printf "%*s" $padding ''
    printf "${CYAN}%s${NC}\n" "$line"
done <<< "$ascii_art"

# === System Preferences afsluiten ===
osascript -e 'try
tell application "System Preferences" to quit
end try
try
tell application "System Settings" to quit
end try'

# === Hulpfunctie voor dynamische UniqueID ===
get_next_uid() {
  dscl . -list /Users UniqueID | awk '{print $2}' | sort -n | tail -1 | awk '{print $1+1}'
}

# === Adminaccount aanmaken ===
read -p "Wil je een adminaccount aanmaken? (y/n): " createAdmin
if [[ "$createAdmin" == "y" ]]; then
    read -p "Voer naam in voor admingroep (bv. Admins): " adminGroup
    read -p "Voer gebruikersnaam in voor adminaccount: " adminUsername
    read -s -p "Voer wachtwoord in voor adminaccount: " adminPassword
    echo

    adminUID=$(get_next_uid)
    sudo dscl . -create /Groups/$adminGroup
    sudo dscl . -create /Users/$adminUsername
    sudo dscl . -create /Users/$adminUsername UserShell /bin/bash
    sudo dscl . -create /Users/$adminUsername RealName "$adminUsername"
    sudo dscl . -create /Users/$adminUsername UniqueID "$adminUID"
    sudo dscl . -create /Users/$adminUsername PrimaryGroupID "80"
    sudo dscl . -create /Users/$adminUsername NFSHomeDirectory /Users/$adminUsername
    sudo dscl . -passwd /Users/$adminUsername "$adminPassword"
    sudo dscl . -append /Groups/admin GroupMembership $adminUsername
    echo "[DONE] Adminaccount '$adminUsername' aangemaakt."
fi

# === Gewone gebruiker aanmaken ===
read -p "Wil je een gewone gebruiker aanmaken? (y/n): " createUser
if [[ "$createUser" == "y" ]]; then
    read -p "Voer gebruikersnaam in: " newUsername
    read -s -p "Voer wachtwoord in: " newPassword
    echo

    userUID=$(get_next_uid)
    sudo dscl . -create /Users/$newUsername
    sudo dscl . -create /Users/$newUsername UserShell /bin/bash
    sudo dscl . -create /Users/$newUsername RealName "$newUsername"
    sudo dscl . -create /Users/$newUsername UniqueID "$userUID"
    sudo dscl . -create /Users/$newUsername PrimaryGroupID "20"
    sudo dscl . -create /Users/$newUsername NFSHomeDirectory /Users/$newUsername
    sudo dscl . -passwd /Users/$newUsername "$newPassword"
    echo "[DONE] Gebruiker '$newUsername' aangemaakt."
else
    echo "[INFO] Geen nieuwe gebruiker aangemaakt."
fi

# === Mac type kiezen ===
echo "Wat voor type Mac is dit?"
echo "a: MacBook Pro"
echo "b: MacBook Air"
echo "c: Mac Mini"
read -p "Keuze (a/b/c): " macTypeInput

case $macTypeInput in
    a) ComputerType="MBP" ;;
    b) ComputerType="MBA" ;;
    c) ComputerType="MMI" ;;
    *) echo "[ERROR] Ongeldige keuze. Exit."; exit 1 ;;
esac

# === Gebruikerstype kiezen ===
echo "Voor welk type medewerker is deze machine?"
echo "a: Server"
echo "b: Developer"
echo "c: Overige medewerker"
read -p "Keuze (a/b/c): " userTypeInput

case $userTypeInput in
    a) UserType="Server" ;;
    b) UserType="Developer" ;;
    c) UserType="Overige medewerker" ;;
    *) echo "[ERROR] Ongeldige keuze. Exit."; exit 1 ;;
esac

# === Bedrijf kiezen ===
echo "Voor welk bedrijf is deze Mac?"
echo "a: Grantly"
echo "b: Het Subsidie Lab"
echo "c: PWRSTAFF"
echo "d: Meetbaar"
read -p "Keuze (a/b/c/d): " companyInput

case $companyInput in
    a) prefix="GRANTLY" ;;
    b) prefix="HSL" ;;
    c) prefix="PWRS" ;;
    d) prefix="MTBR" ;;
    *) echo "[ERROR] Ongeldige keuze. Exit."; exit 1 ;;
esac

read -p "Voer initialen in (bv. JD): " UserInnitials
read -p "Voer nummer/iteratie in (bv. 01): " iterationNumber

computerName="$prefix-$ComputerType-$(date +%y)$iterationNumber-$UserInnitials"
sudo scutil --set ComputerName "$computerName"
sudo scutil --set LocalHostName "$computerName"
echo "[DONE] Computernaam ingesteld als $computerName"

# === Homebrew installeren ===
if ! command -v brew &> /dev/null; then
  echo "Homebrew installatie..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    export PATH="/opt/homebrew/bin:$PATH"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.bash_profile
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc  
  else
    echo "[FOUT] Homebrew installatie lijkt mislukt. Pad niet gevonden."
    exit 1
  fi

  # Even wachten om ervoor te zorgen dat alles correct is ingesteld
  sleep 2

  # Test of brew correct werkt
  if ! command -v brew &> /dev/null; then
    echo "[FOUT] Homebrew werkt niet correct. Controleer de installatie."
    exit 1
  fi

  brew update --force --quiet
  sudo chown -R $adminUsername:admin /opt/homebrew
  sudo chmod -R 775 /opt/homebrew

  brew analytics off
  brew update
  brew upgrade
  sleep 2
  brew doctor

  echo "[DONE] Homebrew is klaar."
else
  echo "[INFO] Homebrew is al geïnstalleerd."
fi

# === Maak de Development Directory ===
create_development_repo() {
  # De root directory voor de ontwikkelprojecten
  development_dir="$HOME/Development"
  
  if [ ! -d "$development_dir" ]; then
    echo "[INFO] 'Development' directory wordt aangemaakt..."
    mkdir -p "$development_dir"
    echo "[DONE] 'Development' directory aangemaakt."
  else
    echo "[INFO] 'Development' directory bestaat al."
  fi

  # Zet de 'Development' directory als de default voor git clones
  echo "[INFO] De 'Development' directory wordt de standaard voor git clone."
  echo "cd $development_dir" >> ~/.bash_profile  # voor bash
  echo "cd $development_dir" >> ~/.zshrc        # voor zsh (indien gebruikt)
  echo "[INFO] Standaard directory voor git clone ingesteld."

  # Herlaad de configuratie voor het shell-profiel
  source ~/.bash_profile
  source ~/.zshrc
}

# Roep de functie aan om de Development directory aan te maken
create_development_repo

# === Wallpaper instellen ===
echo "Wallpapers downloaden..."

case $companyInput in
    a) wallpaperURL="https://www.grntly.com/public-img/wall/GRANTLY-macwallpaper.jpg" ;;
    b) wallpaperURL="https://www.grntly.com/public-img/wall/HSL-macwallpaper.jpg" ;;
    c) wallpaperURL="https://www.grntly.com/public-img/wall/PWRS-macwallpaper.jpg" ;;
    d) wallpaperURL="https://www.grntly.com/public-img/wall/GRANTLY-macwallpaper.jpg" ;;
esac

wallpaperPath="/Library/Desktop Pictures/company-wallpaper.jpg"
sudo mkdir -p "/Library/Desktop Pictures"

if curl -L "$wallpaperURL" -o /tmp/company-wallpaper.jpg; then
  sudo cp /tmp/company-wallpaper.jpg "$wallpaperPath"
  osascript -e "tell application \"System Events\" to set picture of every desktop to POSIX file \"$wallpaperPath\""
  rm /tmp/company-wallpaper.jpg
  echo "[DONE] Wallpaper gedownload en geïnstalleerd."
else
  echo "[ERROR] Wallpaper downloaden mislukt voor $companyInput"
fi

brew install dockutil
echo "[DONE] dockutil geinstalleerd"

if command -v dockutil &> /dev/null; then
   echo "[INFO] Dock wordt opgeschoond..."
   dockutil --remove all --no-restart
   killall Dock 2>/dev/null
else
   echo "[ERROR] Dockutil is niet geïnstalleerd."
fi

install_or_notify() {
  local SOFTWARE=$1
  if brew list --versions "$SOFTWARE" &> /dev/null; then
    echo "[INFO] $SOFTWARE is al geïnstalleerd."
  else
    brew install "$SOFTWARE"
  fi
}

install_or_notify_cask() {
  local CASK=$1
  if brew list --cask --versions "$CASK" &> /dev/null; then
    echo "[DONE] $CASK is al geïnstalleerd."
  else
    brew install --cask "$CASK"
  fi
}

# Functie om Docker bij te werken of te installeren
update_or_install_docker() {
  if brew list --cask --versions docker &> /dev/null; then
    echo "[INFO] Docker is al geïnstalleerd. Bijwerken..."
    brew upgrade --cask docker
  else
    echo "[INFO] Docker is niet geïnstalleerd. Installeren..."
    brew install --cask docker
  fi

  # Controleer of Docker correct werkt
  if ! command -v docker &> /dev/null; then
    echo "[FOUT] Docker werkt niet correct. Controleer de installatie."
    exit 1
  fi
}

# Functie om Docker Compose bij te werken of te installeren
update_or_install_docker_compose() {
  if brew list --versions docker-compose &> /dev/null; then
    echo "[INFO] Docker Compose is al geïnstalleerd. Bijwerken..."
    brew upgrade docker-compose
  else
    echo "[INFO] Docker Compose is niet geïnstalleerd. Installeren..."
    brew install docker-compose
  fi
}

if [[ "$UserType" == "Developer" ]]; then
    install_or_notify gh
    install_or_notify wget
    install_or_notify curl
    install_or_notify php
    update_or_install_docker
    update_or_install_docker_compose
    install_or_notify_cask google-chrome
    install_or_notify_cask google-drive
    install_or_notify_cask spotify
    install_or_notify_cask visual-studio-code
    install_or_notify_cask postman
    install_or_notify_cask github

    handle_error() {
      echo "[ERROR] Er is een fout opgetreden bij het uitvoeren van $1."
      exit 1
    }

    # Check of dockutil is geïnstalleerd en voeg applicaties toe aan de Dock
    if command -v dockutil &> /dev/null; then
        # Voeg applicaties toe aan de Dock, maar verberg eventuele foutmeldingen
        dockutil --add "/Applications/Google Chrome.app" --replacing "Google Chrome" --no-restart 2>/dev/null
        dockutil --add "/Applications/Google drive.app" --replacing "Google drive" --no-restart 2>/dev/null
        dockutil --add "/Applications/Visual Studio Code.app" --replacing "Visual Studio Code" --no-restart 2>/dev/null
        dockutil --add "/Applications/Docker.app" --replacing "Docker" --no-restart 2>/dev/null
        dockutil --add "/Applications/Utilities/Terminal.app" --no-restart 2>/dev/null
        dockutil --add "/Applications/Github desktop.app" --replacing "Github desktop" --no-restart 2>/dev/null
        dockutil --add "/Applications/Spotify.app" --replacing "Spotify" --no-restart 2>/dev/null
        dockutil --add "/Applications/Google docs.app" --replacing "Google docs" --no-restart 2>/dev/null
        dockutil --add "/Applications/Google sheets.app" --replacing "Google sheets" --no-restart 2>/dev/null
        dockutil --add "/Applications/Google slides.app" --replacing "Google slides" --no-restart 2>/dev/null
        # Herstart het Dock, maar verberg eventuele foutmeldingen
        killall Dock 2>/dev/null
    else
        echo "[ERROR] Dockutil is niet geïnstalleerd."
        exit 1
    fi

    if command -v code &> /dev/null; then
      code --install-extension esbenp.prettier-vscode --force
      code --install-extension dbaeumer.vscode-eslint --force
      code --install-extension ms-vscode.vscode-typescript-next --force
      code --install-extension github.copilot --force
    fi

elif [[ "$UserType" == "Server" ]]; then
    install_or_notify nginx
    update_or_install_docker
    update_or_install_docker_compose
    install_or_notify_cask google-chrome
    install_or_notify_cask google-drive
    install_or_notify redis
    install_or_notify postgresql
    install_or_notify_cask iterm2

    if command -v dockutil &> /dev/null; then
      dockutil --add "/System/Applications/Utilities/Activity Monitor.app" --no-restart
      dockutil --add "/Applications/iTerm.app" --no-restart
    fi
elif [[ "$UserType" == "Overige medewerker" ]]; then
    install_or_notify_cask google-chrome

    if command -v dockutil &> /dev/null; then
      dockutil --add "/Applications/Google Chrome.app" --no-restart
      dockutil --add "/System/Applications/Mail.app" --no-restart
      dockutil --add "/System/Applications/Notes.app" --no-restart
      dockutil --add "/Applications/Slack.app" --no-restart
      dockutil --add "/Applications/Google drive.app" --replacing "Google drive" --no-restart 2>/dev/null
      dockutil --add "/Applications/Spotify.app" --replacing "Spotify" --no-restart 2>/dev/null
      dockutil --add "/Applications/Google docs.app" --replacing
      dockutil --add "/Applications/Google sheets.app" --replacing "Google sheets" --no-restart 2>/dev/null
      dockutil --add "/Applications/Google slides.app" --replacing "Google slides" --no-restart 2>/dev/null
    fi
fi

if [[ "$USER" == "$newUsername" && $(command -v dockutil) ]]; then
  killall Dock
fi

# Finder instellingen aanpassen: Toon padbalk en tabbladbalk
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowTabView -bool true
killall Finder
echo "[DONE] Finder-instellingen aangepast: padbalk en tabbladbalk ingeschakeld."

# --- Lokale hosting starten als profiel == developer ---
if [[ "$UserType" == "Developer" ]]; then
  echo "[INFO] Developer profiel gedetecteerd – Docker GUI wordt gestart..."

  # Check if Docker is installed
  if command -v docker &> /dev/null; then
    echo "[INFO] Docker is geïnstalleerd. Docker GUI wordt gestart..."

    # Start Docker GUI
    open -a Docker
    if [[ $? -eq 0 ]]; then
      echo "[INFO] Docker GUI gestart."
    else
      echo "[ERROR] Docker GUI kon niet worden gestart."
    fi
  else
    echo "[WAARSCHUWING] Docker is nog niet correct geïnstalleerd. Docker GUI is niet gestart."
  fi
fi
kill "$SUDO_KEEPALIVE_PID"

echo "[OK] Setup voltooid voor $UserType op $computerName"
echo "--------------------------------------------"
kill "$SUDO_KEEPALIVE_PID"
