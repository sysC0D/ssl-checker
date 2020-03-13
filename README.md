# SSL Checker

## Description
SSL Checker allows verifying the expiration date and issuer. It verifies a specific domain or a domain's group from Route53 (AWS)

## Requirements
* nmap
* openssl
* awscli (if route53 feature needed)

## How to use
```bash
#Help access
./ssl-checker.sh -h
SSL-checker - v0.2
Usage: [-d <domain>] [-p <aws> -z <hosted-zone-id>] [-v] [-h]
         -d: [sub]domain you want check
         -p: provider, for the moment only 'aws' is available
         -z: hosted zone id on AWS
         -v: print version
         -h: print help
```

```bash
#Verifying specific domain
./ssl-checker.sh -d github.com
```

```bash
#Verifying group's domain from Route 53 (Hosted Zone ID)
./ssl-checker.sh -p aws -z ZXXXXXXXXXXXX
```
