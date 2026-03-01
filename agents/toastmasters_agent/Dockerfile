# Same as web_search folder: curl-impersonate base so curl_chrome110 + binary + libs all work
FROM lwthiker/curl-impersonate:0.6-chrome

# Install Python and build deps (Alpine) — same pattern as web_search Dockerfile
RUN apk add --no-cache \
    python3 \
    py3-pip \
    curl \
    build-base \
    musl-dev \
    python3-dev \
    gcc \
    g++ \
    make

WORKDIR /app

COPY requirements.txt .
RUN pip3 install --no-cache-dir --upgrade pip && \
    pip3 install --no-cache-dir -r requirements.txt

COPY . .

ENV PORT=8080
EXPOSE 8080

CMD ["sh", "-c", "exec gunicorn --bind 0.0.0.0:${PORT:-8080} --workers 1 --worker-class uvicorn.workers.UvicornWorker --timeout 0 app:app"]
