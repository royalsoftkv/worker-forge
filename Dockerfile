# ---------------------------------------------------------------------------- #
#                         Stage 1: Download the models                         #
# ---------------------------------------------------------------------------- #
FROM alpine/git:2.43.0 as download

# NOTE: CivitAI usually requires an API token, so you need to add it in the header
#       of the wget command if you're using a model from CivitAI.
RUN apk add --no-cache wget && \
    wget -q -O /model.safetensors https://huggingface.co/SG161222/RealVisXL_V5.0/resolve/main/RealVisXL_V5.0_fp16.safetensors

# ---------------------------------------------------------------------------- #
#                        Stage 2: Build the final image                        #
# ---------------------------------------------------------------------------- #
FROM python:3.10.14-slim as build_final_image

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    ROOT=/stable-diffusion-webui-forge \
    PYTHONUNBUFFERED=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && \
    apt install -y \
    fonts-dejavu-core rsync git jq moreutils aria2 wget libgoogle-perftools-dev libtcmalloc-minimal4 procps libgl1 libglib2.0-0 unzip cmake g++ && \
    apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && apt-get clean -y

RUN --mount=type=cache,target=/root/.cache/pip \
    git clone https://github.com/lllyasviel/stable-diffusion-webui-forge && \
    cd stable-diffusion-webui-forge && \
    pip install xformers && \
    pip install -r requirements_versions.txt && \
    python -c "from launch import prepare_environment; prepare_environment()" --skip-torch-cuda-test

COPY --from=download /model.safetensors /model.safetensors

# install dependencies
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir -r requirements.txt

COPY test_input.json .

ADD src .

RUN cd /stable-diffusion-webui-forge/extensions && \
    git clone https://github.com/Gourieff/sd-webui-reactor-sfw
RUN cd /stable-diffusion-webui-forge/extensions/sd-webui-reactor-sfw && pip install -r requirements.txt
RUN python /stable-diffusion-webui-forge/extensions/sd-webui-reactor-sfw/install.py

RUN mkdir -p /stable-diffusion-webui-forge/models/insightface && \
    mkdir -p /stable-diffusion-webui-forge/models/insightface/models && \
    mkdir -p /stable-diffusion-webui-forge/models/Codeformer && \
    mkdir -p /stable-diffusion-webui-forge/models/GFPGAN
RUN wget -O /stable-diffusion-webui-forge/models/insightface/inswapper_128.onnx https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/inswapper_128.onnx

RUN mkdir -p /stable-diffusion-webui-forge/models/insightface/models/buffalo_l
RUN wget https://github.com/deepinsight/insightface/releases/download/v0.7/buffalo_l.zip -O /stable-diffusion-webui-forge/models/insightface/models/buffalo_l/buffalo_l.zip && \
    wget https://github.com/sczhou/CodeFormer/releases/download/v0.1.0/codeformer.pth -O /stable-diffusion-webui-forge/models/Codeformer/codeformer-v0.1.0.pth && \
    wget https://github.com/xinntao/facexlib/releases/download/v0.1.0/detection_Resnet50_Final.pth -O /stable-diffusion-webui-forge/models/GFPGAN/detection_Resnet50_Final.pth && \
    wget https://github.com/xinntao/facexlib/releases/download/v0.2.2/parsing_parsenet.pth -O /stable-diffusion-webui-forge/models/GFPGAN/parsing_parsenet.pth && \
    wget https://github.com/TencentARC/GFPGAN/releases/download/v1.3.0/GFPGANv1.4.pth -O /stable-diffusion-webui-forge/models/GFPGAN/GFPGANv1.4.pth

RUN mkdir -p /stable-diffusion-webui-forge/models/nsfw_detector/vit-base-nsfw-detector
RUN wget https://huggingface.co/AdamCodd/vit-base-nsfw-detector/resolve/main/config.json -O /stable-diffusion-webui-forge/models/nsfw_detector/vit-base-nsfw-detector/config.json && \
    wget https://huggingface.co/AdamCodd/vit-base-nsfw-detector/resolve/main/confusion_matrix.png -O /stable-diffusion-webui-forge/models/nsfw_detector/vit-base-nsfw-detector/confusion_matrix.png && \
    wget https://huggingface.co/AdamCodd/vit-base-nsfw-detector/resolve/main/model.safetensors -O /stable-diffusion-webui-forge/models/nsfw_detector/vit-base-nsfw-detector/model.safetensors && \
    wget https://huggingface.co/AdamCodd/vit-base-nsfw-detector/resolve/main/preprocessor_config.json -O /stable-diffusion-webui-forge/models/nsfw_detector/vit-base-nsfw-detector/preprocessor_config.json

RUN cd /stable-diffusion-webui-forge/models/insightface/models/buffalo_l && unzip buffalo_l.zip && rm buffalo_l.zip

RUN chmod +x /start.sh
CMD /start.sh