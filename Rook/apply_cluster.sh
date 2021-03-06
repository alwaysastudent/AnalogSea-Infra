#!/bin/bash
cd "${0%/*}"
kubectl apply -f manifests/common.yaml

kubectl apply -f manifests/operator_with_csi.yaml
kubectl apply -f manifests/cluster.yaml

kubectl apply -f manifests/block_pools.yaml
kubectl apply -f manifests/dashboard_external_32350.yaml
kubectl apply -f manifests/mgr-restful.yaml
kubectl apply -f manifests/toolbox.yaml

kubectl apply -f manifests/csi_nodeplugin_rbac.yaml
kubectl apply -f manifests/csi_provisioner_rbac.yaml

kubectl wait --for=condition=available deployment/rook-ceph-osd-0 -n rook-ceph > /dev/null 2>&1
EXIT_CODE=$?
while [ "$EXIT_CODE" != "0" ]
do
  echo "Waiting for Rook deployment to become available..."
  kubectl wait --for=condition=available deployment/rook-ceph-osd-0 -n rook-ceph > /dev/null 2>&1
  EXIT_CODE=$?
  sleep 2
done

ADMIN_BASE64_KEY=$(kubectl get secret rook-ceph-admin-keyring -n rook-ceph -o jsonpath="{['data']['keyring']}" | base64 --decode | grep "key" | awk '{ print $3}' | base64)

MONITOR_ENDPOINT=$(kubectl get svc rook-ceph-mon-a -n rook-ceph -o jsonpath="{['spec']['clusterIP']}" | awk '{print $1":6789"}' | tr -d '\n')

export MONITOR_ENDPOINT ADMIN_BASE64_KEY

cat templates/secret.yaml.template | envsubst > manifests/secret.yaml
cat templates/csi_storageclass.yaml.template | envsubst > manifests/csi_storageclass.yaml
cat templates/snapshotclass.yaml.template | envsubst > manifests/snapshotclass.yaml

kubectl apply -f manifests/secret.yaml
kubectl apply -f manifests/csi_storageclass.yaml
kubectl apply -f manifests/snapshotclass.yaml

./prep.sh
