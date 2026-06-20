"""
seed_models.py
==============
Server-side Modal function that seeds the `scenolytics-models` Named Volume
with all three models used by MLPipeline:

  1. SeamlessM4T v2 large  -> downloaded from the HuggingFace Hub
                               into  /seamless-m4t-v2-large/

  2. Video emotion model   -> downloaded from a GitHub Release asset
     (best_video_emotion_model.h5, tag2) into the volume root:
                               /best_video_emotion_model.h5

  3. Audio emotion model   -> model.safetensors is split into 31 release
     assets (tag1, model.safetensors.part000 .. part030). This function
     downloads each part, verifies its SHA-256 against the hash published
     on the release page, concatenates them in order into a single
     model.safetensors, and places it into:
                               /emotion-recognition-final/model.safetensors

     NOTE: config.json / preprocessor_config.json / label_mapping.json for
     the audio model are NOT downloaded here -- they live only on your
     local machine. Upload them once with the Modal CLI before (or after)
     running this seeding function:

         modal volume put scenolytics-models \\
             /local/path/to/emotion-recognition-final/config.json \\
             /emotion-recognition-final/config.json

         modal volume put scenolytics-models \\
             /local/path/to/emotion-recognition-final/preprocessor_config.json \\
             /emotion-recognition-final/preprocessor_config.json

         modal volume put scenolytics-models \\
             /local/path/to/emotion-recognition-final/label_mapping.json \\
             /emotion-recognition-final/label_mapping.json

     This function will warn (not fail) if those three files are missing
     from the volume after the safetensors are seeded, so you know to run
     the uploads above.

Usage
-----
    modal run modal_app/seed_models.py

    # Re-download / overwrite even if files already exist in the volume:
    modal run modal_app/seed_models.py --force

    # Seed only one model:
    modal run modal_app/seed_models.py --only seamless
    modal run modal_app/seed_models.py --only video
    modal run modal_app/seed_models.py --only audio
"""

import hashlib
import os
import urllib.request
from pathlib import Path
from typing import Optional

import modal

# ---------------------------------------------------------------------------
# Modal app / volume / image
# ---------------------------------------------------------------------------
VOLUME_NAME       = "scenolytics-models"
VOLUME_MOUNT_PATH = "/models_vol"

volume = modal.Volume.from_name(VOLUME_NAME, create_if_missing=True)

image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install(
        "huggingface_hub[hf_transfer]",
        "requests",
    )
    .env({"HF_HUB_ENABLE_HF_TRANSFER": "1"})
)

app = modal.App("scenolytics-seed-models", image=image)

# ---------------------------------------------------------------------------
# Source locations
# ---------------------------------------------------------------------------
HF_SEAMLESS_REPO = "facebook/seamless-m4t-v2-large"
SEAMLESS_DIRNAME = "seamless-m4t-v2-large"   # volume folder name (plain, no suffix)

VIDEO_MODEL_URL      = (
    "https://github.com/abdelrahman218/Scenolytics/releases/download/"
    "tag2/best_video_emotion_model.h5"
)
VIDEO_MODEL_FILENAME = "best_video_emotion_model.h5"  # lives at volume root

AUDIO_DIRNAME       = "emotion-recognition-final"     # volume folder name
AUDIO_RELEASE_TAG    = "tag1"
AUDIO_PART_COUNT     = 31                              # part000 .. part030
AUDIO_PART_URL_TMPL  = (
    "https://github.com/abdelrahman218/Scenolytics/releases/download/"
    f"{AUDIO_RELEASE_TAG}/model.safetensors.part{{idx:03d}}"
)
AUDIO_REASSEMBLED_FILENAME = "model.safetensors"

# SHA-256 of each part, copied verbatim from the release page, used to
# verify every chunk before it's concatenated into the final file.
AUDIO_PART_SHA256 = {
    0:  "5a3718abe8d05b7e3018372b1b1e49ba6451840ea5781412d776172748c71089",
    1:  "84dd232ddd922c42ab8dfad3485e9007109bc033942ebe24a0776d843ff2165d",
    2:  "6d2aad60cda7001bb59c33f165d2faf71fdc6e39c111043fc61701527f9af3b8",
    3:  "85c43ac8c4930eeb0d94f224f6e93ff3f6d9187b811fc2fd2acf8eda9b489cfe",
    4:  "32bd62e52b3426a1c04acfaccd1fbc1421ce460c0c55b0ca3e1a089ff38dfd09",
    5:  "aa49e0e275e3cac96e23402efb1a37269afcdc9dd5539ae62eb1ecfc3fa92c0f",
    6:  "d994a09c14c6a37be7dd1bacdd36f272635ac99793e569393be83e0899ae4619",
    7:  "dd07c1631eefb7d7ce34802b2b6361a175954102e084788c7a2fad82a8e96678",
    8:  "37b4d67ff41c019bd5948b8d090d199adc175e7393a23829ec007b7be138bfd1",
    9:  "1f6c724a35d3ca8b4de844b38d2c5c889044d3baef8a8af1060dd926db0297f3",
    10: "26842f3ac8a10549071d3563f685f4745f5f71749c168c7d9689633ae327db0d",
    11: "8d876ccf432fa59123e9cbd40279bbe7248b304b917cd9180762307c55811a86",
    12: "7b1d83196c284b3eeecda572ad90ce69baa4e8ec25c46642d2f385245c5c9aed",
    13: "f922ecb53309c498d601027c7ba11ff9e2ed5b441190e565066316f2bed5012d",
    14: "559917177230d8b936aaa5448841bbea18b3af7db715abf7e0de6206d8678cc8",
    15: "0db3dd7326b49728ea859b9f1488fb1c3cae9082c2438d8a84dd270dd9882e01",
    16: "2c175d8b1cf6b97c1c37ae92db037d32fd65c903dca7db3e61fb06b613f79a0e",
    17: "134aafd2acc1437321093ec6af5ee6c70eb48c0938864bb0476f9264d1ae6995",
    18: "16ba30861e8736431ce25d362a4840a8db2e891582210ee7dddde0efa12992f2",
    19: "02a9ee3550d74762c98214aa0a20e4f1c7a15d1c969632e4c3c50e621aaa0482",
    20: "df111359cdb01469ee136e98fd8afed1bc0ff85738e18646680c25362187570c",
    21: "d36e273e2d6833c51266095a74c43291237e425be7ecd61a2a90c5b085419efe",
    22: "80d3aea08567c038ba7dc11c443f32fe020624a01e39cf4c27cdf04a953d865c",
    23: "4f02e5a01a13e174ad44d2725d2ad0aed3a88708b8fad56deac0c6ec9241ef27",
    24: "766a8a18ad459436aff28505569a407d73b7d52ad9066252a6c56dd8a626f16c",
    25: "c31c80a66baf9ff0902826185f41fb76993017af0541ea1df24e37cb38cbe8ca",
    26: "804a78e7917ef9339180c099573b3f642788f6cc56b627c94852ba15bc34985f",
    27: "dc9361186e80c7c57aa0162900288aded35e88a6e0d1c50896d3f3a3eede7374",
    28: "57d405ae9eb09faabfe44edd3dae9f3887f5887a060780c8beb097e463519e0b",
    29: "2cda821e3410a24237d64d8ef9db6b549c464d7aa3da2da58a3c4efbdc67e6fc",
    30: "9ee542edcd5c897fed1e7b7c1145e958cc14583ab91176f32d9fbeeb9bb54a60",
}
assert len(AUDIO_PART_SHA256) == AUDIO_PART_COUNT, "part count / hash table mismatch"

# Files expected to already be in the volume (uploaded from your machine
# via `modal volume put`) alongside the reassembled safetensors.
AUDIO_LOCAL_ONLY_FILES = [
    "config.json",
    "preprocessor_config.json",
    "label_mapping.json",
]

CHUNK_SIZE = 8 * 1024 * 1024  # 8 MB streaming read/write


# ---------------------------------------------------------------------------
# Helpers (run inside the Modal container)
# ---------------------------------------------------------------------------
def _download_to_file(url: str, dest: Path) -> None:
    """Stream a URL to disk without loading the whole response into memory."""
    print(f"  downloading {url}")
    req = urllib.request.Request(url, headers={"User-Agent": "scenolytics-seed-script"})
    with urllib.request.urlopen(req) as resp, open(dest, "wb") as f:
        while True:
            chunk = resp.read(CHUNK_SIZE)
            if not chunk:
                break
            f.write(chunk)


def _sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            chunk = f.read(CHUNK_SIZE)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def _seed_seamless(force: bool) -> None:
    from huggingface_hub import snapshot_download

    dest_dir = Path(VOLUME_MOUNT_PATH) / SEAMLESS_DIRNAME
    marker = dest_dir / "config.json"

    if marker.exists() and not force:
        print(f"[seamless] already present at {dest_dir} -- skipping (use --force to redownload)")
        return

    print(f"[seamless] downloading {HF_SEAMLESS_REPO} from HuggingFace Hub -> {dest_dir}")
    dest_dir.mkdir(parents=True, exist_ok=True)
    snapshot_download(
        repo_id=HF_SEAMLESS_REPO,
        local_dir=str(dest_dir),
        local_dir_use_symlinks=False,
    )
    print(f"[seamless] done -> {dest_dir}")


def _seed_video(force: bool) -> None:
    dest = Path(VOLUME_MOUNT_PATH) / VIDEO_MODEL_FILENAME

    if dest.exists() and not force:
        size_mb = dest.stat().st_size / (1024 * 1024)
        print(f"[video] already present at {dest} ({size_mb:.1f} MB) -- skipping (use --force to redownload)")
        return

    print(f"[video] downloading {VIDEO_MODEL_URL} -> {dest}")
    tmp = dest.with_suffix(dest.suffix + ".part")
    _download_to_file(VIDEO_MODEL_URL, tmp)
    tmp.rename(dest)
    size_mb = dest.stat().st_size / (1024 * 1024)
    print(f"[video] done -> {dest} ({size_mb:.1f} MB)")


def _seed_audio(force: bool) -> None:
    dest_dir = Path(VOLUME_MOUNT_PATH) / AUDIO_DIRNAME
    dest_dir.mkdir(parents=True, exist_ok=True)
    final_path = dest_dir / AUDIO_REASSEMBLED_FILENAME

    if final_path.exists() and not force:
        size_mb = final_path.stat().st_size / (1024 * 1024)
        print(f"[audio] {final_path} already present ({size_mb:.1f} MB) -- skipping (use --force to redownload)")
    else:
        parts_dir = dest_dir / "_parts_tmp"
        parts_dir.mkdir(parents=True, exist_ok=True)

        part_paths = []
        try:
            for idx in range(AUDIO_PART_COUNT):
                url = AUDIO_PART_URL_TMPL.format(idx=idx)
                part_path = parts_dir / f"model.safetensors.part{idx:03d}"
                expected_sha = AUDIO_PART_SHA256[idx]

                if part_path.exists() and _sha256_of(part_path) == expected_sha and not force:
                    print(f"[audio] part{idx:03d} already downloaded and verified -- skipping")
                else:
                    print(f"[audio] part {idx + 1}/{AUDIO_PART_COUNT}")
                    _download_to_file(url, part_path)
                    actual_sha = _sha256_of(part_path)
                    if actual_sha != expected_sha:
                        raise RuntimeError(
                            f"SHA-256 mismatch for part{idx:03d}: "
                            f"expected {expected_sha}, got {actual_sha}"
                        )
                    print(f"  part{idx:03d} verified ({part_path.stat().st_size} bytes)")

                part_paths.append(part_path)

            print(f"[audio] reassembling {AUDIO_PART_COUNT} parts -> {final_path}")
            tmp_final = final_path.with_suffix(final_path.suffix + ".part")
            with open(tmp_final, "wb") as out_f:
                for part_path in part_paths:
                    with open(part_path, "rb") as in_f:
                        while True:
                            chunk = in_f.read(CHUNK_SIZE)
                            if not chunk:
                                break
                            out_f.write(chunk)
            tmp_final.rename(final_path)

            size_mb = final_path.stat().st_size / (1024 * 1024)
            print(f"[audio] reassembled -> {final_path} ({size_mb:.1f} MB)")

        finally:
            # Clean up part files regardless of success/failure to avoid
            # leaving ~1.2 GB of redundant data sitting in the volume.
            for part_path in part_paths:
                part_path.unlink(missing_ok=True)
            try:
                parts_dir.rmdir()
            except OSError:
                pass

    # The safetensors are now in place. Warn (don't fail) if the
    # local-only config files haven't been uploaded yet.
    missing = [f for f in AUDIO_LOCAL_ONLY_FILES if not (dest_dir / f).exists()]
    if missing:
        print(
            "[audio] WARNING: the following files are still missing from "
            f"{dest_dir} and must be uploaded from your machine with "
            f"`modal volume put {VOLUME_NAME} <local_path> /{AUDIO_DIRNAME}/<name>`:\n"
            + "\n".join(f"  - {name}" for name in missing)
        )
    else:
        print(f"[audio] all required files present in {dest_dir}")


# ---------------------------------------------------------------------------
# Modal function
# ---------------------------------------------------------------------------
@app.function(
    volumes={VOLUME_MOUNT_PATH: volume},
    timeout=60 * 60,  # large downloads (SeamlessM4T is multi-GB) need headroom
)
def seed(force: bool = False, only: Optional[str] = None):
    """
    Seed the scenolytics-models volume.

    Args:
        force: redownload/overwrite even if target files already exist.
        only:  restrict to one model -- "seamless", "video", or "audio".
               If None, seeds all three.
    """
    targets = {"seamless": _seed_seamless, "video": _seed_video, "audio": _seed_audio}

    if only is not None:
        if only not in targets:
            raise ValueError(f"--only must be one of {list(targets)}, got {only!r}")
        selected = {only: targets[only]}
    else:
        selected = targets

    for name, fn in selected.items():
        print(f"\n=== Seeding: {name} ===")
        fn(force=force)

    volume.commit()
    print("\nVolume committed.")


@app.local_entrypoint()
def main(force: bool = False, only: Optional[str] = None):
    seed.remote(force=force, only=only)