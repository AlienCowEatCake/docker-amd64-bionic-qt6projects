# docker-amd64-bionic-qt6projects
Dockerfile for Ubuntu 18.04 build environment for Qt 6.x projects

## Build

```bash
docker build --platform linux/amd64 -t aliencoweatcake/amd64-bionic-qt6projects:qt6.8.1u1 .
docker build --platform linux/arm64 -t aliencoweatcake/arm64-bionic-qt6projects:qt6.8.1u1 .
docker build --platform linux/i386 -t aliencoweatcake/i386-bionic-qt6projects:qt6.8.1u1 .
```

## Docker Hub

* https://hub.docker.com/r/aliencoweatcake/amd64-bionic-qt6projects
* https://hub.docker.com/r/aliencoweatcake/arm64-bionic-qt6projects
* https://hub.docker.com/r/aliencoweatcake/i386-bionic-qt6projects
