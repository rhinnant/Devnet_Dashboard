# Base image
FROM python:3.11-slim

# Prevent python buffering logs
ENV PYTHONUNBUFFERED=1

# Work directory
WORKDIR /app

# Install system deps
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install dependencies first (better caching)
COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# Copy project
COPY . .

# Expose port (IMPORTANT: match gunicorn)
EXPOSE 8000

# Run gunicorn (adjust "myproject.wsgi:application" if needed)
CMD ["gunicorn", "myproject.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]
