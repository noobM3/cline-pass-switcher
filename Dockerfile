FROM node:22-alpine
WORKDIR /app
COPY package.json server.js ./
COPY public ./public
RUN mkdir -p /app/data
ENV DATA_DIR=/app/data
ENV BIND_HOST=0.0.0.0
EXPOSE 3123
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:3123/health').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"
CMD ["node", "server.js"]
