FROM python:3.12-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install headless browser for patchright/playwright
RUN patchright install --with-deps chromium

# Copy the backend code
# Since the docker-compose context is the backend folder, 
# this copies the contents of backend/ into /app/backend/
COPY . /app/backend

# Set python path so that `import backend.api` works
ENV PYTHONPATH=/app

EXPOSE 8080

CMD ["uvicorn", "backend.api:app", "--host", "0.0.0.0", "--port", "8080"]
