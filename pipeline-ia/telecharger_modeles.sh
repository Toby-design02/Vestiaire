#!/bin/bash
# Télécharge les 4 petits modèles OpenCV (≈ 90 Mo, gratuits) dans pipeline-ia/models/.
set -e
cd "$(dirname "$0")/models"
Z=https://github.com/opencv/opencv_zoo/raw/main/models
for f in face_detection_yunet/face_detection_yunet_2023mar.onnx \
         face_recognition_sface/face_recognition_sface_2021dec.onnx \
         object_detection_yolox/object_detection_yolox_2022nov.onnx \
         image_classification_mobilenet/image_classification_mobilenetv2_2022apr.onnx; do
  [ -f "$(basename $f)" ] || curl -sSL -o "$(basename $f)" "$Z/$f"
done
ls -lh
