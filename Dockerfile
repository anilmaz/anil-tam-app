FROM nginx:alpine

# Copy your frontend files into Nginx's web root
COPY index.html style.css /usr/share/nginx/html/

# Expose port 80
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]