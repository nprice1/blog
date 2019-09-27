+++
subtitle = "Experimenting with Kubernetes"
title = "Pods and Services and Deployments Oh My."
date = "2019-09-20T10:54:24+02:00"
draft = false
+++

I have been getting more and more involved in devopsy stuff. Mostly against my will, but it seems like any 
good programmer should keep up with the latest trends in this field. I wanted to start playing around with Kubernetes,
so I thought I would try and launch my chat application using it.

# Installation

## Minikube

I decided to go with [Minikube](https://kubernetes.io/docs/setup/learning-environment/minikube/) since it is light 
weight and seems well suited to little POC demo stuff. I followed [the Minikube installation guide](https://kubernetes.io/docs/tasks/tools/install-minikube/)
and chose [VirtualBox](https://www.virtualbox.org/wiki/Downloads) as my hypervisor. That word sounds so official.

After I got all this setup, I found my first problem. When I tried testing some of the `kubectl` commands
I kept getting this error:
```
Error from server (NotFound): the server could not find the requested resource
```
I had no idea what that meant, but after some googling I found it was caused by having a mismatch in my `kubectl` 
client and server versions. I confirmed this by running `kubectl version --short` and seeing the following output:
```
Client Version: v1.9.2
Server Version: v1.14.2
```
So I downloaded the proper client version by [following these instructions.](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
After installing the proper version of the client, everything worked correctly.

## Ambassador

Since I have two things that need to talk to each other with a user interface I need a router. I found 
[Ambassador](https://www.getambassador.io) and it looked light weight and easy to setup, all I needed to do to get
started was run 
```
kubectl apply -f https://getambassador.io/yaml/ambassador/ambassador-rbac.yaml
```
since RBAC was enabled.

Now when I run `kubectl get svc` I see this output:
```
NAME               TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
ambassador-admin   NodePort    10.110.49.247   <none>        8877:30021/TCP   23h
kubernetes         ClusterIP   10.96.0.1       <none>        443/TCP          41h
```

Cool there is stuff. So this means Ambassador exposes a [Service](https://kubernetes.io/docs/concepts/services-networking/service/)
in my cluster. A `Service` is an abstraction over a running application to inform how the cluster can interact with
a given application. The simplest definition of a service is just which application selector to use and which port it 
exposes. You'll notice under `PORT(S)` there are two for the `ambassador-admin` service. The first is the internal
port used within the cluster, so other services in the cluster can talk to the `ambassador-admin` service using that
port. The second one is the `NodePort`, which allows a service to be exposed outside the cluster. Definitely not a
thing you should do with your actual application in most cases.

The other thing we can check is how our [Pods](https://kubernetes.io/docs/concepts/workloads/pods/pod/) are doing. A
`Pod` is the actual running application that a service is using. I've only ever seen these being Docker images. When
 we run `kubectl get pods` we get this output:
```
NAME                          READY   STATUS    RESTARTS   AGE
ambassador-7bf6b448c5-fh9fn   1/1     Running   6          23h
ambassador-7bf6b448c5-ppg8x   1/1     Running   0          23h
ambassador-7bf6b448c5-xtrs4   1/1     Running   0          23h
```
It looks like Ambassador creates three different pods (mine have been running for a while) and all are running. We can
get more info on these pods by running `kubectl describe pod POD_NAME`.

OK now that we have our router, time to actually deploy our application. Probably.

# Launching the Chat App

## Modify the Chat Client

The first thing we need to change is the hardcoded `localhost:3000` used in the chat client code for the Websocket. In
the [index.tsx](https://github.com/nprice1/typeScriptChatClient/blob/master/src/index.tsx) file for the chat client 
use the following code to create the WebSocket:
```
const socket: WebSocket = new WebSocket(`ws://${location.hostname+(location.port ? ':'+location.port: '')}/server/`);
```
Run `npm run build` in the chat client directory and rebuild the Docker image with version `chat_client:v1.0.1`

## Making Minikube Use Local Docker Image (Optional)

Since I'm lazy and didn't want to actually deploy my Docker image, I did the following to allow Minikube to use
locally built docker images:

1. Set the environment variables with `eval $(minikube docker-env)`
2. Build both the chat client and chat app from my [Typescript chat project](http://nolanprice.com/post/typescript-react-redux-chat/) using the `docker build` command and tagging them as
`chat_client:v1.0.1` and `chat_server:v1.0.0`.

**NOTE:** This will effect the specification files in the next section, specifically the image name and the image pull
policy. Doing this step requires using `Never` as the image pull policy to prevent Kubernetes from attempting to 
download the image. 

## Create the Specifications

Now we can finally define our services. Having a running service will also require a 
[Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/). A `Deployment` represents a 
desired state for an application, like how many instances are running for example. A `Service` will point to a 
running application that was launched using a `Deployment`. So we will need to create a `Service` and a `Deployment`
for both the chat client and the chat server. Thankfully this is pretty straight forward. 

### Chat Client Specification

Here is what the chat client `Deployment` looks like:
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client
      version: v1
  template:
    metadata:
      labels:
        app: client
        version: v1
    spec:
      containers:
      - name: client
        image: chat_client:v1.0.1
        imagePullPolicy: Never
        ports:
        - containerPort: 80
```
The important parts are in the `spec` where we define which docker image is used and which ports are used by the 
container. Now for the client `Service`:
```
apiVersion: v1
kind: Service
metadata:
  name: client
  labels:
    app: client
spec:
  ports:
  - port: 8080
    targetPort: 80
    name: ui
  selector:
    app: client
```
The important parts here are again in the `spec` where we define port mappings (the `targetPort` here is the port used
in the actual container, the `port` is what is exposed as part of the service) and which `selector` to use. The 
`selector` here is the name we gave to our client `Deployment` above in the `selector.matchLabels` field. And that's it
for the client. Way easier than I was expecting. 

### Chat Server Specification

Now we need a `Service` and `Deployment` for the server. Here is our `Service`:
```
apiVersion: v1
kind: Service
metadata:
  name: server
  labels:
    app: server
spec:
  ports:
  - port: 8081
    name: metrics
  - port: 3000
    name: websocket
  selector:
    app: server
```
I'm exposing both the metrics port and the WebSocket port in case we want to also collect metrics on the server later.
Here is the `Deployment`:
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: server
      version: v1
  template:
    metadata:
      labels:
        app: server
        version: v1
    spec:
      containers:
      - name: server
        image: chat_server:v1.0.0
        imagePullPolicy: Never
        ports:
          - containerPort: 8081
          - containerPort: 3000
```
Now our services are all set, but before we launch everyting we need to setup our routing. 

### Routing

We will need two routes, one for the client and one for the server. Ambassador makes this super easy thankfully. In 
order to create a route we will create two `Mappings` as defined by Ambassador. In our simple case these just setup
the route to trigger a given rule and which service and port will be routed to. Here is the mapping for our client:
```
apiVersion: getambassador.io/v1
kind: Mapping
metadata:
  name: chat-ui
spec:
  prefix: /
  service: client:8080
```
So when we hit the root of our Ambassador load balancer we will route to port `8080` of our `client` service, which
then will hit port `80` of the `chat_client:v1.0.1` container. Nice. The one for the server is a tiny bit more complex:
```
apiVersion: getambassador.io/v1
kind: Mapping
metadata:
  name: chat-backend
spec:
  prefix: /server/
  service: server:3000
  use_websocket: true
  labels:
    ambassador:
      - request_label:
        - server
```
The two extra bits we have here are the `use_websocket: true` option since this is a websocket connection and some
labels so we could easily separate this route from any others in our Ambassador configuration. 

### Ambassador Service

Now we have our application all sorted out, but we are still missing one crucial piece: the Ambassador service. We
have installed Ambassador and defined some mappings but we need an actual running Ambassador service in order to 
actually hit the router and have it do its thing. To do that we will create a file called `ambassador-service.yaml` 
with the following content:
```
---
apiVersion: v1
kind: Service
metadata:
  name: ambassador
spec:
  type: NodePort
  externalTrafficPolicy: Local
  ports:
   - port: 80
     targetPort: 8080
  selector:
    service: ambassador
```
This will start up the service that we will actually be hitting in our browser to run the app. Note that I am using
`NodePort` here since I'm using Minikube which doesn't play nice with the `LoadBalancer` type without some extra work
that we will go over later. 

### Putting It All Together

To make things simple I jammed all of my app configuration into a single file called `app.yaml` with the following 
content:
```
apiVersion: v1
kind: Service
metadata:
  name: client
  labels:
    app: client
spec:
  ports:
  - port: 8080
    targetPort: 80
    name: ui
  selector:
    app: client
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client
      version: v1
  template:
    metadata:
      labels:
        app: client
        version: v1
    spec:
      containers:
      - name: client
        image: chat_client:v1.0.1
        imagePullPolicy: Never
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: server
  labels:
    app: server
spec:
  ports:
  - port: 8081
    name: metrics
  - port: 3000
    name: websocket
  selector:
    app: server
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: server
      version: v1
  template:
    metadata:
      labels:
        app: server
        version: v1
    spec:
      containers:
      - name: server
        image: chat_server:v1.0.0
        imagePullPolicy: Never
        ports:
          - containerPort: 8081
          - containerPort: 3000
---
apiVersion: getambassador.io/v1
kind: Mapping
metadata:
  name: chat-ui
spec:
  prefix: /
  service: client:8080
---
apiVersion: getambassador.io/v1
kind: Mapping
metadata:
  name: chat-backend
spec:
  prefix: /server/
  service: server:3000
  use_websocket: true
  labels:
    ambassador:
      - request_label:
        - server
```
Now to finally launch our app we need to run `kubectl apply -f ambassador-service.yaml` and 
`kubectl apply -f app.yaml`. After we run those we need to make sure all our pods are running by executing
`kubectl get pods` and making sure we see the normal 3 `ambassador` pods as well as `client` and `server` pods all
marked as `Running` like this:
```
NAME                          READY   STATUS    RESTARTS   AGE
ambassador-7bf6b448c5-q8zv4   1/1     Running   0          13m
ambassador-7bf6b448c5-qxjn8   1/1     Running   0          13m
ambassador-7bf6b448c5-w82xn   1/1     Running   0          13m
client-74f94c6d46-l95tp       1/1     Running   0          12s
server-846f69c77c-dmn6g       1/1     Running   0          12s
```
Now we can check and make sure our services are up and running with `kubectl get svc`. We should see something like
this:
```
NAME               TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)             AGE
ambassador         NodePort    10.110.124.46    <none>        80:30034/TCP        11m
ambassador-admin   NodePort    10.100.106.207   <none>        8877:32457/TCP      14m
client             ClusterIP   10.96.241.196    <none>        8080/TCP            50s
kubernetes         ClusterIP   10.96.0.1        <none>        443/TCP             17m
server             ClusterIP   10.103.223.60    <none>        8081/TCP,3000/TCP   49s
```
So our window into our application is the `ambassador` service, which is on port 30034 (the `NodePort`). Minikube has
a handy shortcut for getting the url of a service by running `minikube service ambassador --url`. For me I get
```
http://192.168.99.104:30034
```
When I hit that URL in my browser I see the chat UI! Woot! I can type stuff in and more stuff happens so I'm calling
it good here. I have officially Kubernetes-ed. 

# Bonus Points

Even though I'm basically an expert now in Kubernetes (I can't emphasize how much sarcasm was in that last statement.
Just so much.) I wanted to also try abandoning the need for the `NodePort` since that is not an ideal way of exposing
services. Minikube has a tunnel feature that allows you to play around with `LoadBalancer` services, so I decided to
try that out too. 

One of the nice things about using Kubernetes is the abstractions allow me to do this without effecting very much.
Since the Ambassador `Service` is just an abstraction, I can try this out without deleting any of my running 
containers. That's pretty rad. First I need to get rid of my lame old ambassador service which I can do by running
`kubectl delete -f ambassador-service.yaml`. I could avoid this step and just use the `kubectl apply` command with
an updated config, but I'm paranoid and want to make sure my changes take effect.

Next I'll edit that file to use the `LoadBalancer` type like I've always wanted:
```
---
apiVersion: v1
kind: Service
metadata:
  name: ambassador
spec:
  type: LoadBalancer
  externalTrafficPolicy: Local
  ports:
   - port: 80
     targetPort: 8080
  selector:
    service: ambassador
```

Now I'm going to run `minikube tunnel` in a new terminal and wait until I start seeing some log output (it also 
prompts for the admin password here). Once that is running I can deploy my hot new service by running
`kubectl apply -f ambassador-service.yaml`. Now when I run `kubectl get svc` I see an external IP!
```
NAME               TYPE           CLUSTER-IP       EXTERNAL-IP    PORT(S)             AGE
ambassador         LoadBalancer   10.105.73.23     10.105.73.23   80:32692/TCP        11s
ambassador-admin   NodePort       10.100.106.207   <none>         8877:32457/TCP      20m
client             ClusterIP      10.96.241.196    <none>         8080/TCP            6m33s
kubernetes         ClusterIP      10.96.0.1        <none>         443/TCP             23m
server             ClusterIP      10.103.223.60    <none>         8081/TCP,3000/TCP   6m32s
```
And sure enough when I hit that IP I can start chatting. That was so much easier than I expected that I think I must
have broken something so badly it just happened to make it look like it worked. And I'm ok with that. 