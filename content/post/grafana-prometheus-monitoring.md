+++
title = "Application Monitoring with Docker, Prometheus, and Grafana"
date = "2018-03-30T10:54:24+02:00"
draft = false
tags = ["grafana", "prometheus", "docker"]
+++

Lately I've been interested in how to setup application monitoring. With Docker, it should be pretty straight forward
to setup tools like Prometheus and Grafana, so I set out to see how simple it would be to wire up my little typescript
chat application in Docker with some application monitoring. This means I had to update my typescript server and
client code to work inside a Docker container, add some docker files to build the images, and make a docker compose 
file to spin up the whole shebang. As an extra bonus, I decided to make a tiny "chaos" application that sends some 
garbage to the chat server so we have something more interesting to monitor. 

## Updates to the Code ##

Ideally changes to the code wouldn't be necessary, but in my original implementation I did something a little hacky. 
I was directly using some dependencies from the linked server repo rather than relying on it as an actual npm package. 
In Docker land this is a no go because containers ideally have no context of other repos on the system. I could 
just add the server code as a volume to the client docker image, but that's overkill. Far better to just 
pretend I am a good programmer and make the server an npm package that a Docker image can pull down. 

To fix that, I have to actually use typescript as intended, and make a typings file for the server that defines the 
interface the client should use. Then I had to update the client to actually include the server code as an npm 
dependency and implement the interface appropriately. 

### Server Changes ###

In the server project, I made a new `index.d.ts` to defined the `Message` interface
the clients should use as opposed to just exporting it in the models file. Here is the content of the new file:

```
export interface Message {
	name: string;
	message: string;
}
```

After fixing any broken imports in the server code that was the only change I needed. The client code required a bit 
more effort. 

### Client Changes ###

The first thing we needed to do was include the `typeScriptChatServer` as an actual npm dependency, so I added the following to the `package.json` dependencies:

```
"type-script-server": "git+https://github.com/nprice1/typeScriptChatServer.git",
```

Now rather than using the link method I was using before, the client will pull down the server resource and can use
it as a "proper" dependency. This really isn't super proper though, because I'm still cheating and using the `src/` 
directory for my dependencies which is not a good idea, but I'm lazy and expermenting so tough. 

After including the dependency, I had to fix all my imports that were pulling from the server code (using 
`type-script-server/src/index` as the import path for the `Message` interface). After that, I had to actually 
implement the interface. The server really only cares that the object contract is met, not how the object actually 
gets constructed. Originally I was pulling the actual implementation from the server, but now it is a bit cleaner at 
the cost of some duplicated code. I used the same `UserMessage` implementation as the server. 

Now that the code is Docker ready, we can make the Docker files for each build.

## Server Dockerfile ##

Our server is a super simple node server, so we just need to pull down an appropriate node docker image as the base, 
run our install, build, and start commands like we would if building locally, and blamo we are good to go:

```
FROM node:9

WORKDIR /home/

COPY src/ src/
COPY package.json package.json
COPY tsconfig.json tsconfig.json

RUN npm install
RUN npm run build

CMD npm start
```

I'm being pretty deliberate with my `COPY` commands here, I could save two lines and just do `COPY . .` and then run all my commands, but I try to keep my Docker images super lean and declarative. Doing an entire copy for a directory is asking for trouble, way too easy to share in files you don't want to share. For little projects like this who cares,
but for real world projects where you forgot to remove the production key from the config you were using to test 
locally, it can really suck. 

## Client Dockerfile ##

The client is a little different, we are just loading some static files so all we need is a lightweight web server. 
I chose to use [Nginx](https://www.nginx.com/) because I wanted to. Then I just need to put the static files I want to 
serve up in the proper directory. While working on this, though, I realized I didn't actually have a build command in 
my client. I was just using the `webpack-dev-server` command, so I needed to add an actual build command to the scripts
in my `package.json`:

```
"build": "webpack",
```

This is the point where I always get split for some Docker images. Ideally, you would want your code to be built in the
same container it will be run from. However in this case, I need both npm and nginx, and I don't want to bloat my 
runtime container just so I can build in it. So for expediency I'm just making sure to build my code locally before 
I build my docker image. Then my Dockerfile is nice and easy:

```
FROM nginx

COPY index.html /usr/share/nginx/html/
COPY build/* /usr/share/nginx/html/build/
```

Now nginx will server up my static files and all is well. 

## Monitoring ##

Now it's time for the fun part: monitoring the application. I wanted some simple metrics for my server, so I decided 
to just expose the current number of connections and how many errors the server has retrieved, both of which are just 
stored in memory. Prometheus (our data extractor) relies on a file with metrics data when it makes a `GET` requet to 
the `/metrics` endpoint of your server. So, I had to update my `server.ts` code to not only to handle WebSocket 
connections, but also HTTP connections as well as adding the logic to actually count the connections and errors:

```
import * as WebSocket from 'ws';
import * as http from 'http';
import { UserMessage } from './models';

const port: number = 3000;
const metricsPort: number = 8081;
const server: WebSocket.Server = new WebSocket.Server({ port: port });
const metricsServer: http.Server = http.createServer(requestHandler);

let connections: number = 0;
let errorCount: number = 0;

server.on('connection', ws => {
	console.log('new connection');
	connections++;
	ws.on('message', message => {
		try {
			const userMessage: UserMessage = new UserMessage(message);
			broadcast(JSON.stringify(userMessage));
		} catch (e) {
			console.error(e.message);
			errorCount++;
		}
	});
});

metricsServer.listen(metricsPort, (err: Error) => {
	if (err) {
	  return console.log('something bad happened', err);
	}
  
	console.log(`server is listening on ${metricsPort}`);
});

function broadcast(data: string): void {
	server.clients.forEach(client => {
		client.send(data);
	});
};

function requestHandler(request: http.IncomingMessage, response: http.ServerResponse): void {
	response.end(`connections ${connections}\nerror_count ${errorCount}`);
}

console.log('Server is running on port', port);
```

The changes here were adding simple counts when a new connection is formed and when an error constructing a 
`UserMessage` is encountered. The HTTP handling is dead simple, and will just always return the metrics data 
regardless of which endpoint is requested. 

After defining these metrics, I needed an easy way to bump up my error count so I can see it. To do that, I made a 
super simple "chaos" script that just sends garbage data to the server for a bit:

```
import * as WebSocket from 'ws';

const socket: WebSocket = new WebSocket("ws://server:3000");

for (let i=1; i <= 10; i++) {
    setTimeout(() => {
        socket.send('garbage');
    }, i * 1000);
}
```

Then, in order to run it, I added a "chaos" script to my `package.json` file:

```
"chaos": "node ./build/chaos.js"
```

Now we are ready to make the docker-compose file that will start the whole mamma-jamma. 

## Docker Compose ##

In order to get the whole operation up and running, we need the following services:

1. The chat server.
2. The chat client. 
3. The chaos app. 
4. Prometheus (for data extraction).
5. Grafana (for data visualization).

Prometheus and Grafana both have docker images, so we just need to build docker images for our server and our chat app.
The chaos app can be handled in the docker-compose file with a bit of trickery. In order to build our docker images, 
run the following command in the chat client repo: `docker build . -t chat_client:v1.0.0`, and the following script in
the chat server repo: `docker build . -t chat_server:v1.0.0`. Now that we have our docker images, we can define our 
compose file. First let's load in the external stuff:

```
version: '3.1'

volumes:
  prometheus_data: {}
  grafana_data: {}

services:
  # Prometheus monitoring
  prometheus:
    image: prom/prometheus:v2.0.0
    volumes:
      - ./prometheus/:/etc/prometheus/
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    ports:
      - 9090:9090
    
  grafana:
    image: grafana/grafana
    depends_on:
      - prometheus
    ports:
      - 3001:3000
    volumes:
      - grafana_data:/var/lib/grafana
    env_file:
      - config.monitoring
```

This tells Docker to load in the `v2.0.0` image for Prometheus, share in some config files (which I'll get to below), 
and start the service on port 9090. We also use the latest `grafana` image, share in some config files (more below), 
and start that one on port 3001 to avoid a port collision with the server that runs on 3000. Now let's setup our application images:

```
  server: 
    image: chat_server:v1.0.0
    ports:
      - 3000:3000
      - 8081:8081
  chaos: 
    image: chat_server:v1.0.0
    command: npm run chaos
    depends_on:
      - server
  client:
    image: chat_client:v1.0.0
    ports:
      - 8080:80
    depends_on: 
      - server
```

We are loading the `v1.0.0` images of our client and server we just built. The server will have a WebSocket connection
on port 3000, and an HTTP connection on port 8081 to avoid a collision with the client running on 8080. The chaos 
service is using the handy `command` override to tell the server image it should use `npm run chaos` rather than the
`npm start` it usually uses so we only need one image for multiple uses. 

### Configuration ###

Now that we have a docker-compose file defined, we need to make some config files for Prometheus and Grafana to 
function properly. First, I made a `prometheus` directory in the chat server repo (which we are sharing into the 
prometheus image as a volume) with the following `prometheus.yml` file:

```
# my global config
global:
  scrape_interval:     15s # By default, scrape targets every 15 seconds.
  evaluation_interval: 15s # By default, scrape targets every 15 seconds.
  # scrape_timeout is set to the global default (10s).

  # Attach these labels to any time series or alerts when communicating with
  # external systems (federation, remote storage, Alertmanager).
  external_labels:
      monitor: 'Alertmanager'

# Load and evaluate rules in this file every 'evaluation_interval' seconds.
rule_files:
  # - "first.rules"
  # - "second.rules"

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:

  - job_name: 'prometheus'

    # Override the global default and scrape targets from this job every 5 seconds.
    scrape_interval: 5s

    static_configs:
         - targets: ['localhost:9090']

  - job_name: 'server'

    # Override the global default and scrape targets from this job every 5 seconds.
    scrape_interval: 5s

    static_configs:
         - targets: ['server:8081']
```

Most of it is commented out, the important bits are down in the `scrape_configs` section. Here we tell prometheus
which applications to scrape to collect data. We are having prometheus scrape data on itself so we define the 
`localhost:9090` target since it will be in the same container. For the server, we get to use a handy feature of 
Docker networks and specify the service name rather than an actual address. So saying `server:8081` tells Docker
to route to the `server` service HTTP port and pull the metrics. Pretty sweet. 

Now that prometheus is all setup, we can make a Grafana config which will set an initial password and prevent new 
users from signing up. To do that we create a `config.monitoring` file in the root of the chat server repo with the 
following content:

```
GF_SECURITY_ADMIN_PASSWORD=foobar
GF_USERS_ALLOW_SIGN_UP=false
```

## Putting it all Together ##

Now we can finally run `docker-compose up` and our application is up! You can watch the logs and see the server 
already complaining of the garbage data the chaose app is sending. We can visit `http://localhost:8080` to start a 
client and connect to the server, and we can visit `http://localhost:8081` to see how many connections and errors we
currently have. We can go to `http://localhost:9090` to see how Prometheus is doing, but I want to see some pretty 
graphs. Go to `http://localhost:3001` and login with username `admin` password `foobar`. 

In order to add our Prometheus data source, click the `Create your first datasource` button and enter the data like
the image below

![prometheus data source configuration](/img/prometheus_config.png) 

Now go back to the home screen and click `Create your first dashboard`. In the upper left click on the `New Dadhboard`
text. In the next window, click the `Import dashboard` button. In the `Or paste JSON` entry area, copy and paste the 
contents of the [server-monitoring-dashboard.json](https://raw.githubusercontent.com/nprice1/typeScriptChatServer/master/server-monitoring-dashboard.json)
file in the chat server repo. This will create two panels, one viewing the number of connections and the other 
viewing the number of errors. The error dashboard has a simple alert setup to go off when the number of errors exceeds
5.

Now we have a super simple chat application with some monitoring! Playing around in Grafana is very simple, and you 
can add more alerts and notification methods for the available metrics, or add some more metrics to the server so you 
can get some better monitoring. Happy experimenting!