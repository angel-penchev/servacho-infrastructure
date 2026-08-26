# Advanced Infrastructure as Code: Architecting a Multi-Tenant Proxmox Environment with OpenTofu, OpenBao, and NixOS

The contemporary infrastructure landscape demands rigorous automation, strict multi-tenant isolation, and declarative configuration management. When engineering a hyperconverged environment using Proxmox Virtual Environment (VE), integrating OpenTofu for Infrastructure as Code (IaC), OpenBao for cryptographic secrets management, and NixOS for declarative operating system configurations provides a robust, zero-drift architectural foundation. This report details a comprehensive, sequential strategy for designing, deploying, and managing a multi-organization Proxmox infrastructure. The architecture encompasses dynamic virtual machine (VM) identification, role-based access control (RBAC), Single Sign-On (SSO) integration via Google Workspace, Kubernetes (K3s) and Docker Swarm clustering, and zero-downtime lifecycle management.

## Phase 0: Bootstrapping the Initial OpenTofu Environment

To begin managing a brand new Proxmox cluster with self-hosted OpenTofu, the initial "chicken-and-egg" scenario must be resolved: a virtual machine is required to run OpenTofu, but OpenTofu is intended to provision the virtual machines. This requires a manual bootstrapping phase to create the root Management VM and grant it global API credentials before automating the rest of the infrastructure.

### Implementation Steps

1. **Generate Proxmox API Credentials:** Log into your fresh Proxmox host via SSH as the `root` user to create a dedicated API token rather than relying on root passwords.
    - Create the global OpenTofu user: `pveum user add tofu-provisioner@pve`.
  - Create the initial bootstrap token with full privileges so OpenTofu can authenticate before it begins managing RBAC declaratively: `pveum user token add tofu-provisioner@pve token --privsep=0`.
  - Assign the bootstrap token to a global administrator ACL for the first apply, since the custom `TofuProvisioner` role will be created by OpenTofu itself: `pveum aclmod / -user tofu-provisioner@pve -role Administrator`.
  - The token ID and secret will be displayed in a table; the secret must be saved immediately as it cannot be retrieved again.
2. **Bootstrap the Management VM:** Since OpenTofu is not yet running, manually create the first virtual machine using the "Create VM" wizard in the Proxmox Web UI. Navigate through each screen as follows:
    - **General:** Select your target node (e.g., `pve-01`). Enter **5011** for the VM ID (derived from the Phase 7 dynamic naming convention: VLAN 5 + zero-padded IP octet 011). Set the Name to `management-plane-01`.
    - **OS:** Select "Use CD/DVD disc image file (iso)" and choose your uploaded NixOS minimal installation ISO.
    - **System:** Leave most defaults, but check the **Qemu Agent** box. This allows the Proxmox API (and subsequently OpenTofu) to read the guest's IP address later.
    - **Disks:** Leave Bus/Device as `scsi0` (which implies the high-performance VirtIO SCSI controller). Select your local datastore (e.g., `local-lvm`), check the **Discard** box (to enable TRIM support if you are using SSDs/NVMe storage), and set Disk size to `30` GiB (to accommodate NixOS store caching).
    - **CPU:** Set Cores to `4` and change the Type to `host` for maximum native performance.
    - **Memory:** Set Memory to `8192` MiB (8 GiB). The NixOS evaluation process, coupled with running the OpenBao cryptographic engine, OpenTofu processes, and the GitHub Runner agent requires substantial RAM. 2 GiB is insufficient and will cause out-of-memory (OOM) errors during the NixOS installation or builds.
    - **Network:** Ensure the Model is set to **VirtIO (paravirtualized)** for maximum throughput. Select the default bridge (`vmbr0`) and enter **5** in the VLAN Tag field to place it on the Private Servers network.
    - **Options (Post-Creation):** After the wizard finishes, select the newly created VM on the left sidebar, navigate to the **Options** tab, double-click **Start at boot**, and check the box. This ensures your critical management plane automatically powers on if the physical Proxmox host loses power or reboots.
    - **Finish & Install:** Start the VM, open the console, and complete the NixOS installation. Crucially, during the configuration phase, statically set the machine's IP address to **192.168.5.11**. Ensure the OpenSSH daemon is enabled so you can connect to it remotely.
3. **Install OpenTofu:** SSH into the newly created Management VM at `192.168.5.11` and modify your NixOS environment to install OpenTofu. A concrete, minimal snippet of the NixOS `/etc/nixos/configuration.nix` for this Management VM looks like this:

```
{ config, pkgs, ... }:
{
  # ... (standard bootloader and hardware configurations) ...

  # Set the static IP as requested
  networking.interfaces.eth0.ipv4.addresses = [ {
    address = "192.168.5.11";
    prefixLength = 24;
  } ];
  networking.defaultGateway = "192.168.5.1";
  networking.nameservers = [ "1.1.1.1" ];

  # Install required infrastructure management packages
  environment.systemPackages = with pkgs; [
    opentofu
    git
    colmena # For future remote NixOS deployments
    openbao
  ];

  # Central Secrets Engine for the Root Management Plane
  services.openbao = {
    enable = true;
    settings = {
      ui = true;
      api_addr = "http://127.0.0.1:8200";
      cluster_addr = "http://127.0.0.1:8201";
      listener.tcp = {
        type = "tcp";
        address = "127.0.0.1:8200";
        tls_disable = 1;
      };
      storage.raft = {
        path = "/var/lib/openbao";
        node_id = "servacho-management-plane";
      };
    };
  };

  # Ensure the SSH daemon is enabled so it can be managed remotely
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
  };
}
```

After updating the configuration file, execute `nixos-rebuild switch` to apply the changes and install the OpenTofu binary on the machine.

4. **Configure the Proxmox Provider:** On the bootstrapped Management VM itself, create a dedicated IaC working directory and place your initial OpenTofu files there. A practical bootstrap path is `/srv/iac/bootstrap`. This directory is only for the initial manual bootstrap phase before GitOps is established. In this layout, keep provider configuration in a dedicated `providers.tf` file and keep resources plus import blocks in `main.tf`. The `endpoint` must point to the Proxmox API on the hypervisor or cluster management address, not to the Management VM itself. Because it is a fresh cluster, configure the provider to accept self-signed TLS certificates using `insecure = true`. The `api_token` value must be the full concatenated token string in the form `user@realm!tokenid=tokensecret`.

The below steps are not explicitly nessary, check phase 1 before doing them:
5. **Initialize and Test:** Run `tofu init` to download the provider, then run `tofu plan` to verify successful connectivity to the Proxmox API before attempting any imports.

6. **Import the Management VM into OpenTofu:** Once OpenTofu is initialized and authenticated, bring the manually bootstrapped Management VM under IaC control. Define a `proxmox_virtual_environment_vm` resource block in your `main.tf`, then declare the import directly in code using an `import` block with the `<node_name>/<vm_id>` format. For bootstrap safety, use `lifecycle { ignore_changes = all }` so the first apply records state without mutating the VM.

7. **Create the IaC Role in OpenTofu During Phase 0:** Define `TofuProvisioner` directly in `main.tf` with the provider privileges required for day-to-day VM lifecycle work. This keeps the role declarative from the beginning instead of creating it manually with `pveum`. The root `tofu-provisioner@pve` account will permanently retain the `Administrator` role on `/` to manage cluster-wide infrastructure, IAM, and networking. The custom `TofuProvisioner` role you create here is designed specifically for restricted organizational/tenant users later on.

8. **Avoid Self-Interrupting Apply Runs:** If OpenTofu is executed from the same VM being imported (for example VM `5011`), in-place VM updates can restart the machine and terminate the SSH session mid-apply. During bootstrap, keep the VM resource import-only (`ignore_changes = all`) or execute applies from a different control host.

OpenTofu Configuration for Phase 0 (Provider Bootstrap & VM Import Safety Pattern):

```
resource "proxmox_virtual_environment_role" "tofu_provisioner" {
  role_id = "TofuProvisioner"
  privileges = [
    "VM.Allocate",
    "VM.Audit",
    "VM.Clone",
    "VM.Config.CPU",
    "VM.Config.Memory",
    "VM.Config.Network",
    "VM.Config.HWType",
    "VM.Config.Disk",
    "VM.Config.Options",
    "VM.Config.Cloudinit",
    "VM.PowerMgmt",
    "VM.GuestAgent.Audit",
    "Datastore.AllocateSpace",
    "Datastore.Audit",
    "SDN.Use",
    "Pool.Audit"
  ]
}

# Commented out because the import block is a one-time operation.
# Once the VM is successfully imported into the OpenTofu state file, 
# this block is no longer needed and can be safely disabled.
# import {
#   id = "Servacho-Alice/5012"
#   to = proxmox_virtual_environment_vm.management_vm
# }

resource "proxmox_virtual_environment_vm" "management_vm" {
  name          = "servacho-managment-plane"
  node_name     = "Servacho-Alice"
  vm_id         = 5011
  scsi_hardware = "virtio-scsi-single"

  # Reflecting the manual configuration
  on_boot = true

  agent {
    enabled = true
    timeout = "15m"
    trim    = false
  }

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  disk {
    interface    = "scsi0"
    datastore_id = "local-lvm"
    file_format  = "raw"
    size         = 32
    cache        = "none"
    discard      = "ignore"
    iothread     = true
    ssd          = false
  }

  memory {
    dedicated = 4096
  }

  network_device {
    bridge   = "vmbr0"
    enabled  = true
    firewall = true
    model    = "virtio"
    vlan_id  = 0
  }

  operating_system {
    type = "l26"
  }

  vga {
    enabled = true
  }

  # Commented out because we now WANT OpenTofu to actively manage this VM. 
  # Keeping 'ignore_changes = all' would prevent updating things like CPU or RAM
  # in the future.
  # lifecycle {
  #   # Bootstrap safety: import state first without mutating the VM that is
  #   # currently running OpenTofu. Remove this once applying from another host
  #   # and when ready to reconcile config changes intentionally.
  #   ignore_changes = all
  # }
}
```

After the first successful import/apply, remove the `import` block and gradually replace `ignore_changes = all` with explicit managed attributes.

## Phase 1: GitOps Automation, CI/CD, and Declarative Imports

Before deploying the rest of the infrastructure, it is critical to establish a GitOps pipeline. Operators should not need to SSH into the Management VMs to manually execute `tofu plan`, `tofu apply`, or `tofu import`. The entire lifecycle must be managed through the GitHub repository interface via pull request automation.

To achieve this, GitHub Actions Self-Hosted Runners are deployed on the Management VMs. These runners listen for events from the GitHub repository and execute OpenTofu commands locally on the management node, reporting the output directly back to the GitHub UI.

After this phase is in place, the manually created bootstrap directory from Phase 0 is no longer the primary execution path. OpenTofu commands are instead run from the GitHub repository checkout created by the self-hosted runner for each workflow job. In other words, Phase 0 uses a manually created local working directory on the Management VM, while Phase 1 and later execute from the repository workspace checked out by GitHub Actions.

### Persistent OpenTofu State on the Runner

The GitHub Actions checkout is transient and must not hold the OpenTofu state file. Configure the local backend with a path outside the checkout, for example `/var/lib/opentofu/servacho-infrastructure.tfstate`:

```
terraform {
  backend "local" {
    path = "/var/lib/opentofu/servacho-infrastructure.tfstate"
  }
}
```

The GitHub runner service is sandboxed with a read-only filesystem. Its NixOS configuration must add `opentofu` to `serviceOverrides.StateDirectory`; systemd then creates `/var/lib/opentofu` on persistent storage and grants access to the runner's dynamically allocated service account. Do not create or change its ownership manually. Back up the directory, because state can contain sensitive values and must not be committed to Git.

After adding or changing the backend, run `tofu -chdir=tofu init -migrate-state` once on the runner host to move an existing local state file to the persistent path. If the old state is no longer available, import the already-created resources before applying. The plan and apply workflows should share a GitHub Actions concurrency group so only one operation accesses the state at a time.

### Checking Status and Declared Resources Without Logging In

When an engineer pushes a change to the GitHub repository and opens a Pull Request, the CI/CD pipeline automatically runs `tofu plan`. The output of this plan—detailing exactly which resources will be created, modified, or destroyed—is posted automatically as a comment on the Pull Request. This provides full visibility into the declared resources and the impending infrastructure state directly within GitHub, enabling peer review without ever granting engineers SSH access to the Management VM. Merging the Pull Request subsequently triggers `tofu apply`, permanently enacting the changes.

### Declarative Import from the Repository

Historically, importing existing infrastructure into state required operators to access the terminal and run imperative commands like `tofu import <resource> <id>`. OpenTofu completely eliminates this requirement with the introduction of the declarative `import` block.

Using an `import` block, an operator simply writes the intent to import an existing Proxmox VM or Unifi network directly into a `.tf` file in the GitHub repository. When the Pull Request is opened, the CI/CD pipeline's `tofu plan` validates the import, showing the intent to bind the remote object to the state without making any destructive changes. Once the PR is approved and merged, the pipeline executes the apply, seamlessly bringing the infrastructure under OpenTofu's management.

### Implementation Steps

1. **Host the GitHub Actions Runner on the Management VM:**
    
    NixOS provides a native module for spinning up self-hosted runners. Update your Management VM's `configuration.nix` to include the `services.github-runners` module. This securely attaches the VM to your repository and injects the necessary tools (OpenTofu, Colmena, Git) into the runner's PATH so it can execute infrastructure code locally.
    

    ```nix
    # /etc/nixos/configuration.nix on the Management VM
    { config, pkgs, ... }:
    {
      services.github-runners = {
        management-runner = {
          enable = true;
          url = "https://github.com/angel-penchev/servacho-infrastructure";
          tokenFile = "/var/lib/github-runner/.token";
          extraPackages = with pkgs; [ opentofu git colmena ];
          extraLabels = [ "servacho-management-plane" "self-hosted" ];
        };
      };
    }
    ```


    Generate the `.token` file referenced above before starting or rebuilding the runner service:

    1. In GitHub, open your repository and navigate to **Settings -> Actions -> Runners**.
    2. Click **New self-hosted runner** and select the target OS/architecture for your Management VM.
    3. Copy the runner registration token shown in the setup instructions page (this token is time-limited).
    4. On the Management VM, create the token directory and write the token to the expected file path:

      ```bash
      sudo install -d -m 0755 /var/lib/github-runner
      sudo sh -c 'cat > /var/lib/github-runner/.token'
      # Paste token, then press Ctrl+D
      ```

    5. Restrict file permissions so only root can read it:

      ```bash
      sudo chown root:root /var/lib/github-runner/.token
      sudo chmod 0600 /var/lib/github-runner/.token
      ```

    6. Apply the NixOS configuration so the runner service can consume the token:

      ```bash
      sudo nixos-rebuild switch
      ```

    7. If the registration token expires before use, generate a new one from the same GitHub Runners page and overwrite `/var/lib/github-runner/.token`.

1. **Define the CI/CD Pull Request Plan Workflow:**
    
    Create a `.github/workflows/tofu-plan.yaml` file in your repository. This workflow triggers when a Pull Request is opened or updated, executes `tofu plan`, and securely comments the output back on the PR.

```yaml
# .github/workflows/tofu-plan.yaml
name: OpenTofu Plan

on:
  pull_request:
    branches: [main]

permissions:
  contents: read
  pull-requests: write

concurrency:
  group: tofu-state
  cancel-in-progress: false

jobs:
  plan:
    runs-on: [self-hosted, servacho-management-plane]

    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: OpenTofu init
        run: tofu -chdir=tofu init

      - name: OpenTofu plan
        id: plan
        run: |
          # Use pipefail so that if tofu fails, the whole pipeline step registers the failure
          set -o pipefail
          
          # Run tofu with -input=false, and use 'tee' to show logs in real-time while saving to the file
          tofu -chdir=tofu plan -no-color -input=false -out=tfplan 2>&1 | tee plan_output.txt
          
          # Capture the exit code of the tofu command (not the tee command)
          exit_code=${PIPESTATUS[0]}
          echo "exit_code=$exit_code" >> "$GITHUB_OUTPUT"
          
          # Don't fail the step here so the next PR comment step can run
          exit 0

      - name: Post plan to PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v8
        env:
          PLAN_EXIT_CODE: ${{ steps.plan.outputs.exit_code }}
        with:
          script: |
            const fs = require('fs');
            const path = 'plan_output.txt';
            let planOutput = fs.existsSync(path) ? fs.readFileSync(path, 'utf8') : 'No plan output found.';

            const maxLen = 60000;
            if (planOutput.length > maxLen) {
              planOutput = `${planOutput.slice(0, maxLen)}

...truncated...`;
            }

            const status = process.env.PLAN_EXIT_CODE === '0' ? 'Success' : 'Failed';
            const body = [
              '### OpenTofu Plan Results',
              `Status: **${status}**`,
              '',
              '```hcl',
              planOutput,
              '```'
            ].join('
');

            // 1. Get every existing comment, not just GitHub's first page.
            const comments = await github.paginate(github.rest.issues.listComments, {
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
            });

            // 2. Find the comment made by the bot that contains our header
            const botComment = comments.find(comment => {
              return comment.user.type === 'Bot' && comment.body.includes('### OpenTofu Plan Results');
            });

            // 3. Update if found, otherwise create a new one
            if (botComment) {
              await github.rest.issues.updateComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                comment_id: botComment.id,
                body: body
              });
            } else {
              await github.rest.issues.createComment({
                issue_number: context.issue.number,
                owner: context.repo.owner,
                repo: context.repo.repo,
                body: body
              });
            }

      - name: Fail workflow if plan failed
        if: steps.plan.outputs.exit_code != '0'
        run: |
          echo "OpenTofu plan failed. See PR comment for details."
          exit 1
```


1. **Define the CI/CD Apply Workflow:**
    
    Create a `.github/workflows/tofu-apply.yaml` file to execute changes automatically when code is merged into the `main` branch.
    

```yaml
# .github/workflows/tofu-apply.yaml
name: OpenTofu Apply

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      branch:
        description: Branch or tag to apply
        required: true
        default: main
        type: string
      auto_approve:
        description: Apply without waiting for GitHub environment approval
        required: true
        default: false
        type: boolean

permissions:
  contents: read

concurrency:
  group: tofu-state
  cancel-in-progress: false

jobs:
  apply-automatically:
    if: github.event_name == 'push' || inputs.auto_approve
    runs-on: [self-hosted, servacho-management-plane]

    steps:
      - name: Checkout code
        uses: actions/checkout@v6
        with:
          ref: ${{ github.event_name == 'workflow_dispatch' && inputs.branch || github.sha }}

      - name: OpenTofu init
        run: tofu -chdir=tofu init

      - name: OpenTofu apply
        run: tofu -chdir=tofu apply -auto-approve

  apply-with-approval:
    if: github.event_name == 'workflow_dispatch' && !inputs.auto_approve
    runs-on: [self-hosted, servacho-management-plane]
    environment:
      name: tofu-apply

    steps:
      - name: Checkout code
        uses: actions/checkout@v6
        with:
          ref: ${{ inputs.branch }}

      - name: OpenTofu init
        run: tofu -chdir=tofu init

      - name: OpenTofu apply
        run: tofu -chdir=tofu apply -auto-approve
```

1. **Execute Declarative Imports via Git:**
    
    To import an existing resource (e.g., an unmanaged legacy database VM), add an `import` block to your configuration alongside the matching `resource` block. Push the changes to GitHub, review the plan output in the automated PR comment, and merge. OpenTofu will gracefully absorb the resource on the next apply run. After the import is successful, the `import` block becomes inert and can be removed in a subsequent PR.
    

OpenTofu Configuration for Phase 1 (Declarative Import Block Example):

```
# This block is committed to the GitHub repository.
# When the PR is generated, the CI/CD pipeline runs `tofu plan`,
# which will detect the remote VM and prepare the state import.

import {
  # The ID format expected by the provider (e.g., node_name/vm_id)
  id = "pve-01/105"

  # The OpenTofu resource address it will be bound to
  to = proxmox_virtual_environment_vm.legacy_database
}

# The corresponding resource block must also be written to map the imported data
resource "proxmox_virtual_environment_vm" "legacy_database" {
  name      = "legacy-db-01"
  node_name = "pve-01"
  vm_id     = 105
  # Attributes matching the current state of the VM must be filled out here
}
```

### Example Git Repository File Tree (Management Plane)

The following example shows a practical single-repository layout for a tenant-specific Management Plane (for example, Qoax). It keeps infrastructure provisioning (`terraform`) and operating system state (`nixos`) separated while sharing environment-specific values through clear boundaries.

```
management-plane-qoax/
├── .github/
│   └── workflows/
│       ├── tofu-plan.yaml
│       ├── tofu-apply.yaml
│       └── colmena-apply.yaml
├── terraform/
│   ├── versions.tf
│   ├── providers.tf
│   ├── backend.tf
│   ├── variables.tf
│   ├── locals.tf
│   ├── outputs.tf
│   ├── imports.tf
│   ├── main.tf
│   ├── vm-management-plane.tf
│   ├── vm-workloads.tf
│   ├── networking.tf
│   ├── rbac.tf
│   ├── openbao.tf
│   ├── cloud-init/
│   │   └── ubuntu-appliance.yaml
│   ├── modules/
│   │   ├── proxmox-vm/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── vm-id/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   └── env/
│       ├── qoax.tfvars
│       └── qoax-media.tfvars
├── nixos/
│   ├── flake.nix
│   ├── flake.lock
│   ├── colmena.nix
│   ├── profiles/
│   │   ├── management-plane.nix
│   │   ├── k3s-server.nix
│   │   ├── k3s-agent.nix
│   │   └── docker-swarm-node.nix
│   ├── hosts/
│   │   ├── qoax-management-01/
│   │   │   ├── default.nix
│   │   │   └── hardware-configuration.nix
│   │   ├── qoax-k3s-01/
│   │   │   ├── default.nix
│   │   │   └── hardware-configuration.nix
│   │   └── qoax-k3s-02/
│   │       ├── default.nix
│   │       └── hardware-configuration.nix
│   ├── manifests/
│   │   ├── k3s-upgrade-plan.nix
│   │   └── base-apps.nix
│   └── secrets/
│       ├── README.md
│       └── .gitkeep
├── scripts/
│   ├── tofu-fmt-check.sh
│   ├── tofu-validate.sh
│   └── openbao-login-oidc.sh
├── docs/
│   ├── runbook-bootstrap.md
│   ├── runbook-disaster-recovery.md
│   └── adr/
│       └── 0001-state-backend-local-on-management-vm.md
├── .env.example
├── .gitignore
├── .sops.yaml
├── Makefile
└── README.md
```

Suggested conventions:

- Keep `backend.tf` and state-path decisions tenant-local per repository.
- Keep reusable compute/network primitives in `terraform/modules/`.
- Keep host-specific NixOS in `nixos/hosts/` and shared behavior in `nixos/profiles/`.
- Keep secrets out of Git and resolve credentials dynamically from OpenBao at runtime.

## Phase 2: Central Secrets Management (Root OpenBao)

Before configuring networking and provisioning resources across the cluster, the root Management VM must establish a secure secrets store. Hardcoding credentials for Unifi or the Proxmox API in plaintext within Git is a severe security vulnerability.

By leveraging the OpenBao instance installed in Phase 0 on the root Management VM, we create a secure vault to store infrastructure credentials. OpenTofu will read from this vault at runtime.

### Implementation Steps

1. **Initialize and Unseal OpenBao:** SSH into the root Management VM. Because TLS is disabled for local loopback connections, you must first tell the CLI to use HTTP by running `export BAO_ADDR="http://127.0.0.1:8200"`. Then, run `bao operator init`. 
    - **Understanding Shamir's Secret Sharing:** OpenBao encrypts all data at rest and starts in a "sealed" state. To prevent a single point of compromise, the master unseal key is mathematically split into fragments.
        - **Key Shares:** The total number of pieces the master key is split into.
        - **Key Threshold:** The minimum number of pieces required to reconstruct the master key.
    - **Choosing your Quorum:** 
        - *Solo/Lab Environments:* You may append `-key-shares=1 -key-threshold=1` to generate a single unseal password for maximum convenience.
        - *Production Environments:* Use the standard `-key-shares=5 -key-threshold=3`. This creates a quorum, ensuring no single administrator can unilaterally decrypt the vault, and provides resilience if someone loses their key.
    - Securely store the generated unseal keys and root token offline. Unseal the vault with `bao operator unseal` (entering the required threshold of keys).
2. **Store Infrastructure Secrets:** You can store your Proxmox API token (and any subsequent credentials) using either the Web UI or the Command Line.

   **Option A: Using the Web UI**
   Because the vault only listens on `127.0.0.1` (localhost), you must create a secure SSH tunnel from your workstation:
   ```bash
   ssh -L 8200:127.0.0.1:8200 servacho-managment-plane@<MANAGEMENT_VM_IP>
   ```
   - Open `http://127.0.0.1:8200/ui` in your web browser.
   - **Unseal:** Enter the required threshold of Unseal Keys one by one.
   - **Sign In:** Leave the `Namespace` field completely blank, select **Token** as the method, and paste your **Initial Root Token**.
   - **Create Secrets:** 
       - Navigate to **Secrets Engines** -> **Enable new engine** -> **KV**. Set the path to `secret`.
       - Open the new `secret` engine, click **Create secret**, set the path to `proxmox`, and add an `api_token` key with your Proxmox token value (e.g., `tofu-provisioner@pve!token=...`).

   **Option B: Using the CLI**
   If you prefer to stay in the SSH terminal, log in using your root token and create the key-value secrets engine directly:
   ```bash
   bao login <Initial_Root_Token>
   bao secrets enable -path=secret kv-v2
   bao kv put secret/proxmox api_token="<Your_Proxmox_Token>"
   ```
3. **Configure the Vault Provider:** Update your OpenTofu `providers.tf` configuration to retrieve your Proxmox credentials dynamically from OpenBao, replacing the temporary plaintext token from Phase 1.

OpenTofu Configuration for Phase 2 (Vault Provider Setup):

```hcl
provider "vault" {
  address = "http://127.0.0.1:8200"
  # Vault token is provided securely via the VAULT_TOKEN environment variable in CI
}

ephemeral "vault_kv_secret_v2" "proxmox_credentials" {
  mount = "secret"
  name  = "proxmox"
}

provider "proxmox" {
  endpoint  = "https://192.168.5.10:8006/"
  # The api_token is securely injected from OpenBao
  api_token = ephemeral.vault_kv_secret_v2.proxmox_credentials.data["api_token"]
  insecure  = true
}
```

## Phase 3: Network Orchestration and Unifi Infrastructure Configuration

With GitOps established, all further changes are handled via Pull Requests. A foundational element of a highly automated infrastructure is the deterministic mapping of network topologies to compute resources. The environment relies on a Unifi routing ecosystem to manage distinct Virtual Local Area Networks (VLANs), segregating traffic for different organizational units and exposure levels. This segregation is the physical and logical basis for the subsequent multi-tenant isolation strategy.

Managing the Unifi network layer via OpenTofu ensures that the physical and logical network configurations remain synchronized with the compute infrastructure. By utilizing a Unifi OpenTofu provider, the infrastructure pipeline can programmatically define networks, firewall rules, and DHCP reservations. The network topology dictates the operational boundaries for the virtual machines.

The following table outlines the prescribed VLAN architecture based on the specified network requirements and the provided environment topography:

| **Network Name** | **VLAN ID** | **Subnet** | **DHCP Strategy** | **Primary Architectural Use Case** |
| --- | --- | --- | --- | --- |
| Default | 1 | 192.168.1.0/24 | Server | Core infrastructure management and hypervisor access |
| Main | 2 | 192.168.2.0/24 | Server | Primary trusted local devices and operator workstations |
| Guest | 3 | 192.168.3.0/24 | Server | Untrusted ephemeral device access |
| Public Servers | 4 | 192.168.4.0/24 | Static/Reserved | Externally facing services, reverse proxies, and ingress controllers |
| Private Servers | 5 | 192.168.5.0/24 | Static/Reserved | Internal databases, management planes, and personal administration |
| IoT | 6 | 192.168.6.0/24 | Server | Isolated smart devices and sensors |
| Qoax VPS | 10 | 192.168.10.0/24 | Static/Reserved | Multi-tenant compute for the Qoax organization |
| Qoax Media VPS | 11 | 192.168.11.0/24 | Static/Reserved | High-bandwidth media processing, transcoders, and object storage |
| FMI{Codes} VPS | 12 | 192.168.12.0/24 | Static/Reserved | Isolated compute for the FMI educational/development organization |

### Implementation Steps

1. **Store Unifi Credentials:** Store your Unifi Dream Machine credentials securely in OpenBao.
   - **Using the Web UI:** Access `http://127.0.0.1:8200/ui` (via SSH tunnel), navigate to your `secret` KV engine, click **Create secret**, set the path to `unifi`, and add the `username` and `password` keys.
   - **Using the CLI:** 
     ```bash
     bao kv put secret/unifi username="admin" password="<SuperSecretPassword>"
     ```
2. **Initialize Unifi Provider:** Configure the Unifi OpenTofu provider in your central network-management repository to retrieve the credentials dynamically via the Vault provider.
3. **Define Networks:** Create `unifi_network` resources for each VLAN, explicitly setting the `vlan_id`, `subnet`, and `dhcp_enabled` attributes according to the table above.
4. **Export Network Outputs:** Use OpenTofu `output` variables to export the resulting Unifi network IDs and VLAN tags.
5. **Map to Proxmox Bridges:** Ensure the Proxmox nodes are physically connected to a trunk port on the Unifi switch. Proxmox instances will utilize the standard `vmbr0` bridge, and the VLAN tagging will be handled at the VM network interface level within the OpenTofu `bpg/proxmox` provider.

OpenTofu Configuration for Phase 3 (Unifi Networks Setup):

```
terraform {
  required_providers {
    unifi = {
      source  = "paultyng/unifi"
      version = "~> 0.41.0"
    }
  }
}

provider "unifi" {
  username = data.vault_generic_secret.unifi_credentials.data["username"]
  password = data.vault_generic_secret.unifi_credentials.data["password"]
  api_url  = "https://unifi.local"
  insecure = true
}

resource "unifi_network" "qoax_vps" {
  name         = "Qoax VPS"
  purpose      = "corporate"
  vlan_id      = 10
  subnet       = "192.168.10.1/24"
  dhcp_enabled = false
}

output "qoax_vps_vlan" {
  value = unifi_network.qoax_vps.vlan_id
}
```

## Phase 4: Proxmox Role-Based Access Control and Tenant Isolation

Supporting multiple distinct organizations (Personal, Qoax, FMI{Codes}) on a single Proxmox cluster introduces complex security and isolation requirements. The architecture dictates that different Git repositories manage different sets of machines, and each repository must be strictly confined to its administrative domain. An OpenTofu run triggered by the Qoax repository must be physically and cryptographically incapable of modifying the Personal or FMI{Codes} environments.

To prevent organizational overreach, Proxmox Resource Pools and Role-Based Access Control (RBAC) are utilized as the boundary mechanism. Crucially, the **first OpenTofu instance** (the root Management VM established in Phase 0) acts as the central Identity and Access Management (IAM) authority. It is exclusively responsible for defining all operational roles, users, and resource pools across the entire cluster.

### Implementation Steps

1. **Manage Roles via Root OpenTofu:** Utilize the root OpenTofu instance to manage all Proxmox roles. The `TofuProvisioner` role is created declaratively in Phase 0. While the root `tofu-provisioner@pve` user stays an `Administrator`, this `TofuProvisioner` role serves as the template for all organizational tenant access.
2. **Create Resource Pools:** Use the root OpenTofu instance to codify organizational pools (e.g., `pool-qoax`, `pool-personal`).
3. **Create the Users:** Generate distinct users for each tenant's automation using the root OpenTofu configuration. Note that the `bpg/proxmox` provider deprecates inline ACL blocks in favor of the dedicated `proxmox_acl` resource.
4. **Apply Access Control Lists (ACLs):** Bind the user to their specific pool via the root OpenTofu instance, referencing the managed `TofuProvisioner` role to strictly enforce organizational boundaries.
5. **Generate API Tokens:** From the Proxmox CLI, generate the specific tokens for each user utilizing `-privsep 0` so the token inherits the strictly scoped pool permissions.

OpenTofu Configuration for Phase 4 (RBAC Setup via Root Management VM):

```
# Create the Resource Pool for the Qoax Organization
resource "proxmox_virtual_environment_pool" "pool_qoax" {
  pool_id = "pool-qoax"
  comment = "Isolated Resource Pool for Qoax Infrastructure"
}

# Create the dedicated user for the Qoax organization
resource "proxmox_virtual_environment_user" "tofu_qoax" {
  user_id = "tofu-qoax@pve"
  comment = "Qoax IaC Account"
}

# Bind the user and role explicitly to the Qoax resource pool.
# This references the `proxmox_virtual_environment_role.tofu_provisioner`
# that is now managed by this root OpenTofu instance (from Phase 0).
resource "proxmox_acl" "qoax_pool_acl" {
  path      = "/pool/${proxmox_virtual_environment_pool.pool_qoax.pool_id}"
  role_id   = proxmox_virtual_environment_role.tofu_provisioner.role_id
  user_id   = proxmox_virtual_environment_user.tofu_qoax.user_id
  propagate = true
}
```

## Phase 5: The Dedicated Management Plane and State Isolation

While software-defined RBAC provides the hypervisor-level barrier, the IaC state files and the execution environments themselves must be isolated. Relying solely on logical namespaces within a single, monolithic management instance increases the risk of cross-tenant contamination. The architectural solution is to deploy a dedicated "Management VM" for each Virtual Private Server (VPS) organization.

Each Management VM operates in an isolated VLAN (or a highly restricted management subnet) and hosts its own independent instances of OpenTofu and OpenBao.

### Implementation Steps

1. **Provision Tenant Management VMs via Root OpenTofu:** Unlike the root Management VM (which was bootstrapped manually in Phase 0), the tenant-specific Management VMs (Personal, Qoax, and FMI) are provisioned entirely declaratively by the root OpenTofu instance. Define `proxmox_virtual_environment_vm` resources in your root `.tf` files for each tenant management node, assigning them directly to the resource pools created in Phase 4 (e.g., `pool_id = proxmox_virtual_environment_pool.pool_qoax.id`).
2. **Strict Network Segregation:** Assign the network interfaces for these VMs to their respective, isolated VLANs using the dynamic ID calculation logic defined in Phase 7. For example, configure the Qoax Management VM with a static IP of `192.168.10.11` on VLAN `10` (yielding VM ID `10011`), and the FMI Management VM with `192.168.12.11` on VLAN `12` (yielding VM ID `12011`).
3. **Deploy Core Tooling via Colmena:** From the root Management VM, execute a `colmena apply` deployment to push the NixOS operating system configurations to the newly created tenant Management VMs over SSH. The Nix flake configuration for these child management nodes must explicitly install the `opentofu` and `colmena` packages, and activate the `services.openbao` module configured to use a local Raft integrated storage backend.
4. **Initialize and Unseal OpenBao:** Once the NixOS configuration is active, the OpenBao daemon on each tenant VM will start in a sealed, uninitialized state. SSH into the Qoax Management VM and execute `bao operator init -key-shares=5 -key-threshold=3`. This process outputs five unseal keys and one initial root token. Save these securely (e.g., in the root Management VM's secure offline storage). Finally, run `bao operator unseal` three consecutive times, inputting a different key each time, until the `Sealed` status changes to `false`. Repeat this manual unseal process for the FMI and Personal Management VMs.
5. **Isolate State Backend Configuration:** In the isolated Git repository designated for the Qoax infrastructure, configure the OpenTofu `backend` to store its `.tfstate` locally on the Qoax Management VM's disk at a designated path (e.g., `/var/lib/opentofu/qoax-infrastructure.tfstate`). By executing the Qoax pipeline exclusively on the Qoax VM, the OpenTofu execution environment is physically and cryptographically prevented from reading the FMI or Personal state files.

NixOS Configuration for Phase 5 (OpenBao Service Definition applied via Colmena):

```
services.openbao = {
  enable = true;
  settings = {
    ui = true;
    api_addr = "http://127.0.0.1:8200";
    cluster_addr = "http://127.0.0.1:8201";

    listener.tcp = {
      address = "127.0.0.1:8200";
      # Disabling TLS here assumes you will access it via localhost
      # or place it behind a secure reverse proxy on the management VLAN.
      tls_disable = 1;
    };

    storage.raft = {
      path = "/var/lib/openbao";
      node_id = "raft_node_1";
    };
  };
};

# Ensure required packages exist on the tenant management VM
environment.systemPackages = with pkgs; [
  opentofu
  git
  colmena
];
```

OpenTofu Configuration for Phase 5 (Root Provisioning & State Backend Isolation):

```
# 1. Provisioning the Qoax Management VM from the ROOT OpenTofu instance
resource "proxmox_virtual_environment_vm" "qoax_management_vm" {
  name      = "qoax-management-plane"
  node_name = "pve-01"
  vm_id     = 10011 # Calculated as VLAN 10 + IP .011
  pool_id   = proxmox_virtual_environment_pool.pool_qoax.id

  # Clone from NixOS template
  clone {
    vm_id = 9000
    full  = true
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.10.11/24"
        gateway = "192.168.10.1"
      }
    }
    user_account {
      keys = ["ssh-ed25519 AAAAC3NzaC1... your-root-management-pub-key"]
    }
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = 10
  }

  # ... other standard VM hardware configs ...
}

# -------------------------------------------------------------------

# 2. State Backend config inside the QOAX SPECIFIC Git repository.
# This runs exclusively on the Qoax Management VM.
terraform {
  backend "local" {
    # State file is securely stored on the isolated management plane disk
    path = "/var/lib/opentofu/qoax-infrastructure.tfstate"
  }
}
```

## Phase 6: Tenant Secrets Management and Authentication Strategies

Secret management is a critical vector for securing the infrastructure pipeline, ensuring that credentials, API tokens, and SSH private keys are never hardcoded into the Git repositories. OpenBao, an open-source derivative of HashiCorp Vault, serves as the cryptographic heart of each Management VM.

Because the infrastructure spans multiple environments (Root, Personal, Qoax, FMI), the authentication strategy must adapt to the operational context:

- **Path A: Single Password/Token (Root & Personal Installations):** For the root management plane or isolated personal labs, operators can rely on the Initial Root Token generated during initialization, or enable the basic `userpass` auth method (`bao auth enable userpass`). This provides a simple, single-password login path without external dependencies, which is critical for disaster recovery and solo operations.
- **Path B: SSO Integration (Production & Multi-Tenant Installations):** For organizational tenants (e.g., Qoax, FMI{Codes}), relying on static tokens or shared passwords for human access is an operational anti-pattern. Instead, tenant OpenBao instances are configured to delegate authentication to a Google Workspace environment via Single Sign-On (SSO) using the OpenID Connect (OIDC) protocol. This ensures centralized revocation, MFA enforcement, and accurate audit logging tied to real human identities.

### Implementation Steps (SSO Path)

1. **Configure Google Workspace OAuth:**
    - Navigate to the Google Cloud Console APIs & Services dashboard.
    - Configure the OAuth Consent Screen as an *Internal* application type.
    - Create new OAuth 2.0 Client ID credentials (Web Application).
    - Set the Authorized Redirect URI to match the OpenBao instance callback (e.g., `http://127.0.0.1:8200/ui/vault/auth/oidc/oidc/callback`).
    - Note the Client ID and Client Secret.
2. **Enable OIDC in OpenBao:** On the Qoax Management VM, execute `bao auth enable oidc`.
3. **Configure the Auth Method:** Set the OIDC provider settings in OpenBao, injecting the Google credentials.
4. **Create Role Mappings:** Create the `qoax-engineers` role within OpenBao to map the Google authentication to specific internal policies.
5. **Dynamic Provider Injection:** In your IaC code, utilize the HashiCorp Vault provider to fetch your Proxmox token dynamically at runtime so it is never committed to Git.

OpenTofu Configuration for Phase 6 (Dynamic Credentials via Vault/OpenBao):

```
provider "vault" {
  # The OpenBao service address running locally on the management VM
  address = "http://127.0.0.1:8200"
  # Vault token is provided via the VAULT_TOKEN environment variable
}

data "vault_generic_secret" "proxmox_credentials" {
  path = "secret/proxmox/qoax_token"
}

provider "proxmox" {
  endpoint  = "https://<YOUR_PROXMOX_IP>:8006/"
  # Inject the dynamically fetched secret into the provider configuration
  api_token = ephemeral.vault_kv_secret_v2.proxmox_credentials.data["api_token"]
  insecure  = true
}
```

## Phase 7: Dynamic Virtual Machine Identifier Calculation

With access controls, networks, and secrets handled, OpenTofu is ready to deploy tenant workloads. Proxmox VE requires a unique integer ID for every virtual machine across the cluster, which serves as the primary key for all API operations. In manually managed environments, these IDs are often assigned sequentially, leading to administrative overhead and cognitive disconnect when attempting to correlate a VM ID with its IP address or network segment.

To resolve this, a dynamic calculation methodology within OpenTofu generates deterministic VM IDs based on the assigned VLAN and a zero-padded, 3-digit version of the final IPv4 octet. This zero-padding is crucial to prevent collision and overlapping namespaces. For example, without zero-padding, a machine on `192.168.5.11` (VLAN 5) would become ID `511`, while a machine on `192.168.51.1` (VLAN 51) would also become ID `511`. By padding the final octet to three digits, `.5.11` becomes ID `5011` and `.51.1` becomes ID `51001`, completely isolating the numerical spaces.

### Implementation Steps

1. **Define Input Variables:** Create variables in your OpenTofu module for the target IP and VLAN.
2. **Calculate the ID:** Use HCL `locals` to split the IP string, extract the final octet, format it to always strictly possess 3 digits via `format("%03d", ...)`, and finally concatenate the values.
3. **Assign to VM Resource:** Pass the calculated variable to the `bpg/proxmox` provider block.

OpenTofu Configuration for Phase 7 (Dynamic VM IDs):

```
variable "vm_ip_address" {
  type        = string
  description = "The target IP address for the VM, e.g., 192.168.5.11"
}

variable "vlan_id" {
  type        = string
  description = "The VLAN ID corresponding to the subnet, e.g., 5"
}

locals {
  # Split the IP address into an array of octets
  ip_octets = split(".", var.vm_ip_address)

  # Extract the final octet (index 3)
  final_octet = local.ip_octets[3]

  # Zero-pad the final octet to 3 digits to prevent collisions
  padded_octet = format("%03d", tonumber(local.final_octet))

  # Concatenate the VLAN ID and the padded octet, then cast to a number
  # e.g., VLAN 5 + padded "011" = 5011
  calculated_vm_id = tonumber("${var.vlan_id}${local.padded_octet}")
}

resource "proxmox_virtual_environment_vm" "node" {
  name  = "node-${local.calculated_vm_id}"
  vm_id = local.calculated_vm_id

  # Clone from a pre-built NixOS template with qemu-guest-agent and cloud-init enabled
  clone {
    vm_id = 9000
    full  = true
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${var.vm_ip_address}/24"
        gateway = "192.168.${var.vlan_id}.1"
      }
    }
    user_account {
      # Inject SSH key so Colmena can deploy to the machine
      keys = ["ssh-ed25519 AAAAC3NzaC1... your-management-pub-key"]
    }
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = var.vlan_id
  }
}
```

## Phase 8: Declarative Operating System Configuration via NixOS and GitOps

The synergy between OpenTofu and NixOS provides an exceptionally powerful paradigm for infrastructure management. While OpenTofu excels at provisioning the underlying hardware, NixOS excels at declaratively defining the state of the operating system.

Each organization maintains a dedicated Git repository featuring a `/terraform` directory (for hardware) and a `/nixos` directory (containing the `flake.nix` software state). The deployment is a strict two-stage process using `colmena`.

### Implementation Steps

1. **Hardware Provisioning:** Define the `proxmox_virtual_environment_vm` resource in OpenTofu. Ensure `agent { enabled = true }` is set so Proxmox can resolve the VM's IP address once it boots.
2. **Cloud-Init Bootstrapping:** Inject an SSH public key via a Proxmox Cloud-Init snippet so the Management VM can access the newly cloned machine over SSH.
3. **Colmena Invocation:** Utilize an OpenTofu `null_resource` block that triggers immediately after the VM creation. This block executes Colmena locally on the Management VM to build and push the NixOS configuration.

OpenTofu Configuration for Phase 8 (GitOps NixOS Deployment):

```
resource "null_resource" "nixos_deploy" {
  # This block triggers any time the Proxmox VM ID or IP address changes
  triggers = {
    instance_id = proxmox_virtual_environment_vm.node.id
    ip_address  = var.vm_ip_address
  }

  provisioner "local-exec" {
    # Wait for SSH to become available before attempting to deploy
    # to avoid race conditions right after Proxmox VM creation
    command     = <<-EOT
      echo "Waiting for SSH on ${var.vm_ip_address}..."
      while ! nc -z ${var.vm_ip_address} 22; do
        sleep 5
      done
      colmena apply --on ${var.vm_ip_address}
    EOT
    # Target the nixos directory relative to the terraform execution path
    working_dir = "../nixos"
  }
}
```

## Phase 9: Kubernetes (K3s) Cluster Orchestration Templates

To support microservices and containerized workloads across the different VPS environments, K3s (a lightweight, highly available Kubernetes distribution) is deployed directly via NixOS modules.

The architecture must support multiple distinct Kubernetes clusters per VPS by parameterizing network listening ports and API endpoints.

### Implementation Steps

1. **Configure Master Node:** In your `flake.nix`, configure the K3s server role and initialize the cluster using embedded etcd.
2. **Configure Worker Node:** Point the worker configurations to the Master IP via NixOS settings.
3. **Deploy Native Manifests:** Manage Kubernetes workloads directly from the Git repository using the `services.k3s.manifests` NixOS option, which auto-deploys YAML directly into the cluster on startup.
4. **Provision Hardware:** Use OpenTofu to provision the underlying Proxmox VMs, ensuring resources like `cpu` and `memory` are properly allocated for orchestration workloads.

OpenTofu Configuration for Phase 9 (K3s Node Hardware Provisioning):

```
resource "proxmox_virtual_environment_vm" "k3s_master" {
  name      = "k3s-master-${local.calculated_vm_id}"
  node_name = "pve-01"
  vm_id     = local.calculated_vm_id
  tags      = ["qoax", "kubernetes", "control-plane"]

  # Clone from a pre-built NixOS template
  clone {
    vm_id = 9000
    full  = true
  }

  # Add cloud-init initialization so colmena has SSH access
  initialization {
    ip_config {
      ipv4 {
        address = "${var.vm_ip_address}/24"
        gateway = "192.168.${var.vlan_id}.1"
      }
    }
    user_account {
      keys = ["ssh-ed25519 AAAAC3NzaC1... your-management-pub-key"]
    }
  }

  cpu {
    cores = 4
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 4096
  }

  # The VM requires the QEMU guest agent for IP extraction
  agent {
    enabled = true
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = var.vlan_id
  }
}
```

## Phase 10: Docker Swarm Orchestration Templates

While Kubernetes is highly declarative, initializing a Docker Swarm historically relied on imperative SSH commands (e.g., `docker swarm init`). Because the native Docker OpenTofu provider (`kreuzwerker/docker`) lacks a `docker_swarm_cluster` resource, relying on shell provisioners is a common anti-pattern.

To ensure the cluster is managed *entirely* by OpenTofu without any manual or `remote-exec` shell commands, we leverage the Docker Engine REST API. By configuring NixOS to expose the Docker daemon over TCP, OpenTofu can use a REST API provider (such as `devops-rob/terracurl`) to declaratively send POST requests to the `/swarm/init` and `/swarm/join` endpoints directly.

### Implementation Steps

1. **Expose the Docker API:** Configure the NixOS profile for managers and workers to listen on TCP port 2375, and open the firewall for both the API and Swarm overlay networks (2377, 7946, 4789).
2. **Initialize Swarm (Manager):** Use an OpenTofu REST provider to send a `POST /swarm/init` payload to the primary manager node's Docker API.
3. **Fetch Join Tokens:** Use a REST data source in OpenTofu to `GET /swarm` from the manager and extract the worker join token.
4. **Join Workers:** Use another REST resource to dynamically send `POST /swarm/join` to each worker's Docker API, supplying the manager's IP and the extracted token.

NixOS Configuration for Phase 10 (Docker API Exposure):

```
virtualisation.docker = {
  enable = true;
  autoPrune.enable = true;
  daemon.settings = {
    # Expose the API over TCP to allow OpenTofu REST calls
    "hosts" = [ "unix:///var/run/docker.sock" "tcp://0.0.0.0:2375" ];
  };
};
networking.firewall.allowedTCPPorts = [ 2375 2377 7946 ];
networking.firewall.allowedUDPPorts = [ 7946 4789 ];
```

OpenTofu Configuration for Phase 10 (Declarative API-Driven Swarm Init):

```
terraform {
  required_providers {
    terracurl = {
      source  = "devops-rob/terracurl"
      version = "~> 1.0.1"
    }
  }
}

# 1. Initialize the Swarm cluster via the Manager's REST API
resource "terracurl_request" "swarm_init" {
  name           = "swarm_init_manager"
  url            = "http://${var.manager_ip}:2375/swarm/init"
  method         = "POST"
  response_codes = [200, 406] # 406 means it's already part of a swarm
  
  # Allow the Docker daemon time to bind to TCP after the Colmena OS apply finishes
  max_retry      = 5
  retry_interval = 10 
  
  request_body   = jsonencode({
    ListenAddr    = "0.0.0.0:2377"
    AdvertiseAddr = "${var.manager_ip}:2377"
  })

  # Ensure the NixOS deployment finishes before trying to hit the API
  depends_on = [null_resource.nixos_deploy_manager]
}

# 2. Fetch the cluster info from the Manager to extract the Join Token
data "terracurl_request" "swarm_info" {
  name           = "get_swarm_tokens"
  url            = "http://${var.manager_ip}:2375/swarm"
  method         = "GET"
  response_codes = [200]

  depends_on = [terracurl_request.swarm_init]
}

# 3. Instruct the Worker to join the Swarm via its own REST API
resource "terracurl_request" "swarm_join" {
  name           = "swarm_join_worker_${var.worker_ip}"
  url            = "http://${var.worker_ip}:2375/swarm/join"
  method         = "POST"
  response_codes = [200, 406]
  
  # Allow the Docker daemon time to bind to TCP after the Colmena OS apply finishes
  max_retry      = 5
  retry_interval = 10 
  
  request_body   = jsonencode({
    ListenAddr  = "0.0.0.0:2377"
    RemoteAddrs = ["${var.manager_ip}:2377"]
    JoinToken   = jsondecode(data.terracurl_request.swarm_info.response).JoinTokens.Worker
  })

  depends_on = [null_resource.nixos_deploy_worker]
}
```

## Phase 11: Provisioning Non-NixOS Virtual Machines

When a non-NixOS VM is required (e.g., an Ubuntu Cloud Image appliance), the workflow dynamically uploads a Cloud-Init configuration snippet to the Proxmox datastore and attaches it to the VM.

### Implementation Steps

1. **Define the Cloud-Init Snippet:** Create a YAML file containing standard `#cloud-config` directives (user creation, SSH keys, package installation).
2. **Upload via OpenTofu:** Use the `proxmox_virtual_environment_file` resource to upload the snippet. Note that this requires the OpenTofu provider to have SSH access configured for the Proxmox host.
3. **Attach to VM:** In the VM resource, reference the file ID.

OpenTofu Configuration for Phase 11 (Cloud-Init Snippet and VM Attachment):

```
resource "proxmox_virtual_environment_file" "cloud_config" {
  node_name    = "pve-01"
  datastore_id = "local"
  content_type = "snippets"

  source_raw {
    data      = file("${path.module}/templates/cloud-config.yaml")
    file_name = "custom-config-${local.calculated_vm_id}.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "ubuntu_appliance" {
  name      = "ubuntu-${local.calculated_vm_id}"
  node_name = "pve-01"
  vm_id     = local.calculated_vm_id

  initialization {
    # Attach the uploaded snippet ID as custom user-data
    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
  }
}
```

## Phase 12: Zero-Downtime Lifecycle Management and Automated Upgrades

Achieving true zero downtime requires coordinated choreography at all levels of the hyperconverged stack. Uncoordinated automated reboots can destroy clustered quorum.

### Implementation Steps

1. **Hypervisor High Availability:** Navigate to **Datacenter -> HA** in the Proxmox UI. Create an HA Group selecting all your physical nodes. Add your critical VMs to this HA pool. When you need to run `apt upgrade` and reboot a physical node, Proxmox will automatically live-migrate the VMs to the remaining active nodes in the group.
2. **NixOS Upgrade Configuration:** Enable the NixOS auto-upgrade module but strictly disable the automatic reboot to protect clustered workloads. Add the explicit values to your `configuration.nix` file to ensure the system updates its software closure without forcefully dropping active connections.
3. **Configure Cordon, Drain, and Reboot Automation:** Add the `nixos-needsreboot` package to your system and define a concrete systemd timer and service in your NixOS configuration. This specific service periodically checks for pending kernel updates, safely drains the Kubernetes or Docker Swarm node, and issues a controlled restart.
4. **Automate K3s Engine Upgrades:** Declare the Rancher `system-upgrade-controller` Custom Resources directly in your NixOS configuration using the `services.k3s.manifests` option, setting the `Plan` variable `concurrency: 1` to strictly upgrade nodes sequentially.
5. **Apply OpenTofu Lifecycle Flags:** Instruct OpenTofu to ignore `node_name` changes. If Proxmox live-migrates a VM to another host during an update, subsequent `tofu apply` runs will not attempt to drag the VM back down or reboot it.

NixOS Configuration for Phase 12 (Safe Reboot Service & K3s Upgrades):

```
# 1. Disable forced reboots during upgrades
system.autoUpgrade = {
  enable = true;
  allowReboot = false;
};

# 2. Provide the reboot detection binary
environment.systemPackages = [ pkgs.nixos-needsreboot ];

# 3. Create the concrete systemd service to automate draining and rebooting
systemd.services.safe-cluster-reboot = {
  description = "Safe Cordon, Drain, and Reboot for Cluster Nodes";
  path = [ pkgs.k3s pkgs.docker pkgs.nixos-needsreboot pkgs.coreutils pkgs.systemd pkgs.gnugrep ];
  script = ''
    if nixos-needsreboot | grep -q "Reboot required"; then
      echo "Kernel update detected. Draining node..."

      # For K3s Workloads:
      k3s kubectl cordon $HOSTNAME
      k3s kubectl drain $HOSTNAME --ignore-daemonsets --delete-emptydir-data --force --grace-period=60

      # For Docker Swarm Workloads:
      # docker node update --availability drain $HOSTNAME
      # sleep 60

      echo "Node drained. Rebooting system..."
      systemctl reboot
    else
      echo "No reboot required."
    fi
  '';
};

# 4. Create the systemd timer to execute the service nightly
systemd.timers.safe-cluster-reboot = {
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnCalendar = "*-*-* 03:00:00";
    Persistent = true;
  };
};

# 5. Declarative K3s Upgrade Plan Resource
services.k3s.manifests.k3s-upgrade-plan.content = {
  apiVersion = "upgrade.cattle.io/v1";
  kind = "Plan";
  metadata = {
    name = "k3s-server-plan";
    namespace = "system-upgrade";
  };
  spec = {
    concurrency = 1;
    cordon = true;
    nodeSelector.matchExpressions = [{
      key = "node-role.kubernetes.io/master";
      operator = "In";
      values = [ "true" ];
    }];
    serviceAccountName = "system-upgrade";
    upgrade.image = "rancher/k3s-upgrade";
    version = "v1.28.3+k3s2"; # The target K3s version
  };
};
```

OpenTofu Configuration for Phase 12 (State Protection during Live Migrations):

```
resource "proxmox_virtual_environment_vm" "ha_node" {
  name      = "production-workload"
  # Initial target node for provisioning
  node_name = "pve-01"

  # ... other configurations ...

  lifecycle {
    # Prevents OpenTofu from overriding the host if Proxmox HA
    # has live-migrated this VM to pve-02 for hardware maintenance.
    ignore_changes = [
      node_name
    ]
  }
}
```