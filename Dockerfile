# Pull Base Image
FROM java:8-jre

ENV SERVICE_HOME=/home/pdi \
    POSTGRESQL_DRIVER_VERSION=42.2.5 \
    PDI_VERSION=8.1 \
    PDI_BUILD=8.1.0.0-365 \
    PDI_USER=pdi

# add non root user to run pdi as
RUN useradd -md $SERVICE_HOME -s /bin/bash $PDI_USER

# switch to workdir
WORKDIR ${SERVICE_HOME}

# Prepare SERVICE files
ENV PDI_DIR=${SERVICE_HOME}/data-integration
COPY ./jdbc-libs jdbc-libs/

# Download latest Postgres JDBC Driver
RUN wget --progress=dot:giga https://jdbc.postgresql.org/download/postgresql-${POSTGRESQL_DRIVER_VERSION}.jar -P ${SERVICE_HOME}/jdbc-libs/

# Download Pentaho Data Integration Community Edition and Unpack
RUN wget --progress=dot:giga http://downloads.sourceforge.net/project/pentaho/Pentaho%20${PDI_VERSION}/client-tools/pdi-ce-${PDI_BUILD}.zip \
	&& unzip -q *.zip \
	&& rm -f *.zip

# Add Entry Point and Templates
COPY docker-entrypoint.sh ${PDI_DIR}/docker-entrypoint.sh
RUN chmod +x ${PDI_DIR}/docker-entrypoint.sh

# Update JDBC Drivers in Pentaho DI
# Update Postgres JDBC Driver
RUN echo $PDI_DIR
RUN rm -f ${PDI_DIR}/lib/postgre*.jar && cp -rv ${SERVICE_HOME}/jdbc-libs/postgresql-${POSTGRESQL_DRIVER_VERSION}.jar ${PDI_DIR}/lib/
# Update MSSQL JDBC Driver
RUN tar -zxvf ${SERVICE_HOME}/jdbc-libs/sqljdbc_7.2.1.0_enu.tar.gz -C ${SERVICE_HOME}/jdbc-libs/ \
	&& cp ${SERVICE_HOME}/jdbc-libs/sqljdbc_7.2/enu/mssql-jdbc-7.2.1.jre8.jar ${PDI_DIR}/lib/ \
	&& cp ${SERVICE_HOME}/jdbc-libs/sqljdbc_7.2/enu/auth/x86/sqljdbc_auth.dll ${PDI_DIR}/libswt/win64/

# FiX PERMS for future Volumes
RUN chown -R $PDI_USER:$PDI_USER ${SERVICE_HOME}/ && \
    chown -R $PDI_USER:$PDI_USER /tmp

USER $PDI_USER
WORKDIR ${PDI_DIR}
ENTRYPOINT ["./docker-entrypoint.sh"]
EXPOSE $SERVER_PORT
