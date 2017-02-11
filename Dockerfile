FROM ubuntu:14.04
USER root

RUN apt-get update && apt-get install -y \
	wget \
	bzip2 \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Install Tini
RUN wget --quiet https://github.com/krallin/tini/releases/download/v0.10.0/tini && \
    echo "1361527f39190a7338a0b434bd8c88ff7233ce7b9a4876f3315c22fce7eca1b0 *tini" | sha256sum -c - && \
    mv tini /usr/local/bin/tini && \
    chmod +x /usr/local/bin/tini

# Configure environment
ENV CONDA_DIR /opt/conda
ENV PATH $CONDA_DIR/bin:$PATH
ENV SHELL /bin/bash
ENV NB_USER wcheng
ENV NB_UID 1000
ENV HOME /home/$NB_USER
ENV LANG en_US.UTF-8

# Create notebook user with UID=1000 and in the 'users' group
RUN useradd -m -s /bin/bash -N -u $NB_UID $NB_USER && \
    mkdir -p $CONDA_DIR && \
    chown $NB_USER $CONDA_DIR

USER $NB_USER

# Setup notebook user home directory
RUN mkdir -p /home/$NB_USER/work && \
    mkdir -p /home/$NB_USER/.jupyter	

# Install conda with python 2.7 as notebook user
RUN cd /tmp && \
    mkdir -p $CONDA_DIR && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda2-latest-Linux-x86_64.sh && \
    /bin/bash Miniconda2-latest-Linux-x86_64.sh -f -b -p $CONDA_DIR && \
    rm Miniconda2-latest-Linux-x86_64.sh && \
    $CONDA_DIR/bin/conda update --quiet --yes conda && \
    $CONDA_DIR/bin/conda config --system --add channels conda-forge && \
    $CONDA_DIR/bin/conda config --system --set auto_update_conda false && \
    conda clean -tipsy

# Install Jupyter notebook as notebook user
RUN conda install --quiet --yes \
    notebook \
    scikit-learn \
    matplotlib \
    seaborn \
    nltk \
    pandas \
    && conda clean -tipsy

# Download all NLTK data
RUN python -m nltk.downloader -q all && \
    find ~/nltk_data -name '*.zip' | xargs rm

# Above is the core and any other additional packages add here
RUN conda install --quiet --yes \
	mpld3 \
	&& conda clean -tipsy

USER root

EXPOSE 8888
WORKDIR /home/$NB_USER/work

# Configure container startup
ENTRYPOINT ["tini", "--"]
CMD ["start-notebook.sh"]

# Add local files as late as possible to avoid cache busting
COPY start.sh /usr/local/bin/
COPY start-notebook.sh /usr/local/bin/
COPY jupyter_notebook_config.py /home/$NB_USER/.jupyter/
RUN chown -R $NB_USER:users /home/$NB_USER/.jupyter

# Switch back to notebook user to avoid accidental container runs as root
USER $NB_USER
