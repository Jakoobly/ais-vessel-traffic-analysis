FROM rocker/shiny:4.3.3

USER root

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      libcurl4-openssl-dev \
      libssl-dev \
      libxml2-dev \
      libcairo2-dev \
      libpng-dev \
      libjpeg-dev && \
    rm -rf /var/lib/apt/lists/*

RUN R -e 'install.packages(c("dplyr", "ggplot2", "readr", "shiny"), repos = "https://cloud.r-project.org")'

EXPOSE 3838
USER shiny
CMD ["shiny-server"]
