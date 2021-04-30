+++
title = "TypeScript/React/Redux Chat App Tutorial"
date = "2017-05-01T10:54:24+02:00"
draft = false
tags = ["typescript", "react", "redux", "websockets"]
+++
Most of my experience is in writing backend code. I have always worked with (and love)
typed languages. I am a big fan of verbose programming languages because most of the
projects I've worked on have been large Enterprise projects. When projects get large,
using a scripting language gets hairy. However, scripting languages are also awesome, and I
wanted to get more experience with them. I have written plenty of Javascript with jQuery, but that
doesn't cut it anymore. So I decided to dip my toe into the wild work of Javascript frameworks.
I decided to use TypeScript because I love my types, and I wanted to use React and Redux.
This is a pretty long article, so feel free
[to just skip straight to the source code on my github account](https://github.com/nprice1?tab=repositories).

## Setup ##
First, we have to do all of our awesome frontend setup. Make sure to [install node and npm](https://docs.npmjs.com/getting-started/installing-node) if you haven't already.
Create two directories for your projects, one for the chat server and one for the
chat client. First we will setup our server, so run the following commands in your terminal:

```bash
cd <YOUR CHAT SERVER DIRECTORY>
npm init
npm install --save-dev ts-loader typescript ws @types/ws
npm link
mkdir src
```

Here is what each of those commands is doing:

1. `npm init`: This creates a `package.json` file in your project and asks various questions
about the project you are writing, like the package name and the current version.
**MAKE SURE YOU USE THE NAME type-script-server OR THE IMPORTS IN OUR CLIENT WON'T WORK**
2. `npm install --save-dev ...`: This installs all of the packages that come after it
as dev dependencies. Since we aren't publishing this module, we are only using dev dependencies.
3. `npm link`: This adds a symlink in the current project so that
it can be used in other projects locally. We need this because our chat client project
is going to be using some files from this server project. When we setup our client, we will
be calling npm link again in order to setup the symlink so the chat client can use our server code.
4. `mkdir src`: Makes a new `src/` directory in your project where we will be adding our code.

Now we need to create a new `tsconfig.json` file in the directory that looks like this:

```json
{
  "compilerOptions": {
    "outDir": "./build/",
    "sourceMap": true,
    "noImplicitAny": true,
    "module": "commonjs",
    "target": "ES5",
    "jsx": "react"
  },
  "include": [
    "./src/**/*.ts"
  ],
  "exclude": [
    "./node_modules"
  ]
}
```

This file configures how typescript compiles our project. The important bit that differentiates
this configuration from others is the `"jsx": "react"` line. That tells typescript to use
React to handle the JSX files when building.

Now we can setup the client project:

```bash
cd <YOUR CHAT CLIENT DIRECTORY>
npm init
npm install --save-dev ts-loader typescript webpack react react-dom redux react-redux webpack-dev-server ws @types/react @types/react-dom @types/react-redux @types/redux @types/ws
npm link type-script-server
mkdir src
```

We also need a `tsconfig.json` file in this project that looks like this:

```json
{
  "compilerOptions": {
    "outDir": "./build/",
    "sourceMap": true,
    "noImplicitAny": true,
    "module": "commonjs",
    "target": "ES6",
    "jsx": "react"
  },
  "include": [
    "./src/**/*.ts"
  ],
  "exclude": [
    "./node_modules"
  ]
}
```

Finally we need to create a `webpack.config.js` file to handle the build for our
client app that looks like this:

```javascript
module.exports = {
  devtool: 'source-map',
  entry: './src/index.tsx',
  output: {
    filename: './build/client.js',
  },
  resolve: {
    extensions: ['.webpack.js', '.web.js', '.ts', '.tsx', '.js']
  },

  module: {
    loaders: [{ test: /\.tsx?$/, loader: 'ts-loader' }]
  }
};
```

I am far from an expert on Webpack, I just copied the config I saw used for React apps
using typescript.

## Write the Chat Server ##

First, we should define what our chat message will look like. To do that, we will make a
simple interface and an implementation of that interface that is able to parse an incoming
string. Create a new `models.ts` file in your `src/` directory that looks like this:

```typescript
export interface Message {
 name: string;
 message: string;
}

export class UserMessage implements Message {
 name: string;
 message: string;

 constructor(payload: string) {
   var data = JSON.parse(payload);

   if (!data.name || !data.message) {
     throw new Error('Invalid message payload received: ' + payload);
   }

   this.name = data.name;
   this.message = data.message;
 }
}
```

Our messages will just have two fields: a name and the message itself. We make an
implementation of this interface so that we can have a way to create a message given
a string value. That way when our client sends a message as a string, we can pull the
username and the message from it and make a Message from it.

Now we write our actual server code. Make a new file called `server.ts` in your `src/`
directory that looks like this:

```typescript
import * as WebSocket from 'ws';
import { UserMessage } from './models';

// Create a new WebSocket server
const port: number = process.env.PORT || 3000;
const server: WebSocket.Server = new WebSocket.Server({ port: port });

// Add a handler when clients connect to the WebSocket
server.on('connection', ws => {
	console.log('new connection');
        // Whenever we receive a message, parse it into our UserMessage model and broadcast
        // it to all connected clients
	ws.on('message', message => {
		try {
			const userMessage: UserMessage = new UserMessage(message);
			broadcast(JSON.stringify(userMessage));
		} catch (e) {
			console.error(e.message);
		}
	});
});

function broadcast(data: string): void {
	server.clients.forEach(client => {
		client.send(data);
	});
};

console.log('Server is running on port', port);
```

That's all the code we need for our server to be up and running. Now we need to actually
build it so we can run our server. In the `package.json` file, replace the `"scripts"` entry
with this:

```
"scripts": {
  "test": "echo \"Error: no test specified\" && exit 1",
  "build": "tsc --removeComments --module commonjs --target ES5 --outDir build src/server.ts",
  "start": "node ./build/server.js"
},
```

The `"scripts"` field of the `package.json` file define executable scripts npm can run
on your project. In the above snippet we defined two new scripts:

1. `"build"`: This will build our server code into an executable Javascript file.
2. `"start"`: This will run our server Javascript file using node.

Now we can run `npm run build` to build our code, then we can run `npm start` to start
our server. Try it out and make sure you see the 'Server is running on port 3000' message.

## Write the Chat Client ##

Now it's time for the hard part: the client. Now we get to actually try out all of the
cool frontend frameworks, and to start we will define what our Redux store will look like.

### Redux Store/Actions/Reducers ###

In the `src/` directory create a new `state.ts` file that looks like this:

```typescript
import { Message as MessageModel } from 'type-script-server/src/models';

export interface ChatState {
  messages: MessageModel[],
  users: string[]
}
```

Our application state is pretty straightforward. We just have a list of messages
(a list of objects implementing our Message interface we defined in the server) and
a list of users. Now that we have our Redux store, we need to figure out which actions
and reducers we will need. To figure this out, we need to decide what kinds of things
should trigger an update to our application state. For a chat app, the only things
that would cause our state to update is sending a message or a user signing in.

(**NOTE:** For our example the user list only ever stores the current user, it doesn't get updated when
other users sign in. I left it in there just so we could have multiple options, and we
could always add some code to our server that updates our user list when a new client
joins and just assigns them a unique ID or something.)

So we will have two actions: ADD_MESSAGE and ADD_USER.
In your `src/` directory make a new directory named `/actions`. In the new `actions/`
directory, make a new file called `index.ts` that looks like this:

```typescript
import { Message as MessageModel } from 'type-script-server/src/models';

export type Action = {
  type: 'ADD_MESSAGE',
  message: MessageModel
} | {
  type: 'ADD_USER',
  username: string,
  socket: WebSocket
}

export const addMessageAction = (message: MessageModel): Action => ({
  type: 'ADD_MESSAGE',
  message
});

export const addUserAction = (username: string, socket: WebSocket): Action => ({
  type: 'ADD_USER',
  username,
  socket
});
```

In this file we declared our own `Action` type that will have type `ADD_MESSAGE`
or `ADD_USER` as well as the fields we will need for executing those
actions (the message, socket, and username). We also defined two functions that
create our actions that will be used when we want to dispatch a given action to Redux.

Now that we have our actions, we can make our reducers. Reducers are how Redux handles
modifying your application state. Given some action, Redux will call your reducers to
get the updated version of the state (unchanged, or a copy of the state with a modification).
We are going to make our reducers in separate files, so make a new directory called `reducers/`
in your `src/` directory. First we will make a new file called `addMessage.ts` that
looks like this:

```typescript
import { Action } from '../actions';
import { ChatState } from '../state';

const initialState: ChatState = {
  messages: [],
  users: []
};

export function addMessage(state: ChatState = initialState, action: Action): ChatState {
  if (action.type === 'ADD_MESSAGE') {
    console.log("ADDING MESSAGE");
    return {
      messages: [ ...state.messages, action.message ],
      users: state.users
    };
  }

  return state;
}
```

Any Redux action will be handled to all of our reducers. So this guy is responsible
for checking if it is an action it cares about, and if so it makes the appropriate
modification. This reducer says when it finds the `ADD_MESSAGE` action, it should
modify our application state by adding a new message to our list of messages. Note
that we return a copy of the state, we don't directly modify the state.

Next we will create a file called `addUser.ts` that looks like this:

```typescript
import { Action } from '../actions';

import { Message as MessageModel, UserMessage } from 'type-script-server/src/models';
import { ChatState } from '../state';

const initialState: ChatState = {
  messages: [],
  users: []
};

export function addUser(state: ChatState = initialState, action: Action): ChatState {
  if (action.type === 'ADD_USER') {
    const joinedUserMessageObject: MessageModel = {
      name: action.username,
      message: "joined the chat"
    }
    const joinedUserMessage: MessageModel = new UserMessage(JSON.stringify(joinedUserMessageObject));
    action.socket.send(JSON.stringify(joinedUserMessage));
    return {
      messages: state.messages,
      users: [ ...state.users, action.username ]
    };
  }

  return state;
}
```

This is very similar to our `addMessage` reducer, it checks to see if this is the
`ADD_USER` action and it updates the state to have the new username. It does one extra
bit, it sends a message to our socket to notify everyone that a new user has joined,
hence the need for the socket in the `ADD_USER` action field.

### React/Redux Components ###

Now that we have our Redux store, actions, and reducers all sorted out, we can make
our React view components. First make a new `components/` directory. Our top level
component will be our app, so make a new `App.tsx` file (the `.tsx` extension is the
typescript version of the `.jsx` extension) that looks like this:

```typescript
import * as React from 'react';
import * as redux from 'redux';
import { connect } from 'react-redux';

import { Action, addUserAction } from '../actions';
import { ChatState } from '../state';

import { ChatApp } from './ChatApp';

const mapStateToProps = (state: ChatState, ownProps: OwnProps): ConnectedState => ({});

const mapDispatchToProps = (dispatch: redux.Dispatch<Action>): ConnectedDispatch => ({
  addUser: (username: string, socket: WebSocket) => {
    dispatch(addUserAction(username, socket));
  }
});

interface OwnProps {
  socket: WebSocket
}

interface ConnectedState {
}

interface ConnectedDispatch {
  addUser: (username: string, socket: WebSocket) => void
}

interface OwnState {
  username: string,
  submitted: boolean
}

export class AppComponent extends React.Component<ConnectedState & ConnectedDispatch & OwnProps, OwnState> {

  state = {
    username: '',
    submitted: false
  }

  usernameChangeHandler = (event: any) => {
    this.setState({ username: event.target.value });
  }

  usernameSubmitHandler = (event: any) => {
    event.preventDefault();
    this.setState({ submitted: true, username: this.state.username });
    this.props.addUser(this.state.username, this.props.socket);
  }

  render() {
    if (this.state.submitted) {
      // Form was submitted, now show the main App
      return (
        <ChatApp username={this.state.username} socket={this.props.socket} />
      );
    }
    return (
      <form onSubmit={this.usernameSubmitHandler} className="username-container">
        <h1>React Instant Chat</h1>
        <div>
          <input
            type="text"
            onChange={this.usernameChangeHandler}
            placeholder="Enter a username..."
            required />
        </div>
        <input type="submit" value="Submit" />
      </form>
    );
  }
}

export const App: React.ComponentClass<OwnProps> = connect(mapStateToProps, mapDispatchToProps)(AppComponent);
```

There is a lot of stuff going on in this component. To start, let's go over the interfaces
we created:

```typescript
interface OwnProps {
  socket: WebSocket
}

interface ConnectedState {
}

interface ConnectedDispatch {
  addUser: (username: string, socket: WebSocket) => void
}

interface OwnState {
  username: string,
  submitted: boolean
}
```

Here I'm defining what is handed to the React component, and what will be pulled
out of the Redux store and mapped to the component props. The `OwnProps` interface
shows that this component expects to be handed a WebSocket. The `ConnectedState` would
be any props that would be pulled directly out of the Redux store, in this case there
isn't anything we are pulling out of the store. The `ConnectedDispatch` interface
will map any of our action creators to the props of our component. So in this case
we are expecting to get an `addUser()` function that takes a username and a WebSocket.
Finally, the `OwnState` interface defines what the component state will be that isn't
pulled from our Redux store. This component will be keeping track of the current
username and whether or not the sign in form has been submitted in its state.

Now let's look at the two map functions:

```typescript
const mapStateToProps = (state: ChatState, ownProps: OwnProps): ConnectedState => ({});

const mapDispatchToProps = (dispatch: redux.Dispatch<Action>): ConnectedDispatch => ({
  addUser: (username: string, socket: WebSocket) => {
    dispatch(addUserAction(username, socket));
  }
});
```

These functions describe how we map the contents of the Redux store/dispatch functions
to our component. The `mapStateToProps()` function will map any field in the Redux store
into the given prop of our component. In this case we aren't pulling anything from the Redux
store. The `mapDispatchToProps()` function maps functions that will dispatch Redux
actions to props in our component. In this case, our component will get an `addUser` prop
that is a function that will dispatch our `ADD_USER` action and update our Redux store
using the `addUser` reducer.

Finally, let's look at the actual React component:

```typescript
export class AppComponent extends React.Component<ConnectedState & ConnectedDispatch & OwnProps, OwnState> {

  // Initialize the state
  state = {
    username: '',
    submitted: false
  }

  // Whenever the username field changes, store that in the component state so
  // we have an up to date copy when we submit the form
  usernameChangeHandler = (event: any) => {
    this.setState({ username: event.target.value });
  }

  // Whenever the username form is submitted, update the component state to say
  // it has been submitted (so we show the main app rather than the login page)
  // and fire the addUser() action to update our Redux store.
  usernameSubmitHandler = (event: any) => {
    event.preventDefault();
    this.setState({ submitted: true, username: this.state.username });
    this.props.addUser(this.state.username, this.props.socket);
  }

  render() {
    if (this.state.submitted) {
      // Form was submitted, now show the main App
      return (
        <ChatApp username={this.state.username} socket={this.props.socket} />
      );
    }
    return (
      <form onSubmit={this.usernameSubmitHandler} className="username-container">
        <h1>React Instant Chat</h1>
        <div>
          <input
            type="text"
            onChange={this.usernameChangeHandler}
            placeholder="Enter a username..."
            required />
        </div>
        <input type="submit" value="Submit" />
      </form>
    );
  }
}

export const App: React.ComponentClass<OwnProps> = connect(mapStateToProps, mapDispatchToProps)(AppComponent);
```

Notice our component extends the `React.Component` type, and we define the combination
of props pulled from Redux and the props for our component as our component props, and
the component state as our state. The rest is just our usual React component. To start
we will render a simple login page, then after the user has entered their name and
submitted the form we will show the actual app. The final line is how we actually
connect our app to the Redux store, and we specify the mapping functions.

Any component that needs to connect to the Redux store will look similar to this.
The next component we will make is the ChatApp, which is also connected to the Redux
store. Create a new file called `ChatApp.tsx` that looks like this:

```typescript
import * as React from 'react';
import * as redux from 'redux';
import { connect } from 'react-redux';

import { Message as MessageModel, UserMessage } from 'type-script-server/src/models';
import { ChatState } from '../state';
import { Action } from '../actions';

import { Messages } from './Messages';
import { ChatInput } from './ChatInput';

const mapStateToProps = (state: ChatState, ownProps: OwnProps): ConnectedState => ({
  messages: state.messages
});

const mapDispatchToProps = (dispatch: redux.Dispatch<Action>): ConnectedDispatch => ({});

interface OwnProps {
  socket: WebSocket,
  username: string
}

interface ConnectedState {
  messages: MessageModel[]
}

interface ConnectedDispatch {
}

interface OwnState {
}

export class ChatAppComponent extends React.Component<ConnectedState & ConnectedDispatch & OwnProps, OwnState> {

  sendHandler = (message: string) => {
    const messageObject: MessageModel = {
      name: this.props.username,
      message: message
    }
    this.props.socket.send(JSON.stringify(messageObject));
  }

  render() {
     return (
       <div className="container">
         <h3>React Chat App</h3>
         <Messages username={this.props.username} messages={this.props.messages} />
         <ChatInput onSend={this.sendHandler} />
       </div>
     );
   }
}

export const ChatApp: React.ComponentClass<OwnProps> = connect(mapStateToProps, mapDispatchToProps)(ChatAppComponent);
```

This component isn't dispatching any actions, but it is connecting to the Redux
store in order to pull the current list of messages out as a prop. It also defines
what to do when a user posts a message (just send it with our socket). Notice this
isn't dispatching our `addMessageAction`, we will see how that is handled later.

Now we just need to define our vanilla (non-Redux connected) React components. Create
a new file called `ChatInput.tsx` that looks like this:

```typescript
import * as React from 'react';

interface OwnProps {
  onSend: (UserMessage: string) => void
}

interface OwnState {
  chatInput: string
}

export class ChatInput extends React.Component<OwnProps, OwnState> {

  state = {
    chatInput: ''
  }

  textChangeHandler = (event: any) => {
    this.setState({ chatInput: event.target.value });
  }

  submitHandler = (event: any) => {
    // Stop the form from refreshing the page on submit
    event.preventDefault();

    // Call the onSend callback with the chatInput UserMessage
    this.props.onSend(this.state.chatInput);

    // Clear the input box
    this.setState({ chatInput: '' });
  }

  render() {
    return (
       <form className="chat-input" onSubmit={this.submitHandler}>
         <input type="text"
           onChange={this.textChangeHandler}
           value={this.state.chatInput}
           placeholder="Write a UserMessage..."
           required />
       </form>
    );
  }

}
```

This defines our actual chat input, which will store the current user message as
state and send it out whenever the user sends the message.

Next create a new file called `Messages.tsx` that looks like this:

```typescript
import * as React from 'react';

import { Message as MessageModel } from 'type-script-server/src/models';

import { Message } from './Message';

interface OwnProps {
  username: string,
  messages: MessageModel[]
}

interface OwnState {
}

export class Messages extends React.Component<OwnProps, OwnState> {

  componentDidUpdate() {
    // get the message list container and set the scrollTop to the height of the container
    const objDiv = document.getElementById('messageList');
    objDiv.scrollTop = objDiv.scrollHeight;
  }

  render() {
    // Loop through all the messages in the state and create a Message component
    const messages = this.props.messages.map((message: MessageModel, i) => {
        return (
          <Message
            key={i}
            username={message.name}
            message={message.message}
            fromMe={message.name === this.props.username} />
        );
      });

    return (
      <div className='messages' id='messageList'>
        { messages }
      </div>
    );
  }
}
```

This component handles rendering all of our messages and scrolling to the bottom
of the list every time a new message is added.

For our last component, create a new `Message.tsx` file that looks like this:

```typescript
import * as React from 'react';

interface OwnProps {
  key: number,
  username: string,
  message: string,
  fromMe: boolean
}

interface OwnState {
}

export class Message extends React.Component<OwnProps, OwnState> {

  render() {
    // Was the message sent by the current user. If so, add a css class
    const fromMe = this.props.fromMe ? 'from-me' : '';

    return (
      <div className={`message ${fromMe}`}>
        <div className='username'>
          { this.props.username }
        </div>
        <div className='message-body'>
          { this.props.message }
        </div>
      </div>
    );
  }
}
```

This simply renders a chat message, and marks if the message is from the current
user.

### Client Entry Point ###

We've defined everything we need for our app to work, now we need to hook everything
together. To do that we will make our actual entry point. In your `src/` directory
make a new file called `index.tsx` that looks like this:

```typescript
import * as React from 'react';
import * as ReactDOM from 'react-dom';
import { createStore, compose, Reducer } from 'redux';
import { Provider } from 'react-redux';
import { Action, addMessageAction } from './actions';
import { addMessage } from './reducers/addMessage';
import { addUser } from './reducers/addUser';
import { App } from './components/App';

import { UserMessage } from 'type-script-server/src/models';
import { ChatState } from './state';

const socket: WebSocket = new WebSocket("ws://localhost:3000");

// For every reducer in our list, send the given action
function combineReducers(...reducers: Reducer<ChatState>[]) {
  return (state: ChatState, action: Action) => {
    return reducers.reduce((previous: ChatState, next: Reducer<ChatState>) => next(previous, action), state);
  }
}

let store = createStore(combineReducers(addMessage, addUser), undefined, (window as any).__REDUX_DEVTOOLS_EXTENSION__ && (window as any).__REDUX_DEVTOOLS_EXTENSION__());

// Listen for messages from the server
socket.onmessage = (message: MessageEvent) => {
  // Whenever the server broadcasts a message, add it to our message list
  store.dispatch(addMessageAction(new UserMessage(message.data)));
};

// Render the app
ReactDOM.render(
  <Provider store={store}>
    <App socket={socket} />
  </Provider>,
  document.getElementById("app")
);
```

In order to hook everything together, we first need to actually make a connection
to our server. Thankfully WebSockets make that super simple, just one line. Next
we need to actually create our Redux store. To do that we pass three parameters: a
function to tell Redux how to delegate actions to our reducers (we just pass an action
to every reducer and they decide if they handle it or not), the initial state (undefined
here because our reducers handle making the initial state as a default parameter), and
the last parameter allows us to use the Redux dev tools in Chrome (which are some of
the coolest dev tools I've ever seen, I highly recommend using them). After creating
our store, we make sure that any time we get a message from our server we add the
new message to our Redux store so it will be rendered in our message list. We do that
by dispatching the `addMessageAction` which is handled by our `addMessage` reducer.
Finally, we use React to actually render our App. Notice we are using a special component
we pulled from react-redux called `Provider`. This is the component that will have
our Redux store in it, and it can provide anything from the store to any component
that needs it (any of our components that used the `connect()` function).

### Build and Render ###

Alright now we have all of our code, we need to actually render our app. In order
to do that, we will need an HTML page. In your project root directory (not the `src/` directory,
the directory above it) make a new file called `index.html` that looks like this:

```html
<html>
  <head>
    <title>Typescript Chat</title>
    <link href="https://maxcdn.bootstrapcdn.com/font-awesome/4.7.0/css/font-awesome.min.css" rel="stylesheet">
  </head>
  <body>
    <div id="app"></div>
    <script src="/build/client.js"></script>
  </body>
</html>
```

This includes our built client Javascript (our Webpack config has the output file set
to be `client.js`) and includes a div on the page that React will replace with our app.

Now let's add a script in NPM that will start a little server that will serve up our
client and also watch for any changes we make and deploy them. In the `package.json`
file, replace the `"scripts"` entry with this:

```
"scripts": {
  "test": "echo \"Error: no test specified\" && exit 1",
  "watch": "webpack-dev-server --compress --history-api-fallback --progress --host 0.0.0.0 --port 3005"
},
```

## Run the App ##

Finally we get to actually run our app. Go to your server project directory and
run `npm start`, this will start your server listening on port 3000. Now go to your
client project directory and run `npm run watch`, this will start a server that will
server your `index.html` page on port 3005 (it will also automatically update your
client if you make any code changes). Now go to http://localhost:3005 in your web
browser. You should see a very simple login page asking for your username. Enter
your username and submit. You should see this:

```text
<your username>
joined the chat
```

Now open a new tab and go to http://localhost:3005. Enter a new username and submit.
Now you're chatting! Enter a message in either tab and make sure it shows up in the
other tab. Now you can write some styles and make a good looking super simple chat app.

### Edit 05/10/2018 ###

Updated versions and made some fixes as pointed out by GitHub user [wildcart](https://github.com/wildcart) as 
seen in these [issues](https://github.com/nprice1/typeScriptChatClient/issues/2)
