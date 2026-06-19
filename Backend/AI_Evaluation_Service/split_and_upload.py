# split.py
def split_file(path, chunk_size=40*1024*1024):
    with open(path, 'rb') as f:
        i = 0
        while chunk := f.read(chunk_size):
            out = f"{path}.part{i:03d}"
            with open(out, 'wb') as o:
                o.write(chunk)
            print(f"Created {out} ({len(chunk)/1024/1024:.1f} MB)")
            i += 1

split_file(r"D:\Year 4\Scenolytics\backend\AI_Evaluation_Service\models\emotion-recognition-final\model.safetensors")