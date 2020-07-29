FROM mlverse/mlverse-base:version-0.2.3

USER rstudio

RUN echo "Invalidate Cache: $RANDOM" && R --quiet -e 'install.packages("tensorflow")'
RUN echo "Invalidate Cache: $RANDOM" && R --quiet -e 'install.packages("keras")'
RUN echo "Invalidate Cache: $RANDOM" && R --quiet -e 'install.packages("sparklyr")'
RUN echo "Invalidate Cache: $RANDOM" && R --quiet -e 'install.packages("remotes")'

RUN echo "Invalidate Cache: $RANDOM" && R --quiet -e 'remotes::install_github("rstudio/pins")'
RUN echo "Invalidate Cache: $RANDOM" && R --quiet -e 'remotes::install_github("r-tensorflow/alexnet")'

RUN echo "Invalidate Cache: $RANDOM" && R --quiet -e 'reticulate::install_miniconda()'
RUN echo "Invalidate Cache: $RANDOM" && R --quiet -e 'tensorflow::install_tensorflow(version = "gpu")'

RUN echo "Invalidate Cache: $RANDOM" && R --quiet -e 'sparklyr::spark_install()'

CMD rstudio-server start & tail -f /dev/null
