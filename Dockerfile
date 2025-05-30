# Use Ubuntu as base image
FROM ubuntu:22.04

# Install cron
RUN apt-get update && apt-get install -y cron

# Create the log file to be able to run tail
RUN touch /var/log/cron.log

# Copy the script
COPY script.sh /usr/local/bin/script.sh
RUN chmod +x /usr/local/bin/script.sh

# Create the cron job
RUN echo "0 0 * * * /usr/local/bin/script.sh >> /var/log/cron.log 2>&1" > /etc/cron.d/my-cron-job

# Give execution rights on the cron job
RUN chmod 0644 /etc/cron.d/my-cron-job

# Apply cron job
RUN crontab /etc/cron.d/my-cron-job

# Create the entrypoint script
RUN echo '#!/bin/bash\nservice cron start\ntail -f /var/log/cron.log' > /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Run the entrypoint script
ENTRYPOINT ["/entrypoint.sh"]