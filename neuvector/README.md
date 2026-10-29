# neuvector/

NeuVector custom resources for this demo (policy as code, extension 1).
They are **not** part of the main Argo CD Application (`argocd/application.yaml` only syncs `deploy/`).

- `admission/` — `NvAdmissionControlSecurityRule` objects, all scoped to namespace `nv-demo`.
  Apply manually: `kubectl --kubeconfig <downstream> apply -f neuvector/admission/`
