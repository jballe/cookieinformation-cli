ARG BASE_IMAGE
FROM ${BASE_IMAGE}
WORKDIR /app
ADD cookieinformation.ps1 .
ENTRYPOINT ["pwsh", "/app/cookieinformation.ps1"]
CMD "-Help"