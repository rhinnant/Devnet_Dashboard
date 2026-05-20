# 1. Base image
FROM python:3.12-slim

# 2. Prevent Python from writing pyc files
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# 3. Set working directory
WORKDIR /app

# 4. Install system dependencies (important for Django + security tools)
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# 5. Copy requirements first (better caching)
COPY requirements.txt /app/

# 6. Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# 7. Copy project files
COPY . /app/

# 8. Run migrations (optional but common)
RUN python manage.py migrate --noinput || true

# 9. Collect static files (optional)
RUN python manage.py collectstatic --noinput || true

# 10. Expose port
EXPOSE 8000

# 11. Run app with Gunicorn
CMD ["gunicorn", "myproject.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]
