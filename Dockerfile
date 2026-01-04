FROM ubuntu:24.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install essential tools
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    build-essential \
    ca-certificates \
    curl \
    git \
    gnupg \
    jq \
    less \
    locales \
    man-db \
    nano \
    openssh-client \
    python3 \
    python3-pip \
    rsync \
    sudo \
    unzip \
    vim \
    wget \
    zip \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20.x
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install Google Cloud SDK
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | \
    tee /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
    gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    apt-get update && apt-get install -y google-cloud-cli && \
    rm -rf /var/lib/apt/lists/*

# Install Firebase CLI and Gemini CLI globally
RUN npm install -g firebase-tools @google/gemini-cli

# Set up locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Create dev user with UID/GID matching host (1000:1000)
ARG USER_ID=1000
ARG GROUP_ID=1000

# Remove existing ubuntu user if present, then create dev user
RUN userdel -r ubuntu 2>/dev/null || true && \
    groupdel ubuntu 2>/dev/null || true && \
    if ! getent group ${GROUP_ID} > /dev/null 2>&1; then \
        groupadd -g ${GROUP_ID} dev; \
    fi && \
    useradd -m -u ${USER_ID} -g ${GROUP_ID} -s /bin/bash dev && \
    echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create directories that will be used for mounts
RUN mkdir -p /home/dev/src \
    /home/dev/.claude \
    /home/dev/.local/share/claude \
    /home/dev/.local/bin \
    /home/dev/.config/gcloud \
    /home/dev/.config/firebase \
    /home/dev/.config/configstore \
    /home/dev/.gemini && \
    chown -R dev:dev /home/dev

# Set up PATH for Claude CLI
ENV PATH="/home/dev/.local/bin:${PATH}"

# Switch to dev user
USER dev
WORKDIR /home/dev

# Set up shell prompt with container indicator
RUN echo 'PS1="[\[\e[1;36m\]yolo\[\e[0m\]] \[\e[1;32m\]\u\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ "' >> /home/dev/.bashrc

# Add helpful aliases
RUN echo 'alias ll="ls -la"' >> /home/dev/.bashrc && \
    echo 'alias src="cd ~/src"' >> /home/dev/.bashrc

# Default working directory
WORKDIR /home/dev/src

# Keep container running
CMD ["sleep", "infinity"]
