FROM nginx:alpine

# Copiar archivos compilados de Flutter Web
COPY public /usr/share/nginx/html

# Copiar configuración personalizada de Nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80 10000

CMD ["nginx", "-g", "daemon off;"]
