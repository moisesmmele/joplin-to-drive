FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# add user
RUN useradd -d 1000 -m -s /bin/bash appuser

# Install dependencies
RUN apt-get update && \
	apt-get install -y \
	curl \
	gnupg \
	unzip \
	cron \
	ca-certificates\
	nano \
	nodejs \
	npm \
	rclone && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

# Install joplin CLI globally
RUN npm install -g joplin --unsafe-perm=true --allow-root

# Setup directories
RUN \	
	# create directories
	mkdir -p /config/joplin /config/rclone /export /scripts /var/log && \
	# set proper dir ownership
	chown -R appuser:appuser /config /export /scripts /var/log && \
	

# copy scripts
COPY joplin-cron /etc/cron.d/joplin-cron
COPY joplin-export.sh /scripts/joplin-export.sh


# set permissions, ownership and symlinks
RUN \
	# set execution policy
	chmod +x /scripts/joplin-export.sh && \
	chmod 0644 /etc/cron.d/joplin-cron && \


	# Symlink configfiles to expected path
	mkdir -p /root/.config && \
	ln -s /config/joplin /root/.config/joplin && \
	mkdir -p /root/.config/rclone && \
	ln -s /config/rclone/rclone.conf /root/.config/rclone/rclone.conf && \

	# Ensure appuser ownership of their home directory
	chown -R appuser:appuser /home/appuser

CMD ["cron", "-f"]
