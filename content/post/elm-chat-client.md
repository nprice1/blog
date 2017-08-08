+++
title = "Elm Chat Client for Typescript Chat Server"
date = "2017-08-04T10:54:24+02:00"
draft = false
+++
Since writing the Typescript chat server and client, I delved pretty deep into all of the fancy frontend frameworks and got to know 
them pretty well. They are fun to work in, but there is so much overhead involved, I started craving more similarity to my backend roots. 
I found some articles on Elm, and it peaked my interest. It looks so much like my favorite language (Haskell) that I wanted to try it out.
When I first read the articles, the barrier to entry seemed enormous. There was a HUGE tutorial page for getting even the simplest thing
to work in Elm. After a while, articles about using Elm in production started rolling in and the reviews weren't bad. So I decided to take
another look, and thankfully things had improved drastically. The documentation is clear and easy to follow, and I felt like I could get started
quickly. So I decided to rewrite the chat client in Elm.

## Setup ##

First you need to install Elm and all the fancy tools that come bundled with it. [This page](https://guide.elm-lang.org/install.html) was
extermely helpful in everything from installing Elm, to describing each of the command line tools, to describing the language itself. I highly
recommend taking a quick peek through all of the articles to get familiar with the language. After installing, let's write some code!

## Dependencies ##

Dependency management for Elm relies on the `elm-package.json` file. This file can be updated manually or using the awesome `elm-package` dependency
management tool. Here is what my `elm-package.json` looks like:

```json
{
    "version": "1.0.0",
    "summary": "Chat Client",
    "repository": "https://github.com/nprice1/elmChatClient.git",
    "license": "BSD3",
    "source-directories": [
        "."
    ],
    "exposed-modules": [],
    "dependencies": {
        "elm-lang/core": "5.1.1 <= v < 6.0.0",
        "elm-lang/html": "2.0.0 <= v < 3.0.0",
        "elm-lang/websocket": "1.0.2 <= v < 2.0.0"
    },
    "elm-version": "0.18.0 <= v < 0.19.0"
}

```

This should look very familiar for anybody who has looked at an npm `package.json` file. It shows the dependencies and all versions for those
dependencies. Add this file to the root of your project. Run `elm-package install` to make sure all the packages are properly installed.

## The Code ##

Now we can get down to actually writing the code. The [Elm Guide Architecture](https://guide.elm-lang.org/install.html) page provides a very helpful
blueprint for all Elm code that looks like this:

```elm
import Html exposing (..)


-- MODEL

type alias Model = { ... }


-- UPDATE

type Msg = Reset | ...

update : Msg -> Model -> Model
update msg model =
  case msg of
    Reset -> ...
    ...


-- VIEW

view : Model -> Html Msg
view model =
  ...
```

All we need to do is fill in the gaps. The Elm architecture enforces the non-mutatable state ideas that are suggested by the Redux state management pattern. 
This means we can make some pretty direct comparisons to the original [TypeScript Client](https://github.com/nprice1/typeScriptChatClient). The Model will be 
our Redux state, the Update will be our Reducers, and the View will be our React components. So let's start filling in this skeleton.

## Imports ##

First let's import all the libraries we will need. First we import everything we need for our view:

```elm
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onInput, onClick)
```

The `Html` package gives us all of the HTML elements we need in order to actually render our view (div's, span's, input, etc.). The `Html.Attributes` package
gives us the attributes we need for any of our view elements (like class, value, etc.). We actually only need `value`, but I'm just pulling in everything. 
We also need some events that we will be firing. For this app we only use text fields and buttons, so we only need the `onClick` and `onInput` events.  

This app will be using Websockets, so we need to make sure to pull that in:

```elm
import WebSocket
```

Finally, we will be dealing with JSON payloads sent to/received from the server, so we need the JSON libraries from Elm to both encode and decode our messages:

```elm
import Json.Decode exposing (..)
import Json.Encode exposing (..)
```

As an extra bonus I also imported the Debug package to make sure I could log to the console in case anything fails:

```elm
import Debug exposing (..)
```

Now that we have all of our imports, we can move on to figuring out what our application state will look like.

## Model ##

The Model will represent our application state. Since we already did this when writing the TypeScript client, let's look at what we did there:

```typescript
import { Message as MessageModel } from 'type-script-server/src/models';

export interface ChatState {
  messages: MessageModel[],
  users: string[]
}
```

Our application state was pretty simple, we kept track of the current users (well really it was just the current user), and all of the messages that have
been sent. We also had a type representing what our Message would look like:

```typescript
export interface Message {
 name: string;
 message: string;
}
```

Since we already have these defined, let's just move them over to Elm. First we will create a type to represent a message:

```elm
type alias Message = {
  name : String,
  message : String
}
```

Very straightforward conversion thankfully. Converting the Redux state to our application state is a tiny bit more complicated, though. In our
React/Redux application, some of our components had their own internal state (like the current values in a text field) that we now have to keep
track of in our core application state. Elm may have a way of separating this out, but since I'm just starting out I'm keeping it all in
the same place. So here is our consolidated state:

```elm
type alias Model = { 
  currentUserName: String,
  currentMessage: String,
  users : List String,
  messages : List Message
}
``` 

The `currentUserName` and `currentMessage` are going to keep track of the current data in text fields, and then we have the users and message list like the React/Redux state.

The Elm application expects an `init` function that provides the inital Model and the command to run. Our init funciton is pretty simple:

```elm
init : (Model, Cmd Msg)
init =
  (Model "" "" [] [], Cmd.none)
```

We provide a model with no username, no message, empty user list, and empty message list. We are also providing no command, because nothing needs to be done to init.

That's it for the model, now we need to define how that model will be updated.

## Updates ##

In our React/Redux application, our reducers handled the state updates. We had two reducers, one for adding users and one for adding messages. 
Since our application state is a bit more complicated, we will need a few more. To start, we define the Elm messages that we expect to receive:

```elm
type Msg = 
  UpdateUserName String | 
  UpdateMessage String |
  NewUser | 
  SendMessage |
  ReceiveMessage String
```

Here is the summary for each of these messages:  

1. **UpdateUserName**: This replaces the React view that maintained its own state about the current user name for the login form. This updates the current user name. The parameter passed for this update is the new user name.
2. **UpdateMessage**: Like the UpdateUserName, this replaces the React view state that kept track of the current message before sending it. This updates the current message. The parameter passed to this message is the new message.
3. **NewUser**: This logins a user and updates the user list. Right now this is only fired when the current user logs in, not when other users login. This takes the place of the `ADD_USER` reducer. There is no parameter passed for this message, it uses data from the model.
4. **SendMessage**: Fired when the user sends a message. This will use the currentMessage state and send it using the Websocket. In our React/Redux application this was handled by a React component. No parameter is passed for this message, it uses data from the model.
5. **ReceiveMessage**: This is fired when we recieve a message from the WebSocket and we add it to the current list of messages. This takes the place of the `ADD_MESSAGE` reducer. The parameter passed to this message is the stringified JSON payload from the server.

### JSON Decoding/Encoding ###

All of this work hinges on something that it turns out is not as trivial as I was hoping in Elm: JSON parsing. Handling JSON in Elm relies
on decoding (JSON to an Elm type) and encoding (Elm type to JSON), so we need to setup some helper methods to do that. First we will define the decoder:

```elm
messageDecoder : Decoder Message
messageDecoder = map2 Message (field "name" Json.Decode.string) (field "message" Json.Decode.string)
```

This function is used to create an Elm `Decoder` which can be passed a parameter and turn it into a given Elm type. This decoder says that when handed the 
parameter it is expecting a field called `"name"` which is a string, and a field called `"message"` which is a string and it constructs a Message with those two values.
Now that we have the `Decoder`, we can make a function that takes stringified JSON and turns it into a message like so:

```elm
jsonToMessage : String -> Message 
jsonToMessage messageJson =
  case decodeString messageDecoder messageJson of
    Ok message -> message

    Err err -> 
      Debug.log ("Failed to decode message" ++ err)
      (Message "" "")
```

This function takes in stringified JSON we get from the chat server and uses the Elm `decodeString` function which uses the decoder we created above to finally spit out a `Message`.
We also get our first glimpse into some Elm error handling. The `decodeString` function returns a `Result`, which will either be `Ok` with the result, or `Err` with an error message.
We are doing some very basic error handling here, logging if it failed and returning an empty message.

Next we need to define our encoder:

```elm
messageEncoder : Message -> Json.Encode.Value
messageEncoder message =
    Json.Encode.object [ ("name", Json.Encode.string message.name), ("message", Json.Encode.string message.message) ]
```

This encoder takes in a `Message` and tells Elm how to create a JSON object out of it. The result of the encoder is always a `Json.Encode.Value`, which can be various things.
In this case we want a JSON object with a string field `"name"` and a string field `"message"`. Now that we have an encoder function we can create a helper function to get us our JSON:

```elm
messageToJson : Message -> String
messageToJson message =
  encode 4 (messageEncoder message)
```

This function just uses the Elm `encode` function and uses 4 space indentation for the resulting JSON string.

Now we have everything we need to write our actual Update function:

```elm
update : Msg -> Model -> (Model, Cmd Msg)
update msg {currentUserName, currentMessage, users, messages} =
  case msg of
    UpdateUserName newUserName -> (Model newUserName currentMessage users messages, Cmd.none)

    UpdateMessage newMessage -> (Model currentUserName newMessage users messages, Cmd.none)

    NewUser -> (Model currentUserName currentMessage (currentUserName :: users) messages, WebSocket.send webSocketAddress (createUserMessageJson "joined the chat" currentUserName))

    SendMessage -> (Model currentUserName "" users messages, WebSocket.send webSocketAddress (createUserMessageJson currentMessage currentUserName))

    ReceiveMessage userMessage -> (Model currentUserName currentMessage users (jsonToMessage userMessage :: messages), Cmd.none)
```

The `update` function takes in the `Msg` that was fired and the current `Model` for our application. We MUST handle all of the messages we have defined or else the compiler will complain. 
The result of the update function is the updated `Model` and any `Cmd` that needs to be run. The only `Cmd` we have is sending our messages using the Websocket. Here is an explanation for
each of the modifications we make for the messages:

1. **UpdateUserName**: We get handed the new user name as the user types it in the text box, and we update the model with a new `currentUserName`. No commands is required.
2. **UpdateMessage**: Like the UpdateUserName, this updates the `currentMessage` and leaves everything else unchanged. No command is required.
3. **NewUser**: When we receive this message we add the current user (pulled from the `currentUserName`) to our list of users, and now we actually need to use a command. When a user joins
the chat we need to send a message to the server. So, we use the `WebSocket.send` function and our `createUserMessageJson` helper function defined above to send our JSON payload for a user
joining the chat.
4. **SendMessage**: First we reset the `currentMessage` field to reset the text input, and we send the JSON payload with the current message (before being erased).
5. **ReceiveMessage**: Whenever we receive a message from the server, we first convert it to a `Message` using our decoding helper function, then we add it to our `messages` list.

**NOTE:** The `{...}` syntax is used to spread values for a type, so we are just expanding the `Model` object into individual parameters.
We also have a `webSocketAddress` constant defined here, you can see that value in the full code below.

## Subscriptions (WebSocket) ##

We have one way of firing a message from outside of our View, and that is the WebSocket. To make sure we catch when messages are sent we need to create
a subscription for our WebSocket, which just fires a `Msg` whenever something is received from the server:

```elm
subscriptions : Model -> Sub Msg
subscriptions model =
  WebSocket.listen webSocketAddress ReceiveMessage
```

I don't pretend to fully understand this model, but my best guess is Elm allows subsriptions for certain events to fire `Msg's`. This one is telling Elm
that whenever you receive a message from the given WebSocket, fire the `ReceiveMessage` message. The other way to fire `Msg's` is to use the view.

## View ##

Time to setup user interaction and actually rendering our app. Our view is very easy in this case:

```elm
view : Model -> Html Msg
view model =
  case model.users of
    [] ->
      div []
        [ 
          input [ type_ "text", placeholder "User Name", onInput UpdateUserName, Html.Attributes.value model.currentUserName ] [],
          button [ onClick NewUser ] [ text "Login" ]
        ]
    _  ->
      div []
        [ 
          input [ type_ "text", placeholder "Message", onInput UpdateMessage, Html.Attributes.value model.currentMessage ] [],
          button [ onClick SendMessage ] [ text "Send Message" ],
          div [] (List.map viewMessage (List.reverse model.messages))
        ]

viewMessage : Message -> Html msg
viewMessage msg =
  div [] [ text (msg.name ++ ": " ++ msg.message) ]
```

We have two views here, one when we don't have any users and one where we do. When we don't have users we show a simple login form that
updates the current user name in the model and a button that sends the `NewUser` message. After the user logs in we see a simple message form
with a div underneath that displays all of the messages. Each HTML element in Elm has two arrays associated with them. The first array are the 
attributes, and the second is the content. Most of what we are doing here is related to attributes, the important ones being what we are using 
for the `onInput`, `onClick`, and `Html.Attributes.value` entries. The `onInput` and `onClick` attributes both point to a `Msg` that will be fired
with the event. As a user inputs into the text box for the login form, for example, the `UpdateUserName` `Msg` will be fired with the current value
in the text box, allowing us to keep track of the current username with all input. Then, the `onClick` for our button will send the `NewUser` `Msg` 
that sends the message to the server informing a user has logged in. The `Html.Attributes.value` points to the value in the model so that when we 
update the model (like clearing out the current message), it is reflected in the View.

## Putting it All Together ##

The last thing we need to do is tell Elm all of the pieces of our application. We do that with a `Program` that describes the model, view, updates, and subscriptions.
Here is what our `Program` looks like:

```elm
main : Program Never Model Msg
main =
  Html.program
    { 
      init = init, 
      view = view, 
      update = update, 
      subscriptions = subscriptions
    }
```

Each of these values correspond to what we added throughout this tutorial. Here is our full source code:

```elm
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onInput, onClick)
import WebSocket
import Json.Decode exposing (..)
import Json.Encode exposing (..)
import Debug exposing (..)

webSocketAddress : String
webSocketAddress = "ws://localhost:3000"

main : Program Never Model Msg
main =
  Html.program
    { 
      init = init, 
      view = view, 
      update = update, 
      subscriptions = subscriptions
    }


-- MODEL

type alias Message = {
  name : String,
  message : String
}

type alias Model = { 
  currentUserName: String,
  currentMessage: String,
  users : List String,
  messages : List Message
}

init : (Model, Cmd Msg)
init =
  (Model "" "" [] [], Cmd.none)


-- UPDATE

type Msg = 
  UpdateUserName String | 
  UpdateMessage String |
  NewUser | 
  SendMessage |
  ReceiveMessage String

update : Msg -> Model -> (Model, Cmd Msg)
update msg {currentUserName, currentMessage, users, messages} =
  case msg of
    UpdateUserName newUserName -> (Model newUserName currentMessage users messages, Cmd.none)

    UpdateMessage newMessage -> (Model currentUserName newMessage users messages, Cmd.none)

    NewUser -> (Model currentUserName currentMessage (currentUserName :: users) messages, WebSocket.send webSocketAddress (createUserMessageJson "joined the chat" currentUserName))

    SendMessage -> (Model currentUserName "" users messages, WebSocket.send webSocketAddress (createUserMessageJson currentMessage currentUserName))

    ReceiveMessage userMessage -> (Model currentUserName currentMessage users (jsonToMessage userMessage :: messages), Cmd.none)

createUserMessageJson : String -> String -> String
createUserMessageJson message currentUserName =
  messageToJson (Message currentUserName message)

messageDecoder : Decoder Message
messageDecoder = map2 Message (field "name" Json.Decode.string) (field "message" Json.Decode.string)

messageEncoder : Message -> Json.Encode.Value
messageEncoder message =
    Json.Encode.object [ ("name", Json.Encode.string message.name), ("message", Json.Encode.string message.message) ]

jsonToMessage : String -> Message 
jsonToMessage messageJson =
  case decodeString messageDecoder messageJson of
    Ok message -> message

    Err err -> 
      Debug.log ("Failed to decode message" ++ err)
      (Message "" "")

messageToJson : Message -> String
messageToJson message =
  encode 4 (messageEncoder message)


-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
  WebSocket.listen webSocketAddress ReceiveMessage


-- VIEW

view : Model -> Html Msg
view model =
  case model.users of
    [] ->
      div []
        [ 
          input [ type_ "text", placeholder "User Name", onInput UpdateUserName, Html.Attributes.value model.currentUserName ] [],
          button [ onClick NewUser ] [ text "Login" ]
        ]
    _  ->
      div []
        [ 
          input [ type_ "text", placeholder "Message", onInput UpdateMessage, Html.Attributes.value model.currentMessage ] [],
          button [ onClick SendMessage ] [ text "Send Message" ],
          div [] (List.map viewMessage (List.reverse model.messages))
        ]

viewMessage : Message -> Html msg
viewMessage msg =
  div [] [ text (msg.name ++ ": " ++ msg.message) ]
```

Now we can finally run it.

## Running the Client ##

In order to run this, you need to have the [TypeScript Chat Server](https://github.com/nprice1/typeScriptChatServer) installed and running. 
Next, in the directory with your Elm Chat Client you can run `elm-reactor`. This will start a web server listening on port 8000. 
So when you visit http://localhost:8000/App.elm you should see an input field and a button (the login form). After entering a username and logging in, 
you should see a similar form that allows inputting messages. You can open a new tab in your browser at the same address and start chatting.

## Improvements ##

This chat client is pretty bare bones, shocking I know. There are a ton of things that can be done to improve how it works, but here are the things
that jump out the most in my mind.

1. **UI**: The chat app looks like an MIT professors blog, bare bones HTML. Add some CSS to make it look like an actual application.
2. **User List**: Our user list state is meant to keep track of all users currently logged in, but right now it only tracks the current user. Getting this
to actually keep track of users would be a nice touch. You can parse the nasty `"joined the chat"` message to get the user name, but
the preferred approach would be to have the WebSocket send different messages for logging in and sending messages. If you wanted the real list of users,
you would also need some persistence in the server.
3. **Separate the State**: A nice benefit of our React/Redux application was different React components can maintain there own state without polluting the 
core application state. Right now the `currentUserName` and `currentMessage` fields are cruft we hopefully don't need to have in our core model. Elm 
hopefully supports breaking the state into individual pieces, otherwise the state would get bonkers pretty fast.

## Conclusion ##

All in all I really enjoyed writing this. Elm is a pleasant language and I can't help but love anything that takes some ideals from Haskell. The
architecture makes sense, and I love when programs can enforce "good" practices since I can safely admit that I, as a human programmer, can be super
dumb sometimes. However, I do have two small complaints, both of which would only really be a problem at scale and may already have solutions I am 
unaware of:

1. JSON Handling is Annoying. We are dealing with very simple JSON objects here and it is already getting bloated, I can't imagine what it would look like
with large nested JSON objects.
2. Views could get gnarly. With large complex views, I'm not sure how readable or maintainable this representation of HTML will be. As long as you can 
modularize the view easily it wouldn't be so bad, but this is just asking for mega 1000 line don't-look-directly-at-it-you'll-go-blind views.

In case it wasn't obvious I am far from an expert on Elm and I make some assumptions in this post. If you notice anything incorrect please let me know
in the comments!