FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
	apt-get install -y \
	curl \
	gnupg \
	unzip \
	cron \
	ca-certificates\
	nodejs \
	npm \
	rclone && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

# Install joplin CLI globally
RUN npm install -g joplin --unsafe-perm=true --allow-root

# add user
RUN useradd -d 1000 -m -s /bin/bash appuser

# Setup directories
RUN \	
	# create directories
	mkdir -p /config/joplin /config/rclone /export /scripts /var/log && \
	# set proper dir ownership
	chown -R appuser:appuser /config /export /scripts /var/log && \
	

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh

# Make entrypoint executable
RUN chmod +x /entrypoint.sh

# START
ENTRYPOINT ["/entrypoint.sh"]
