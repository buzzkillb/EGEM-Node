# ![Ethergem](https://github.com/TeamEGEM/meta/blob/master/images/140x140.png)
# Install Egem Node
https://egem.io/

forked from sehidcan
This script is to install a Ethergem node on your own vps.
It has been testing on a $5 [Vultr VPS](https://www.vultr.com/?ref=7408289). EGEM Devs Referral code. =)

Requirements: Ubuntu 16.04 LTS

## Egem Node Installer
```
bash -c "$(wget --no-check-certificate -O - https://raw.githubusercontent.com/shdcn/fun2code/master/egemnode.sh)"
```

During the process you will be prompted to type in some details for your node.

Node Name and Contact Details which shows up on network.egem.io
If all went well when you visit the page you should see your newly created node on the page. 

*** Note after setup if you notice that your node is red it could be due to not being fully sysnced with the current block height. Give it a few min to catch up and you should be good to go.
If you have any trouble feel free to ask for help on the Official Egem discord. 

# To add your new node to the bootnode list.

When you boot up go-egem there is a line that looks like this:

* self=enode://02cae3b86ae74b64b8766bb177ff4578cc51a18ad5b1b3df1304faef5e39bcb928d3308ca9991ef8aeedc5b7124eb0dca7b0bc74a5f682b13662a98112426057@[::]:30666  
You remove the self= and then inside of the [::] at the end you replace it with your outside IP address.

So it should look something like this when done:

* enode://02cae3b86ae74b64b8766bb177ff4578cc51a18ad5b1b3df1304faef5e39bcb928d3308ca9991ef8aeedc5b7124eb0dca7b0bc74a5f682b13662a98112426057@[154.34.678.12]:30666

fork egem's bootnode, edit file, then submit pull request
