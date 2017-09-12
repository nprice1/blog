+++
date = "2017-09-12T10:54:24+02:00"
title = "Using Host Network Docker for Mac"
subtitle = "Private Repos in Docker"
draft = false
+++

I've been using [Docker](https://www.docker.com/) a lot at work lately, and it is pretty awesome. Generally I prefer structure over chaos, which is why 
I lean towards typed languages rather than scripting languages. I like things well defined. I like to know exactly what I'm getting. Docker seemed like
a very interesting solution for this problem. Specifically, it sounded like a great way to solve the "Well it doesn't happen on my machine" bugs. We 
started using Docker and things were pretty awesome, and then we started using private repos on [Gitlab](https://gitlab.com/) and things got less awesome. 
The joy of Docker containers is also one of the major drawbacks: a Docker image is bare bones. Meaning no SSH keys (unless you want to share them into an 
image which is a huge no-no for me since anybody getting a hold of your Docker image can get your key super easily). So the question became, how do we get
the best of both worlds? How can we get access to our private repositories from within a docker container without wanting to kill something or making something
super insecure?

# The Problem

Let's make the problem a little more concrete. Say we have a Node project that uses a private Gitlab repo as a dependency. Our goal is to perform an `npm install`
command in the docker image itself rather than sharing in our build artifacts. That way we get all of the glory of Docker: we have a guaranteed build environment
with a semi-determinstic (npm isn't great with deterministic, using yarn would help) build across any OS. Take that with a grain of salt, but it is atleast 
closer than just letting a dev's local machine determine your runtime. 

Alright now we have a problem to solve, let's take our first swing at a Docker file:

```
FROM node:7-alpine

WORKDIR /home/app/current/

RUN apk update && \
    apk upgrade && \
    apk add --no-cache libc6-compat && \
    apk add --no-cache git
    
COPY src/ src/
COPY package.json package.json

RUN npm install

CMD npm start
```

All in all that is a pretty straight forward Docker file. We install libc6-compat (which may not be required for all node projects but I ran into it enough to include
it in all my node Docker files) and we install git since we are using a git dependency (again may not be necessary, but this issue will also occur if you have a private 
hosting server for your npm packages). Then we share in our source and our package JSON and we try and build. Now we run it... and things don't go well:

```
npm ERR! remote: HTTP Basic: Access denied
npm ERR! fatal: Authentication failed
```

Alright so we couldn't authenticate over HTTP, that sucks. How about we try SSH? Shockingly we get the same issue, no SSH keys in our Docker image. Let's take our first
swing at fixing the issue. 

# Solution 1: ALL THE DOCKER IMAGES!

The easiest route for solving this issue is to just share our SSH keys into the Docker image. Then it would be able to pull our repo and all would be well. Except for the
whole problem of having your SSH keys built into a deployable artifact that can be easily found by anybody that has your image. That sucks. Well Docker does provide a way
to share files transiently into docker containers (not images, terminology gets really confusing right around here). The first attempt at solving this problem was to just
make a node Docker image that expected to have SSH keys shared into it at run time (in the container) and perform the `npm install` there. After that, you could pull out 
the build artifacts and share them into your final Docker image. Here is our intermediate Docker file:

```
FROM node:7-alpine

# Creates a docker image suitable for building Node projects.
# Run this container 
COPY . /home/app/current

# Install Git, which is needed for npm install
RUN apk update \
    && apk upgrade \
    && apk add --no-cache \
    bash \
    git \
    openssh

RUN mkdir -p /root/.ssh

RUN echo $'Host gitlab.com\n\
IdentityFile /root/.ssh/id_rsa\n\
IdentitiesOnly yes\n\
PasswordAuthentication no'\
    > /root/.ssh/config
```

This docker image is expecting a file to be stored at `/root/.ssh/id_rsa` that will be used to pull your private repo using SSH. Alright nothing too fancy here, but now we
need a script to build our actual Docker image, you know the one with our app in it and stuff. Let's say the Docker image above is named `node-build-env:7-alpine`, then our script 
would look like this:

```
#!/bin/sh

# If the one needed argument was not given
image_name=our-image
tmpdir="$PWD/temp"

# Make sure the temp directory does not already exist
rm -rf $tmpdir

mkdir $tmpdir

# Copy the current repo into the temp directory
cp -r dist $tmpdir
cp package.json $tmpdir
cp Dockerfile $tmpdir

# Make a new node modules directory that will be filled in by the next command
mkdir $tmpdir/node_modules

# Install node_modules from the proper environment.
# Share host machine private ssh key.
docker run -it -w /home/app/current \
                -v ~/.ssh/id_rsa:/root/.ssh/id_rsa \
                -v $tmpdir/package.json:/home/app/current/package.json \
                -v $tmpdir/node_modules/:/home/app/current/node_modules/ \
                node-build-env:7-alpine \
                npm install
            
if [ $? -node 0 ] 
then
  echo "Failed to run intermediary docker file"
  exit 1
fi

docker build -t "$image_name" $tmpdir

# Clean up
rm -rf $tmpdir
```

Things are getting a bit more complicated here. Also notice our `docker run` command is using the `-it` flag. That's because if the host machine SSH file is password
protected as it should be, the user has to interact with the terminal while building this Docker image. We now have a working solution, but is it the best one?

## Cons

1. Too many docker images. Having to run an intermediary Docker image for ANY node app is crazy. What happens if we need to update our node version? We need to change
two places now, and if we only change one then who knows what weirdness would happen. 
2. Requires user interaction during Docker build. Guess what that means? No automation unless you want to write some wonky scripts.

These may seem like pretty minor cons, but they were a big deal to us and we wanted a better solution.

# Solution 2: Local Repo Hosting

Another way of looking at the problem is that our repos require authentication to get to. What if they were public? Obviously that defeats the whole purpose, but what if
we just make them public on our internal network? Then anybody with a VPN connection can run the build as if the repos were public. Since Docker images are running on a 
host machine that should have access to the network, the Docker image would then be able to get the repos too! All would be well and the children would frolic in the fields!

Our Sys-Admins got a local Gitlab install on one of our servers and opened up the repos, and we were ready to test. We could use our initial docker file again:

```
FROM node:7-alpine

WORKDIR /home/app/current/

RUN apk update && \
    apk upgrade && \
    apk add --no-cache libc6-compat && \
    apk add --no-cache git
    
COPY src/ src/
COPY package.json package.json

RUN npm install

CMD npm start
```

I ran the build and... nothing. Like seriously nothing, the build would just hang forever with no error messages or anything. After some Googling I found out there are 
some flags you need to pass in order to have a Docker image use the host network wholesale during image building, specifically you just need to pass `--network host` in 
the build command and you should be good to go. And if you are running on Linux you are! Everything works and you are happy as a clam. I on the other hand am running on 
Mac and this did NOT work. At the time of writing this post, Docker for Mac did not support using the host network in Docker containers. Some limitation with the Mac OS. 
Crap. 

## The Cons

1. Doesn't work on Mac.

Since I do my dev work on a Mac, this proved to be a blocker issue and required one more step to finally get this working. 

# Solution 3 (For Mac): SSH Tunnel With Edited Hosts File

Alright so apparently Mac refuses to open up the network to the Docker image, that sucks. Quite a while ago I was working on a project that required a VPN connection that
I didn't have access to, but I did have SSH access to a server that did have the VPN connection. I asked around the office and was told about how freaking awesome 
[SSH tunnels](https://en.wikipedia.org/wiki/Tunneling_protocol) are. An SSH tunnel allows proxying requests over a given port to another server. It turns out I could setup
an SSH tunnel that routes all HTTPS traffic (port 443) directly to the server hosting our repos. Awesome! 

Now the next hitch, that would mean having `https://localhost` in my package.json files... Not ideal. This obviously breaks the idea that I could still build my project without
needing Docker at all. If we need a new IP to host name mapping, we need to edit the `/etc/hosts` file. Specifically we need to map our localhost traffic to be whatever the domain
for our private repos is. Docker for Mac makes this a little trickier since you can't just use localhost, but they do provide a custom mapping for your local machine IP using 
`docker.for.mac.localhost`. Here is our new dev docker image:

```
FROM node:7-alpine

WORKDIR /home/app/current/

RUN apk update && \
    apk upgrade && \
    apk add --no-cache libc6-compat && \
    apk add --no-cache git

COPY src/ src/
COPY package.json package.json

# Get the IP address for docker.for.mac.localhost
RUN nslookup docker.for.mac.localhost | sed -rn 's/Address 1: ([^\n\r]*).*/\1/p' | tr '\n' ' ' > local.ip
RUN echo "   super.secret.domain.com" >> local.ip

# Update the host and install
RUN echo "$(cat local.ip)" >> /etc/hosts && npm install

CMD npm start
```

First let's look at how we get the content we will be putting in our hosts file. We do a quick `nslookup` for the name provided by docker for mac and pipe it into a nasty
`sed` call that will pull out the actual IP address from the result and store that in a file called `local.ip`. Then we append our super secret private repo server domain 
name to the `local.ip` file. 

The next part is a little weird simply because we have to run two commands right after each other. This is because while building images, Docker does some interesting things
with the `/etc/hosts` file, so any changes you make don't persist between calls. So we have to make sure we call `npm install` in the same command we update our hosts file with 
the new host. 

Alright now we have a dev Docker image that will route all requests to our super secret private repo domain through our host. Now we need to setup the actual tunnel so it will 
correctly route the traffic. To do that I wrote a simple script:

```
#!/bin/bash

# start an ssh tunnel
sudo ssh -f -N -L 443:super.secret.domain.com:443 $USER@127.0.0.1

image_name=our-app-image

docker build -t "$image_name" -f Dockerfile.dev .

# kill the ssh tunnel
tunnel_pid="$(pgrep sshd)"
sudo kill -9 $tunnel_pid
```

We start an SSH tunnel that routes all HTTPS traffic on our localhost to our super secret domain by SSH'ing into itself, which is pretty meta. The `$USER` variable is provided
by unix so it will attempt to SSH into itself using the current user. We then build an image using our dev docker file (you definitely don't want to be messing with the hosts file
in your production image if you can avoid it) and everything routes! Now we can pretend to use the host network on Mac and the Linux users can stop making fun of us so much!