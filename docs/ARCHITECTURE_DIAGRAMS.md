# Architecture Diagrams — viya4-iac-k8s

## Repository Structure

```
viya4-iac-k8s/
│
├── main.tf           ← Root dispatcher: selects topology via deployment_type
├── locals.tf         ← is_azure / is_openstack / is_bare_metal / is_vsphere
├── variables.tf      ← All input variables for all 4 topologies
├── outputs.tf        ← Conditional outputs routed from active topology
├── versions.tf       ← Terraform version + local provider only
│                        (each topology's versions.tf declares its own cloud provider)
│
├── roles/            ← SHARED Ansible roles (kubernetes/ — common across all topologies)
│   └── kubernetes/   ← cni/ cri/ control_plane/ node/ vip/ loadbalancer/ storage/ metrics/
│
├── scripts/
│   ├── lib/
│   │   └── common.sh ← Shared shell functions (gather_ans_creds, clean_up)
│   ├── deploy.sh     ← Azure orchestration  [sources lib/common.sh]
│   └── oss-k8s.sh    ← OpenStack / bare_metal / vSphere  [sources lib/common.sh]
│
├── topologies/
│   ├── azure/        ← Azure IaaS (azurerm provider)
│   ├── openstack/    ← OpenStack / HPOS (openstack provider)
│   ├── bare_metal/   ← Pre-existing nodes (local provider — no cloud provisioning)
│   └── vsphere/      ← VMware vSphere (vsphere provider)
│
│   # All four share the same internal layout:
│   └── <any-topology>/
│       ├── main.tf              # VM provisioning + inventory/ansible-vars generation
│       ├── variables.tf         # Topology-scoped variables only
│       ├── locals.tf            # Derived values
│       ├── outputs.tf           # Output contract
│       ├── versions.tf          # Cloud provider (azurerm/openstack/vsphere/local)
│       ├── provider.tf          # Provider auth — use env vars; never commit secrets
│       ├── provider.tf.example
│       ├── ansible.cfg          # roles_path = ./roles:../../roles
│       ├── requirements.txt
│       ├── requirements.yml
│       ├── playbooks/
│       │   ├── systems-install.yaml
│       │   ├── kubernetes-install.yaml
│       │   └── kubernetes-uninstall.yaml
│       ├── roles/
│       │   └── systems/
│       │       └── <topology>/  # provider-specific OS setup only
│       │                        # kubernetes/ resolves via ../../roles (shared)
│       ├── modules/             # Topology-specific Terraform modules
│       │                        # (not present in bare_metal — no cloud resources)
│       ├── templates/           # ansible-vars.yaml.tmpl, inventory.tmpl
│       └── sample-input-<topology>.tfvars
│
├── docker/
│   ├── Dockerfile
│   └── entrypoint.sh
└── tests/
```

---

## Topology Dispatch Model

> **Important:** The root dispatcher code in `main.tf` exists for reference and
> IDE navigation, but **cannot be applied from the repository root**. Terraform
> forbids using `count` or `for_each` on modules that contain their own `provider`
> blocks — doing so produces: *"Module is incompatible with count, for_each, and
> depends_on"*. All scripts therefore bypass root and run Terraform directly inside
> the chosen topology directory.

**How scripts operate (topology-direct mode):**

```
# scripts/oss-k8s.sh and scripts/deploy.sh both do:

TOPOLOGY_DIR="$BASEDIR/topologies/$SYSTEM"   # e.g. topologies/openstack

terraform -chdir="$TOPOLOGY_DIR" init
terraform -chdir="$TOPOLOGY_DIR" plan  -var-file "$TFVARS"
terraform -chdir="$TOPOLOGY_DIR" apply -var-file "$TFVARS"
```

Each topology is a **fully self-contained Terraform root module** — its own
`versions.tf` declares the required cloud provider, and its `provider.tf`
configures credentials. No root init is needed.

**Root-level files (reference / structural only):**

```
main.tf      → module blocks (count pattern) — reference, not applied directly
locals.tf    → is_azure / is_openstack / is_bare_metal / is_vsphere flags
variables.tf → consolidated variable definitions for all 4 topologies
outputs.tf   → output routing via active_module (used when root IS applied)
versions.tf  → requires: local ~> 2.4 only (no cloud providers at root)
```

---

## Ansible Roles — Shared vs Topology-Specific

```
roles/kubernetes/                   ← SHARED (repo root) — one copy for all topologies
  cni/
    calico/
    cilium/
  cri/
    containerd/
    crio/
  control_plane/
  node/
  vip/
  loadbalancer/
    metallb/
    kube-vip/
  storage/
    nfs-csi-driver/
    sig-storage-local-static-provisioner/
  metrics/
    metrics-server/
  toolbox/
  misc/
  sas-iac-buildinfo/

topologies/<topology>/roles/systems/<topology>/   ← TOPOLOGY-SPECIFIC (provider OS setup)
  azure/      ← Azure cloud-init, disk, network config
  openstack/  ← OpenStack floating IP, cloud-init specifics
  vsphere/    ← VMware custom disk and network tasks
  bare_metal/ ← Bare-metal pre-flight checks
```

**Role resolution order** (Ansible `roles_path`):
```
./roles          ← topology-specific roles checked FIRST  (overrides shared if needed)
../../roles      ← shared repo-root roles checked as FALLBACK
```

This means a topology can override any shared role by placing a same-named role in
`topologies/<name>/roles/`. Nothing needs to change in shared code.

---

## Script Architecture

```
scripts/
  lib/
    common.sh        ← gather_ans_creds()   — prompt / read Ansible credentials
                        clean_up()           — remove kubeconfig + buildinfo artifacts

  deploy.sh          ← Azure only; sources lib/common.sh
    gather_azure_creds()   — Azure SP / MSI credential collection
    terraform_prep()       — init + credential injection
    terraform_up/down()    — apply / destroy
    ansible_prep()         — galaxy install
    [action loop]          — apply → setup → install → update → uninstall → destroy

  oss-k8s.sh         ← OpenStack / bare_metal / vsphere; sources lib/common.sh
    gather_tf_creds()      — openstack / vsphere credential collection
    terraform_prep/up/down()
    allocate_vip_floating_ip()  — OpenStack: pre-allocate control-plane + LB VIPs
    patch_vip_allowed_pairs()   — OpenStack: neutron port allowed_address_pairs
    ansible_prep()
    [action loop]          — apply → setup → install → update → uninstall → destroy
```

---

## Azure Topology — Resource Layout

```
Azure Subscription
└── Resource Group  (azurerm_resource_group)
    ├── Virtual Network  (module.azure_network)
    │   ├── Subnet: k8s     ← Kubernetes node NICs
    │   ├── Subnet: misc    ← Jump / NFS / CR NICs
    │   └── NSG rules
    │
    ├── Kubernetes Nodes  (module.azure_vms — one VM per pool member)
    │   ├── control_plane-{1..N}
    │   ├── system-{1..N}
    │   └── <worker_pool>-{1..N}
    │
    ├── Jump Server  (module.azure_jump, when create_jump = true)
    ├── NFS Server   (module.azure_nfs,  when create_nfs  = true)
    │
    └── Generated Files
        ├── inventory           ← Ansible inventory
        └── ansible-vars.yaml   ← Ansible variables
```

---

## Adding a New Topology

1. Copy `topologies/_template/` to `topologies/<name>/`.
2. In root `locals.tf` add: `is_<name> = local.deployment_type_normalized == "<name>"`
   and extend the `active_module` ternary with `local.is_<name> ? one(module.<name>) :`.
3. In root `main.tf` add a module block with `count = local.is_<name> ? 1 : 0`.
4. In root `variables.tf` extend the `deployment_type` validation to include `"<name>"`.
5. `outputs.tf` — **no changes needed** (routes through `local.active_module`).
6. Set `ansible.cfg` `roles_path = ./roles:../../roles` — shared Kubernetes roles are
   available automatically; add only provider-specific systems roles in `roles/systems/<name>/`.
7. Run `scripts/validate-topology.sh <name>` to confirm all required files are in place.

---

## Root Dispatcher — Output Routing

Prior to this refactor, every output in `outputs.tf` repeated a four-way ternary.
`locals.tf` now owns a single `active_module` resolution:

```
locals.tf
  active_module = (
    is_azure      ? one(module.azure)       ← one() returns null for count=0 modules
    is_openstack  ? one(module.openstack)
    is_bare_metal ? one(module.bare_metal)
    is_vsphere    ? one(module.vsphere)
    : null
  )

outputs.tf
  cluster_name        = try(active_module.cluster_name,        null)
  prefix              = try(active_module.prefix,              null)
  node_pools_summary  = try(active_module.node_pools_summary,  null)
  ...                   ← single pattern, adding a 5th topology changes outputs.tf zero times
```

---

## Unified Orchestrator Model (target)

Current state has two entry-point scripts.  Target state consolidates to one:

```
entrypoint.sh
  └── orchestrate.sh          ← single lifecycle dispatcher for ALL topologies
        ├── sources lib/common.sh
        │     gather_ans_creds()    clean_up()
        │     terraform_up/down()   ansible_prep()
        │     run_playbook()        phase_apply/setup/install/uninstall/destroy()
        │
        └── sources lib/hooks/${SYSTEM}.sh   ← topology-specific overrides only
              azure.sh        → gather_azure_creds, pre_apply
              openstack.sh    → gather_openstack_creds, post_apply (VIP alloc + port patch)
              vsphere.sh      → gather_vsphere_creds
              bare_metal.sh   → apply/destroy no-op guards

Migration from current to target:
  Phase A (done):  common.sh extracted, ANSIBLE_ROLES_PATH unified, ansible.cfg dual path
  Phase B (next):  hooks/ library, orchestrate.sh, entrypoint.sh simplified to 3 lines
```

---

## Runtime Workspace Isolation

```
WORKDIR (Docker bind mount at /workspace, or $BASEDIR in native mode)
│
├── <prefix>-azure/           ← cluster-scoped; all state isolated here
│   ├── terraform.tfvars      ← operator input (bind-mounted read-only)
│   ├── terraform.tfstate     ← Terraform state
│   ├── inventory             ← generated by Terraform template
│   ├── ansible-vars.yaml     ← generated by Terraform template
│   ├── kubeconfig            ← generated by Ansible post-install
│   ├── cluster-contract.json ← generated output contract (see DAC section)
│   └── logs/
│       ├── apply-20260115T142200.log
│       └── install-20260115T144500.log
│
├── <prefix>-openstack/       ← independent; safe to run in parallel
│   └── ...
│
└── <prefix>-vsphere/
    └── ...

Concurrent safety: two clusters share one bind-mount root but never share
  a state file, inventory, or kubeconfig — no serialization required.
```

---

## DAC / SAS Viya Integration Contract

```
Infrastructure provisioning (Terraform)
  └── writes cluster-contract.json  (Stage 1 — infrastructure fields)

Kubernetes installation (Ansible)
  └── patches cluster-contract.json (Stage 2 — post-install fields: api_endpoint, kubeconfig, storage classes)

cluster-contract.json schema (v1.0):
  {
    "contract_version": "1.0",
    "cluster": {
      "name", "deployment_type", "kubernetes_version",
      "kubernetes_cni", "kubernetes_cri",
      "api_endpoint", "control_plane_vip", "control_plane_fqdn"
    },
    "network":  { "service_cidr", "pod_cidr", "load_balancer_addresses" },
    "access":   { "kubeconfig_path", "kubeconfig_context" },
    "storage":  { "classes[]", "default_class", "nfs_server" },
    "nodes":    { "control_plane_count", "worker_pools": { name: { count, machine_type, labels } } },
    "infrastructure": { "provider", "region", "resource_prefix", "jump_ip", "nfs_ip" }
  }

DAC reads ONLY cluster-contract.json — never inventory, ansible-vars.yaml, or glob paths.
  kubeconfig  →  contract.access.kubeconfig_path   (relative to contract file)
  API server  →  contract.cluster.api_endpoint
  LB IP       →  contract.network.load_balancer_addresses[0]
  Storage     →  contract.storage.default_class
```

---

## Version Governance Flow

```
versions.yaml  (repo root — single source of truth)
  │
  ├── tooling.*              ← Dockerfile ARGs  (TERRAFORM_VERSION, KUBECTL_VERSION, HELM_VERSION)
  │                             scripts/validate-versions.sh enforces equality
  │
  ├── providers.*            ← each topology's versions.tf provider constraints
  │                             validate-versions.sh enforces constraint strings match
  │
  ├── kubernetes[*].components  ← tested CNI/CRI/kube-vip versions per K8s minor
  │                                kubernetes-install.yaml asserts compatibility at runtime
  │
  └── viya_compatibility.*   ← which K8s minors are tested with each Viya LTS
                                DAC or pre-flight script can warn on unsupported combos

Kubernetes version selection inside roles/kubernetes/control_plane/:
  cluster_version "1.31.3"
    → k8s_minor = 31
    → kubeadm_api_version = "v1beta4"    (v1beta3 for <= 1.30)
    → template: kubeadm-config.v1beta4.j2
```
