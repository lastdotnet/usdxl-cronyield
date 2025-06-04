# Use Ubuntu as base image
FROM --platform=linux/amd64 ubuntu:22.04

# Install required packages
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    libssl-dev \
    pkg-config \
    bash \
    && rm -rf /var/lib/apt/lists/*


# Create app directory
WORKDIR /app

# Copy the script
COPY script.sh /app/script.sh

# Make script executable
RUN chmod +x /app/script.sh

# Default command (will be overridden by ECS task)
CMD ["/bin/bash", "-c", "/app/script.sh"]