FROM node:18-alpine

WORKDIR /app

# Copiar package.json
COPY package.json ./

# Instalar dependencias
RUN npm install --production

# Copiar código
COPY server.js ./

EXPOSE 3000

CMD ["node", "server.js"]
