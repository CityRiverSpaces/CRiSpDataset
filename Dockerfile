FROM rocker/r2u:latest

WORKDIR /project
COPY DESCRIPTION DESCRIPTION

RUN R -e "install.packages('devtools')"
RUN R -e "devtools::install_deps()"

CMD ["R"]
