FROM node:24
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
RUN useradd -m -u 1000 user || (userdel -r node && useradd -m -u 1000 user)
USER user
ENV HOME=/home/user NPM_CONFIG_PREFIX=/home/user/.npm-global PATH=/home/user/.npm-global/bin:$PATH
RUN npm i -g omniroute@3.8.51 && omniroute --version
COPY --chown=user key-proxy.mjs entrypoint.sh /app/
EXPOSE 7860
CMD ["bash","/app/entrypoint.sh"]
