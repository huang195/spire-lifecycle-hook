#!/bin/bash

exec >> /var/log/postStart.log 2>&1

STATE=$(cat)

MY_PID=$$
echo "MY_PID: $MY_PID"

CONTAINER_PID=$(echo "$STATE" | jq -r '.pid')
echo "CONTAINER_PID: $CONTAINER_PID"

echo "INPUT: $STATE"

enterCgroup() {
  sourcePID=$1
  targetPID=$2

  while IFS= read -r line; do
    IFS=':' read -ra items <<< "$line"
    if [ ${#items[@]} -eq 3 ]; then
      path="/sys/fs/cgroup/${items[1]}${items[2]}/cgroup.procs"
      echo "path: $path"

      # enter cgroup
      echo "cgroup.procs (before): `cat $path`"
      echo "$sourcePID" > $path
      echo "cgroup.procs (after): `cat $path`"

    else
      echo "Error: cannot parse cgroup file"
      exit 1
    fi
  done < "/proc/$targetPID/cgroup"
}

(
#this loops is to handle the time the SPIRE controller manager takes to register the workload
while true; do
  enterCgroup $BASHPID $CONTAINER_PID; \
  /root/spire-1.10.3/bin/spire-agent api fetch -socketPath /var/run/spire//agent-sockets/spire-agent.sock -write /tmp; \
  ret=$?
  if [ $ret -eq 0 ]; then
    enterCgroup $BASHPID $$
    break
  else
    enterCgroup $BASHPID $$; \
    echo "cannot fetch SPIRE identities. wait 1s..."
    sleep 1
  fi
done
)

nsenter -t $CONTAINER_PID --mount sh -c "mkdir -p /var/run/secrets/spire/"
cat /tmp/bundle.0.pem | nsenter -t $CONTAINER_PID --mount sh -c "cat > /var/run/secrets/spire/bundle.0.pem"
cat /tmp/svid.0.key | nsenter -t $CONTAINER_PID --mount sh -c "cat > /var/run/secrets/spire/svid.0.key"
cat /tmp/svid.0.pem | nsenter -t $CONTAINER_PID --mount sh -c "cat > /var/run/secrets/spire/svid.0.pem"

exit 0
