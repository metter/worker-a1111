FROM python:3.10-slim

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip    