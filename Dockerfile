# Use the official Ubuntu base image
FROM nvidia/cuda:12.2.0-base-ubuntu20.04

# Set DEBIAN_FRONTEND to noninteractive to prevent timezone prompts
ENV DEBIAN_FRONTEND=noninteractive

# Update package lists and install necessary packages
RUN apt-get update && \
    apt-get install -y fonts-dejavu-core rsync git jq moreutils aria2 wget libgoogle-perftools-dev procps libgl1-mesa-glx libglib2.0-0 && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean -y

# Install build essentials and Python dependencies
RUN apt-get update && \
    apt-get install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev && \
    wget https://www.python.org/ftp/python/3.10.9/Python-3.10.9.tar.xz && \
    tar -xf Python-3.10.9.tar.xz && \
    cd Python-3.10.9 && \
    ./configure --enable-optimizations && \
    make -j$(nproc) && \
    make altinstall && \
    cd .. && \
    rm -rf Python-3.10.9 Python-3.10.9.tar.xz && \
    apt-get install -y python3-pip && \
    ln -s /usr/local/bin/pip3.10 /usr/local/bin/pip && \
    python3.10 --version \
    pip --version

# Create symbolic links for python
RUN ln -s /usr/local/bin/python3.10 /usr/local/bin/python

ADD src .

# Cleanup section (Worker Template)
RUN apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

RUN chmod +x /start.sh
CMD /start.sh