# Users in Lima VMs

When you launch a Lima VM with this configuration, the guest user account is created to **match the host user**:

- **Same username** as the person who runs `limactl start`.
- **Same UID/GID** as on the host.
- **Passwordless sudo** is enabled for that user.

This is not custom to our setup — it is Lima’s **default behavior**.

______________________________________________________________________

## How it works

- At first boot, Lima builds a small ISO (`cidata.iso`) that contains [cloud-init](https://cloud-init.io/) configuration.

- Inside this, the `user-data` template from the Lima project tells cloud-init to:

  - Create a user with your **host username** and **UID/GID**.
  - Allow that user to run `sudo` without being asked for a password.
  - Lock the account password (so login is only via key).
  - Copy your host SSH public keys into that user’s `~/.ssh/authorized_keys` if this condition is met:

  ```yaml
  ssh:
  loadDotSSHPubKeys: true
  ```

This ensures:

- File ownership lines up correctly between host and VM when you mount directories.
- You can SSH in right away with your existing keys.
- You don’t need to set or type a password.

______________________________________________________________________

## Reference: Lima default `user-data`

From Lima’s [cidata template](https://github.com/lima-vm/lima/blob/master/pkg/cidata/cidata.TEMPLATE.d/user-data):

```yaml
users:
- name: "{{.User}}"
  uid: {{.UID}}
  gid: {{.GID}}
  ssh_authorized_keys:
  - "{{.SSHAuthorizedKeys}}"
  sudo: ALL=(ALL) NOPASSWD:ALL
  lock_passwd: true
```
