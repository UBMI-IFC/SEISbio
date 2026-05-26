FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    sudo \
    ca-certificates \
    curl \
    wget \
    git \
    procps \
  && rm -rf /var/lib/apt/lists/*

RUN curl -L -o /tmp/miniforge.sh https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh \
  && bash /tmp/miniforge.sh -b -p /opt/miniforge \
  && rm /tmp/miniforge.sh

RUN groupadd -g 1000 tutorial \
  && useradd -m -s /bin/bash -u 1000 -g 1000 tutorial \
  && echo "tutorial ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/tutorial \
  && chmod 0440 /etc/sudoers.d/tutorial \
  && chown -R tutorial:tutorial /opt/miniforge \
  && mkdir -p /home/tutorial \
  && chown -R tutorial:tutorial /home/tutorial

COPY docker/sandbox-entrypoint.sh /usr/local/bin/sandbox-entrypoint
RUN chmod +x /usr/local/bin/sandbox-entrypoint

USER tutorial
ENV PATH="/opt/miniforge/bin:$PATH"
ENV CONDA_PKGS_DIRS="/home/tutorial/.conda/pkgs"
ENV CONDA_ENVS_DIRS="/home/tutorial/.conda/envs"
WORKDIR /home/tutorial

ENTRYPOINT ["sandbox-entrypoint"]
CMD ["bash", "-lc", "sleep infinity"]
