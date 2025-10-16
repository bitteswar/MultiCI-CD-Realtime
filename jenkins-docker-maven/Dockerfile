# Start from the official Jenkins LTS image with JDK 17
FROM jenkins/jenkins:lts-jdk17

USER root

# Install Docker CLI and Maven
RUN apt-get update && \
    apt-get install -y docker.io maven && \
    apt-get clean

# Add jenkins user to docker group to avoid permission issues
RUN usermod -aG docker jenkins

USER jenkins
