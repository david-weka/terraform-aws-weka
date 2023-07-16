#!/bin/bash
set -ex

yum install -y jq

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
instance_id=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/instance-id)

region=${region}
subnet_id=${subnet_id}
nics_num=${nics_num}

for (( i=1; i<nics_num; i++ ))
do
  eni=$(aws ec2 create-network-interface --region "$region" --subnet-id "$subnet_id" --groups ${groups}) # groups should not be in quotes it needs to be a list
  network_interface_id=$(echo "$eni" | python3 -c "import sys, json; print(json.load(sys.stdin)['NetworkInterface']['NetworkInterfaceId'])")
  attachment=$(aws ec2 attach-network-interface --region "$region" --device-index "$i" --instance-id "$instance_id" --network-interface-id "$network_interface_id")
  attachment_id=$(echo "$attachment" | python3 -c "import sys, json; print(json.load(sys.stdin)['AttachmentId'])")
  aws ec2 modify-network-interface-attribute --region "$region" --attachment AttachmentId="$attachment_id",DeleteOnTermination=true --network-interface-id "$network_interface_id"
done

aws lambda invoke --region "$region" --function-name "${deploy_func_name}" --payload "{\"vm\": \"$instance_id\"}" output
printf "%b" "$(cat output | sed 's/^"//' | sed 's/"$//' | sed 's/\\\"/"/g')" > /tmp/deploy.sh
chmod +x /tmp/deploy.sh
/tmp/deploy.sh 2>&1 | tee /tmp/weka_deploy.log
