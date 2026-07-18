# Lab 01: Deploy a small LLM on kind with llama.cpp

**Goal:** Run a small LLM on a local Kubernetes cluster, expose it on your machine, and send inference requests.

**Duration:** about 10 minutes  
**Stack:** Docker Desktop, kind, llama.cpp, NodePort

---

## Learning objectives

By the end of this lab you will be able to:

1. Create a local Kubernetes cluster with kind
2. Check that the cluster and nodes are healthy
3. Deploy llama.cpp with a small GGUF model
4. Observe each deployment phase in real time (download, pod start, readiness)
5. Call the model from a browser and from the OpenAI-compatible API
6. Replace the base model or add a LoRA adapter

---

## Prerequisites

Run these checks before you start:

```bash
docker version
kind version
kubectl version --client
```

| Check | Expected result |
|-------|-----------------|
| Docker | Server section shows a running daemon |
| kind | Version prints (for example `kind v0.23.0`) |
| kubectl | Client version prints |

**Note:** Give Docker Desktop at least 8 GB RAM (Settings, Resources).

---

## Step 1: Create the kind cluster

### 1.1 Run the setup script

```bash
cd llm-deploys-on-k8s
chmod +x scripts/*.sh
./scripts/setup-kind.sh
```

### 1.2 What happens in real time

| Order | Event | What you see |
|-------|-------|--------------|
| 1 | kind starts a Docker container | `Creating cluster "llm-lab"` |
| 2 | Kubernetes control plane starts | `Starting control-plane` |
| 3 | CNI and StorageClass install | `Installing CNI`, `Installing StorageClass` |
| 4 | kubectl context switches | `Set kubectl context to "kind-llm-lab"` |
| 5 | llama.cpp image loads into the node | `Loading llama.cpp image into kind` |

kind runs Kubernetes inside a Docker container on your laptop. The file `kind/cluster.yaml` maps host port `18080` to NodePort `30080` so you can reach the model at `http://localhost:18080` without `kubectl port-forward`.

### 1.3 Checks after cluster creation

```bash
kubectl get nodes
kubectl cluster-info
kubectl get storageclass
```

| Command | What to look for |
|---------|------------------|
| `kubectl get nodes` | One node named `llm-lab-control-plane` with STATUS `Ready` |
| `kubectl cluster-info` | Control plane URL responds |
| `kubectl get storageclass` | A default StorageClass exists (kind installs `standard`) |

If the node is `NotReady`, wait 30 to 60 seconds and run `kubectl get nodes` again.

---

## Step 2: Review what will be deployed

Before applying manifests, understand the four Kubernetes objects:

| Object | File | Purpose |
|--------|------|---------|
| Namespace | `k8s/llamacpp/namespace.yaml` | Isolates LLM resources in `llm` |
| PVC | `k8s/llamacpp/pvc.yaml` | Stores the downloaded GGUF file (3 Gi) |
| ConfigMap | `k8s/llamacpp/configmap.yaml` | Model URL, LoRA URL, server settings |
| Deployment | `k8s/llamacpp/deployment.yaml` | Init container (download) + llama.cpp server |
| Service | `k8s/llamacpp/service.yaml` | NodePort 30080 exposes port 8080 inside the pod |

The Deployment has two containers in sequence:

1. **Init container `fetch-model`:** downloads the GGUF file into the PVC (runs once per pod)
2. **Container `server`:** runs `/app/llama-server` and loads the model into memory

---

## Step 3: Deploy llama.cpp

### 3.1 Run the deploy script

```bash
./scripts/deploy-llamacpp.sh
```

### 3.2 Or deploy step by step manually

```bash
kubectl apply -f k8s/llamacpp/namespace.yaml
kubectl apply -f k8s/llamacpp/pvc.yaml
kubectl apply -f k8s/llamacpp/configmap.yaml
kubectl apply -f k8s/llamacpp/deployment.yaml
kubectl apply -f k8s/llamacpp/service.yaml
```

### 3.3 Watch the deployment in real time

Open a second terminal and run:

```bash
kubectl -n llm get pods -w
```

| Pod phase | Meaning |
|-----------|---------|
| `Pending` | Scheduler is placing the pod on a node |
| `PodInitializing` | Init container is downloading the model (~670 MB, about 1 to 2 minutes) |
| `Running` (0/1) | Server container started; model is loading into RAM |
| `Running` (1/1) | Readiness probe passed; pod accepts traffic |

Check init container download progress:

```bash
kubectl -n llm logs -f deploy/llamacpp -c fetch-model
```

Check server startup:

```bash
kubectl -n llm logs -f deploy/llamacpp -c server
```

Look for this line in server logs:

```
llama_server: listening on http://0.0.0.0:8080
```

### 3.4 Checks after deployment

```bash
kubectl -n llm get all
kubectl -n llm rollout status deployment/llamacpp
kubectl -n llm get pvc
curl http://localhost:18080/health
```

| Check | Expected result |
|-------|-----------------|
| Pod STATUS | `Running`, READY `1/1` |
| Service | TYPE `NodePort`, PORT `8080:30080/TCP` |
| PVC | STATUS `Bound` |
| Health endpoint | `{"status":"ok"}` |

---

## Step 4: Send inference requests

### 4.1 Browser

Open: **http://localhost:18080**

This is the llama.cpp web UI. Type a message and confirm the model replies.

### 4.2 API (OpenAI-compatible)

```bash
./scripts/test-llamacpp.sh
```

Or send a request manually:

```bash
curl http://localhost:18080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "tinyllama",
    "messages": [{"role": "user", "content": "What runs this model?"}],
    "max_tokens": 80
  }'
```

**Note:** Applications that use the OpenAI API format can point to `http://localhost:18080`. Inside the cluster, clients use the Service DNS name `llamacpp.llm.svc.cluster.local:8080`.

---

## Step 5: Use your own model or LoRA adapter

To deploy a different GGUF base model or add a fine-tuned LoRA adapter:

```bash
export MODEL_URL="https://huggingface.co/YOU/MODEL/resolve/main/model.Q4_K_M.gguf"
export LORA_URL="https://huggingface.co/YOU/ADAPTER/resolve/main/adapter.gguf"

kubectl -n llm delete pvc model-cache --ignore-not-found
./scripts/deploy-llamacpp.sh
```

### What happens in real time

1. Deleting the PVC removes the cached model file
2. A new pod starts; the init container downloads the new files
3. The server loads the base model and attaches the LoRA adapter if `LORA_URL` is set
4. The Service keeps the same NodePort; no change needed on the client side

---

## Step 6 (optional): KServe path

KServe adds an `InferenceService` CRD and a controller that manages model serving.

```bash
./scripts/install-kserve.sh
./scripts/deploy-kserve.sh
./scripts/test-kserve.sh
```

Check status:

```bash
kubectl -n kserve-lab get inferenceservice tiny-llm
kubectl -n kserve-lab get pods
```

Predictor URL: **http://localhost:18081**

| | llama.cpp | KServe |
|---|-----------|--------|
| Model format | GGUF (+ LoRA) | HuggingFace / custom runtimes |
| Setup time | about 10 min | about 20 min |
| API | OpenAI-compatible | KServe v1 predict |
| Use case | Small models, adapters | ML platform, versioning |

---

## Real-time request flow

When you send a chat request from your laptop:

```
1. curl or browser  ->  localhost:18080
2. Docker Desktop   ->  kind node (port mapping 18080 to 30080)
3. kube-proxy       ->  Service llamacpp (NodePort 30080)
4. Service          ->  Pod llamacpp (container port 8080)
5. llama-server     ->  loads tokens, runs inference, returns JSON
```

When the pod restarts but the PVC still has the model file:

```
1. New pod scheduled
2. Init container skips download (file already on PVC)
3. Server container starts faster (only model load into RAM)
```

---

## Troubleshooting

| Problem | Command | Fix |
|---------|---------|-----|
| Pod `ImagePullBackOff` | `kubectl -n llm describe pod -l app=llamacpp` | Image must be `ghcr.io/ggml-org/llama.cpp:server` |
| Pod `Pending` | `kubectl -n llm describe pod -l app=llamacpp` | Check Docker memory; increase to 8 GB+ |
| Health check fails | `kubectl -n llm logs deploy/llamacpp -c server` | Wait for `listening on http://0.0.0.0:8080` |
| Port 18080 in use | `netstat -an \| findstr 18080` (Windows) | Change `hostPort` in `kind/cluster.yaml` and recreate cluster |

---

## Cleanup

Remove everything in one step:

```bash
./scripts/cleanup.sh
```

This deletes the `llm-lab` kind cluster. All namespaces, pods, PVCs, and services inside it are removed with the cluster.

---

## Files reference

| File | Role |
|------|------|
| `kind/cluster.yaml` | kind cluster and host port mapping |
| `k8s/llamacpp/deployment.yaml` | Init download and llama.cpp server |
| `k8s/llamacpp/configmap.yaml` | `MODEL_URL`, `LORA_URL` |
| `k8s/kserve/inferenceservice.yaml` | KServe HuggingFace example |
| `scripts/setup-kind.sh` | Create cluster and load image |
| `scripts/deploy-llamacpp.sh` | Apply manifests and wait for rollout |
| `scripts/cleanup.sh` | Delete kind cluster and all lab resources |
