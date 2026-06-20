FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --upgrade pip

# PyTorch with CUDA 12.1 support (T4 GPU on Modal)
RUN pip install --no-cache-dir \
    torch==2.4.0 torchaudio==2.4.0 \
    --index-url https://download.pytorch.org/whl/cu121

# Core stack
RUN pip install --no-cache-dir \
    numpy==1.26.4 \
    tensorflow==2.15.0 \
    tf_keras==2.15.0 \
    keras==2.15.0 \
    h5py==3.10.0 \
    protobuf==4.25.3

# Install rest
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir --no-deps whisperx==3.8.6 && \
    pip install --no-cache-dir ctranslate2 faster-whisper nltk pandas && \
    python -c "import whisperx; print(whisperx.load_align_model)"
RUN pip install --no-cache-dir "protobuf==4.25.3" --force-reinstall    
# Re-pin numpy LAST (mediapipe upgrades it)
RUN pip install --no-cache-dir "numpy==1.26.4" --force-reinstall

COPY . .

EXPOSE 5012

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5012"]