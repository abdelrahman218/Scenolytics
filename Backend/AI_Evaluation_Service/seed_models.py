import modal
import os

app = modal.App("seed-models")
volume = modal.Volume.from_name("scenolytics-models", create_if_missing=True)

image = (
    modal.Image.debian_slim()
    .add_local_dir(
        r"D:\Year 4\Scenolytics\Backend\AI_Evaluation_Service\models\seamless-m4t-v2-large",
        remote_path="/mnt/seamless"
    )
    .add_local_dir(
        r"D:\Year 4\Scenolytics\Backend\AI_Evaluation_Service\models\emotion-recognition-final",
        remote_path="/mnt/emotion"
    )
)

@app.function(
    image=image,
    volumes={"/app/models": volume},
    timeout=3600,
)
def seed():
    import shutil

    for src, dst in [
        ("/mnt/seamless", "/app/models/seamless-m4t-v2-large"),
        ("/mnt/emotion",  "/app/models/emotion-recognition-final"),
    ]:
        if not os.path.exists(dst):
            print(f"Copying {src} -> {dst}...")
            shutil.copytree(src, dst)
            print("Done.")
        else:
            print(f"{dst} already exists, skipping.")

    volume.commit()
    print("Volume seeded.")

@app.local_entrypoint()
def main():
    seed.remote()