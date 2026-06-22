import modal

app = modal.App("download-video-model")
model_volume = modal.Volume.from_name("scenolytics-models")
MODEL_DIR = "/app/models"

@app.function(
    volumes={MODEL_DIR: model_volume},
    timeout=300,
)
def download():
    import urllib.request
    import os
    
    url = "https://github.com/abdelrahman218/Scenolytics/releases/download/tag2/best_video_emotion_model.h5"
    dest = f"{MODEL_DIR}/best_video_emotion_model.h5"
    
    print(f"Downloading to {dest}...")
    urllib.request.urlretrieve(url, dest)
    print(f"Done. Size: {os.path.getsize(dest) / 1024/1024:.1f} MB")
    model_volume.commit()
    print("Volume committed.")

@app.local_entrypoint()
def main():
    download.remote()