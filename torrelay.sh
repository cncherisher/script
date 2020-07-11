#!/bin/bash

# Force check for root
  if ! [ "$(id -u)" = 0 ]; then
    echo "You need to be logged in as root!"
    exit 1
  fi

# Setup calls for Tor: Stable, Experimental, and Nightly. Also sets up calls for Project: GitHub, Torrc, Web Directory, and Repository Paths for mapping in script.
    P_Tor_Stable="https://deb.torproject.org/torproject.org"
    P_Tor_Experimental="tor-experimental-0.3.4.x"
    P_Tor_Nightly="tor-nightly-master"
    P_GH_URL="https://raw.githubusercontent.com/torworld/fastrelay/master"
    P_Tor_Torrc="/etc/tor/torrc"
    P_WEB_DIR="/usr/share/nginx/html"
    P_REPO_PATH="/etc/apt/sources.list.d"

# Setting up an update/upgrade global function
    function upkeep() {
      echo "Performing upkeep.."
        apt-get update -y
        apt-get dist-upgrade -y
        apt-get clean -y
    }

# Setting up a Tor installer + status check with hault
    function tor_install() {
      echo "Performing tor_install.."
        apt-get install tor
        service tor status
        service tor stop
    }

# Setting up different Tor branches to prep for install
    function tor_stable() {
      echo "Grabbing Stable build dependencies.."
      echo deb "$P_Tor_Stable" "$flavor" main > "$P_REPO_PATH"/repo.torproject.list
      echo deb-src "$P_Tor_Stable" "$flavor" main >> "$P_REPO_PATH"/repo.torproject.list
        apt install tor deb.torproject.org-keyring
        curl "$P_Tor_Stable"/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --import
        gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | apt-key add -
        gpg --keyserver keys.gnupg.net --recv A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89
    }

    function tor_experimental() {
      echo "Grabbing Experimental build dependencies.."
        tor_stable
      echo deb "$P_Tor_Stable" "$P_Tor_Experimental"-"$flavor" main >> "$P_REPO_PATH"/repo.torproject.list
      echo deb-src "$P_Tor_Stable" "$P_Tor_Experimental"-"$flavor" main >> "$P_REPO_PATH"/repo.torproject.list
    }

    function tor_nightly() {
      echo "Grabbing Nightly build dependencies.."
        tor_stable
      echo deb "$P_Tor_Stable" "$P_Tor_Nightly"-"$flavor" main >> "$P_REPO_PATH"/repo.torproject.list
      echo deb-src "$P_Tor_Stable" "$P_Tor_Nightly"-"$flavor" main >> "$P_REPO_PATH"/repo.torproject.list
    }

    # Setting up different NGINX branches to prep for install
  function nginx_stable() {
      echo deb http://nginx.org/packages/"$system"/ "$flavor" nginx > "$P_REPO_PATH"/"$flavor".nginx.stable.list
      echo deb-src http://nginx.org/packages/"$system"/ "$flavor" nginx >> "$P_REPO_PATH"/"$flavor".nginx.stable.list
        wget https://nginx.org/keys/nginx_signing.key
        apt-key add nginx_signing.key
    }

  function nginx_mainline() {
      echo deb http://nginx.org/packages/mainline/"$system"/ "$flavor" nginx > "$P_REPO_PATH"/"$flavor".nginx.mainline.list
      echo deb-src http://nginx.org/packages/mainline/"$system"/ "$flavor" nginx >> "$P_REPO_PATH"/"$flavor".nginx.mainline.list
        wget https://nginx.org/keys/nginx_signing.key
        apt-key add nginx_signing.key
    }

    # Attached func for NGINX branch prep.
      function nginx_default() {
        echo "Installing NGINX.."
          service nginx status
        echo "Raising limit of workers.."
          ulimit -n 65536
          ulimit -a
        echo "Setting up Security Limits.."
          wget -O /etc/security/limits.conf "$P_GH_URL"/etc/security/limits.conf
        echo "Setting up background NGINX workers.."
          wget -O /etc/default/nginx "$P_GH_URL"/etc/default/nginx
          echo "Setting up configuration file for NGINX main configuration.."
            wget -O /etc/nginx/nginx.conf "$P_GH_URL"/nginx/nginx.conf
        echo "Restarting the NGINX service..."
        service nginx restart
        echo "Grabbing fastrelay-website-template from GitHub.."
          wget https://github.com/torworld/fastrelay-website-template/archive/master.tar.gz -O - | tar -xz -C "$P_WEB_DIR"/  && mv "$P_WEB_DIR"/fastrelay-website-template-master/* "$P_WEB_DIR"/
        echo "Removing temporary files/folders.."
          rm -rf "$P_WEB_DIR"/fastrelay-website-template-master*
      }


# START

# Checking for multiple "required" pieces of software.
    tools=( lsb-release wget curl dialog socat dirmngr apt-transport-https ca-certificates )
     grab_eware=""
       for e in "${tools[@]}"; do
         if command -v "$e" >/dev/null 2>&1; then
           echo "Dependency $e is installed.."
         else
           echo "Dependency $e is not installed..?"
            upkeep
            grab_eware="$grab_eware $e"
         fi
       done
      apt-get install $grab_eware

    # Grabbing info on active machine.
        flavor=$(lsb_release -cs)
        system=$(lsb_release -is | awk '{print tolower($1)}')


# Backlinking Tor dependencies for APT.
          read -r -p "Do you want to fetch the core Tor dependencies? (Y/N) " REPLY
            case "${REPLY,,}" in
              [yY]|[yY][eE][sS])
                HEIGHT=20
                WIDTH=120
                CHOICE_HEIGHT=3
                BACKTITLE="TorWorld | FastRelay"
                TITLE="Tor Build Setup"
                MENU="Choose one of the following Build options:"

                OPTIONS=(1 "Stable Build"
                         2 "Experimental Build"
                         3  "Nightly Build")

                CHOICE=$(dialog --clear \
                                --backtitle "$BACKTITLE" \
                                --title "$TITLE" \
                                --menu "$MENU" \
                                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                                "${OPTIONS[@]}" \
                                2>&1 >/dev/tty)

                clear

# Attached Arg for dialogs $CHOICE output
            case $CHOICE in
              1)
                tor_stable
                upkeep
                tor_install
                ;;
              2)
                tor_experimental
                upkeep
                tor_install
                ;;
              3)
                tor_nightly
                upkeep
                tor_install
                ;;
            esac
        clear

# Setting up the Torrc file with config input options.

# Nickname
          read -r -p "Nickname: " REPLY
            if [[ "${REPLY,,}"  =~  ^([a-zA-Z])+$ ]]
              then
                echo "Machine Nickname is: '""$REPLY""' "
                echo Nickname "$REPLY" > "$P_Tor_Torrc"
              else
                echo "Invalid."
            fi

# DirPort
          read -r -p "DirPort (Example: 9030): " REPLY
            if [[ "${REPLY,,}"  =~  ^([0-9])+$ ]]
              then
                echo "Machine DirPort is: '""$REPLY""' "
                echo DirPort "$REPLY" >> "$P_Tor_Torrc"
              else
                echo "You did not input any numbers."
            fi

# ORPort
          read -r -p "ORPort (Example: 9001): " REPLY
            if [[ "${REPLY,,}"  =~  ^([0-9])+$ ]]
              then
                echo "Machine ORPort is: '""$REPLY""' "
                echo ORPort "$REPLY" >> "$P_Tor_Torrc"
              else
                echo "You did not input any numbers."
            fi

# Dialog for ExitPolicy selection.
            HEIGHT=20
            WIDTH=120
            CHOICE_HEIGHT=4
            BACKTITLE="TorWorld | FastRelay"
            TITLE="FastRelay ExitPolicy Setup"
            MENU="Choose one of the following ExitPolicy options:"

            OPTIONS=(1 "Reduced ExitPolicy"
                     2 "Browser Only ExitPolicy"
                     3 "NON-Exit (RELAY ONLY) Policy"
                     4 "Bridge Only (Unlisted Bridge) Policy")

            CHOICE=$(dialog --clear \
                            --backtitle "$BACKTITLE" \
                            --title "$TITLE" \
                            --menu "$MENU" \
                            $HEIGHT $WIDTH $CHOICE_HEIGHT \
                            "${OPTIONS[@]}" \
                            2>&1 >/dev/tty)

                clear
                case $CHOICE in
                        1)
                            echo "Loading in a Passive ExitPolicy.."
                              wget "$P_GH_URL"/policy/passive.s02018050201.exitlist.txt -O ->> "$P_Tor_Torrc"
                            ;;
                        2)
                            echo "Loading in a Browser Only ExitPolicy.."
                              wget "$P_GH_URL"/policy/browser.s02018050201.exitlist.txt -O ->> "$P_Tor_Torrc"
                            ;;
                        3)
                            echo "Loading in NON-EXIT (RELAY ONLY) Policy"
                              wget "$P_GH_URL"/policy/nonexit.s02018050201.list.txt -O ->> "$P_Tor_Torrc"
                            ;;
                        4)
                            echo "Loading in Bridge Only (Unlisted Bridge) Policy"
                              wget "$P_GH_URL"/policy/bridge.s02019011501.list -O ->> "$P_Tor_Torrc"
                            ;;
                esac
              clear

              # NGINX Arg main
              read -r -p "Do you want to fetch the core NGINX dependencies, and install? (Y/N) " REPLY
                case "${REPLY,,}" in
                  [yY]|[yY][eE][sS])
                    HEIGHT=20
                    WIDTH=120
                    CHOICE_HEIGHT=2
                    BACKTITLE="TorWorld | FastRelay"
                    TITLE="NGINX Branch Builds"
                    MENU="Choose one of the following Build options:"

                    OPTIONS=(1 "Stable"
                             2 "Mainline")

                    CHOICE=$(dialog --clear \
                                    --backtitle "$BACKTITLE" \
                                    --title "$TITLE" \
                                    --menu "$MENU" \
                                    $HEIGHT $WIDTH $CHOICE_HEIGHT \
                                    "${OPTIONS[@]}" \
                                    2>&1 >/dev/tty)


              # Attached Arg for dialogs $CHOICE output
                  case $CHOICE in
                    1)
                      echo "Grabbing Stable build dependencies.."
                        nginx_stable
                        upkeep
                        nginx_default
                        ;;
                    2)
                      echo "Grabbing Mainline build dependencies.."
                        nginx_mainline
                        upkeep
                        nginx_default
                        ;;
                  esac
              clear

              # Close Arg for Main Statement.
                    ;;
                  [nN]|[nN][oO])
                    echo "You have said no? We cannot work without your permission!"
                    ;;
                  *)
                    echo "Invalid response. You okay?"
                    ;;
              esac


# Contact Information
            read -r -p "Contact Information: " REPLY
              if [[ "${REPLY,,}"  =~  ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]
                then
                  echo "Machines Contact info is: '$REPLY' | You must enter a valid email address for now. You can change it manually later on via ($P_Tor_Torrc)"
                  echo ContactInfo "$REPLY" >> "$P_Tor_Torrc"
                else
                  echo "Invalid."
              fi

# Setup Arg for PIP+Nyx
    read -r -p "Do you wish to install Nyx to monitor your Tor Relay? (Y/N) " REPLY
      case "${REPLY,,}" in
        [yY]|[yY][eE][sS])
              echo "Setting up Python-PIP in order to install Nyx.."
                apt-get install python-pip
                pip install nyx
              echo -e "ControlPort 9051\nCookieAuthentication 1" >> "$P_Tor_Torrc"
                upkeep
                service tor restart
            ;;
          [nN]|[nN][oO])
            echo "You have said no? We cannot work without your permission!"
            ;;
          *)
            echo "Invalid response. You okay?"
            ;;
      esac

# Close Arg for Main Statement.
      ;;
    [nN]|[nN][oO])
      echo "You have said no? We cannot work without your permission!"
      ;;
    *)
      echo "Invalid response. You okay?"
      ;;
esac
