FROM openjdk:11-slim

# Install Ant
RUN apt-get update && \
    apt-get install -y ant && \
    apt-get clean

WORKDIR /app
COPY . .

# Build with Ant
RUN ant build

# Deploy to Tomcat
FROM tomcat:9-jre11-slim
COPY --from=0 /app/dist/*.war /usr/local/tomcat/webapps/ROOT.war
EXPOSE 8080
CMD ["catalina.sh", "run"]
