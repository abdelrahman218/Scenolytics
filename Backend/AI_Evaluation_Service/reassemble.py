# delete_empty.py
import modal
app = modal.App("fix-volume")
model_volume = modal.Volume.from_name("scenolytics-models")

@app.function(volumes={"/models": model_volume})
def fix():
    import os
    os.remove("/models/emotion-recognition-final/model.safetensors")
    model_volume.commit()
    print("Deleted empty file")

@app.local_entrypoint()
def main():
    fix.remote()