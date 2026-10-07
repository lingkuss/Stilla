"""Offline authoring only: measure a portrait, never ship/run inference in the app.

Usage: python extract_face_landmarks.py portrait.png model.task face-landmarks.json
Requires mediapipe 0.10.21 in an isolated authoring environment.
"""
import hashlib
import json
import sys
from pathlib import Path
import mediapipe as mp
from mediapipe.tasks.python.vision.face_landmarker import FaceLandmarksConnections

portrait, model, destination = map(Path, sys.argv[1:])
options = mp.tasks.vision.FaceLandmarkerOptions(
    base_options=mp.tasks.BaseOptions(model_asset_path=str(model)), num_faces=1)
with mp.tasks.vision.FaceLandmarker.create_from_options(options) as detector:
    result = detector.detect(mp.Image.create_from_file(str(portrait)))
assert len(result.face_landmarks) == 1, "Expected exactly one reference face"
connections = FaceLandmarksConnections.FACE_LANDMARKS_TESSELATION
triangles = [[connections[i].start, connections[i].end, connections[i + 1].end]
             for i in range(0, len(connections), 3)]
data = {
    "portrait_sha256": hashlib.sha256(portrait.read_bytes()).hexdigest(),
    "authoring_tool": f"MediaPipe FaceLandmarker {mp.__version__} (offline)",
    "landmarks": [[p.x, p.y, p.z] for p in result.face_landmarks[0][:468]],
    "triangles": triangles,
    "oval": [[p.start, p.end] for p in FaceLandmarksConnections.FACE_LANDMARKS_FACE_OVAL],
}
destination.write_text(json.dumps(data, separators=(",", ":")) + "\n")
print(f"Measured {len(data['landmarks'])} points, {len(triangles)} triangles → {destination}")
