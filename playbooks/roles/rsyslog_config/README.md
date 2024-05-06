# rsyslog_config

This Ansible Role configures your rsyslog config files for the OVHcloud Log Data Platform.

This Ansible Role contains tasks to:

- Configure the OVHcloud Log Data Platform connectivity.
- Discover your SAP environments.
- Create a unique rsyslog configuration file containing all your environments inside.
- Install a service to process and forward audit logs from an Application Server ABAP.

## Requirements

## Role Variables

### Default variables

```yaml
sap_usr_path: /usr/sap
sap_rsyslog_dir_path: /etc/rsyslog.d
sap_rsyslog_install_path: /tmp/rsyslog_conf_install
sap_rsyslog_local_dir_path: /tmp/rsyslog_conf_install/src/rsyslog.d
ovhcloud_sap_sal_service_name: ovhcloud-sap-audit
ovhcloud_sap_rsyslog_filename: ovhcloud-sap-rsyslog.conf
rsyslog_ext: .conf
sap_rsyslog_install_url: https://github.com/ovh/sap-logs-on-ovhcloud-logs-data-platform
sap_rsyslog_install_file: rsyslog_configuration_files.tar.gz
sap_rsyslog_conf_filename: {
  "HDB": "hana_tenant",
  "W": "webd",
  "ASCS": "ascs_abap",
  "SCS": "ascs_java",
  "D": "as_abap",
  "J": "as_java",
  "ROUTER": "router",
  "ENQS4": "enq_s4",
  "ENQNW": "enq_nw"
}
```

### Custom variables

```yaml
sap_sid:
ldp_target_platform:
ldp_ca_file_path:
audit_ldp_target_platform:
audit_ldp_ca_file_path:
software_stack:
hana_sid:
collect_sal: false
```

## Dependencies

N/A

## Example Playbook

```yaml
- name: Playbook - SAP logs on OVHcloud Logs Data Platform
  hosts: all
  tasks:
    - name: Configure rsyslog config files
      ansible.builtin.include_role:
        name: rsyslog_config
      vars:
        sap_sid: S0P
        ldp_target_platform: gra159-xxx.gra159.logs.ovh.com
        ldp_ca_file_path: /etc/rsyslog.d/logstash.crt
        software_stack: S4
        hana_sid: H0P
```

## License

## Author Information