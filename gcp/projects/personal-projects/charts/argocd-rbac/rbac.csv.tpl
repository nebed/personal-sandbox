p, role:argocd-admin, applications, update, */*, allow
p, role:argocd-admin, applications, delete,  */*, allow
p, role:argocd-admin, applications, sync,  */*, allow
p, role:argocd-admin, applications, override,  */*, allow
p, role:argocd-admin, applications, action/*,  */*, allow
p, role:argocd-admin, exec, create,  */*, allow
# Allow admins to delete the whole application
p, role:argocd-admin, projects, delete, *, allow
p, role:argocd-admin, projects, update, *, allow

g, nebed, role:argocd-admin
