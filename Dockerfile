FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html dashboard.html release.html styles.css main.js cube.js /usr/share/nginx/html/

# Build-time version, served at /version.txt and shown in the footer.
# Also added to the CSS/JS links (styles.css?v=<version>), so each deploy uses new
# URLs and no browser can keep showing an old cached file.
ARG VERSION=dev
RUN echo "$VERSION" > /usr/share/nginx/html/version.txt \
 && sed -i -E "s/(styles\.css|main\.js|cube\.js)\"/\1?v=${VERSION}\"/g" /usr/share/nginx/html/*.html

EXPOSE 80
