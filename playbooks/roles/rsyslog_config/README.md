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
sap_hana_usr_path: /hana/shared
sap_rsyslog_dir_path: /etc/rsyslog.d
sap_rsyslog_conf_path: /etc/rsyslog.conf
sap_rsyslog_install_path: /tmp/sap_logs_on_ldp_configuration_files
sap_rsyslog_local_dir_path: /tmp/sap_logs_on_ldp_configuration_files/src/rsyslog.d
ovhcloud_sap_sal_service_name: ovhcloud-sap-audit
ovhcloud_sap_rsyslog_filename: ovhcloud-sap-rsyslog.conf
rsyslog_ext: .conf
sap_rsyslog_install_url: https://github.com/ovh/sap-logs-on-ovhcloud-logs-data-platform
sap_rsyslog_install_file: rsyslog_configuration_files.tar.gz
sap_rsyslog_conf_filename: {
  "HDB": "hana_tenant",
  "W": "webd",
  "ASCS": "ascs_abap",
  "SCS": "scs_java",
  "D": "as_abap",
  "J": "as_java",
  "ROUTER": "router",
  "ENQS4": "enq_s4",
  "ENQNW": "enq_nw"
}
```

### Custom variables

| Custom variable | Description |
| --------------- | ----------- |
| sap_sid         | The System ID (SID) of your SAP system, used to identify your SAP instance. |
| ldp_target_platform | The endpoint URL of your Log Data Platform (LDP) instance, where logs will be sent (e.g., gra159-xxx.gra159.logs.ovh.com). |
| ldp_ca_file_path | The file path to the LDP platform certificate, required for secure log transmission (e.g., /etc/rsyslog.d/ldp.crt). |
| audit_ldp_target_platform | The endpoint URL of your LDP platform specifically for audit logs, where audit logs will be sent (e.g., gra159-xxx.gra159.logs.ovh.com). |
| audit_ldp_ca_file_path | The file path to the audit LDP platform certificate, required for secure audit log transmission (e.g., /etc/rsyslog.d/audit_ldp.crt). |
| software_stack | The software stack type, which can be one of the following: NW (NetWeaver), S4 (S/4HANA), or HANA (SAP HANA). |
| hana_sid | The System ID (SID) of your SAP HANA system, used to identify your SAP HANA instance. |
| collect_sal | A boolean flag to enable (true) or disable (false) the extraction of audit logs on your ABAP system. |
| ldp_ca | The LDP platform certificate in PEM format, required if the certificate is not already present on your server. |
| audit_ldp_ca | The audit LDP platform certificate in PEM format, required if the certificate is not already present on your server. |

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

This code is released under the Apache 2.0 License. Please see LICENSE for more details.
