# ---- Base image with CUDA 12.4 ----
FROM pytorch/pytorch:2.4.0-cuda12.4-cudnn9-runtime AS env_base
ENV DEBIAN_FRONTEND=noninteractive PIP_PREFER_BINARY=1

RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && \
    apt-get install -y git vim libgl1-mesa-glx libglib2.0-0 python3-dev gcc g++ pkg-config libcairo2-dev && \
    apt-get clean
RUN pip3 install --no-cache-dir --upgrade pip setuptools==76.1.0

# ---- Clone and install ComfyUI ----
FROM env_base AS base
ARG BUILD_DATE
ENV BUILD_DATE=$BUILD_DATE
RUN echo "$BUILD_DATE" > /build_date.txt

WORKDIR /app
RUN git clone https://github.com/comfyanonymous/ComfyUI.git .

# Install requirements + extras compatible with CUDA 12.4
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir bitsandbytes==0.43.1 onnxruntime-gpu==1.19.2 ninja triton opencv-python spandrel kornia fal_client
RUN pip install --no-cache-dir -v xformers --index-url https://download.pytorch.org/whl/cu124

# ---- Custom nodes ----
WORKDIR /app/custom_nodes
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    git clone https://github.com/twri/sdxl_prompt_styler.git && \
    git clone https://github.com/Fannovel16/comfyui_controlnet_aux.git && \
    cd comfyui_controlnet_aux && pip install --no-cache-dir -r requirements.txt && \
    cd .. && git clone https://github.com/cubiq/ComfyUI_IPAdapter_plus.git && \
    git clone https://github.com/zhangp365/ComfyUI-utils-nodes.git && \
    pip install --no-cache-dir google-generativeai

ENV LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"
ENV PYTHONUNBUFFERED=1

# ---- Final stage ----
FROM base AS runtime
WORKDIR /app
EXPOSE 8188

# Clean caches
RUN rm -rf /root/.cache/pip/*

# Optional: update repos on build
RUN cd /app && git pull && \
    cd /app/custom_nodes/comfyui_controlnet_aux && git pull && \
    cd /app/custom_nodes/ComfyUI_IPAdapter_plus && git pull || true

# IPv6-compatible startup (fixes Salad 503)
CMD ["python3", "main.py", "--listen", "::", "--port", "8188"]
