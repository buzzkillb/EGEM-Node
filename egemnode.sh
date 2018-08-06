#!/bin/bash

create_swap(){
    swap_file="/swapfile"
    
    total_swap_size="$(swapon -s | grep -vi "size" | awk '{s+=$3}END{print s}')"
    
    if [ -z "${total_swap_size}" ]; then
        total_swap_size="0"
    fi
    
    if [ "${total_swap_size}" -lt "2097148" ]; then
        swap_needed="$(((2097148 - ${total_swap_size}) / 1024))"
    else
        swap_needed="0"
    fi
    
    if [ "${swap_needed}" == 0 ]; then
        echo
        echo "Looks like you already have 2GB (total) swap file/partition."
        echo "Skipping swap creation."
        echo
        sleep 3
    else
        if [ "${swap_needed}" -lt "128" ]; then
            swap_needed=128
        elif [ "${swap_needed}" -gt "128" ] && [ "${swap_needed}" -le "256" ]; then
            swap_needed=256
        elif [ "${swap_needed}" -gt "256" ] && [ "${swap_needed}" -le "512" ]; then
            swap_needed=512
        elif [ "${swap_needed}" -gt "512" ] && [ "${swap_needed}" -le "1024" ]; then
            swap_needed=1024
        elif [ "${swap_needed}" -gt "1024" ] && [ "${swap_needed}" -le "1536" ]; then
            swap_needed=1536
        elif [ "${swap_needed}" -gt "1536" ] && [ "${swap_needed}" -le "2048" ]; then
            swap_needed=2048
        fi
        
        echo
        echo "-------------------------------------------------------------------"
        echo "You have a total of $((${total_swap_size}/1024)) MB swap file/partition."
        echo
        echo "Swap file with ${swap_needed} MB size will be created..."
        echo "-------------------------------------------------------------------"
        echo
        sleep 5
        
        swapoff ${swap_file}
        rm -rf ${swap_file}
        
        fallocate -l ${swap_needed}M ${swap_file} || error "Create Swap - fallocate"
        chmod 600 ${swap_file}
        mkswap ${swap_file} || error "Create Swap - mkswap"
        swapon ${swap_file} || error "Create Swap - swapon"
        
        if [ -n "$(grep ${swap_file} /etc/fstab)" ]; then
            sed -i "s/.*${swap_file}.*//g" /etc/fstab
        fi
        
        echo "${swap_file} none swap sw 0 0" | tee -a /etc/fstab
    fi
}

install_egem_node(){
    cd ${HOME}
    
    echo
    echo "What would you like to name your instance? (example -> TeamEGEM Node - East Coast USA):"
    read nodename
    
    echo
    echo "How can developers contact you? (example -> Discord: @TeamEGEM):"
    read contactdetails
    
    add_repos
    update_system
    essentials
    fw_conf
    livenet_data
    install_go_egem
    install_net_intel
    create_service
    start_go_egem
    start_net_intel
    
    echo
    echo "-------------------------------------------------------------------"
    echo "Setup comlete."
    echo
    echo "Your node should be listed on https://network.egem.io"
    echo
    echo "If it is not listed, try rebooting your VPS and check again."
    echo
    echo "Don't forget to thank our hard working EGEM Devs"
    echo "for this so easy node experience."
    echo "-------------------------------------------------------------------"
    echo
}

add_repos(){
    echo
    echo "-------------------------------------------------------------------"
    echo "Adding necessary repositories"
    echo "-------------------------------------------------------------------"
    echo
    sleep 3
    
    if [ -z "$(which add-apt-repository)" ]; then
        echo
        apt-get install -y software-properties-common
        echo
    fi
    
    add-apt-repository main
    add-apt-repository universe
    add-apt-repository restricted
    add-apt-repository multiverse
    
    [ -z "$(apt-cache search golang-1.10)" ] && add-apt-repository ppa:gophers/archive
}

update_system(){
    echo
    echo "-------------------------------------------------------------------"
    echo "Updating current system packages"
    echo "-------------------------------------------------------------------"
    echo
    sleep 3
    
    echo "If you see a prompt about 'Grub Configuration',"
    echo "prefer keeping the currently installed version."
    echo
    echo
    sleep 5
    
    { apt-get update && apt-get upgrade -y && apt-get -f install; } || error "Install Node - system update"
}

essentials(){
    echo
    echo "-------------------------------------------------------------------"
    echo "Installing necessary packages"
    echo "-------------------------------------------------------------------"
    echo
    sleep 3
    
    [ -z "$(which curl)" ] && { apt-get install -y curl || error "Install Node - curl"; }
    curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
    
    [ -n "$(which go)" ] && apt-get -y remove golang && apt-get -y autoremove
    apt-get install -y build-essential screen git fail2ban ufw golang-1.10 nodejs || error "Install Node - necessary packages"
    
    ln -f /usr/lib/go-1.10/bin/go /usr/bin/go
    
    echo; npm install -g pm2 || error "Install Node - pm2"; echo
}

fw_conf(){
    echo
    echo "-------------------------------------------------------------------"
    echo "Configuring Firewall"
    echo "-------------------------------------------------------------------"
    echo
    sleep 3
    
    ufw default allow outgoing
    ufw default deny incoming
    ufw allow ssh/tcp
    ufw limit ssh/tcp
    ufw allow 8545/tcp
    ufw allow 30666/tcp
    ufw allow 30661/tcp
    ufw logging on
    ufw --force enable
}

livenet_data(){
    echo
    echo "-------------------------------------------------------------------"
    echo "Downloading live network data"
    echo "-------------------------------------------------------------------"
    echo
    sleep 3
    
    cd ${HOME}
    rm -rf ${dir_live_net}/egem
    mkdir -p ${dir_live_net}/egem
    
    cd ${dir_live_net}/egem
    
    wget --no-check-certificate https://raw.githubusercontent.com/TeamEGEM/EGEM-Bootnodes/master/static-nodes.json || error "Install Node - live network data download"
}

install_go_egem(){
    echo
    echo "-------------------------------------------------------------------"
    echo "Installing Go-Egem"
    echo "-------------------------------------------------------------------"
    echo
    sleep 3
    
    cd ${HOME}
    rm -rf ${dir_go_egem}
    git clone https://github.com/TeamEGEM/go-egem.git || error "Install Node - Go-EGEM download"
    cd ${dir_go_egem} && make egem || error "Install Node - Go-EGEM make"
    cd ${HOME}
}

start_go_egem(){
    echo
    echo "-------------------------------------------------------------------"
    echo "Starting Go-Egem"
    echo "-------------------------------------------------------------------"
    echo
    sleep 3
    
    systemctl start ${servicefile} || warn "Go-EGEM start"
    
    echo
    echo "Your node is syncronizing with network now. This may take some time."
    echo
    sleep 3
}

install_net_intel(){
    echo
    echo "Installing EGEM Net-Intelligence"
    echo "(necessary for sending statistics to network.egem.io)"
    echo
    sleep 3
    
    rm -rf ${dir_net_intel}
    git clone https://github.com/TeamEGEM/egem-net-intelligence-api.git || error "Install Node - net-intel download"
    
    cd ${dir_net_intel}
    
    sed -i '17s/.*/      "INSTANCE_NAME"   : '"'$nodename'"',/' app.json
    sed -i '18s/.*/      "CONTACT_DETAILS" : '"'$contactdetails'"',/' app.json
    sed "s/'/\"/g" app.json
    
    npm install || error "Install Node - net-intel install"
}

start_net_intel(){
    echo
    echo "-------------------------------------------------------------------"
    echo "Starting EGEM Net-Intelligence"
    echo "-------------------------------------------------------------------"
    echo
    sleep 3
    
    env PATH=$PATH:/usr/local/bin pm2 startup -u root
    cd ${dir_net_intel}
    pm2 start app.json || warn "net-intel start"
}

create_service(){
    cd /etc/systemd/system/
    
    [ -f ${servicefile} ] && rm -rf ${servicefile}
    
    touch ${servicefile}
    
    echo "[Unit]" >> ${servicefile}
    echo "Description=Go-EGEM Service" >> ${servicefile}
    echo "After=network-online.target" >> ${servicefile}
    echo "" >> ${servicefile}
    echo "[Service]" >> ${servicefile}
    echo "User=root" >> ${servicefile}
    echo "Type=simple" >> ${servicefile}
    echo "#TimeoutStartSec=15" >> ${servicefile}
    echo "Restart=always" >> ${servicefile}
    echo "#RestartSec=5" >> ${servicefile}
    
    ram_size="$(free -m | grep -i "mem:" | awk '{print $2}')"
    
    # if [ "${ram_size}" -lt "256" ]; then
        # cache_size="128"
    # elif [ "${ram_size}" -gt "256" ] && [ "${ram_size}" -le "512" ]; then
        # cache_size="256"
    # elif [ "${ram_size}" -gt "512" ] && [ "${ram_size}" -le "1024" ]; then
        # cache_size="1024"
    # elif [ "${ram_size}" -gt "1024" ]; then
        # cache_size="1024"
    # fi
    
    cache_size="1024"
    
    echo "ExecStart=${dir_go_egem}/build/bin/egem --datadir ${dir_live_net} --maxpeers 100 --rpc --cache ${cache_size}" >> ${servicefile}
    
    echo "#ExecStop=/usr/bin/pkill egem" >> ${servicefile}  
    echo "" >> ${servicefile}
    echo "[Install]" >> ${servicefile}
    echo "WantedBy=multi-user.target" >> ${servicefile}
    echo "" >> ${servicefile}
    
    systemctl daemon-reload
    systemctl disable ${servicefile}
    systemctl enable ${servicefile}
}

update_egem_node(){
    echo
    
    systemctl stop ${servicefile}
    
    cd ${dir_go_egem}
    make clean || error "Update Node - make clean"
    git pull || error "Update Node - git pull"
    make all || error "Update Node - make all"
    
    systemctl start ${servicefile} || warn "Go-EGEM start"
}

cleanup(){
    systemctl stop ${servicefile}
    systemctl disable ${servicefile}
    
    pm2 kill
    pm2 unstartup -u root
    
    rm -rf /etc/systemd/system/${servicefile}
    rm -rf ${dir_live_net}
    rm -rf ${dir_go_egem}
    rm -rf ${dir_net_intel}
    
}

error(){
    echo
    echo "Error. Install failed at this step ->  ${1}"
    echo
    exit 1
}

warn(){
    echo
    echo "This step has failed ->  ${1}"
    echo
    sleep 3
}

dir_net_intel="${HOME}/egem-net-intelligence-api"
dir_live_net="${HOME}/live-net"
dir_go_egem="${HOME}/go-egem"

servicefile="egem.service"

cd ${HOME}

while true
do
    clear
    echo
    echo "======================================================"
    echo " Egem Node Installer v2 (based on BuzzkillB's script) "
    echo "======================================================"
    echo
    echo " 1 - Install Egem Node with Swap File (2G size)"
    echo " 2 - Install Egem Node without Swap File"
    echo
    echo " 3 - Update Egem Node (go-egem)"
    echo
    echo " 4 - Start Egem Node (go-egem) (if installed but stopped)"
    echo " 5 - Stop Egem Node (go-egem)"
    echo
    echo " 6 - Start Network-Intelligence (node-app)"
    echo " 7 - Stop Network-Intelligence (node-app)"
    echo
    echo " 8 - How do I check if my node is running?"
    echo " 9 - What is next? What do I need to do?"
    echo "10 - What is the ROI of a masternode?"
    echo
    echo " r - Remove previous installation (confirmation required)"
    echo " q - exit this script"
    echo
    echo -n " Enter your selection: "
    read answer
    
    clear; echo; echo
    
    case ${answer} in
    1)
        create_swap && install_egem_node
    ;;
    2)
        install_egem_node
    ;;
    3)
        update_egem_node
    ;;
    4)
        start_go_egem
    ;;
    5)
        systemctl stop ${servicefile}
    ;;
    6)
        start_net_intel
    ;;
    7)
        pm2 kill
    ;;
    8)
        echo
        echo "-------------------------------------------------------------------"
        echo
        echo "Your node has 2 working parts: go-egem and network-intelligence app"
        echo
        echo "go-egem --->>> the actual node"
        echo "network-intelligence --->>> sends stats to https://network.egem.io"
        echo
        echo "To check go-egem:"
        echo "ps x | grep go-egem"
        echo
        echo "If go-egem is running, you should see this path on the screen:"
        echo "${dir_go_egem}/build/bin/egem"
        echo
        echo
        echo "To check network-intelligence:"
        echo "pm2 status"
        echo
        echo "If app is running, you should see a table"
        echo "where 'node-app' is listed and says 'online'"
        echo
        echo "-------------------------------------------------------------------"
        echo
    ;;
    9)
        echo
        echo "-------------------------------------------------------------------"
        echo
        echo "If setup has completed without errors, your node should be up"
        echo "and running."
        echo
        echo "Now go to EGEM Discord, #node-owners channel."
        echo
        echo "Run these commands:"
        echo "/botreg YourWalletAddress"
        echo "/changeip YourVpsIP"
        echo
        echo "Last step is asking Riddlez to complete your registration."
        echo
        echo "PS: Make sure you have the necessary balance in your wallet."
        echo
        echo "Happy earnings Node Owner! ^^"
        echo
        echo "-------------------------------------------------------------------"
        echo
    ;;
    10)
        echo
        echo "-------------------------------------------------------------------"
        echo "For detailed info about nodes go check this page:"
        echo
        echo "http://triforce.egem.io/egem/"
        echo
        echo "Don't forget to thank BuzzkillB for that page."
        echo "-------------------------------------------------------------------"
        echo
    ;;
    r)
        echo
        echo "-------------------------------------------------------------------"
        echo "Warning !"
        echo
        echo "This will delete all previously downloaded/created node data"
        echo "(go-egem and node-app, egem systemd service etc)"
        echo
        echo "Use this if you need a fresh node re-install."
        echo "-------------------------------------------------------------------"
        echo
        
        echo
        echo "-------------------------------------------------------------------"
        echo "Press Enter to continue"
        echo "-------------------------------------------------------------------"
        echo
        read input
        
        cleanup
    ;;
    q)
        exit
    ;;
    esac
    
    echo
    echo "-------------------------------------------------------------------"
    echo "Press Enter to continue"
    echo "-------------------------------------------------------------------"
    echo
    read input
done
