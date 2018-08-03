#!/bin/bash

create_swap(){
    swap_file="/swapfile"
    
    if [ -n "$(grep swap /etc/fstab)" ]; then
        echo
        echo "Looks like you already have a swap file/partition."
        echo "Skipping swap creation."
        echo
        sleep 3
    else
        fallocate -l 2G ${swap_file} || error "Create Swap - fallocate"
        chmod 600 ${swap_file}
        mkswap ${swap_file} || error "Create Swap - mkswap"
        swapon ${swap_file} || error "Create Swap - swapon"
        
        echo "${swap_file} none swap sw 0 0" | tee -a /etc/fstab
    fi
}

install_egem_node(){
    cd ${HOME}
    
    echo
    echo "What woud you like to name your instance? (example -> TeamEGEM Node East Coast USA):"
    read nodename
    
    echo
    echo "What is your node's contact details? (example -> twitter: @TeamEGEM):"
    read contactdetails
    
    add_repos
    update_system
    essentials
    fw_conf
    livenet_data
    install_go_egem
    start_go_egem
    install_net_intel
    start_net_intel

    echo
    echo "-------------------------------------------------------------------"
    echo "Setup comlete."
    echo
    echo "Your node should be listed on https://network.egem.io"
    echo
    echo "Don't forget to thank our hard working EGEM Devs"
    echo "for this so easy node experience."
    echo "-------------------------------------------------------------------"
    echo
}

update_egem_node(){
    echo
    pkill screen
    cd ${dir_go_egem}
    make clean || error "Update Node - make clean"
    git pull || error "Update Node - git pull"
    make all || error "Update Node - make all"
    
    auto_start "go-egem"
}

add_repos(){
    echo
    echo "-------------------------------------------------------------------"
    echo "Adding necessary repositories"
    echo "-------------------------------------------------------------------"
    echo
    sleep 3
    
    add-apt-repository main
    add-apt-repository universe
    add-apt-repository restricted
    add-apt-repository multiverse
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
    
    up_sys || error "Install Node - system update"
}

up_sys(){
    apt-get update && apt-get upgrade -y && apt-get -f install
}

essentials(){
    echo
    echo "-------------------------------------------------------------------"
    echo "Installing necessary packages"
    echo "-------------------------------------------------------------------"
    echo
    sleep 3
    
    up_ess
    
    echo
    npm install -g pm2 || error "Install Node - pm2"
    echo
}

up_ess() {
    if [ -z "$(which curl)" ]; then
        apt-get install -y curl
    fi
    
    curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
    
    apt-get install -y build-essential screen git fail2ban ufw golang nodejs || error "Install Node - necessary packages"
    
    if [ -n "$(lsb_release -r | grep 18)" ]; then
        apt-get install -y golang || error "Install Node - golang package"
    else
        if [ -n "$(which go)" ]; then
            apt-get -y remove golang
            apt-get -y autoremove
        fi
        
        apt-get install -y golang-1.10 || error "Install Node - golang-1.10 package"
        ln -f /usr/lib/go-1.10/bin/go /usr/bin/go
    fi
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
    rm -rf ${dir_live_net}
    mkdir -p ${dir_live_net}

    cd ${dir_live_net}
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
    
    auto_start "go-egem"
    
    #if [ -f /etc/systemd/system/${service1} ]; then
    #    systemctl start ${service1} || error "Go-EGEM start"
    #else
    #    screen -dmS go-egem ${dir_go_egem}/build/bin/egem --datadir ${dir_live_net}/ --maxpeers 100 --rpc || error "Go-EGEM start"
    #fi
    
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
    
    auto_start "node-app"
    
    #if [ -f /etc/systemd/system/${service2} ]; then
    #    systemctl start ${service2} || error "net-intel start"
    #else
    #    cd ${dir_net_intel} && pm2 start app.json || error "net-intel start"
    #fi
}

auto_start(){
    case $1 in
    "go-egem")
        if [ ! -f /etc/systemd/system/${service1} ]; then
            cd /etc/systemd/system/ && touch ${service1}
            
            echo "[Unit]" >> ${service1}
            echo "Description=Go-EGEM Service" >> ${service1}
            echo "" >> ${service1}
            echo "[Service]" >> ${service1}
            echo "User=root" >> ${service1}
            echo "Type=simple" >> ${service1}
            echo "#TimeoutStartSec=15" >> ${service1}
            echo "Restart=always" >> ${service1}
            echo "#RestartSec=5" >> ${service1}
            echo "ExecStart=/usr/bin/${xone}" >> ${service1}
            echo "#ExecStop=/usr/bin/pkill screen" >> ${service1}
            echo "#ExecStop=/usr/bin/pkill go-egem" >> ${service1}    
            echo "" >> ${service1}
            echo "[Install]" >> ${service1}
            echo "WantedBy=multi-user.target" >> ${service1}
            echo "" >> ${service1}
            
            cd /usr/bin/ && touch ${xone}
            
            echo "#!/bin/bash" >> ${xone}
            echo "" >> ${xone}
            echo "screen -dmS go-egem ${dir_go_egem}/build/bin/egem --datadir ${dir_live_net}/ --maxpeers 100 --rpc" >> ${xone}
            echo "" >> ${xone}
            
            chmod +x ${xone}
        fi
        
        systemctl daemon-reload
        systemctl disable ${service1}
        systemctl enable ${service1}
        systemctl start ${service1} || error "Go-EGEM start"
    ;;
    "node-app")
        if [ ! -f /etc/systemd/system/${service2} ]; then
            touch ${service2}
            
            echo "[Unit]" >> ${service2}
            echo "Description=Node-App Service" >> ${service2}
            echo "" >> ${service2}
            echo "[Service]" >> ${service2}
            echo "User=root" >> ${service2}
            echo "Type=simple" >> ${service2}
            echo "#TimeoutStartSec=15" >> ${service2}
            echo "Restart=always" >> ${service2}
            echo "#RestartSec=5" >> ${service2}
            echo "ExecStart=/usr/bin/${xtwo}" >> ${service2}
            echo "#ExecStop=/usr/bin/pkill pm2" >> ${service2}
            echo "#ExecStop=/usr/bin/pkill node" >> ${service2}    
            echo "" >> ${service2}
            echo "[Install]" >> ${service2}
            echo "WantedBy=multi-user.target" >> ${service2}
            echo "" >> ${service2}
            
            cd /usr/bin/ && touch ${xtwo}
            
            echo "#!/bin/bash" >> ${xtwo}
            echo "" >> ${xtwo}
            echo "cd ${dir_net_intel} && pm2 start app.json" >> ${xtwo}
            echo "" >> ${xtwo}
            
            chmod +x ${xtwo}
        fi
        
        systemctl daemon-reload
        systemctl disable ${service2}
        systemctl enable ${service2}
        systemctl start ${service2} || error "net-intel start"
    ;;
    esac 
}

error(){
    echo
    echo "Error. Install failed at this step ->  ${1}"
    echo
    exit 1    
}

dir_net_intel="${HOME}/egem-net-intelligence-api"
dir_live_net="${HOME}/live-net"
dir_go_egem="${HOME}/go-egem"

service1="goegem.service"
service2="nodeapp.service"
xone="goegem"
xtwo="nodeapp"

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
    echo " 3 - Update Egem Node (go-egem)"
    echo
    echo " 4 - Start Egem Node (go-egem) (if installed but stopped)"
    echo " 5 - Stop Egem Node (go-egem)"
    echo " 6 - Start Network-Intelligence (node-app)"
    echo " 7 - Stop Network-Intelligence (node-app)"
    echo
    echo " 8 - How do I check if my node is running?"
    echo " 9 - What is next? What do I need to do?"
    echo "10 - ROI of nodes?"
    echo
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
        pkill screen
        pkill go-egem
    ;;
    6)
        start_net_intel
    ;;
    7)
        pkill pm2
        pkill node
    ;;
    8)
        echo
        echo "-------------------------------------------------------------------"
        echo
        echo "Your node has 2 working parts: go-egem and network-intelligence app"
        echo "go-egem is the actual node, network-intelligence part just sends stats to network.egem.io"
        echo
        echo "To check go-egem:"
        echo "screen -r go-egem"
        echo
        echo "If go-egem is running, you should see a lot of info flowing on the screen."
        echo
        echo "To quit that screen:"
        echo "press  Ctrl + A  and  Ctrl + D"
        echo
        echo "To check network-intelligence:"
        echo "pm2 status"
        echo
        echo "If app is running, you should see a table where 'node-app' is listed and says 'online'"
        echo
        echo "-------------------------------------------------------------------"
        echo
    ;;
    9)
        echo
        echo "-------------------------------------------------------------------"
        echo
        echo "If setup has completed without errors, your node must be up and running."
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
        echo "http://triforce.egem.io/egem.php"
        echo
        echo "Don't forget to thank BuzzkillB for that page."
        echo "-------------------------------------------------------------------"
        echo
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
