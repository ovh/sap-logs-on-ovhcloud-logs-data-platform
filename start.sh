#!/usr/bin/env bash
# This script helps identify SAP environments to deploy and configure rsyslog
# to capture files relevant for a SAP administrator searching for logs, backups, audits, or other information.

PROGRAM_PATH=$(dirname "$0")
SAP_DEFAULT_USER_PATH="/usr/sap"
SAP_DEFAULT_HANA_PATH="/hana/shared"
SAP_RSYSLOG_DIR_PATH="/etc/rsyslog.d"
SAP_RSYSLOG_CONF_PATH="/etc/rsyslog.conf"
OVHCLOUD_SAP_PROGRAM_DIR_LOCATION="ovhcloud-sap-rsyslog.conf"
OVHCLOUD_SAP_SAL_SERVICE_NAME="ovhcloud-sap-audit"
SAP_PROGRAM_DIR_LOCATION="${PROGRAM_PATH}"
SAP_RSYSLOG_LOCAL_DIR_PATH="${SAP_PROGRAM_DIR_LOCATION}/src/rsyslog.d"
LOG_FILE="/tmp/sap-logs-on-ldp-installation.log"
SAP_RSYSLOG_GITHUB_ENDPOINT="https://github.com/ovh/sap-logs-on-ovhcloud-logs-data-platform"
SAP_RSYSLOG_SRC_FILENAME="rsyslog_configuration_files.tar.gz"
OS_RELEASE_ID=$(grep "^ID=" /etc/os-release | sed -e "s/^.*\"\(.*\)\"$/\1/")

STARTED_INSTALLATION_MESSAGE="SAP logs on OVHcloud Logs Data Platform installation has started, all information in ${LOG_FILE}"
ERROR_INSTALLATION_MESSAGE="SAP logs on OVHcloud Logs Data Platform installation in error, all information in ${LOG_FILE}"
SUCCESS_INSTALLATION_MESSAGE="SAP logs on OVHcloud Logs Data Platform installation is finished, all information in ${LOG_FILE}"

declare -A SAP_RSYSLOG_CONF_FILENAME
SAP_RSYSLOG_CONF_FILENAME[HDB]="hana_tenant"
SAP_RSYSLOG_CONF_FILENAME[W]="webd"
SAP_RSYSLOG_CONF_FILENAME[ASCS]="ascs_abap"
SAP_RSYSLOG_CONF_FILENAME[SCS]="scs_java"
SAP_RSYSLOG_CONF_FILENAME[D]="as_abap"
SAP_RSYSLOG_CONF_FILENAME[J]="as_java"

main() {
    # Call getopt to validate the provided input.
    options=$(getopt -o h,f,k:,s:,t:,p:,a: --long help,force,software-stack:,sap-sid:,ldp-target-platform:,ldp-ca-file-path:,audit-ldp-target-platform:,audit-ldp-ca-file-path:,hana-sid:,collect-sal -- "$@")

    local force=false
    local collect_sal=false
    local sids=()
    local related_sid=""

    eval set -- "${options}"

    while true; do 
        case "$1" in
            -h | --help)
                # Display Help
                help;
                exit;;
            -f | --force)
                force=true;
                shift ;;
            -k | --software-stack)
                software_stack="$2";
                shift 2 ;;
            -s | --sap-sid)
                sids+=("$2");
                shift 2 ;;
            -t | --ldp-target-platform)
                ldp_target_platform="$2";
                shift 2 ;;
            -p | --ldp-ca-file-path) 
                ldp_ca_file_path="$2";
                shift 2 ;;
            --audit-ldp-target-platform)
                audit_ldp_target_platform="$2";
                shift 2 ;;
            --audit-ldp-ca-file-path) 
                audit_ldp_ca_file_path="$2";
                shift 2 ;;
            -a | --hana-sid)
                related_sid="$2";
                shift 2 ;;
            --collect-sal)
                collect_sal=true;
                shift ;;
            --)
                shift
                break
                ;;
        esac
    done

    wall "${STARTED_INSTALLATION_MESSAGE}"

    logging "INFO" "1/5 - Checking parameters and environment..."

    check_ldp_variables "${ldp_target_platform}" "${ldp_ca_file_path}"

    if [ "${software_stack}" ]; then
        check_software_stack "${software_stack}"
    fi

    if [ -z "${related_sid}" ] && [ "${SOFT_STACK}" = "hana" ]; then
        related_sid=($(discover_sid))
    elif [ -z "${sids}" ] && [ ! -z "${SOFT_STACK}" ] && [ "${SOFT_STACK}" != "hana" ]; then
        sids+=($(discover_sid))
    fi

    # Check whether a HANA SID is provided to "swap" it as primary SID.
    if ([ $(is_hana "${related_sid}") = true ] && [ "${SOFT_STACK}" = "hana" ]); then
        local tmp_sid="${sids}"
        sids=("${related_sid}")
        related_sid="${tmp_sid}"
    fi

    if [ "${force}" = false ] && [ ! -z "${SOFT_STACK}" ]; then
        check_sid "${sids[@]}"
    fi

    if [ ! -d "${SAP_RSYSLOG_LOCAL_DIR_PATH}" ]; then
        download_files
    fi

    logging "INFO" "2/5 - Checking installed packages..."

    check_rsyslog_packages
    check_rsyslog_running $force

    logging "INFO" "3/5 - Checking and configuring rsyslog file..."

    if [ -f "${SAP_RSYSLOG_DIR_PATH}/${OVHCLOUD_SAP_PROGRAM_DIR_LOCATION}" ]; then
        logging "INFO" "File ${OVHCLOUD_SAP_PROGRAM_DIR_LOCATION} already exist."
        logging "INFO" "The file will be renamed as ${OVHCLOUD_SAP_PROGRAM_DIR_LOCATION}.old to keep a trace of the old config."
        mv "${SAP_RSYSLOG_DIR_PATH}/${OVHCLOUD_SAP_PROGRAM_DIR_LOCATION}" "${SAP_RSYSLOG_DIR_PATH}/${OVHCLOUD_SAP_PROGRAM_DIR_LOCATION}.old"
    fi

    create_main_rsyslog_file "${ldp_target_platform}" "${ldp_ca_file_path}" "${audit_ldp_target_platform}" "${audit_ldp_ca_file_path}" "${sids[0]}" "${related_sid}" > "${SAP_RSYSLOG_DIR_PATH}/${OVHCLOUD_SAP_PROGRAM_DIR_LOCATION}"
    add_rsyslog_file "${sids[@]}" "${related_sid}" >> "${SAP_RSYSLOG_DIR_PATH}/${OVHCLOUD_SAP_PROGRAM_DIR_LOCATION}"

    logging "INFO" "4/5 - Installation of SAP AS ABAP Security Audit Log service"

    if [ "${collect_sal}" == false ]; then
        logging "INFO" "Installation of SAP AS ABAP Security Audit Log service not activated."
    else
        install_collect_sal "${sids[0]}" $(discover_env "${sids[0]}" | grep -o -E "(D)[0-9]{2}" | head -1 | sed "s/^.\([0-9]*\)/\1/")
    fi

    sed -i 's/^$RepeatedMsgReduction   on/$RepeatedMsgReduction   off/g' ${SAP_RSYSLOG_CONF_PATH}

    logging "INFO" "5/5 - Restarting rsyslog daemon..."
	
    systemctl restart rsyslog.service
    # Get log returned by rsyslog with its invocation ID.
    rsyslog_restart_result=$(journalctl _SYSTEMD_INVOCATION_ID=`systemctl show -p InvocationID --value rsyslog.service` -p err -o cat)

    if ! systemctl is-active --quiet rsyslog.service; then
        logging "ERROR" "Error while restarting the service rsyslog."
        logging "ERROR" "${rsyslog_restart_result}"
        exit 1
    elif [ "${rsyslog_restart_result}" ]; then
        logging "WARNING" "Server was restarted correctly, but some rsyslog errors were detected:"
        logging "WARNING" "${rsyslog_restart_result}"
    fi
	
    logging "INFO" "The configuration is done."
    logging "INFO" "You can now access your log directly through the LDP platform on Graylog."
    logging "INFO" "If you would like to add new files on your rsyslog that don't exists on the conf files,"
    logging "INFO" "you can directly write new input on ${SAP_RSYSLOG_DIR_PATH}/${OVHCLOUD_SAP_PROGRAM_DIR_LOCATION} file."
    logging "INFO" "Examples are displayed inside this file."
    logging "INFO" "If you find files that must be added by default with the script, always feel free to contribute to our repository on GitHub!"

    wall "${SUCCESS_INSTALLATION_MESSAGE}"
}       

help() {
    # Display Help
    echo "This script creates a new rsyslog file with all the default regex needed"
    echo "to identify SAP log messages, errors and audits."
    echo
    echo "Syntax: ./start.sh [--]'command' variable..."
    echo "options:"
    echo "-h --help                     Print this Help."
    echo "-k --software-stack           Software Stack of the Instance, S4 / NW / HANA."
    echo "-s --sap-sid                  SAP SID. Three alphanumeric characters."
    echo "-t --ldp-target-platform      LDP target platform URI, ex: gra159-xxx.gra159.logs.ovh.com."
    echo "-p --ldp-ca-file-path         LDP certificate absolute path."
    echo "--audit-ldp-target-platform   Audit LDP target platform URI, ex: gra159-xxx.gra159.logs.ovh.com."
    echo "--audit-ldp-ca-file-path      Audit LDP certificate absolute path."
    echo "--hana-sid                    HANA SID. Three alphanumeric characters."
    echo "--collect-sal                 Boolean, enables the processing and forwarding of audit logs from an Application Server ABAP."
    echo "-f                            Force the installation."
    echo
}

download_files() {
    logging "INFO" "Local rsyslog configuration files not available. Downloading rsyslog configuration files..."
    
    SAP_PROGRAM_DIR_LOCATION="/tmp/sap_logs_on_ldp_configuration_files"
    SAP_RSYSLOG_LOCAL_DIR_PATH="${SAP_PROGRAM_DIR_LOCATION}/src/rsyslog.d"

    if [ ! -d "${SAP_PROGRAM_DIR_LOCATION}" ]; then
        mkdir "${SAP_PROGRAM_DIR_LOCATION}"
    fi

    latest_version=$(curl -Ls -o /dev/null -w %{url_effective} "${SAP_RSYSLOG_GITHUB_ENDPOINT}/releases/latest" | cut -d'/' -f 8)
    curl -s -L "${SAP_RSYSLOG_GITHUB_ENDPOINT}/archive/refs/tags/${latest_version}.tar.gz" -o "${SAP_PROGRAM_DIR_LOCATION}/${SAP_RSYSLOG_SRC_FILENAME}"
    
    if [ $? -ne 0 ]; then
        logging "ERROR" "Unable to download the rsyslog configuration from bucket."
        wall "${ERROR_INSTALLATION_MESSAGE}"
        exit 1
    fi
    
    tar xf "${SAP_PROGRAM_DIR_LOCATION}/${SAP_RSYSLOG_SRC_FILENAME}" -C "${SAP_PROGRAM_DIR_LOCATION}" --strip-components=1
}

check_ldp_variables() {
    local ldp_target_platform="$1"
    local ldp_ca_file_path="$2"

    if [ -z "${ldp_target_platform}" ] || [ -z "${ldp_ca_file_path}" ]; then
        logging "ERROR" "ldp-target-platform and ldp-ca-file-path parameters needed."
        wall "${ERROR_INSTALLATION_MESSAGE}"
        exit 1
    fi

    if [[ ! "${ldp_target_platform}" =~ ^[a-z]{3}[0-9]+-[a-z0-9]+.[a-z]{3}[0-9]+.logs.ovh.com$ ]]; then
        logging "ERROR" "ldp-target-platform is not correct."
        wall "${ERROR_INSTALLATION_MESSAGE}"
        exit 1
    fi

    if [[ ! "${ldp_ca_file_path}" = /* ]]; then
        logging "ERROR" "ldp-ca-file-path must be an absolute path."
        wall "${ERROR_INSTALLATION_MESSAGE}"
        exit 1
    fi
}

check_sid() {
    local sids="$@"

    for sid in "${sids[@]}"; do

        if [ "${#sid}" != 3 ]; then
            logging "ERROR" "${sid} SID must be 3 characters."
            wall "${ERROR_INSTALLATION_MESSAGE}"
            exit 1
        fi

        if [ ! -d "${SAP_DEFAULT_USER_PATH}/${sid}" ]; then
            logging "ERROR" "${sid} SID doesn't exist."
            wall "${ERROR_INSTALLATION_MESSAGE}"
            exit 1
        fi

    done

}

check_software_stack() {
    # Software Stack, defined the complete environment.
    # It can be S4, NW or HANA.
    # It's needed to correctly configure the rsyslog file.
    local software_stack=$(echo "$1" | tr "[:upper:]" "[:lower:]")
    
    if [[ -z "${software_stack}" ]]; then
        logging "ERROR" "Software Stack is required. Possible values are: S4, NW or HANA."
        wall "${ERROR_INSTALLATION_MESSAGE}"
        exit 1
    fi

    if [[ ! "${software_stack}" = "s4" ]] && [[ ! "${software_stack}" = "nw" ]] && [[ ! "${software_stack}" = "hana" ]]; then
        logging "ERROR" "Software Stack must have S4, NW or HANA value."
        wall "${ERROR_INSTALLATION_MESSAGE}"
        exit 1
    fi

    SOFT_STACK=$software_stack
}

check_rsyslog_packages() {
    # Check rsyslog and rsyslog-gtls modules exist and are running
    if [ ! "$(rpm -qa | grep rsyslog)" ] || [ ! "$(rpm -qa | grep rsyslog-module-gtls)" ]; then
        logging "ERROR" "The solution LDP on SAP can only works if rsyslog and rsyslog-module-gtls are installed."
        logging "ERROR" "Please ensure that the packages are correctly installed before relaunching the script."
        wall "${ERROR_INSTALLATION_MESSAGE}"
        exit 1
    fi

    if [ $(rpm -qa | grep rsyslog-module-gtls | sed 's/rsyslog-module-gtls-\([0-9]\.[0-9]*\)\..*/\1/' | version) -lt $(version "8.2108") ]; then
        logging "ERROR" "The rsyslog-module-gtls version is older than the version recommended (8.2108)."
        logging "ERROR" "Please ensure to have the correct version before relaunching the script."
        wall "${ERROR_INSTALLATION_MESSAGE}"
        exit 1
    fi
}

version() {
    local cmd=(awk -F. '{ printf("%d%03d", $1, $2); }')
    if is_interactive; then
        echo "$*" | "${cmd[@]}"
    else
        "${cmd[@]}"
    fi
}

is_interactive() {
    [ -t 0 ] && return 0
    return 1
}

check_rsyslog_running() {
    local force="$1"

    if [ ! "$(systemctl --type=service | grep rsyslog)" ] && [ "${force}" = false ]; then
        logging "ERROR" "rsyslog is not running. If is it not an error, please add the parameter -f."
        wall "${ERROR_INSTALLATION_MESSAGE}"
        exit 1
    fi
}

create_main_rsyslog_file() {
    local ldp_target_platform="$1"
    local ldp_ca_file_path="$2"
    local audit_ldp_target_platform="$3"
    local audit_ldp_ca_file_path="$4"
    local sap_sid="$5"
    local hana_sid="$6"
    local rsyslog_file="${SAP_RSYSLOG_LOCAL_DIR_PATH}/main_${OS_RELEASE_ID}.conf"

    if [ -z "${audit_ldp_target_platform}" ] || [ -z "${audit_ldp_target_platform}" ]; then
        audit_ldp_target_platform="${ldp_target_platform}"
        audit_ldp_ca_file_path="${ldp_ca_file_path}"
    fi

    if [ -z "${hana_sid}" ] && [ ! -z ${SOFT_STACK} ] && [ ! ${SOFT_STACK} == "hana" ]; then
        hana_sid="$(discover_hdb $sap_sid)"
    elif [ -z "${hana_sid}" ] && ([ -z ${SOFT_STACK} ] || [ "${force}" = true ]); then
        hana_sid="NIL"
    fi

    if [ $(is_hana "${sap_sid}") == true ]; then
        local tmp_sid="${sap_sid}"
        sap_sid="${hana_sid}"
        hana_sid="${tmp_sid}"
    fi

    if [ -z "${sap_sid}" ]; then
        sap_sid="NIL"
    fi

    if [ "${ldp_target_platform}" ] && [ "${ldp_ca_file_path}" ]; then
        sed \
            -e "s/<LDP_TARGET_PLATFORM>/${ldp_target_platform}/g" \
            -e "s;<LDP_CA_FILE_PATH>;${ldp_ca_file_path};g" \
            -e "s/<AUDIT_LDP_TARGET_PLATFORM>/${audit_ldp_target_platform}/g" \
            -e "s;<AUDIT_LDP_CA_FILE_PATH>;${audit_ldp_ca_file_path};g" \
            -e "s/^[^#]\(.*\)<SAP_SID>/ \1${sap_sid}/g" \
            -e "s/^[^#]\(.*\)<HANA_SID>/ \1${hana_sid}/g" \
            $rsyslog_file
    else
        logging "ERROR" "ldp-target-platform and ldp-ca-file-path parameters needed."
        wall "${ERROR_INSTALLATION_MESSAGE}"
        exit 1
    fi
}

add_rsyslog_file() {
    local sids=("${@:1:$# -1}")     # Array
    local hana_sid="${@: -1}"       # Last parameter
    local hostname="$(hostname)"

    if [ $(is_saprouter) = true ]; then
        cat "${SAP_RSYSLOG_LOCAL_DIR_PATH}/router.conf"
    elif [ -z "${saprouter}" ] && [ -z "${sids}" ]; then
        logging "WARNING" "No environment has been discovered. The file will be created with only the rsyslog input."
        return 0
    fi

    if [ -z "${SOFT_STACK}" ]; then
        return 0
    fi

    for sid in "${sids[@]}"; do
        local sap_sid="${sid}"
        local sap_hana_sid="${hana_sid}"
        local envs=$(discover_env $sid)

        if [ -z "${envs}" ] && [ "${SOFT_STACK}" != "hana" ] && [ ! -z "${sap_sid}" ]; then
            logging "WARNING" "No ${SOFT_STACK^^} environment has been discovered on ${sap_sid} SID."
            break
        elif [ -z "${envs}" ] && [ "${SOFT_STACK}" != "hana" ] && [ -z "${sap_sid}" ]; then
            logging "WARNING" "No ${SOFT_STACK^^} environment has been discovered."
            break
        elif [ -z "${envs}" ] && [ "${SOFT_STACK}" == "hana" ] && [ ! -z "${sap_hana_sid}" ]; then
            logging "WARNING" "No ${SOFT_STACK^^} environment has been discovered on ${sap_hana_sid} SID."
            break
        elif [ -z "${envs}" ] && [ "${SOFT_STACK}" == "hana" ] && [ -z "${sap_hana_sid}" ]; then
            logging "WARNING" "No ${SOFT_STACK^^} environment has been discovered."
            break
        fi

        if [ -z "${sap_hana_sid}" ]; then
            sap_hana_sid="$(discover_hdb $sap_sid)"
        fi

        if [ $(is_hana "${sap_sid}") == true ]; then
            local tmp_sid="${sap_sid}"
            sap_sid="${sap_hana_sid}"
            sap_hana_sid="${tmp_sid}"
        fi

        for env in $envs; do
            local env_split=(`split_env "${env}"`)
            local type="${env_split[0]}"
            local instance_number="${env_split[1]}"
            local tenants=(`discover_tenant "${sid}" "${env}"`)
            local files=(`get_files $type`)

            if [ $(is_hana "${sid}") == true ]; then
                sed \
                    -e "s/<SAP_SID>/${sap_sid}/g" \
                    -e "s/<HANA_SID>/${sap_hana_sid}/g" \
                    -e "s/<INSTANCE_NUMBER>/${instance_number}/g" \
                    -e "s/<HOSTNAME>/${hostname}/g" \
                    -e "s/<SERVER_TYPE>/${type}/g" \
                    "${SAP_RSYSLOG_LOCAL_DIR_PATH}/hana.conf"
            fi

            for tenant in "${tenants[@]}"; do
                for file in "${files[@]}"; do
                    sed \
                        -e "s/<SAP_SID>/${sap_sid}/g" \
                        -e "s/<HANA_SID>/${sap_hana_sid}/g" \
                        -e "s/<INSTANCE_NUMBER>/${instance_number}/g" \
                        -e "s/<HOSTNAME>/${hostname}/g" \
                        -e "s/<SERVER_TYPE>/${type}/g" \
                        -e "s/<HANA_TENANT>/${tenant}/" \
                        "${file}"
                done
            done
        done
    done
}

discover_sid() {
    logging "INFO" "Discovering SAP SID."

    if [ ! -z "${SOFT_STACK}" ] && [ "${SOFT_STACK}" = "hana" ]; then
        if [ -d "${SAP_DEFAULT_HANA_PATH}" ]; then
            ls "${SAP_DEFAULT_HANA_PATH}/" \
                | grep -E "^([A-Z0-9]{3})" \
                | tr "\n" " "
        fi
    elif [ ! -z "${SOFT_STACK}" ] && [ ! "${SOFT_STACK}" = "hana" ] && [ -d "${SAP_DEFAULT_HANA_PATH}" ] ; then
        echo ""
    elif [ -d "${SAP_DEFAULT_USER_PATH}" ]; then
            ls "${SAP_DEFAULT_USER_PATH}/" \
                | grep -E "^([A-Z0-9]{3})" \
                | tr "\n" " "
    fi
}

discover_env() {
    local sid="$1"

    if [ "${sid}" ] && [ -d "${SAP_DEFAULT_USER_PATH}/${sid}" ]; then
        if [ "${SOFT_STACK}" = "hana" ]; then
            ls "${SAP_DEFAULT_USER_PATH}/${sid}/" \
                | grep -E "^(HDB)[0-9]{2}" \
                | tr "\n" " "
        else
            ls "${SAP_DEFAULT_USER_PATH}/${sid}/" \
                | grep -E "^(W|ASCS|SCS|D|J|ERS)[0-9]{2}" \
                | tr "\n" " "
        fi
    fi
}

split_env() {
    local env="$1"
    echo "${env}" | sed -e "s/\(.*\)\([0-9][0-9]\)/\1 \2/"
}


discover_hdb() {
    local sid="$1"

    local profile="${SAP_DEFAULT_USER_PATH}/${sid}/SYS/profile/DEFAULT.PFL"
    local hdb_var="dbs/hdb/dbname"

    if [ ! -d "${SAP_DEFAULT_USER_PATH}/${sid}" ]; then
        echo "NIL"
        return 0
    fi

    local dbname=$(grep $hdb_var $profile | sed -e "s/^.*\(...\)$/\1/")

    if [ ${dbname} ]; then
        echo "${dbname}"
        return 0
    fi

    echo "NIL"
}

discover_tenant() {
    local sid="$1"
    local env="$2"
    local hostname=$(hostname)

    if [ "${sid}" ] && [ "${env}" ] && [ -d "${SAP_DEFAULT_USER_PATH}/${sid}/${env}/${hostname}/trace/" ]; then
        ls "${SAP_DEFAULT_USER_PATH}/${sid}/${env}/${hostname}/trace/" \
            | grep -E "^DB_[A-Z0-9]{3}" \
            | sed -e "s/DB_\(.*\)/\1/g" \
            | tr "\n" " "
        return 0
    fi

    echo "NIL"
}

is_saprouter() {
    if [ -d "${SAP_DEFAULT_USER_PATH}/saprouter" ]; then
        echo true
        return 0
    fi

    echo false
}

is_hana() {
    local sid="$1"

    if [ "${sid}" ] && [ -d "/hana/shared/${sid}" ]; then
        echo true
        return 0
    fi

    echo false
}

get_files() {
    local type="$1"
    local files=()

    if [ -f "${SAP_RSYSLOG_LOCAL_DIR_PATH}/${SAP_RSYSLOG_CONF_FILENAME[${type}]}.conf" ]; then
        files+=("${SAP_RSYSLOG_LOCAL_DIR_PATH}/${SAP_RSYSLOG_CONF_FILENAME[${type}]}.conf")
    fi

    if [ "${type}" == "ASCS" ] || [ "${type}" == "ERS" ]; then
        files+=("${SAP_RSYSLOG_LOCAL_DIR_PATH}/enq_${SOFT_STACK}.conf")
    fi

    echo "${files[@]}"
}

install_collect_sal() {
    local sid="$1"
    local instance_number="$2"

    if [ ! "${instance_number}" ]; then
        logging "WARNING" "The installation of the ${OVHCLOUD_SAP_SAL_SERVICE_NAME} service cannot be completed, because no instance has been found."
        return 0
    fi

    logging "INFO" "Moving files to the correct folders."
    mv "${SAP_PROGRAM_DIR_LOCATION}/src/${OVHCLOUD_SAP_SAL_SERVICE_NAME}.service" "/etc/systemd/system/${OVHCLOUD_SAP_SAL_SERVICE_NAME}.service"
    mv "${SAP_PROGRAM_DIR_LOCATION}/src/${OVHCLOUD_SAP_SAL_SERVICE_NAME}d" "/usr/sbin/${OVHCLOUD_SAP_SAL_SERVICE_NAME}d"
    chmod +x "/usr/sbin/${OVHCLOUD_SAP_SAL_SERVICE_NAME}d"

    logging "INFO" "Modifying the environment variables used by the service."
    SYSTEMD_EDITOR=tee systemctl edit "${OVHCLOUD_SAP_SAL_SERVICE_NAME}.service" << EOF
[Service]
Environment="OVHCLOUD_SAP_SID=${sid}"
Environment="OVHCLOUD_SAP_INSTANCE_NUMBER=${instance_number}"
Environment="OVHCLOUD_SAP_SOFTWARE_STACK=${software_stack}"
EOF

    logging "INFO" "Start new service ${OVHCLOUD_SAP_SAL_SERVICE_NAME}.service."
    systemctl daemon-reload
    systemctl enable "${OVHCLOUD_SAP_SAL_SERVICE_NAME}.service"
    systemctl start "${OVHCLOUD_SAP_SAL_SERVICE_NAME}.service"
}

logging() {
   local date=$(date --utc --iso-8601=seconds)
   local type="$1"
   local message="$2"
   
   echo 1>&2 "${date} ${type}    ${message}"
   echo "${date} ${type}    ${message}" >> "${LOG_FILE}"
}

main "$@"
