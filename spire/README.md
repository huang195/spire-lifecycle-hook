# SPIRE

## Installation

```
helm upgrade --install --create-namespace -n spire-mgmt spire-crds spire-crds --repo https://spiffe.github.io/helm-charts-hardened/
helm upgrade --install -n spire-mgmt spire spire --repo https://spiffe.github.io/helm-charts-hardened/ -f values.yaml
```

## Uninstallation

```
helm uninstall -n spire-mgmt spire
helm uninstall -n spire-mgmt spire-crds
kubectl delete namespace spire-mgmt

kubectl delete crd clusterfederatedtrustdomains.spire.spiffe.io
kubectl delete crd clusterspiffeids.spire.spiffe.io
kubectl delete crd clusterstaticentries.spire.spiffe.io
```
