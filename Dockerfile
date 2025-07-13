FROM debian:bookworm

# System dependencies
RUN apt-get update && apt-get install -y \
    git python3 python3-pip python3-venv \
    libjpeg-dev libopenjp2-7-dev imagemagick build-essential

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

# Install IT8951-ePaper manually since it doesn't have proper packaging
# RUN git clone https://github.com/ludwigw/IT8951-ePaper.git /tmp/IT8951-ePaper && \
#     cd /tmp/IT8951-ePaper && \
#     git checkout refactir && \
#     pip install -e . || pip install . || echo "IT8951-ePaper installed manually"

# Switch to pi user for remaining operations
USER pi

# Ensure bin/ exists and add mock epdraw
RUN mkdir -p bin && \
    echo '#!/bin/bash' > bin/epdraw && \
    echo 'echo "Mock epdraw called with: $@" >> /tmp/epdraw_mock.log' >> bin/epdraw && \
    echo 'exit 0' >> bin/epdraw && \
    chmod +x bin/epdraw

# Update the CMD or ENTRYPOINT to use the new main.py location
# For example, if you had:
# CMD ["python3", "main.py"]
# Change to:
CMD ["python3", "-m", "liturgical_display.main"] 