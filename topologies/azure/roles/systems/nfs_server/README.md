# NFS Server Role - Azure Disk Management

This role sets up an NFS server with RAID5 on Azure managed disks, synchronized with the production IAC `viya4-iac-azure` cloud-config pattern.

## Features

### ✅ Implemented from IAC cloud-config

1. **Wait for Azure Disks** (bootcmd equivalent)
   - Waits up to 10 minutes for 4 Azure managed disks to attach
   - Polls `/dev/disk/azure/scsi1/` directory

2. **LVM RAID5 Setup**
   - Creates physical volumes from Azure disks
   - Creates volume group `data-vg01`
   - Creates RAID5 logical volume `data-lv01` with 3 stripes
   - Mounts to `/export` with proper permissions

3. **NFS Exports Configuration**
   - Root export with `fsid=0` for NFS protocol
   - `/export` with read-write access
   - `/pvs` for viya4-deployment compatibility
   - `/srv/nfs/kubernetes/sc/default` for Kubernetes storage

4. **Persistent Mounting**
   - Adds to `/etc/fstab` using UUID
   - Survives VM reboot

5. **CIDR-Based Access Control** (Production)
   - Variable `nfs_export_cidr` allows specifying allowed CIDR blocks
   - Default: `*` (POC - open to all)
   - Production: Set to `{{ aks_cidr_block }}` from inventory

### Installed Packages

- `nfs-kernel-server` - NFS server daemon
- `rpcbind` - RPC port mapper
- `lvm2` - LVM management tools
- `parted` - Disk partitioning
- `e2fsprogs` - ext4 filesystem utilities

## Usage

### Basic (POC with open access)
```bash
ansible-playbook -i inventory site.yaml -t nfs_server
```

### Production (with CIDR restrictions)
```bash
ansible-playbook -i inventory site.yaml \
  -e nfs_export_cidr="10.0.0.0/8" \
  -t nfs_server
```

### Using Inventory Variables
Define in `inventory/group_vars/nfs_servers.yaml`:
```yaml
aks_cidr_block: "10.0.0.0/8"
nfs_export_cidr: "{{ aks_cidr_block }}"
```

## Verification

After the role runs, verify the setup:

```bash
# Check RAID5 status
sudo lvdisplay /dev/data-vg01/data-lv01

# Check mount
df -h /export

# Check NFS exports
sudo exportfs -v

# Test NFS mount from another host
mount -t nfs <nfs-server-ip>:/export /mnt/test
```

## What's Different from cloud-config

| Aspect | cloud-config | Role |
|--------|--------------|------|
| **Trigger** | cloud-init on first boot | Ansible on any run |
| **Idempotent** | One-time only | Idempotent (safe to re-run) |
| **Error Handling** | Silent failures | Explicit logging and validation |
| **CIDR Control** | Conditional shell logic | Ansible variables |
| **Disk Wait** | Fixed 4-disk count | Uses find command |

## Requirements

- 4 Azure managed disks attached to the VM
- Root/sudo access
- Ubuntu/Debian OS (uses apt package manager)

## Files

- `tasks/main.yaml` - Primary role tasks
- `defaults/main.yaml` - Variable defaults and documentation
- `README.md` - This file
