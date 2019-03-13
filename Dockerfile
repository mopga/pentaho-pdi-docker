# Pull Base Image
FROM java:8

# Set Environment Variables
ENV PDI_VERSION=8.1 PDI_BUILD=8.1.0.0-365 \
	KETTLE_HOME=/data-integration \
	POSTGRESQL_DRIVER_VERSION=42.2.5 

# Install Required Packages
RUN apt-get update \
	&& apt-get install -y libwebkitgtk-1.0-0 zip unzip \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

# Download Pentaho Data Integration Community Edition and Unpack
RUN wget --progress=dot:giga http://downloads.sourceforge.net/project/pentaho/Pentaho%20${PDI_VERSION}/client-tools/pdi-ce-${PDI_BUILD}.zip \
	&& unzip -q *.zip \
	&& rm -f *.zip

# Add Entry Point and Templates
COPY docker-entrypoint.sh $KETTLE_HOME/docker-entrypoint.sh

# Switch Directory
WORKDIR $KETTLE_HOME

#Update JDBC Drivers
RUN wget --progress=dot:giga https://jdbc.postgresql.org/download/postgresql-${POSTGRESQL_DRIVER_VERSION}.jar \
	&& rm -f lib/postgre*.jar \
	&& mv *.jar lib/.

RUN chmod +x ./docker-entrypoint.sh

ENTRYPOINT ["./docker-entrypoint.sh"]

EXPOSE ${SERVER_PORT}

#CMD ["slave"]
