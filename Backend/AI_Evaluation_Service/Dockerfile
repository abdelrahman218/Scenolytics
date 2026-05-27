FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --upgrade pip

# PyTorch CPU only
RUN pip install --no-cache-dir \
    torch==2.4.0 torchaudio==2.4.0 \
    --index-url https://download.pytorch.org/whl/cpu

# Core stack
RUN pip install --no-cache-dir \
    numpy==1.26.4 \
    tensorflow==2.15.0 \
    tf_keras==2.15.0 \
    keras==2.15.0 \
    h5py==3.10.0 \
    protobuf==4.25.3
RUN apt-get update && \
    apt-get install -y \
        libavutil56 libavcodec58 libavformat58 \
        libswresample3 libswscale5 \
    && rm -rf /var/lib/apt/lists/*
# Install rest
RUN pip install --no-cache-dir -r requirements.txt

# Re-pin numpy LAST (mediapipe upgrades it)
RUN pip install --no-cache-dir "numpy==1.26.4" --force-reinstall

RUN pip cache purge

COPY . .

EXPOSE 5009

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5009"]