# Use an official nginx image as a parent image
FROM nginx:latest

# Remove default nginx static resources
RUN rm -rf /usr/share/nginx/html/*

# Copy static resources from current directory to the nginx container
COPY . /usr/share/nginx/html

# Expose port 3000
EXPOSE 3000

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
