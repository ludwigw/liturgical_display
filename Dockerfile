FROM debian:bookworm

# System dependencies
RUN apt-get update && apt-get install -y \
    git python3 python3-pip python3-venv \
    libjpeg-dev libopenjp2-7-dev imagemagick build-essential sudo

# Create non-root user
RUN useradd -ms /bin/bash pi

# Configure sudo access for pi user
RUN echo "pi ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER pi
WORKDIR /home/pi/liturgical_display

# Copy project files and change ownership
COPY --chown=pi:pi . /home/pi/liturgical_display

# Install Python dependencies in a virtual environment
RUN python3 -m venv /home/pi/venv --clear
RUN /home/pi/venv/bin/pip install --upgrade pip && /home/pi/venv/bin/pip install -r requirements.txt
ENV PATH="/home/pi/venv/bin:$PATH"

# All other dependencies (including liturgical-calendar) are installed by setup.sh

# Ensure bin/ exists and add mock epdraw
RUN mkdir -p bin && \
    echo '#!/bin/bash' > bin/epdraw && \
    echo 'echo "Mock epdraw called with: $@" >> /tmp/epdraw_mock.log' >> bin/epdraw && \
    echo 'exit 0' >> bin/epdraw && \
    chmod +x bin/epdraw

# Update the CMD or ENTRYPOINT to use the new main.py location
CMD ["python3", "-m", "liturgical_display.main"] 