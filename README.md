# pentaho-pdi-docker
Docker installation for Pentaho PDI with clustering

This is dockerfile for running slave or masters of Pentaho PDI cluster and the tool run.sh for running multiple nodes of cluster

You need docker and docker-compose tu run it.

For running make simple steps:

1. Clone this repo
2. Change the file pentaho.conf for adding your hosts, ports and names
3. run the run.sh

What it done for you:

 - generates separated dirs for each master or slave
 - generate docker-compose in this dirs for master or slave
 - generate dirs for persistent volumes for logging and fixes permissions for them
 - runs all your master and slaves in daemon mode of docker-compose
 - check the opened ports for instances of PDI cluster (needed installed curl in system)




