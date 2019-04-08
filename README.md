# pentaho-pdi-docker
Docker installation for Pentaho PDI with clustering

This is dockerfile for running slave or masters of Pentaho PDI cluster and the tool run.sh for running multiple nodes of cluster

This is prepeared with jdbc drivers for:
- [MSSQL](https://www.microsoft.com/en-us/download/details.aspx?id=57782)
- [PostgreSQL](https://jdbc.postgresql.org/download/postgresql-42.2.5..jar)


You need docker and docker-compose to run it.

For running make simple steps:

1. Clone this repo
2. Change the file pentaho.conf for adding your hosts, ports and names

##### Description of variables used in config file:

| Variable      | Description   | 
| ------------- |:-------------:|
| CPU_LIMIT_SLAVE |[cpus usage limit](https://docs.docker.com/engine/reference/run/#cpu-period-constraint) for SLAVE SERVER|
| CPU_LIMIT_MASTER     | [cpus usage limit](https://docs.docker.com/engine/reference/run/#cpu-period-constraint) for MASTER SERVER|  
| SLAVE_NUMBER | Numbaer of SLAVE server instances |
| MASTER_NUMBER  |  Numbaer of MASTER server instances |
|  PENTAHO_DI_JAVA_OPTIONS_MASTER |  JAVA OPTS for MASTER |
|  PENTAHO_DI_JAVA_OPTIONS_SLAVE |  JAVA OPTS for SLAVE  |
| SERVER_NAME  | name for SLAVE server in pentaho xml config file  |
| SERVER_HOST  | hostname  for SLAVE server in pentaho xml config file  |
| SERVER_PORT | port  for SLAVE server in pentaho xml config file |
| SERVER_USER  | username for SLAVE server in pentaho xml config file |
| SERVER_PASSWD  | password  for SLAVE server in pentaho xml config file |
|  MASTER_%VARNAME% |  the same variables for MASTER description in slave config |


3. run the run.sh

What it done for you:

 - generates separated dirs for each master or slave
 - generate docker-compose in this dirs for master or slave
 - generate dirs for persistent volumes for logging and fixes permissions for them
 - runs all your master and slaves in daemon mode of docker-compose
 - check the opened ports for instances of PDI cluster (needed installed curl in system)




