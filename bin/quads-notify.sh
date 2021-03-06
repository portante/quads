#!/bin/sh
#  Send email and IRC notifications when hosts are assigned
#  Send email notifications when hosts are expiring.
#######

if [ ! -e $(dirname $0)/load-config.sh ]; then
    echo "$(basename $0): could not find load-config.sh"
    exit 1
fi

# load the ../conf/quads.yml values as associative array
source $(dirname $0)/load-config.sh

quads=${quads["install_dir"]}/bin/quads.py
data_dir=${quads["data_dir"]}

days="1 3 5 7"
future_days="7"

# only worry about environments with active hosts
env_list=$($quads --summary | awk '{ print $1 }')
env_full_list=$($quads --full-summary | awk '{ print $1 }')

function craft_initial_message() {
    msg_file=$(mktemp /tmp/ImsgXXXXXXXXXX)
    owner=$1
    env_to_report=$2
    ircbot_ipaddr=${quads["ircbot_ipaddr"]}
    ircbot_port=${quads["ircbot_port"]}
    ircbot_channel=${quads["ircbot_channel"]}
    cloudinfo="$($quads --summary | grep $env_to_report)"
    report_file=${env_to_report}-${owner}-initial-$($quads --ls-ticket --cloud-only ${env_to_report})
    additional_cc="$($quads --ls-cc-users --cloud-only ${env_to_report} | sed "s/$/@${quads["domain"]}/")"
    cc_field=${quads["report_cc"]}
    if [ "$additional_cc" ]; then
        cc_field="$cc_field,$(echo $additional_cc | sed 's/ /,/')"
    fi
    if [ ! -f ${data_dir}/report/${report_file} ]; then
        touch ${data_dir}/report/${report_file}
        if ${quads["email_notify"]} ; then
            cat > $msg_file <<EOI
To: $owner@${quads["domain"]}
Cc: $cc_field
Subject: New QUADS Assignment Allocated
From: QUADS <quads@${quads["domain"]}>
Reply-To: dev-null@${quads["domain"]}

Greetings Citizen,

You've been allocated a new environment!

$cloudinfo

(Details)
http://${quads["wp_wiki"]}/assignments/#$env_to_report

You can view your machine list, duration and other
details above.

You can also view/manage your hosts via Foreman:

${quads["foreman_url"]}

Username: $env_to_report
Password: $($quads --ls-ticket --cloud-only ${env_to_report})

For additional information regarding system usage
please see the following documentation:

http://${quads["wp_wiki"]}/faq/

DevOps Team

EOI
            /usr/sbin/sendmail -t < $msg_file 1>/dev/null 2>&1
        fi
        if ${quads["irc_notify"]} ; then
            # send IRC notification
            printf "$ircbot_channel QUADS: $cloudinfo is now active, choo choo! - http://${quads["wp_wiki"]}/assignments/#$env_to_report" | nc -w 1 $ircbot_ipaddr $ircbot_port
        fi
    fi
    cat $msg_file
    rm -f $msg_file
}

function craft_future_initial_message() {
    msg_file=$(mktemp /tmp/ImsgXXXXXXXXXX)
    owner=$1
    env_to_report=$2
    ircbot_ipaddr=${quads["ircbot_ipaddr"]}
    ircbot_port=${quads["ircbot_port"]}
    ircbot_channel=${quads["ircbot_channel"]}
    cloudinfo="$($quads --full-summary | grep $env_to_report)"
    report_file=${env_to_report}-${owner}-pre-initial-$($quads --ls-ticket --cloud-only ${env_to_report})
    additional_cc="$($quads --ls-cc-users --cloud-only ${env_to_report} | sed "s/$/@${quads["domain"]}/")"
    cc_field=${quads["report_cc"]}
    if [ "$additional_cc" ]; then
        cc_field="$cc_field,$(echo $additional_cc | sed 's/ /,/')"
    fi
    if [ ! -f ${data_dir}/report/${report_file} ]; then
        touch ${data_dir}/report/${report_file}
        if ${quads["email_notify"]} ; then
            cat > $msg_file <<EOI
To: $owner@${quads["domain"]}
Cc: $cc_field
Subject: New QUADS Assignment Allocated
From: QUADS <quads@${quads["domain"]}>
Reply-To: dev-null@${quads["domain"]}

Greetings Citizen,

You've been allocated a new environment!  The environment is not
yet ready for use but you are being notified ahead of time that
it is being prepared.

$cloudinfo

(Details)
http://${quads["wp_wiki"]}/assignments/#$env_to_report

You can view your machine list, duration and other
details above.  Once the environment is active you 
will receive an additional notification.

For additional information regarding the Scale Lab usage
please see the following documentation:

http://${quads["wp_wiki"]}/faq/

DevOps Team

EOI
            /usr/sbin/sendmail -t < $msg_file 1>/dev/null 2>&1
        fi
        if ${quads["irc_notify"]} ; then
            # send IRC notification
            printf "$ircbot_channel QUADS: $cloudinfo is defined and upcoming! - http://${quads["wp_wiki"]}/assignments/#$env_to_report" | nc -w 1 $ircbot_ipaddr $ircbot_port
        fi
    fi
    cat $msg_file
    rm -f $msg_file
}

function craft_message() {
    msg_file=$(mktemp /tmp/msgXXXXXXXXXX)

    owner=$1
    days_to_report=$2
    env_to_report=$3
    current_list_file=$4
    future_list_file=$5
    cloudinfo="$($quads --summary | grep $env_to_report)"
    report_file=${env_to_report}-${owner}-${days_to_report}-$($quads --ls-ticket --cloud-only ${env_to_report})
    additional_cc="$($quads --ls-cc-users --cloud-only ${env_to_report} | sed "s/$/@${quads["domain"]}/")"
    cc_field=${quads["report_cc"]}
    if [ "$additional_cc" ]; then
        cc_field="$cc_field,$(echo $additional_cc | sed 's/ /,/')"
    fi
    if [ ! -f ${data_dir}/report/${report_file} ]; then
        touch ${data_dir}/report/${report_file}
        if ${quads["email_notify"]} ; then
            cat > $msg_file <<EOM
To: $owner@${quads["domain"]}
Cc: $cc_field
Subject: QUADS upcoming expiration notification
From: QUADS <quads@${quads["domain"]}>
Reply-To: dev-null@${quads["domain"]}

This is a message to alert you that in $days_to_report days
your allocated environment:

$cloudinfo

(Details)
http://${quads["wp_wiki"]}/assignments/#$env_to_report

will have some or all of the hosts expire.  The following
hosts will automatically be reprovisioned and returned to
the pool of available hosts.

EOM
            comm -23 $current_list_file $future_list_file >> $msg_file
            cat >> $msg_file <<EOM

For additional information regarding the Scale Lab usage
please see the following documentation:

http://${quads["wp_wiki"]}/faq/

Thank you for your attention.

DevOps Team

EOM
            /usr/sbin/sendmail -t < $msg_file 1>/dev/null 2>&1
        fi
    fi
    cat $msg_file
    rm -f $msg_file
}

function craft_future_message() {
    msg_file=$(mktemp /tmp/msgXXXXXXXXXX)

    owner=$1
    days_to_report=$2
    env_to_report=$3
    current_list_file=$4
    future_list_file=$5
    cloudinfo="$($quads --full-summary | grep $env_to_report)"
    report_file=${env_to_report}-${owner}-pre-${days_to_report}-$($quads --ls-ticket --cloud-only ${env_to_report})
    additional_cc="$($quads --ls-cc-users --cloud-only ${env_to_report} | sed "s/$/@${quads["domain"]}/")"
    cc_field=${quads["report_cc"]}
    if [ "$additional_cc" ]; then
        cc_field="$cc_field,$(echo $additional_cc | sed 's/ /,/')"
    fi
    if [ ! -f ${data_dir}/report/${report_file} ]; then
        touch ${data_dir}/report/${report_file}
        if ${quads["email_notify"]} ; then
            cat > $msg_file <<EOM
To: $owner@${quads["domain"]}
Cc: $cc_field
Subject: QUADS upcoming expiration notification
From: QUADS <quads@${quads["domain"]}>
Reply-To: dev-null@${quads["domain"]}

This is a message to alert you that in $days_to_report days
your allocated environment:

$cloudinfo

(Details)
http://${quads["wp_wiki"]}/assignments/#$env_to_report

will change.  As host schedules are activated some
hosts will automatically be reprovisioned and moved to
your environment.  Specifically:

EOM
            comm -13 $current_list_file $future_list_file >> $msg_file
            cat >> $msg_file <<EOM

For additional information regarding the Scale Lab usage
please see the following documentation:

http://${quads["wp_wiki"]}/faq/

Thank you for your attention.

DevOps Team

EOM
            /usr/sbin/sendmail -t < $msg_file 1>/dev/null 2>&1
        fi
    fi
    cat $msg_file
    rm -f $msg_file
}

for e in $env_list ; do
    # if "nobody" is the owner you can skip it...
    if [ "$($quads --ls-owner --cloud-only $e)" == "nobody" ]; then
        :
    else
        echo =============== Initial Message
        craft_initial_message $($quads --cloud-only $e --ls-owner) $e
    fi

    alerted=false
    for d in $days ; do
        # if "nobody" is the owner you can skip it...
        if [ "$($quads --ls-owner --cloud-only $e)" == "nobody" ]; then
            :
        else
            if $alerted ; then
                :
            else
                tmpcurlist=$(mktemp /tmp/curlistfileXXXXXXX)
                tmpfuturelist=$(mktemp /tmp/futurelistfileXXXXXXX)
                $quads --cloud-only $e --date "$(date +%Y-%m-%d) 05:00" | sort > $tmpcurlist
                $quads --cloud-only $e --date "$(date -d "now + $d days" +%Y-%m-%d) 05:00" | sort > $tmpfuturelist
                if cmp -s $tmpcurlist $tmpfuturelist ; then
                    :
                else
                    echo ============= Additional message
                    craft_message $($quads --cloud-only $e --ls-owner) $d $e $tmpcurlist $tmpfuturelist
                    alerted=true
                fi
                rm -f $tmpcurlist $tmpfuturelist
            fi
        fi
    done
done

for e in $env_full_list ; do
    if echo "$env_list" | grep -q $e ; then
        :
    else
        # if "nobody" is the owner you can skip it...
        if [ "$($quads --ls-owner --cloud-only $e)" == "nobody" ]; then
            :
        else
            echo ============= Future initial message
            craft_future_initial_message $($quads --cloud-only $e --ls-owner) $e
        fi

        alerted=false
        for d in $future_days ; do
            # if "nobody" is the owner you can skip it...
            if [ "$($quads --ls-owner --cloud-only $e)" == "nobody" ]; then
                :
            else
                if $alerted ; then
                    :
                else
                    tmpcurlist=$(mktemp /tmp/curlistfileXXXXXXX)
                    tmpfuturelist=$(mktemp /tmp/futurelistfileXXXXXXX)
                    $quads --cloud-only $e --date "$(date +%Y-%m-%d) 05:00" | sort > $tmpcurlist
                    $quads --cloud-only $e --date "$(date -d "now + $d days" +%Y-%m-%d) 05:00" | sort > $tmpfuturelist
                    if cmp -s $tmpcurlist $tmpfuturelist ; then
                        :
                    else
                        echo ============= Future additional message
                        craft_future_message $($quads --cloud-only $e --ls-owner) $d $e $tmpcurlist $tmpfuturelist
                        alerted=true
                    fi
                    rm -f $tmpcurlist $tmpfuturelist
                fi
            fi
        done
    fi
done
