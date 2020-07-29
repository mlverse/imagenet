FROM mlverse/mlverse-base:version-0.2.3

RUN R --quiet -e 'install.packages("tensorflow")'
RUN R --quiet -e 'install.packages("keras")'
RUN R --quiet -e 'install.packages("sparklyr")'
RUN R --quiet -e 'install.packages("remotes")'

RUN R --quiet -e 'remotes::install_github("rstudio/pins")'
RUN R --quiet -e 'remotes::install_github("r-tensorflow/alexnet")'

RUN R --quiet -e 'reticulate::install_miniconda()'
RUN R --quiet -e 'tensorflow::install_tensorflow(version = "gpu")'

RUN R --quiet -e 'sparklyr::spark_install()'

CMD rstudio-server start & tail -f /dev/null
