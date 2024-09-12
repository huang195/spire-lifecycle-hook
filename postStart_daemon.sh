#!/bin/bash

SOCKET_PATH="/var/run/spire-lifecycle.sock"

exec >> /var/log/postStart.log

if [ -e "$SOCKET_PATH" ]; then
    rm "$SOCKET_PATH"
fi

MY_PID=$$
echo "MY_PID: $MY_PID"

CONTAINERD_PID=`pgrep -x containerd`
echo "CONTAINERD_PID: $CONTAINERD_PID"
      
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
      
while true; do

  nc -Ul "$SOCKET_PATH" | while read -r line; do

    sleep 1

    if [[ "$line" =~ ^[0-9]+$ ]]; then
      CONTAINER_PID=$line
      echo "CONTAINER_PID: $CONTAINER_PID"
      
      (
      enterCgroup $BASHPID $CONTAINER_PID; \
      /root/spire-1.10.3/bin/spire-agent api fetch -socketPath /var/run/spire/sockets/agent.sock -write /tmp; \
      enterCgroup $BASHPID $$; \
      )

      cat /tmp/bundle.0.pem | nsenter -t $CONTAINER_PID --mount sh -c "cat > /tmp/bundle.0.pem"
      cat /tmp/svid.0.key | nsenter -t $CONTAINER_PID --mount sh -c "cat > /tmp/svid.0.key"
      cat /tmp/svid.0.pem | nsenter -t $CONTAINER_PID --mount sh -c "cat > /tmp/svid.0.pem"
    else
      echo "Expected a process id, but got: $line"
    fi
  done

done
