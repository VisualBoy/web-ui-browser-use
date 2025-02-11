FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    netcat-traditional \
    gnupg \
    curl \
    unzip \
    xvfb \
    libgconf-2-4 \
    libxss1 \
    libnss3 \
    libnspr4 \
    libasound2 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    xdg-utils \
    fonts-liberation \
    dbus \
    xauth \
    xvfb \
    x11vnc \
    tigervnc-tools \
    supervisor \
    net-tools \
    procps \
    git \
    python3-numpy \
    fontconfig \
    fonts-dejavu \
    fonts-dejavu-core \
    fonts-dejavu-extra \
    tinyproxy \
    && rm -rf /var/lib/apt/lists/*

# Update tinyproxy configuration
RUN sed -i 's/^#Allow 127.0.0.1/Allow 0.0.0.0\/0/' /etc/tinyproxy/tinyproxy.conf \
    && echo "ConnectPort 443" >> /etc/tinyproxy/tinyproxy.conf \
    && echo "ConnectPort 563" >> /etc/tinyproxy/tinyproxy.conf \
    && echo "MaxClients 100" >> /etc/tinyproxy/tinyproxy.conf

# Add tinyproxy to supervisor
RUN echo "[program:tinyproxy]" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "command=/usr/sbin/tinyproxy -d" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "autostart=true" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "autorestart=true" >> /etc/supervisor/conf.d/supervisord.conf

# Install noVNC
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc \
    && git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify \
    && ln -s /opt/novnc/vnc.html /opt/novnc/index.html

# Install Chrome
RUN curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list

# Set up working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install Playwright and browsers with system dependencies
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
RUN playwright install --with-deps chromium \
    && playwright install-deps \
    && apt-get install -y google-chrome-stable

# Copy the application code
COPY . .

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    BROWSER_USE_LOGGING_LEVEL=info \
    CHROME_PATH=/usr/bin/google-chrome \
    ANONYMIZED_TELEMETRY=false \
    DISPLAY=:99 \
    RESOLUTION=1920x1080x24 \
    VNC_PASSWORD=vncpassword \
    CHROME_PERSISTENT_SESSION=true \
    RESOLUTION_WIDTH=1920 \
    RESOLUTION_HEIGHT=1080

# Set up supervisor configuration
RUN mkdir -p /var/log/supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 7788 6080 5900

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
