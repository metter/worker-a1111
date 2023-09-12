
FROM python:3.10.9-slim

RUN git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
    cd stable-diffusion-webui && \
    git reset --hard 89f9faa63388756314e8a1d96cf86bf5e0663045 && \
    python launch.py --skip-cuda-test --exit  

ADD src .

# Cleanup section (Worker Template)
RUN apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

RUN chmod +x /start.sh
CMD /start.sh
