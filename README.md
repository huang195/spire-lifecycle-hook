# spire-lifecycle-hook

## Concepts

The intent of this project is to inject SPIRE workload identities (e.g., JWT
token, X509 certificates) into pods at a known location when they start,
similar to how service tokens are placed at
`/var/run/secrets/kubernetes.io/serviceaccount` directory. 

## How it works

Start a Kubernetes cluster using Kind:

```
kind create cluster
```

Install SPIRE using the instructions (here)[./spire/README.md].

After the cluster is started, we need to modify the container runtime so our
script runs when pods are starting. Every container runtime is slightly
different in how this is configured. In Kind/Podman, where the container
runtime is `containerd`, its configuration is located at
`/etc/containers/cri-base.json`. Get a shell on its worker node:

```
podman exec -it 3ae bash
```

and modify its configuration file to add the following section:

```
  "hooks": {
    "postStart": [
      {
	    "path": "/usr/local/bin/postStart.sh"
      }
    ]
  }
```

This is assuming we're using `"ociVersion": "1.1.0"`. As each version of OCI
spec is slightly different, if you're using a different version, check with its
specification on how container lifecycle hooks are configured.

Now cp the script to the worker node:

```
podman cp postStart.sh 3ae:/usr/local/bin/postStart.sh
podman cp postStart_daemon.sh 3ae:/usr/local/bin/postStart_daemon.sh
```

For changes to take into effect, we need to restart containerd.

```
systemctl restart containerd
```

Check if containerd is successfully restarted:

```
systemctl status containerd
```

In a shell on the worker node, start `postStart_daemon.sh` in the background.

```
/usr/local/bin/postStart_daemon.sh &
```

In the future, this could be replaced with a daemonset, so it doesn't have to
be done manually on each worker node.

Now we are ready to test this out. Start the openssl server and client:

```
kubectl apply -f workload/openssl-client.yaml 
kubectl apply -f workload/openssl-server.yaml
```

Make sure both pods are in a running state:

```
$ kubectl get pods
NAME             READY   STATUS    RESTARTS   AGE
openssl-client   1/1     Running   0          64s
openssl-server   1/1     Running   0          86s
```

On both pods, our script should have placed SPIRE identity files to their `/tmp` directory. You should see something like:

```
$ kubectl exec openssl-client -- ls /tmp
bundle.0.pem
svid.0.key
svid.0.pem
```

From 2 terminals, have a shell opened for both the openssl-client and openssl-server pods. On the openssl-server pod, run:

```
$ openssl s_server -accept 3000 -CAfile /tmp/bundle.0.pem -cert /tmp/svid.0.pem -key /tmp/svid.0.key -state -www
```

Then on the openssl-client pod, run:

```
openssl s_client -connect openssl-svc:3000 -CAfile /tmp/bundle.0.pem -cert /tmp/svid.0.pem -key /tmp/svid.0.key -state
```

You should see the openssl client and server are able to establish mTLS connection using the injected SPIRE certificates.

To cleanup:

```
kubectl delete -f workload/openssl-client.yaml -f workload/openssl-server.yaml --force
```
