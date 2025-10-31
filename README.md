# ContainerCraft (TAM-DO Case Study)

A small static frontend served by Nginx with example Docker and Kubernetes manifests. This repository contains a tiny sample site and manifests to build, run, and deploy it locally or to a Kubernetes cluster.

## Repository structure

- `index.html` — The static single-page frontend (ContainerCraft). Shows features, about and a small local visit counter (uses localStorage).
- `style.css` — Styles for the page (glass, gradient background, responsive container).
- `Dockerfile` — Minimal Dockerfile based on `nginx:alpine` that copies `index.html` and `style.css` into the Nginx web root.
- `deployment.yaml` — Kubernetes Deployment manifest that expects an image named `dbhitman/anil-tam-app:latest` and runs 2 replicas exposing port 80 in the pod.
- `service.yaml` — Kubernetes Service manifest of type `LoadBalancer` that routes traffic to pods labeled `app: anil-tam-app` on port 80.

> Note: `deployment.yaml` references an image `dbhitman/anil-tam-app:latest` (published on Docker Hub). That image is public, so you can deploy the manifests as-is and Kubernetes will pull the image from Docker Hub. If you'd rather use your own image, follow the Docker build & push steps below and update `deployment.yaml` to the image you publish.

## How the app works (quick overview)

- The UI is fully static and client-side; there is no backend server code in this repo.
- `index.html` and `style.css` are served by Nginx when packaged in the Docker image.
- A small inline script in `index.html` stores a visit counter in the browser's `localStorage` and displays the count.

## Contract (inputs / outputs / success criteria)

- Input: Static files (`index.html`, `style.css`).
- Output: HTTP server serving static assets on port 80.
- Success: Accessing the container or service root (/) returns the page and assets load correctly (CSS and JS behavior functional).

## Build & run locally with Docker

These steps assume you have Docker installed and are running PowerShell (pwsh).

1. Build the image locally. From the repository root run:

```powershell
docker build -t anil-tam-app:local .
```

2. Run the image and map port 80 to your host (example maps to port 8080):

```powershell
docker run --rm -p 8080:80 anil-tam-app:local
```

3. Open http://localhost:8080 in your browser. You should see the ContainerCraft site.

Tip: Use `docker logs <container_id>` to inspect Nginx logs if assets fail to load.

## Publish to Docker Hub (optional)

If you want to deploy to a remote Kubernetes cluster, push an image to a registry first.

1. Tag the image for Docker Hub (replace `<username>` with your Docker ID):

```powershell
docker tag anil-tam-app:local <username>/anil-tam-app:latest
```

2. Log in and push:

```powershell
docker login
docker push <username>/anil-tam-app:latest
```

3. Update `deployment.yaml` to reference `<username>/anil-tam-app:latest` or replace the existing `image:` value.

## Deploy to Kubernetes (cloud or local)

These instructions cover both cloud clusters and local tools like Minikube or Kind. Make sure `kubectl` is installed and pointing at your desired cluster context.

1. (Optional) If you pushed an image to Docker Hub, edit `deployment.yaml` to use your published image name. If you are deploying to a local cluster that can access your local Docker daemon (e.g., Docker Desktop), you can keep the image name you built locally or load the image into the cluster.

2. Apply manifests (recommended order: Deployment then Service, although `kubectl apply -f .` will work):

```powershell
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

3. Check pods & service:

```powershell
kubectl get pods -l app=anil-tam-app
kubectl get svc anil-tam-service
```

4. Access the service:
- On a cloud provider with a supported `LoadBalancer`, wait for an external IP on the service and open it in a browser.
- On Minikube: run `minikube service anil-tam-service --url` to get the reachable URL.
- On Kind (or other clusters without LoadBalancer), either change `service.yaml` to `NodePort` or use port-forwarding:

```powershell
kubectl port-forward svc/anil-tam-service 8080:80
# then open http://localhost:8080
```

## Local cluster notes (Minikube / Docker Desktop)

- Minikube: If your cluster runs inside Minikube, build the image and load it into Minikube:

```powershell
docker build -t anil-tam-app:local .
minikube image load anil-tam-app:local
# then set deployment.yaml image to anil-tam-app:local and apply
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

- Docker Desktop Kubernetes: images built locally are available to the cluster by default.

## DigitalOcean: creating a cluster & using the LoadBalancer

If you plan to run this on DigitalOcean Kubernetes (DOKS) the steps below walk through creating a cluster, publishing a container image to DigitalOcean Container Registry (DCR), and using the built-in LoadBalancer.

Prerequisites:
- `doctl` (DigitalOcean CLI) installed and authenticated (`doctl auth init`).
- `kubectl` installed and configured.

1) Create a cluster with `doctl` (example — replace region, size and version as needed):

```powershell
doctl auth init
doctl kubernetes cluster create my-cluster --region nyc1 --version 1.27.4 --node-pool "name=default;size=s-2vcpu-4gb;count=2"
```

2) Save the cluster kubeconfig so `kubectl` talks to the new cluster:

```powershell
doctl kubernetes cluster kubeconfig save my-cluster
kubectl get nodes
```

3) (Recommended) Use DigitalOcean Container Registry to host your image so the cluster can pull it reliably.

```powershell
doctl registry create my-registry
doctl registry login
docker tag anil-tam-app:local registry.digitalocean.com/<your-registry>/anil-tam-app:latest
docker push registry.digitalocean.com/<your-registry>/anil-tam-app:latest
```

Update `deployment.yaml` to use the pushed image, for example:

```yaml
	image: registry.digitalocean.com/<your-registry>/anil-tam-app:latest
```

Note: This repository already references a public Docker Hub image `dbhitman/anil-tam-app:latest`. If you prefer to use that public image directly on DigitalOcean, you can skip pushing to DCR and keep or set the image in `deployment.yaml` to:

```yaml
	image: dbhitman/anil-tam-app:latest
```

Kubernetes will pull that image from Docker Hub automatically. If you use a private image registry (Docker Hub private repo, DCR private, etc.), ensure you configure `imagePullSecrets` in the manifest or use a registry credential helper so the cluster nodes can authenticate.

Also consider image pull policy:

```yaml
	imagePullPolicy: IfNotPresent
```
This avoids re-pulling the image on every pod restart when using locally-cached or stable published images.

4) Apply the manifests to create the deployment & service in the cluster:

```powershell
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

5) Verify the service and get the external IP assigned by DigitalOcean's LoadBalancer:

```powershell
kubectl get svc anil-tam-service
kubectl describe svc anil-tam-service
```

Notes and best practices for DigitalOcean:
- A `Service` of type `LoadBalancer` will cause DigitalOcean to provision a cloud Load Balancer automatically; this may take a minute.
- The external IP/hostname will appear in `kubectl get svc` once provisioned.
- For TLS termination and advanced routing, prefer an Ingress controller (e.g., Nginx Ingress or Traefik) and cert-manager to obtain certificates automatically.
- To customize the DO Load Balancer (health checks, session affinity, etc.) use the DigitalOcean Control Panel or create an Ingress with annotations — avoid relying on provider-specific annotations unless you confirm the exact keys and behavior in the DO docs.

If you want, I can add a small `doctl`/PowerShell script that automates image push and `kubectl apply` for this repo.

## Important details from each file

- `index.html` — contains the page markup and an inline script that stores a browser-local visit counter under the key `pageVisitCount`. No server-side code.
- `style.css` — visual styling (glassmorphism, gradients). Keep alongside `index.html` in the Docker image so it can be served by Nginx.
- `Dockerfile` — uses `nginx:alpine`, copies `index.html` and `style.css` into `/usr/share/nginx/html/` and exposes port 80.
- `deployment.yaml` — deployment with 2 replicas, container port 80, image `dbhitman/anil-tam-app:latest`. Update the `image:` to your published image if needed. If using a private registry, configure image pull secrets.
- `service.yaml` — `LoadBalancer` service on port 80. For clusters without an external LB, change to `NodePort` or use port-forwarding.

## Common changes you might want to make

- To change the app name or metadata, edit `deployment.yaml` metadata fields and labels, keeping selector and labels aligned.
- To serve additional static files, add them to the `COPY` line in the `Dockerfile` and ensure references in `index.html` are correct.
- To run more replicas, change `spec.replicas` in `deployment.yaml`.

## Troubleshooting

- Blank page or missing CSS: Confirm `style.css` is present in `/usr/share/nginx/html/` inside the container. Run `docker exec -it <container> /bin/sh` and check the files.
- Kubernetes pods in CrashLoopBackOff: Inspect pod logs with `kubectl logs <pod>` and `kubectl describe pod <pod>`.
- Image pull failures: ensure the image name is correct and accessible from the cluster. For private registries add imagePullSecrets.

## Security & production notes

- This repo is a static demo. For production consider:
	- Adding HTTPS (TLS) termination via an Ingress + cert-manager or cloud LB with TLS.
	- Proper health/readiness probes in `deployment.yaml`.
	- Smaller, hardened base images or serving assets from a CDN.

## License

This repository includes example files for demonstration. Add a LICENSE file if you want to declare terms.

---

If you'd like, I can also:
- Add a small Makefile or PowerShell script with the common build/push/deploy commands.
- Create a `kustomization.yaml` to make image name substitution easier.

Let me know which of those you'd prefer and I'll add it.

