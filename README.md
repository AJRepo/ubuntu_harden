# ubuntu_harden
Saving Generic Script for Hardening Ubuntu VMs/Servers

Assumes a Ubuntu 20.04 or greater base install. 

Useful for a server not managed by Puppet or Chef and with the following 
hardenings done

1. Send an email every time someone logs in
2. All bash commands logged to syslog
3. Change to only allow ssh login via key (no password). 
