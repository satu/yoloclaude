FROM ubuntu:24.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install essential tools
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    build-essential \
    ca-certificates \
    curl \
    ffmpeg \
    git \
    gnupg \
    jq \
    less \
    locales \
    man-db \
    nano \
    openjdk-21-jdk \
    openssh-client \
    python3 \
    python3-pip \
    rsync \
    sudo \
    tmux \
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

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
    tee /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# Install Firebase CLI and Gemini CLI globally
RUN npm install -g firebase-tools @google/gemini-cli

# Set up locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Create user with UID/GID/username matching host
ARG USERNAME=dev
ARG USER_ID=1000
ARG GROUP_ID=1000

# Remove existing ubuntu user if present, then create user matching host
RUN userdel -r ubuntu 2>/dev/null || true && \
    groupdel ubuntu 2>/dev/null || true && \
    if ! getent group ${GROUP_ID} > /dev/null 2>&1; then \
        groupadd -g ${GROUP_ID} ${USERNAME}; \
    fi && \
    useradd -m -u ${USER_ID} -g ${GROUP_ID} -s /bin/bash ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create directories that will be used for mounts
RUN mkdir -p /home/${USERNAME}/src \
    /home/${USERNAME}/.claude \
    /home/${USERNAME}/.local/share/claude \
    /home/${USERNAME}/.local/bin \
    /home/${USERNAME}/.config/gcloud \
    /home/${USERNAME}/.config/firebase \
    /home/${USERNAME}/.config/configstore \
    /home/${USERNAME}/.gemini && \
    chown -R ${USERNAME}:${GROUP_ID} /home/${USERNAME}

# Set up PATH for Claude CLI
ENV PATH="/home/${USERNAME}/.local/bin:${PATH}"

# Switch to user
USER ${USERNAME}
WORKDIR /home/${USERNAME}

# Set up shell prompt with container indicator
RUN echo 'PS1="[\[\e[1;36m\]yolo\[\e[0m\]] \[\e[1;32m\]\u\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ "' >> ~/.bashrc

# Add helpful aliases
RUN echo 'alias ll="ls -la"' >> ~/.bashrc && \
    echo 'alias src="cd ~/src"' >> ~/.bashrc

# Default working directory
WORKDIR /home/${USERNAME}/src

# Keep container running
CMD ["sleep", "infinity"]
