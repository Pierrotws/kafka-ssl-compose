#!/bin/bash

set -o nounset \
    -o errexit \
    -o verbose \
    -o xtrace

# Generate CA key
openssl req -new -x509 -keyout datahub-ca.key -out datahub-ca.crt -days 365 -subj '/CN=ca.datahub/OU=test/O=datahub/L=paris/S=fr/C=fr' -passin pass:datahub -passout pass:datahub

for i in broker producer consumer
do
	echo $i
	# Create keystores
	keytool -genkey -noprompt \
				 -alias $i \
				 -dname "CN=$i.datahub, OU=test, O=datahub, L=paris, S=fr, C=fr" \
				 -keystore kafka.$i.keystore.jks \
				 -keyalg RSA \
				 -storepass datahub \
				 -keypass datahub

	# Create CSR, sign the key and import back into keystore
	keytool -keystore kafka.$i.keystore.jks -alias $i -certreq -file $i.csr -storepass datahub -keypass datahub

	openssl x509 -req -CA datahub-ca.crt -CAkey datahub-ca.key -in $i.csr -out $i-ca-signed.crt -days 9999 -CAcreateserial -passin pass:datahub

	keytool -keystore kafka.$i.keystore.jks -alias CARoot -import -file datahub-ca.crt -storepass datahub -keypass datahub

	keytool -keystore kafka.$i.keystore.jks -alias $i -import -file $i-ca-signed.crt -storepass datahub -keypass datahub

	# Create truststore and import the CA cert.
	keytool -keystore kafka.$i.truststore.jks -alias CARoot -import -file datahub-ca.crt -storepass datahub -keypass datahub

  echo "datahub" > ${i}_sslkey_creds
  echo "datahub" > ${i}_keystore_creds
  echo "datahub" > ${i}_truststore_creds
done
