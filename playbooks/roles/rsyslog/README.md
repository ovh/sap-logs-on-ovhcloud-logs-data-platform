# rsyslog

This Ansible Role configures your operating system to install rsyslog and its components required for the OVHcloud Log Data Platform.

This Ansible Role contains tasks to:

- Install rsyslog and rsyslog-gtls-module.
- Start rsyslog service and enable it.

## Requirements

The [community.general](https://docs.ansible.com/ansible/latest/collections/community/general/index.html) Ansible Collections are required. Ensure that these Ansible Collections are installed before using this Ansible Role, by using the command:

```bash
ansible-galaxy collection install community.general
```

## Role Variables

### Default variables

N/A

### Custom variables

N/A

## Dependencies

N/A

## Example Playbook

```yaml
- name: Playbook - rsyslog configure
  hosts: all
  tasks:
    - name: Configure rsyslog
      ansible.builtin.include_role:
        name: rsyslog
```

## License

## Author Information
