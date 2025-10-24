p, role:argocd-admin, applications, update, */*, allow
p, role:argocd-admin, applications, delete,  */*, allow
p, role:argocd-admin, applications, sync,  */*, allow
p, role:argocd-admin, applications, override,  */*, allow
p, role:argocd-admin, applications, action/*,  */*, allow
p, role:argocd-admin, exec, create,  */*, allow
# Allow admins to delete the whole application
p, role:argocd-admin, projects, delete, *, allow
p, role:argocd-admin, projects, update, *, allow

{{ if or (contains "prod" $.Values.global.environment.name) (contains "infra" $.Values.global.environment.name) }}
p, role:argocd-dev, applications, action/argoproj.io/Rollout/*, */*, allow
{{ else }}
p, role:argocd-dev, applications, update, */*, allow
p, role:argocd-dev, applications, delete, */*, allow
p, role:argocd-dev, applications, sync, */*, allow
p, role:argocd-dev, applications, override, */*, allow
p, role:argocd-dev, applications, action/*, */*, allow
p, role:argocd-dev, exec, create, */*, allow
{{ end }}

g, nebed, role:argocd-admin

g, nebed, role:argocd-dev

################################################################################
# Global RBAC definitions
################################################################################

# The difference between partial-admin and the built-in admin role is that partial
# admins can't create applications or set ArgoCD installation-wide configuration.
# This is intentional; those settings should be managed via GitOps, and code reviewed.
p, role:partial-admin, applications, update, */*, allow
p, role:partial-admin, applications, delete, */*, allow
p, role:partial-admin, applications, sync, */*, allow
p, role:partial-admin, applications, override, */*, allow
p, role:partial-admin, applications, action/*, */*, allow
p, role:partial-admin, exec, create, */*, allow
p, role:partial-admin, projects, update, *, allow
p, role:partial-admin, clusters, update, *, allow
p, role:partial-admin, repositories, update, *, allow

g, nebed, role:partial-admin
