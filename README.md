# SAP logs on OVHcloud Logs Data Platform

This project helps SAP Administrator in the configuration and deployment of rsyslog for your SAP environment, providing rsyslog file(s) in /src/rsyslog.d and a launcher to configure easily your environment.

## Distributions and SAP versions

SAP logs on OVHcloud Logs Data Platform has been tested on the following distributions and SAP versions.

| Distribution |
| ------ |
| SUSE Linux Enterprise Server 15 SP4/SP5 |
| Red Hat Enterprise Linux 8.6 |

| SAP version |
| ----------- |
| NetWeaver 7.50 |
| S/4HANA 2023 |
| SAP Network Interface Router, Version 40.4 |
| SAP Web Dispatcher Version 7.89.0 |

## Getting Started

### Prerequisites

As this project is working with rsyslog and OVHcloud Logs Data Platform, make sure the packages rsyslog (>=8.23.0) and rsyslog-module-gtls (>=8.2108) are presents on your environment.

```bash
$ rpm -qa rsyslog
rsyslog-8.2306.0-150400.5.27.1.x86_64

$ rpm -qa rsyslog-module-gtls
rsyslog-module-gtls-8.2306.0-150400.5.27.1.x86_64
```

If the version is lower than required, please update your operating system. If the output message is empty, it means that the package is not present on your operating system and you must install it.

- SLES

```bash
zypper install rsyslog rsyslog-module-gtls
```

- RHEL

```bash
yum install rsyslog rsyslog-module-gtls
```

## Usage

### Terminal

To deploy easily the rsyslog files on your environment a launcher is available to configure parts of the files.
Below are presented some examples of how to use the launcher:

A minimal deployment requires only the OVHcloud Logs Data Platform endpoint and the location of the certificate:

```bash
./start.sh \
--ldp-target-platform gra159-xxx.gra159.logs.ovh.com \
--ldp-ca-file-path /etc/rsyslog.d/logstash.crt
```

Deployment with setting the software stack to let the script discover your SAP environment:

```bash
./start.sh --software-stack S4 \
--ldp-target-platform gra159-xxx.gra159.logs.ovh.com \
--ldp-ca-file-path /etc/rsyslog.d/logstash.crt
```

Deployment with setting the SAP SID or the SAP HANA SID:

```bash
./start.sh --software-stack NW \
--sap-sid S0P \
--ldp-target-platform gra159-xxx.gra159.logs.ovh.com \
--ldp-ca-file-path /etc/rsyslog.d/logstash.crt
```

Deployment with SAP audit logs on a specific Data Stream:

```bash
./start.sh --software-stack HANA \
--sap-sid S0P \
--hana-sid HDB \
--ldp-target-platform gra159-xxx.gra159.logs.ovh.com \
--ldp-ca-file-path /etc/rsyslog.d/logstash.crt \
--audit-ldp-target-platform gra159-xxx.gra159.logs.ovh.com \
--audit-ldp-ca-file-path /etc/rsyslog.d/audit-logstash.crt
```

The SAP logs on OVHcloud Logs Data Platform feature provides the possibility to retrieve the ABAP security audit logs directly with the parameter --collect-sal. More information about the action of this parameter in the following chapter named SAP AS ABAP Security Audit Log.

```bash
./start.sh --software-stack NW \
--sap-sid S0P \
--ldp-target-platform gra159-xxx.gra159.logs.ovh.com \
--ldp-ca-file-path /etc/rsyslog.d/logstash.crt \
--collect-sal
```

### Ansible (>=2.15)

Ansible playbooks are also available if you intend to apply the rsyslog configuration on myany servers at the same time.
The playbook configures rsyslog and download the configuration files, which will then be applied.

A minimal deployment requires only the OVHcloud Logs Data Platform endpoint and the location of the certificate:

```yaml
- name: Playbook - SAP logs on OVHcloud Logs Data Platform
  hosts: all
  tasks:
    - name: Configure rsyslog
      ansible.builtin.include_role:
        name: rsyslog

    - name: Configure rsyslog config files
      ansible.builtin.include_role:
        name: rsyslog_config
      vars:
        ldp_target_platform: gra159-xxx.gra159.logs.ovh.com
        ldp_ca_file_path: /etc/rsyslog.d/logstash.crt
```

Deployment with setting the software stack to let the script discover your SAP environment:

```yaml
- name: Playbook - SAP logs on OVHcloud Logs Data Platform
  hosts: as
  tasks:
    - name: Configure rsyslog
      ansible.builtin.include_role:
        name: rsyslog

    - name: Configure rsyslog config files
      ansible.builtin.include_role:
        name: rsyslog_config
      vars:
        software_stack: S4
        ldp_target_platform: gra159-xxx.gra159.logs.ovh.com
        ldp_ca_file_path: /etc/rsyslog.d/logstash.crt
```

Deployment with setting the SAP SID or the SAP HANA SID:

```yaml
- name: Playbook - SAP logs on OVHcloud Logs Data Platform
  hosts: as
  tasks:
    - name: Configure rsyslog
      ansible.builtin.include_role:
        name: rsyslog

    - name: Configure rsyslog config files
      ansible.builtin.include_role:
        name: rsyslog_config
      vars:
        software_stack: NW
        sap_sid: S0P
        ldp_target_platform: gra159-xxx.gra159.logs.ovh.com
        ldp_ca_file_path: /etc/rsyslog.d/logstash.crt
```

Deployment with setting the SAP SID and the SAP HANA SID on SAP HANA:

```yaml
- name: Playbook - SAP logs on OVHcloud Logs Data Platform
  hosts: hana
  tasks:
    - name: Configure rsyslog
      ansible.builtin.include_role:
        name: rsyslog

    - name: Configure rsyslog config files
      ansible.builtin.include_role:
        name: rsyslog_config
      vars:
        software_stack: HANA
        sap_sid: S0P
        hana_sid: H0P
        ldp_target_platform: gra159-xxx.gra159.logs.ovh.com
        ldp_ca_file_path: /etc/rsyslog.d/logstash.crt
```

Deployment with SAP audit logs on a specific Data Stream:

```yaml
- name: Playbook - SAP logs on OVHcloud Logs Data Platform
  hosts: as
  tasks:
    - name: Configure rsyslog
      ansible.builtin.include_role:
        name: rsyslog

    - name: Configure rsyslog config files
      ansible.builtin.include_role:
        name: rsyslog_config
      vars:
        software_stack: S4
        ldp_target_platform: gra159-xxx.gra159.logs.ovh.com
        ldp_ca_file_path: /etc/rsyslog.d/logstash.crt
        audit_ldp_target_platform: gra159-xxx.gra159.logs.ovh.com
        audit_ldp_ca_file_path: /etc/rsyslog.d/audit-logstash.crt
```

Launch ansible playbook:

```sh
ansible-playbook playbooks/main.yml
```

## RegEx scope

- RSYSLOG
- HANA
- AS (ABAP/JAVA)
- ASCS (ABAP/JAVA)
- SAProuter
- SAP Web Dispatcher
- ERS

## SAP AS ABAP Security Audit Log

SAP offers the possibility with [the Security Audit Log](https://help.sap.com/doc/saphelp_nw73ehp1/7.31.19/en-us/c7/69bcb7f36611d3a6510000e835363f/frameset.htm) to record security-related system information of your SAP system.

By activating it, all activities that you specify will be recorded into an audit log file located in /usr/sap/\<SID\>/D\<NI\>/log/audit_YYYYMMDD for SAP NetWeaver 7.50. Please note that the service only accepts daily files with the name audit_YYYYDDMM.

However, for SAP S/4HANA, the [classic approach](https://help.sap.com/docs/ABAP_PLATFORM_NEW/025d1fb2f02c42c097f04f45df09106a/22a96e48a27c4dea8a43929ddf6a1730.html?locale=en-US#loiod8419c5e939449fdad6a38429da2d108) must be configured. Only one file per day must be generated, the option "protection format active" must be disabled and the parameter FN_AUDIT (set in the DEFAULT.PFL profile) must be set with the value ++++++++.AUD, where ++++++++ equals YYYYDDMM. In order to load this new configuration, a restart of your SAP system must be done.

As those files can't be correctly parsed with rsyslog, OVHcloud developed a Linux service in order to identify and send messages to rsyslog through the /var/log/messages file. These messages come from Security Audit Log process are identified with the tag security_audit_abap.

Enable and start service ovhcloud-sap-audit.service:

```sh
systemctl enable ovhcloud-sap-audit.service
systemctl start ovhcloud-sap-audit.service
```

## Contributing

Always feel free to help out! Whether it's filing bugs and feature requests or working on some of the open issues, our contributing guide will help get you started.

## License

This code is released under the Apache 2.0 License. Please see LICENSE for more details.

