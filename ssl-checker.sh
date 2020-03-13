#!/usr/bin/env bash
VERSION=0.2
NAME="SSL-checker"

# Global Values
SSL_PORT="443"
SSL_TIMEOUT_CHECK="1"
SSL_WARNING_DAYS="14"
SSL_WARNING_SEC=$(($SSL_WARNING_DAYS*86400))
ROUTE53_MAXITEMS="500"
ROUTE53_TMPFILE="./list_dns_entries.txt"

function minTLS() {
    DOMAIN=$1
    result_tls=$(nmap --script ssl-enum-ciphers -p ${SSL_PORT} ${DOMAIN})
    min_tls=$(echo $result_tls| sed -r -e "s/^.*ssl-enum-ciphers:[[:space:]]+\|[[:space:]]+([A-Za-z0-9.]+):.*$/\1/g")
    if [[ "$min_tls" == "SSL"* || "$min_tls" == "TLSv1.0" ]]
    then
      echo "\e[91m>=${min_tls}"
    elif [[ "$min_tls" == "TLSv1.1" ]]
    then
      echo "\e[93m>=${min_tls}"
    elif [[ "$min_tls" == "TLSv1."* ]]
    then
      echo "\e[92m>=${min_tls}"
    else
      echo "\e[91m_error_"
    fi
}

function checkSSL () {
    DOMAIN=$1
    HTTPS_OPEN=1 #0 -> Open & #1 -> Close
    nc -w $SSL_TIMEOUT_CHECK -z $DOMAIN $SSL_PORT &> /dev/null; HTTPS_OPEN=$?
    if [ $HTTPS_OPEN == 0 ]
    then
        SSL_STATUS=$( echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:$SSL_PORT 2>/dev/null | openssl x509 -noout -issuer -enddate -checkend $SSL_WARNING_SEC)
        SSL_ISSUER=$(echo $SSL_STATUS| awk -F "CN = " '{print $2}'|sed 's|notAfter.*$||')
        SSL_VALID=$(echo $SSL_STATUS| awk -F " GMT " '{print $2}')
        if [ "$SSL_VALID" == "Certificate will expire" ]
        then
            SSL_END_DATE=$(echo $SSL_STATUS| awk -F "notAfter=" '{print $2}'|sed 's|GMT.*$|GMT|')
            echo -e "\e[91m\u274c \e[39mSSL $DOMAIN - Port=Open - \e[91m$SSL_VALID: $SSL_END_DATE \e[39m- $(minTLS $DOMAIN) \e[39m- Issuer=$SSL_ISSUER"
        else
            echo -e "\e[92m\u2714 \e[39mSSL $DOMAIN - Port=Open - \e[92m$SSL_VALID \e[39m- $(minTLS $DOMAIN) \e[39m- Issuer=$SSL_ISSUER"
        fi
    fi
}

function getDNSRecords () {
    aws route53 list-resource-record-sets --hosted-zone-id $ROUTE53_HOSTZONE --max-items=$ROUTE53_MAXITEMS --query "ResourceRecordSets[?Type == 'CNAME'].Name" --output text>$ROUTE53_TMPFILE
    aws route53 list-resource-record-sets --hosted-zone-id $ROUTE53_HOSTZONE --max-items=$ROUTE53_MAXITEMS --query "ResourceRecordSets[?Type == 'A'].Name" --output text>>$ROUTE53_TMPFILE
    sed -i -e "s/\.\t/\n/g" $ROUTE53_TMPFILE
    sed -i -e "/^*/d" $ROUTE53_TMPFILE
}

function awsSrc () {
    getDNSRecords
    while IFS= read -r dnsValue
    do
        checkSSL $dnsValue
    done < "$ROUTE53_TMPFILE"
}

function domainSrc () {
    dnsValue=$1
    checkSSL $dnsValue
}

function clean () {
    rm -f $ROUTE53_TMPFILE
}

function printHelp () {
    echo "$NAME - v${VERSION}"
    echo "Usage: [-d <domain>] [-p <aws> -z <hosted-zone-id>] [-v] [-h]"
    echo -e "\t -d: [sub]domain you want check"
    echo -e "\t -p: provider, for the moment only 'aws' is available"
    echo -e "\t -z: hosted zone id on AWS"
    echo -e "\t -v: print version"
    echo -e "\t -h: print help"
}

simpleDomain=""
hostedZoneId=""
provider=""
while getopts :hvp:z:d: option
do
   case "${option}"
      in
      \?)
         echo "Invalid option: -$OPTARG" >&2
         printHelp
         exit -1
         ;;
      h) printHelp
         exit 0
         ;;
      v)
         echo "$NAME v$VERSION" && exit 0
         ;;
      p) provider=${OPTARG} ;;
      z) hostedZoneId=${OPTARG} ;;
      d) simpleDomain=${OPTARG} ;;
      *) print_help
         exit 0
         ;;
   esac
done

if [ ! -z $simpleDomain ]
then
    checkSSL $simpleDomain
    exit 0
fi

if [ ! -z $hostedZoneId ] && [ "$provider" == "aws" ]
then
    ROUTE53_HOSTZONE=$hostedZoneId
    awsSrc
    clean
    exit 0
fi

echo "bad argument"
printHelp
