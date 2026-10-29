# nv-cicd-demo

A small demo of a common CI/CD split, with NeuVector (SUSE Security) guarding the registry and the cluster entrance:

```
GitHub ── push ──▶ Jenkins: build (amd64 + arm64) → push :candidate-N → NeuVector scan
                     ├─ above threshold: build fails, no tag promoted
                     └─ passes: promote :<version> → commit new tag to deploy/
Docker Hub ◀── NeuVector registry scan (continuous)
Argo CD syncs deploy/ ──▶ NeuVector admission control (namespace nv-demo only) ──▶ allow / deny
```

Argo CD has no NeuVector integration of its own: Argo CD deploys, NeuVector checks what reaches the cluster.

## Layout

| Path | What | Owner |
|---|---|---|
| `app/` | Go HTTP service: `/` returns the version, `/healthz` returns 200, listens on **8080** | CI track |
| `Jenkinsfile` | Build, Push candidate, NeuVector scan, Promote, Update GitOps repo | CI track |
| `deploy/` | Kustomize: namespace `nv-demo`, Deployment and Service `nv-cicd-demo` | CD track |
| `argocd/` | Argo CD Application `nv-cicd-demo` (auto sync of `deploy/` into `nv-demo`) | CD track |
| `neuvector/` | NeuVector CRDs for the policy-as-code extension, not synced by the main Application | CD track |

## Contract between CI and CD

- Image: `docker.io/yansheng133/nv-cicd-demo`
- The deployed tag lives in **one place**: `deploy/kustomization.yaml`, `images[0].newTag`.
  Jenkins updates it with `kustomize edit set image docker.io/yansheng133/nv-cicd-demo:<version>`
  (run inside `deploy/`) or an equivalent one-line edit, then commits and pushes to `main`.
- The container runs as UID 65532 with a read-only root filesystem; the app must not need to write to disk.
