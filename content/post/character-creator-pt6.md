+++
subtitle = "Apollo and Hooks"
title = "Let's Make A DnD Character: Part 6"
date = "2022-05-06T15:54:24+02:00"
draft = false
series = ["Let's Make a DnD Character"]
tags = ["dnd", "graphql", "react", "hooks", "apollo"]
+++

The GraphQL API isn't very cool without actually seeing the data in action, so it's time to implement the client. In the same
spirit of my [Part 5](/post/character-creator-pt5/) post where I just overloaded my Java app to run both a REST and GraphQL 
api, I'm going to overload my client to support both. I have written a bunch of business logic around rendering this stuff, 
so I don't want to have to rebuild all of that. Instead I will use the power of [React Hooks](https://reactjs.org/docs/hooks-intro.html)
so that my component can just blindly grab the data it needs and I can switch out the client. 

# Switching Clients

I want to be able to switch which client is being used without having to reload or pass some kind of build parameter. The downside of 
this is that I will be loading a lot more data than I might actually need, but I don't mind that right now. So I'm going to make a 
button in the app that allows the user to switch which client is being used. To do that, I am going to make my top level `App` 
component be stateful and track which client we are using:

```typescript
type State = {
  useApollo: boolean;
}

const App = () => {
  const [state, setData] = React.useState<State>({
      useApollo: true,
  });

  return (
    <div className="App">
      <div className="client-selector">
        <button onClick={() => setData({useApollo: true})}>Use Apollo</button>
        <button onClick={() => setData({useApollo: false})}>Use REST</button>
      </div>
      <CharacterInfoComponent useApollo={state.useApollo} />
    </div>
  );
}
```

It looks super ugly and I love it so I'm keeping it. Notice this also required me to add a new prop to my `CharacterInfoComponent` to 
track which client is being used. I was hoping to allow my `CharacterInfoComponent` to ignore everything about it, but I also didn't 
want to spend too much time on it so I figured this was a good compromise. It just means my hook that I will create needs to know if
we are using Apollo or not. 

# Custom Hook

Now onto the good stuff, making a custom hook. The hook will handle fetching the data our `CharacterInfoComponent` needs to do its job, 
as well as managing the state of fetching that data (like if it loading, or ran into an error). Then we have centralized business logic,
and the state can be managed in the hook rather than our components having to share state. So I created a `useCharacterInfo.tsx` file 
for my new hook. To actually start writing it, though, I need to install Apollo and get a client setup.

## Setting Up Apollo

This was super easy, I just needed to install the tools:

```bash
npm install @apollo/client graphql
```

Then in my `useCharacterInfo.tsx` file I can do this:

```typescript
import {
    ApolloClient,
    InMemoryCache,
    gql,
} from "@apollo/client";
  
const apolloClient = new ApolloClient({
    uri: 'http://localhost:8080/graphql',
    cache: new InMemoryCache()
});
```

We also need to define the query we want to use, and this part still sucks. I really dislike having to provide every single field in the
query, but here it is:

```typescript
const QUERY = gql`
    query {
        newCharacter {
            name
            race
            characterClass
            background
            alignment
            speed
            hitDice
            skills
            proficiencies
            proficiencyModifier
            strength {
                base
                modifier
                proficient
            }
            dexterity {
                base
                modifier
                proficient
            }
            intelligence {
                base
                modifier
                proficient
            }
            wisdom {
                base
                modifier
                proficient
            }
            constitution {
                base
                modifier
                proficient
            }
            charisma {
                base
                modifier
                proficient
            }
            languages
            feature {
                name
                description
            }
            ideals
            traits
            flaws
            bonds
            equipment {
                name
                quantity
            }
            spriteSheet
        }
    }
`;
```

Gross. But hey, this allows us to make fancy requests where we only grab the data we wanted, so I'll shut up about it. For now. Mostly.

## Make The Hook

Now we can actually start writing the hook logic. First we need to define what data we are going to return, so I just went with what the
cool Apollo `useQuery` hook uses:

```typescript
export type HookResponse = {
    loading: boolean;
    error?: Error;
    characterInfo?: CharacterInfo;
};
```

The purpose of this hook is to centralize state management and business logic, so I'll use the `React.useState` hook to maintain this
state in a single place:

```typescript
export const useCharacterInfo = (useApollo: boolean): HookResponse => {
    const [state, setData] = React.useState<HookResponse>({
        loading: true,
    });

    React.useEffect(() => {
        // This is where we can actually do our business logic
    }, [useApollo]);

    return {
        loading: state.loading,
        error: state.error,
        characterInfo: state.characterInfo,
    };
};
```

Now our hook will only rerender when the `useApollo` value passed in changes, which is cool. To implement our actual business logic, we
need to define a method for retrieving the `CharacterInfo` model with our OpenAPI client and our Apollo client:

```typescript
type NewCharacterResponse = {
    newCharacter: CharacterInfo;
}

const getInfoApollo = async (): Promise<CharacterInfo> => {
    return (await apolloClient.query<NewCharacterResponse>({ query: QUERY, fetchPolicy: 'no-cache'})).data.newCharacter;
};

const getInfoRest = async (): Promise<CharacterInfo> => {
    return await InfoService.getInfo();
};
```

I'm using the `no-cache` fetch policy here because if I don't, Apollo will attempt to be helpful and just reuse the same response it 
got last time since my query isn't actually changing. Which normally would be great, but not for this case. 

Now that we have the business logic setup, I can fully flesh out my hook:

```typescript
export const useCharacterInfo = (useApollo: boolean): HookResponse => {
    const [state, setData] = React.useState<HookResponse>({
        loading: true,
    });

    React.useEffect(() => {
        (async () => {
            try {
                let characterInfo: CharacterInfo;
                if (useApollo) {
                    characterInfo = await getInfoApollo();
                } else {
                    characterInfo = await getInfoRest();
                }
                setData({
                    loading: false,
                    characterInfo,
                });
            } catch (e) {
                setData({
                    loading: false,
                    error: e as Error,
                });
            }
        })();
    }, [useApollo]);

    return {
        loading: state.loading,
        error: state.error,
        characterInfo: state.characterInfo,
    };
};
```

That was super easy and I love it. And using it is even easier:

```typescript
const CharacterInfoComponent = ({ useApollo }: Props) => {
    const { loading, error, characterInfo } = useCharacterInfo(useApollo);

    ...existing business logic for rendering stuff
}
```

And... that's it. That was a lot easier than I was expecting, and now we can leverage the power of GraphQL to fetch only the data we actually
need with a huge performance benefit (as long as the backend is implemented correctly).

