# reactjs-k8s

The motivation for this project was a container that would run the ReactJS SPA
on a Kubernetes cluster along with all other applications in an single domain.
The motivation was having it with strong Auth so that I could integrate with
APIs without stubbing out the Auth so that the application could run on my
desktop.

The approach I am trying is to run the server run on the cluster minikube in
this case and share my file system with minikube this way I can do local
development but the SPA is run from the cluster.

First I would get this to work with Docker and then get this to run on Kubernetes
using a helm chart.

```bash
docker pull node:15.5.0-alpine
docker run -it  -p 8080:3000 --entrypoint /bin/sh -v /Users/seizadi/project/reactjs-sample:/host -w /host node:15.5.0-alpine
```

From inital testing looks like everything we need yarn ... is already installed so we don't need
to create a new container.

```bash
docker run -it  -p 8080:3000 --entrypoint "yarn start" -v /Users/seizadi/project/reactjs-sample:/host -w /host node:15.5.0-alpine
```

This did not work as expected :(
```bash
docker: Error response from daemon: OCI runtime create failed: container_linux.go:349: starting 
container process caused "exec: \"yarn start\": executable file not found in $PATH": unknown
```

Tried a few things and did not work so I decided to get a Dockerfile setup to test it.

```bash
docker run -it  -p 8080:3000 -v /Users/seizadi/project/reactjs-sample:/host -w /host soheileizadi/reactjs-k8s:latest
yarn run v1.22.5
$ react-scripts start
ℹ ｢wds｣: Project is running at http://172.17.0.2/
ℹ ｢wds｣: webpack output is served from 
ℹ ｢wds｣: Content not from webpack is served from /host/public
ℹ ｢wds｣: 404s will fallback to /
Starting the development server...
Compiled successfully!

You can now view reactjs-sample in the browser.

  Local:            http://localhost:3000
  On Your Network:  http://172.17.0.2:3000

Note that the development build is not optimized.
To create a production build, use yarn build.
```

Ok now time to package this for running it on kubernetes!
Now with helm chart done and we need to make sure that the
target for development is mounted on minkube:

```bash
❯ minikube mount /Users/seizadi/projects/reactjs-sample:/host
🚀  Userspace file server: ufs starting
✅  Successfully mounted /Users/seizadi/projects/reactjs-sample to /host

📌  NOTE: This process must stay alive for the mount to be accessible ...
```


```bash
k create namespace test
namespace/test created
 
kname test
Context "minikube" modified.

cd helm
helm install react-test .
```
When I look at logs I get this error...

```bash
❯ k get pods
NAME                                      READY   STATUS             RESTARTS   AGE
react-test-reactjs-k8s-5cd7cb6f8b-l9n2t   0/1     CrashLoopBackOff   5          3m50s
❯ k exec -it react-test-reactjs-k8s-5cd7cb6f8b-l9n2t /bin/sh
kubectl exec [POD] [COMMAND] is DEPRECATED and will be removed in a future version. Use kubectl exec [POD] -- [COMMAND] instead.
error: unable to upgrade connection: container not found ("reactjs-k8s")

❯ k logs react-test-reactjs-k8s-5cd7cb6f8b-l9n2t
yarn run v1.22.5
$ react-scripts start
/host/node_modules/.bin/react-scripts:2
/**

SyntaxError: Invalid or unexpected token
    at wrapSafe (node:internal/modules/cjs/loader:1024:16)
    at Module._compile (node:internal/modules/cjs/loader:1072:27)
    at Object.Module._extensions..js (node:internal/modules/cjs/loader:1137:10)
    at Module.load (node:internal/modules/cjs/loader:973:32)
    at Function.Module._load (node:internal/modules/cjs/loader:813:14)
    at Function.executeUserEntryPoint [as runMain] (node:internal/modules/run_main:76:12)
    at node:internal/main/run_main_module:17:47
error Command failed with exit code 1.
info Visit https://yarnpkg.com/en/docs/cli/run for documentation about this command.
```
 To debug this I set it back nginx container to test the volume configuration, remember to
set the port back I had the health check failing...

```bash
❯ k get pods
NAME                               READY   STATUS             RESTARTS   AGE
test-reactjs-k8s-7945b64d6-zhztn   0/1     CrashLoopBackOff   5          3m58s

❯ k describe pod test-reactjs-k8s-7945b64d6-zhztn
Name:         test-reactjs-k8s-7945b64d6-zhztn
Namespace:    test
Priority:     0
Node:         minikube/192.168.64.43
Start Time:   Wed, 30 Dec 2020 05:02:16 -0800
Labels:       app.kubernetes.io/instance=test
              app.kubernetes.io/name=reactjs-k8s
              pod-template-hash=7945b64d6
Annotations:  <none>
Status:       Running
IP:           172.17.0.9
IPs:
  IP:           172.17.0.9
Controlled By:  ReplicaSet/test-reactjs-k8s-7945b64d6
Containers:
  reactjs-k8s:
    Container ID:   docker://8d490897c1eb263b66eae68cdd6093e539c7c9d3f97d4c69f1acb78f7c93c92f
    Image:          nginx:latest
    Image ID:       docker-pullable://nginx@sha256:4cf620a5c81390ee209398ecc18e5fb9dd0f5155cd82adcbae532fec94006fb9
    Port:           3000/TCP
    Host Port:      0/TCP
    State:          Waiting
      Reason:       CrashLoopBackOff
    Last State:     Terminated
      Reason:       Completed
      Exit Code:    0
      Started:      Wed, 30 Dec 2020 05:05:45 -0800
      Finished:     Wed, 30 Dec 2020 05:06:06 -0800
    Ready:          False
    Restart Count:  5
    Liveness:       http-get http://:http/ delay=0s timeout=1s period=10s #success=1 #failure=3
    Readiness:      http-get http://:http/ delay=0s timeout=1s period=10s #success=1 #failure=3
    Environment:    <none>
    Mounts:
      /host from host-mount (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-lnsml (ro)
Conditions:
  Type              Status
  Initialized       True 
  Ready             False 
  ContainersReady   False 
  PodScheduled      True 
Volumes:
  host-mount:
    Type:          HostPath (bare host directory volume)
    Path:          /host
    HostPathType:  
  default-token-lnsml:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  default-token-lnsml
    Optional:    false
QoS Class:       BestEffort
Node-Selectors:  <none>
Tolerations:     node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                 node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type     Reason     Age                    From               Message
  ----     ------     ----                   ----               -------
  Normal   Scheduled  4m34s                  default-scheduler  Successfully assigned test/test-reactjs-k8s-7945b64d6-zhztn to minikube
  Normal   Pulling    4m33s                  kubelet            Pulling image "nginx:latest"
  Normal   Pulled     4m25s                  kubelet            Successfully pulled image "nginx:latest"
  Normal   Created    3m25s (x3 over 4m25s)  kubelet            Created container reactjs-k8s
  Normal   Started    3m25s (x3 over 4m25s)  kubelet            Started container reactjs-k8s
  Warning  Unhealthy  3m25s (x6 over 4m15s)  kubelet            Liveness probe failed: Get http://172.17.0.9:3000/: dial tcp 172.17.0.9:3000: connect: connection refused
  Normal   Killing    3m25s (x2 over 3m55s)  kubelet            Container reactjs-k8s failed liveness probe, will be restarted
  Normal   Pulled     3m25s (x2 over 3m55s)  kubelet            Container image "nginx:latest" already present on machine
  Warning  Unhealthy  3m18s (x7 over 4m18s)  kubelet            Readiness probe failed: Get http://172.17.0.9:3000/: dial tcp 172.17.0.9:3000: connect: connection refused
~/projects/go-pr/
```

The mount looks fine with mount:
```bash
❯ k exec -it test-reactjs-k8s-56cc7669df-x7fv9 -- /bin/sh
# ls /host
README.md  node_modules  package.json  public  src  tsconfig.json  yarn.lock
# pwd
/host
```
Looks like it is an issue with the ReactJS project and yarn, so I go back to docker and reproduce this problem with
this project:
```bash
docker run -it  -p 8080:3000 -v  /Users/seizadi/projects/...ui:/host -w /host soheileizadi/reactjs-k8s:latest
yarn run v1.22.5
$ react-scripts start
ℹ ｢wds｣: Project is running at http://172.17.0.3/
ℹ ｢wds｣: webpack output is served from 
ℹ ｢wds｣: Content not from webpack is served from /host/public
ℹ ｢wds｣: 404s will fallback to /
Starting the development server...
Files successfully emitted, waiting for typecheck results...

```

That works on docker! :( WTF

I remembered I had turned on proxy on this:
```bash
  "proxy": "http://127.0.0.1:4433",
```
So I removed that from configuration to see if that makes a difference. Answer NO!

Then I put console.log in the first code that excutes and I see it in the docker run but not in the
minikube run, so it does not execute any of the script. At this point I try this on kind,
see this [kind guide on how to setup mounts](https://kind.sigs.k8s.io/docs/user/configuration/#extra-mounts)
```bash
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  # add a mount from /path/to/my/files on the host to /files on the node
  extraMounts:
  - hostPath: /Users/seizadi/project/reactjs-sample
    containerPath: /host
```

Create cluster...
```bash
❯ kind create cluster --config config-with-mounts.yaml
....
❯ k logs test-reactjs-k8s-84ff496648-wg7zn
yarn run v1.22.5
$ react-scripts start
ℹ ｢wds｣: Project is running at http://10.244.0.5/
ℹ ｢wds｣: webpack output is served from 
ℹ ｢wds｣: Content not from webpack is served from /host/public
ℹ ｢wds｣: 404s will fallback to /
Starting the development server...
```

So this works on kind cluster and the problem is with minikube running this workload!
I guess this means I will stop using minikube for now.

Disable Readiness and Liveness probes
```bash
  Warning  Unhealthy    4m3s                   kubelet            Readiness probe failed: Get "http://10.244.0.5:3000/": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
  Warning  Unhealthy    4m3s                   kubelet            Liveness probe failed: Get "http://10.244.0.5:3000/": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
  Norma
```

Now the whole system comes up...
```bash
❯ k logs test-reactjs-k8s-5cb9c9b456-vxhvp
yarn run v1.22.5
$ react-scripts start
ℹ ｢wds｣: Project is running at http://10.244.0.6/
ℹ ｢wds｣: webpack output is served from 
ℹ ｢wds｣: Content not from webpack is served from /host/public
ℹ ｢wds｣: 404s will fallback to /
Starting the development server...
Compiled successfully!

You can now view reactjs-sample in the browser.

  Local:            http://localhost:3000
  On Your Network:  http://10.244.0.6:3000

Note that the development build is not optimized.
To create a production build, use yarn build.
```

