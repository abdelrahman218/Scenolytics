FROM python:3.11-slim

WORKDIR /app

# Install only what's needed
RUN apt-get update && apt-get install -y --no-install-recommends \
    libopenblas-dev \
    liblapack-dev \
    libgomp1 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --upgrade pip

# Install PyTorch (CPU only, smaller)
RUN pip install --no-cache-dir \
    torch==2.4.0 torchaudio==2.4.0 \
    --index-url https://download.pytorch.org/whl/cpu

# Install core stack
RUN pip install --no-cache-dir \
    numpy==1.26.4 \
    tensorflow==2.15.0 \
    tf_keras==2.15.0 \
    keras==2.15.0 \
    h5py==3.10.0 \
    protobuf==4.25.3

# Install rest
RUN pip install --no-cache-dir -r requirements.txt

# Final cleanup (important)
RUN pip cache purge

COPY . .

EXPOSE 5012

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5012"]