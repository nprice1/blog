+++
subtitle = "GraphQL in Java"
title = "Let's Make A DnD Character: Part 5"
date = "2022-05-05T15:54:24+02:00"
draft = false
series = ["Let's Make a DnD Character"]
tags = ["dnd", "graphql", "java"]
+++

Time to play around with the first bit of new tech: GraphQL. Since I have all of the character creator logic already written in my
Spring Boot Java app, I figured I will just expand on that and see how hard it would be to migrate a REST API to a GraphQL one. 
The first step for all of my API work is the spec.

# GraphQL Spec

We already made a swagger spec in [Part 1](/post/character-creator.html), so most of the work is already done here. We need to define
two endpoints: one for getting the character info and one for getting the sprite sheet. On top of that, we need our data models in the
spec as well. Since I already went through the data models in part 1 I'll just skip that part and provide the GraphQL version of our 
models now:

```
type CharacterInfo {
    name: String
    race: String
    characterClass: String
    background: String
    alignment: String
    strength: AbilityScore
    dexterity: AbilityScore
    intelligence: AbilityScore
    wisdom: AbilityScore
    constitution: AbilityScore
    charisma: AbilityScore
    proficiencyModifier: Int
    skills: [String]
    proficiencies: [String]
    languages: [String]
    equipment: [Equipment]
    speed: String
    hitDice: Int
    feature: Feature
    traits: [String]
    ideals: [String]
    bonds: [String]
    flaws: [String]
}

type AbilityScore {
    base: Int
    modifier: Int
    proficient: Boolean
}

type Equipment {
    name: String
    quantity: Int
}

type Feature {
    name: String
    description: [String]
}
```


Not much changed here, but I did change the `class` property to be `characterClass` to avoid confusion with the built in Java 
`getClass()` method. Now the more interesting part, the queries.

In my original swagger spec I had a simple GET endpoint that would dynamically build a character, so that query is easy:


```
type Query {
  newCharacter: CharacterInfo
}
```


The one I ran into issues with was the sprite sheet. In my original spec I was lazy and just provided the entire `CharacterInfo` model
even though we only needed a small subset of that. Since GraphQL requires 
[Input Types](https://graphql.org/graphql-js/mutations-and-input-types/), that would be super redundant and annoying. So instead I 
narrowed down the parameters to be just what I actually needed: the list of equipment and the character's race:

```
type Query {
  newCharacter: CharacterInfo
  sprites(equipmentNames: [String]!, race: String): String
}
```

Put it all together, and we have a working GraphQL spec. Now onto the Spring automagic.

# Spring Boot GraphQL Setup

I am just going to reuse my existing Spring Boot app, and add a new `/graphql` route to handle all the new fanciness. In order to do
that, I am going to use the [GraphQL Spring Boot Starter](https://github.com/graphql-java-kickstart/graphql-spring-boot) which handles a
lot of boilerplate. 

## Update pom.xml

First we need to add the new dependencies. When doing research for which dependencies to add, I started getting annoyed with the variety
of mismatched dependencies from my first pass at this project and what is available now, so I also updated my base version of Spring 
Boot and removed the Spring Fox dependency since it was causing some issues I didn't want to deal with right now. On top of that I 
wanted to play around with the [Spring Boot Actuator](https://spring.io/guides/gs/actuator-service/) to get some performance metrics
outside of what I'm going to get with Istio. Here is the full updated pom with the new GraphQL dependency included:

```xml
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.nolanprice</groupId>
    <artifactId>character-creator</artifactId>
    <packaging>jar</packaging>
    <name>character-creator</name>
    <version>1.0.0</version>
    <properties>
        <java.version>1.11</java.version>
        <maven.compiler.source>${java.version}</maven.compiler.source>
        <maven.compiler.target>${java.version}</maven.compiler.target>
    </properties>
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>2.6.7</version>
    </parent>
    <build>
        <sourceDirectory>src/main/java</sourceDirectory>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <executions>
                    <execution>
                        <goals>
                            <goal>repackage</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <configuration>
                    <source>11</source>
                    <target>11</target>
                </configuration>
            </plugin>
        </plugins>
    </build>
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.data</groupId>
            <artifactId>spring-data-commons</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-websocket</artifactId>
        </dependency>
        <dependency>
            <groupId>com.graphql-java-kickstart</groupId>
            <artifactId>graphql-spring-boot-starter</artifactId>
            <version>12.0.0</version>
        </dependency>
        <dependency>
            <groupId>javax.xml.bind</groupId>
            <artifactId>jaxb-api</artifactId>
            <version>2.3.1</version>
        </dependency>
        <dependency>
            <groupId>com.fasterxml.jackson.datatype</groupId>
            <artifactId>jackson-datatype-jsr310</artifactId>
        </dependency>
        <dependency>
            <groupId>org.openapitools</groupId>
            <artifactId>jackson-databind-nullable</artifactId>
            <version>0.2.1</version>
        </dependency>
    <!-- Bean Validation API support -->
        <dependency>
            <groupId>javax.validation</groupId>
            <artifactId>validation-api</artifactId>
        </dependency>
        <dependency>
            <groupId>com.fasterxml.jackson.core</groupId>
            <artifactId>jackson-databind</artifactId>
        </dependency>
    </dependencies>
</project>
```

Now onto the next automagic portion: configuration.

## Application Config

Since I'm updating the base Spring Boot stuff, I decided to also switch to a YAML configuration file. So I renamed my 
`application.properties` file to be `application.yml`, and I converted the existing settings to the new format:

```yaml
spring:
  application:
    name: java-character-creator
  main:
    allow-bean-definition-overriding: true
  jackson:
    date-format: com.nolanprice.RFC3339DateFormat
    serialization:
      WRITE_DATES_AS_TIMESTAMPS: false

server:
  port: 8080
```

Since I added the cool new Spring Actuator endpoints, I need to set those up as well:

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics
```

Now I want to enable GraphQL, and I also want to enable 
[Playground](https://www.apollographql.com/docs/apollo-server/v2/testing/graphql-playground/) to interact with the API. I also turned
on [Voyager](https://github.com/APIs-guru/graphql-voyager) for funsies:

```yaml
graphql:
  servlet:
    actuator-metrics: true
    async:
      timeout: 5000
  playground:
    enabled: true
    cdn:
      enabled: false
      version: latest
  voyager:
    enabled: true
```

Now onto actually writing some damn code.

# Writing Some Damn Code

In order for my new GraphQL schema to mean anything at all, I need to add it to the classpath so the GraphQL Spring Boot Starter can
find it. So I created a `schema.graphqls` file in my `src/main/resources` folder. By default, the GraphQL starter will scan the 
classpath for all schema files and use those when compiling all of the query resolvers. 

Speaking of Query Resolvers, its time to make some of those. I have two queries: one to fetch the character info and another for 
the sprite sheet. In order to register our query handlers, we need to implement the `GraphQLQueryResolver` for both of our queries.
That's easy enough since I already built all the logic to grab that data. First we implement the character info resolver in a new 
`graphql` package:

```java
@Component
public class CharacterInfoResolver implements GraphQLQueryResolver {

    private final CharacterInfoFactory characterInfoFactory;

    @Autowired
    public CharacterInfoResolver(CharacterInfoFactory characterInfoFactory) {
        this.characterInfoFactory = characterInfoFactory;
    }

    public CompletableFuture<CharacterInfo> newCharacter() {
        return CompletableFuture.supplyAsync(characterInfoFactory::createCharacterInfo);
    }
}
```

Notice the `newCharacter()` method matches the name in our GraphQL schema file. If it doesn't, then the app will fail to launch since
all queries need a resolver. Then we do something similar for our sprite query:

```java
@Component
public class SpriteResolver implements GraphQLQueryResolver {

    private final SpriteBuilder spriteBuilder;

    @Autowired
    public SpriteResolver(SpriteBuilder spriteBuilder) {
        this.spriteBuilder = spriteBuilder;
    }

    public CompletableFuture<byte[]> sprites(List<String> equipment, String race) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return spriteBuilder.buildSpriteSheet(equipment, race);
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        });
    }
}
```

The parameters for the GraphQL query will be automatically supplied based on the name, so that's all we need.

That's it for the code. That's pretty sweet. 

# GraphQL Playground

Now I want to see the API actually working. To do that, I just start the app and go to `http://localhost:8080/playground` to load 
the GraphQL playground for my server. It provides a bunch of help when interacting with the API. The first thing I want to do is
generate my first character. To do that, I need to execute my `newCharacter` query. Should be easy enough, I just enter this as my 
query:

```
query {
    newCharacter
}
```

Except that doesn't work. Apparently GraphQL queries require specifying every field you want to query, which makes sense since that is
the main thing GraphQL is known for. For this use case though it really sucks, because I need to do this to get a full character:

```
query {
  newCharacter{
    name
    race
    characterClass
    background
    alignment
    strength {
      modifier
      base
      proficient
    }
    dexterity {
      modifier
      base
      proficient
    }
    intelligence {
      modifier
      base
      proficient
    }
    wisdom {
      modifier
      base
      proficient
    }
    constitution {
      modifier
      base
      proficient
    }
    charisma {
      modifier
      base
      proficient
    }
    proficiencies
    proficiencyModifier
    languages
    equipment {
     	name
    	quantity
    }
    speed
    hitDice
    feature {
      name
      description
    }
    traits
    ideals
    bonds
    flaws
  }
}
```

That's... a lot. There is a fancy trick where you can use introspection to fetch all of the fields for a given model, then you 
can perform a second query using that. That would require doing a query like this:

```
{
   __type(name:"CharacterInfo") {
      fields {
         name
      }  
   }
}
```

Then loop through the results and make a follow up query. That is not super fun, but hey that is just because I'm used to the REST API
method of getting huge objects. So how about I lean more into the GraphQL way of doing things?

# Field Specific Data Resolvers

Every field of a model object in GraphQL requires a data resolver. By default, it just uses the `get` method on the Java model if it is 
available, so we got all of that for free by providing a full `CharacterInfo` model in our implementation. But, that means if someone 
only wants to grab a small piece of the character info, they have to wait for everything to resolve. Which sucks. So instead, let's make some field specific resolvers to speed things up and remove redundancy when all you want is a subset of the info.

First we will rename the query resolver, since it will no longer be responsible for generating an entire CharacterInfo object. Instead
we can call it `NewCharacterResolver` since that is what it is actually responsible for. Here is the new resolver:

```java
@Component
public class NewCharacterResolver implements GraphQLQueryResolver {

    private final CharacterInfoFactory characterInfoFactory;

    @Autowired
    public NewCharacterResolver(CharacterInfoFactory characterInfoFactory) {
        this.characterInfoFactory = characterInfoFactory;
    }

    public CompletableFuture<CharacterInfo> newCharacter() {
        return CompletableFuture.supplyAsync(CharacterInfo::new);
    }

}
```

There is one weird part of this, I am supplying a new `CharacterInfo` here with the idea it will be added to with the various field 
resolvers I will add. I really don't like code that relies on side effects, but I'm not sure how else I'm supposed to do this. There is 
a lot of auto magic going on here. But oh well, we can move on to field resolvers and see what happens. 

In order to allow granular field resolving, I need to add a `GraphQLResolver` for the `CharacterInfo` object. That will tell the 
framework that when fetching a field for `CharacterInfo` it should use the various `get` methods defined in the resolver instead. To 
start with I will resolve `race` and `name`, since `race` requires an API call and `name` relies on the `race` field. Should allow for
some good use cases.

I want this API to be fast, so I will have both of these use `CompletableFuture` return types to tell GraphQL it can fetch everything
in parallel. However, I have a dependency between fields already, and that is where things get weird. Here is my first pass at 
implementing the resolver:

```java
@Component
public class CharacterInfoResolver implements GraphQLResolver<CharacterInfo> {

    private final CharacterInfoFactory characterInfoFactory;

    @Autowired
    public CharacterInfoResolver(CharacterInfoFactory characterInfoFactory) {
        this.characterInfoFactory = characterInfoFactory;
    }

    public CompletableFuture<String> getRace(CharacterInfo characterInfo) {
        System.out.println("Getting race");
        return characterInfoFactory.getRace().thenApply(Race::getName);
    }

    public CompletableFuture<String> getName(CharacterInfo characterInfo) {
        System.out.println("Getting name");
        return getRace(characterInfo).thenCompose(characterInfoFactory::getName);
    }
}
```

Now when I query the API like this:

```
query {
    newCharacter {
        race
    }
}
```

I get a `race` back, and avoid fecthing the `name` altogether. And same when I query for the `name`. Rad. What is less rad is when I query for both:

```
query {
    newCharacter {
        race
        name
    }
}
```

When I do this, I end up fetching the `race` twice, and worse it will potentially be different both times. Having fields be dependent 
on each other seems like a common issue in GraphQL land, or at least I thought it would be. From my googling I could not determine the
best practice for solving this issue. Some solutions I could think of were:

1. Make `CharacterInfo` use `CompletableFuture` as the return type for all of the fields, then my resolvers could wait for them. But 
having a model object that has futures in it seems super weird.
1. Use the `context` that is provided by the `DataFetchingEnvironment` to store our futures so we can wait on stuff appropriately. That
also seems like an anti pattern which I would like to avoid.
1. Change the data model for our character. GraphQL uses a breadth first approach for resolving data in a model, so if I structure the
model in such a way that all data that is dependent on other data is nested, then I can just be positive I can pull what I need off of
the dynamic character info at the proper time. This seems like the "right" solution, but really messes with my brain. 
1. Create some kind of utility/cache that stores futures so they can be awaited elsewhere. This seems better than the `context` but is
functionally the same since I would need to store session info to handle concurrent users. 
1. Make field fetching synchronous, but then you could have wildly different query times depending on the field order in your query.

I'm not sure if my use case is just terrible for GraphQL or if I'm not thinking about the problem the right way, but none of these 
solutions seem that great. In fact, it seems like the data modelling is begging for errors that ruin the entire reason to use GraphQL
in the first place. My very first attempt at setting two simple string fields yielded an extremely inefficient query. Since this is 
probably just me struggling with the learning curve, I'll work towards making this work in the least insane manner I can find.

# The Least Insane Manner

I did a lot of research and testing for this problem. I finally landed on something I don't hate with a passion, but I still don't love
it. First, though, I will walk through what I thought would be the "best" solution and why it didn't work. My first attempt was to 
restructure my data model so that all of the fields that other things are dependent on would be at the top level since GraphQL resolves
the query tree in a breadth first manner. That way, in my nested models I could check if the parent field was already loaded and if not
I could just fire off the future and be good. So I attempted to structure my schema like this:

```
type CharacterInfo {
    race: String
    ...other dependent fields
    details: CharacterDetails
}

type CharacterDetails {
    name: String
    ...other fields that rely on parent data
}
.
.
.
```

Then I attempted to write the resolvers and ran into a snag, I was thinking about the `parent` the wrong way. According to the 
[GraphQL Tools docs](https://www.graphql-tools.com/docs/resolvers), all resolvers will receive their parent as the first parameter. 
So for the query resolver, it will be some root object the server provides (in my case this will be null). Then in the model resolvers,
it will be handed the model being returned. What I was hoping was in my `CharacterDetails` resolver, I could reference the parent 
object which would be a fully constructed `CharacterInfo`. However, that is actually a grand-parent relationship. When resolving
`CharacterDetails.name`, I would only have access to `CharacterDetails`, which is definitely not what I needed.

So I was back to square one and played around with a bunch of different solutions. Finally I landed on one that works well: 
[Dataloaders](https://www.graphql-java-kickstart.com/servlet/dataloaders/). While this isn't 100% the intended use case for these
bad boys, the overall idea behind them is for handling queries that will be done over and over again over the life of a single query, 
so I think this is a good fit. 

# Custom Dataloaders

In order to define my own data loaders, I have some scoping decisions to make. For my chosen framework, I can have three possible scopes
for my data loaders: global, request scoped, or query scoped. A global scope is for data that should be shared for all users using the 
API, which definitely will not work for my use case. For my current API setup, request scoped and query scoped are basically the same, 
so I will just stick with query scoped for now. To do that, I need to use Spring Boot magic and define a context builder that will 
override the default behavior. So I created a `GraphQLContextBuilder` class with the following content:

```java
@Component
public class GraphQLContextBuilder implements GraphQLServletContextBuilder {

    @Override
    public GraphQLContext build() {
        return new DefaultGraphQLContext();
    }

    @Override
    public GraphQLContext build(HttpServletRequest httpServletRequest, HttpServletResponse httpServletResponse) {
        return DefaultGraphQLServletContext.createServletContext()
                                           .with(httpServletRequest)
                                           .with(httpServletResponse)
                                           .with(buildDataLoaderRegistry())
                                           .build();
    }

    @Override
    public GraphQLContext build(Session session, HandshakeRequest handshakeRequest) {
        return DefaultGraphQLWebSocketContext.createWebSocketContext()
                                             .with(session)
                                             .with(handshakeRequest)
                                             .with(buildDataLoaderRegistry())
                                             .build();
    }

    private DataLoaderRegistry buildDataLoaderRegistry() {
        DataLoaderRegistry registry = new DataLoaderRegistry();
        // This is where my custom data loaders go
        return registry;
    }

}
```

Sweet so now I have a way to define some data loaders that can be shared for all of my resolvers. The sharing part is critical for my
use case because if I switch out the dependent data anywhere down the line, I will get inconsistent results like an Elf with a Human 
name, which I will absolutely not stand for and neither should you.

Each data loader returns a future, which will be great because I can leverage that for excellent performance in queries because I will 
only ever execute a future when I need it, and the result will stick around for anybody that needs it. There is one downside here, since
the Java implementation of data loaders is pretty specific to solving the 
[N+1 problem](https://medium.com/the-marcy-lab-school/what-is-the-n-1-problem-in-graphql-dd4921cb3c1a), the interface for them is all 
around batching. So even though I don't actually batch anything (I only ever return a single character in my API), and I don't actually
do any lookups based on unique identifiers or anything, I have to pretend I do. This means my data loaders are butt ugly. Here is what
a data loader would look like to get the race of a character:

```java
private BatchLoader<String, Race> getRaceLoader(DndApiClient apiClient) {
    return (unused) -> dndApiClient.getRace()
                                   .thenApply(result -> ImmutableList.of(result));
}
```

I absolutely hate having to have an `unused` lambda parameter, but the purpose of that in the abstraction is for fetching data with 
some unique identifier. There might be a way for me to avoid that, but I couldn't find it. The other annoying part is I have to return 
a `List` of results because it is expecting to batch stuff, but I will only ever be retrieving a single value in my use case so I'm
fudging it here and just always returning a single result. 

Pretty much all of my shared data follows this pattern (just call the DndApiClient), so I can generify most of my data loaders:

```java
private <T> BatchLoader<String, T> createAsyncBatchLoader(Supplier<CompletableFuture<T>> supplier) {
    return (unused) -> supplier.get()
                               .thenApply(result -> ImmutableList.of(result));
}
```

Then I can also make one for the sync case, for things like the stat rolls that need to be shared throughout the query:

```java
private <T> BatchLoader<String, T> createSyncBatchLoader(Supplier<T> supplier) {
    return (unused) -> CompletableFuture.completedFuture(ImmutableList.of(supplier.get()));
}
```

Now I can actually add something reusable to my data loader registry! I have to include the `dndApiClient` to my context builder so 
I can actually call the API methods, then I can use my generic async batch loader function to get things rolling:

```java
private final DndApiClient dndApiClient;

@Autowired
public GraphQLContextBuilder(DndApiClient dndApiClient) {
    this.dndApiClient = dndApiClient;
}
.
.
.

private DataLoaderRegistry buildDataLoaderRegistry() {
    DataLoaderRegistry registry = new DataLoaderRegistry();
    registry.register("raceLoader",
                      DataLoaderFactory.newDataLoader(createAsyncBatchLoader(dndApiClient::getRace)));
    return registry;
}
```

Now that I have my data loader, I can fix my resolver:

```java
@Component
public class CharacterInfoResolver implements GraphQLResolver<CharacterInfo> {

    private final CharacterInfoFactory characterInfoFactory;

    @Autowired
    public CharacterInfoResolver(CharacterInfoFactory characterInfoFactory) {
        this.characterInfoFactory = characterInfoFactory;
    }

    public Object getRace(CharacterInfo characterInfo, DataFetchingEnvironment dataFetchingEnvironment) {
        return dataFetchingEnvironment.getDataLoader("raceLoader")
                                      .load(dataFetchingEnvironment.getExecutionId())
                                      .thenApply(Race::getName);
    }

    public CompletableFuture<String> getName(CharacterInfo characterInfo, DataFetchingEnvironment dataFetchingEnvironment) {
        return getRace(characterInfo, dataFetchingEnvironment).thenCompose(characterInfoFactory::getName);
    }

}
```

Now if you run the app and hit the playground (http://localhost:8080/playground), you can query for the `race`, `name`, or both and 
the API will only get hit once! Success. I can follow this same process for every field in `CharacterInfo` to get a full API ready to
go. I won't go over that part here since it is a lot of very repetitive code, but at the end we can query for any field we want and 
know it will perform the bare minimum of requests to get it. Which is pretty cool.

# Sprites

Now onto something I completely forgot about, generating the sprite sheet in GraphQL. I added some code changes to return a `byte[]` 
in the `SpriteResolver` above as a placeholder, and now we can test it. When running the playground, we can execute a query like this:

```
query {
    sprites (
        equipmentNames: [ "Javelin", "Dagger" ]
        race: "Human"
    )
}
```

And hope for the best. And our hope means nothing, because we get this back:

```
{
  "data": {
    "sprites": "[B@655975cb"
  }
}
```

That is not a sprite sheet, and I figured I would need some tweaking before that worked so that's fine. However after some extensive 
googling it seems like providing a bytestream with GraphQL is just... not a thing. The best practice in this scenario is to provide
a URL with a static resource that the client can download separately. That is kind of annoying, but I can see why it is preferred. So
now we need to store our sprite sheet as a local image, and provide an endpoint to serve up that image. 

## New Swagger Endpoint

Since I already have an endpoint that does this correctly, I will just make a new endpoint that will serve up a Sprite Sheet with a 
given identifier and have the app store them on the file system. Here is the new endpoint in my swagger definition:

```yaml
  /sprite/{name}:
    get:
      tags:
        - sprite
      summary: Get an existing sprite sheet by name
      operationId: getSpriteSheetByName
      parameters:
        - in: path
          name: name
          description: The name of the sprite sheet to fetch
          required: true
          schema:
            type: string
      responses:
        '200':
          description: The sprite sheet for the provided character info
          content:
            image/png:
              schema:
                type: string
                format: binary
```

Pretty simple. Since I updated to using the `openapi-generator` maven plugin, this will automatically make a new endpoint interface
method for me. However I can't actually implement it yet, since I will need a few changes the sprite builder. 

Originally the sprite builder logic was to just provide a raw byte array, but now we want to store a file on the filesystem. 
Thankfully this is super easy, we just modify our `toByteArray` method to instead write to a file:

```java
public  static final String SPRITE_FOLDER = "sprites";

public File getSpriteSheetFile(String name) {
    return new File(String.format("%s/%s", SPRITE_FOLDER, name));
}

private File toFile(BufferedImage bufferedImage) throws IOException {
    File file = getSpriteSheetFile(UUID.randomUUID().toString());
    ImageIO.write(bufferedImage, "png", file);
    return file;
}
```

Now I can implement the new endpoint, as well as make a minor tweak to the old one to handle the new implementation. Thankfully the 
Spring `Resource` class makes this super easy in my `SpriteApiController`:

```java
@Override
public ResponseEntity<Resource> getSpriteSheet(CharacterInfo characterInfo) {
    try {
        return ResponseEntity.ok(new FileSystemResource(spriteBuilder.buildSpriteSheet(characterInfo.getEquipment()
                                                                                                    .stream()
                                                                                                    .map(Equipment::getName)
                                                                                                    .collect(Collectors.toList()),
                                                                                        characterInfo.getRace())));
    } catch (Exception e) {
        LOGGER.error("Failed to generate sprite sheet", e);
        return new ResponseEntity<>(HttpStatus.INTERNAL_SERVER_ERROR);
    }
}

@Override
public ResponseEntity<Resource> getSpriteSheetByName(String name) {
    try {
        return ResponseEntity.ok(new FileSystemResource(spriteBuilder.getSpriteSheetFile(name)));
    } catch (Exception e) {
        LOGGER.error("Failed to generate sprite sheet", e);
        return new ResponseEntity<>(HttpStatus.INTERNAL_SERVER_ERROR);
    }
}
```

## Fix the GraphQL Resolver

Now that I have a new endpoint to handle this, I can update my sprite GraphQLQueryResolver to do the right thing. But, then I would 
have to make 3 API calls to get all of my data: one to get the character info, one to generate the sprite and the file, and one to 
actually download the file. That seems super annoying, so I'll just utilize the power of GraphQL and just add the sprite data to the
`CharacterInfo` model, so a client can query it when they want it. Here is the update to the spec:

```
type Query {
  newCharacter: CharacterInfo
}

type CharacterInfo {
    name: String
    race: String
    characterClass: String
    background: String
    alignment: String
    strength: AbilityScore
    dexterity: AbilityScore
    intelligence: AbilityScore
    wisdom: AbilityScore
    constitution: AbilityScore
    charisma: AbilityScore
    proficiencyModifier: Int
    skills: [String]
    proficiencies: [String]
    languages: [String]
    equipment: [Equipment]
    speed: String
    hitDice: Int
    feature: Feature
    traits: [String]
    ideals: [String]
    bonds: [String]
    flaws: [String]
    spriteSheet: String
}
```

And now my `CharacterInfoResolver` can handle setting it with a relative URL for fetching the image. I can just follow the same pattern
I used before. The sprite sheet requires all the equipment names to work properly, so I needed a data loader to fetch all the equipment.
However, fetching equipment relies on the character class and background. So now I needed a data loader that relied on data loaders. It
was actually pretty tricky getting that to work, but in the end I just ended up using futures for class and background as the inputs
to the data loader and everying worked out, and here is the resulting fetch function in my `CharacterInfoResolver`:

```java
public CompletableFuture<String> getSpriteSheet(CharacterInfo characterInfo, DataFetchingEnvironment dataFetchingEnvironment) {
    CompletableFuture<Race> raceFuture = loadRace(dataFetchingEnvironment);
    CompletableFuture<List<Equipment>> equipmentFuture = loadEquipment(dataFetchingEnvironment);
    return CompletableFuture.allOf(raceFuture,
                                   equipmentFuture)
                            .thenApply(unused -> {
                                try {
                                    File spriteFile =  spriteBuilder.buildSpriteSheet(equipmentFuture.join()
                                                                                                     .stream()
                                                                                                     .map(Equipment::getName)
                                                                                                     .collect(Collectors.toList()),
                                                                                      raceFuture.join()
                                                                                                 .getName());
                                    return "/rest/character-builder/v1/sprite/" + spriteFile.getName();
                                } catch (Exception e) {
                                    throw new RuntimeException(e);
                                }
                            });
}
```

# Conclusion

Well this turned out to be a lot. Yet again I had glorious aspirations of implementing this API in 3 different languages and doing some
elaborate performance testing and making a new [Apollo](https://www.apollographql.com/) client to interact with it. Alas, turns out new
technologies are tricky to learn. I'm happy I was able to delve so deep into GraphQL, at least the Java implementation. This isn't 
enough usage for me to form firm opinions on the technology yet, but here are some takeaways I have so far (best taken with a grain of
salt):

## Pros

- Ridiculously flexible, which is like the whole thing for GraphQL so duh. Being able to fetch only the data needed at any given time 
is extremely powerful and pretty fun to work with.
- Field level query optimization. I really like reasoning about how to fetch data in performant ways, and this use case actually ended
up showing some cool things. Data loaders are very easy to setup and use. Being able to introduce complex queries when needed is very 
cool.
- Great tooling. After playing around with the swagger autogen stuff, GraphQL seems way more fleshed out. Pretty much out of the box I 
had everything I needed and the API interaction UIs are awesome. 
- Easy to understand schema. The schema reads very well and is extremely easy to work with. 

## Cons

- It seems waaaaaaaay too easy to make horrible performing queries. Like app killing queries. If your data modelling is poor (which is 
true for everyone at some point, I'm convinced of that) then wrangling the queries can be very difficult.
- Pretty specific use cases. This was a terrible example for GraphQL since I want to fetch the entire model every time, but even if 
I didn't a lot of this stuff could just be solved with multiple REST endpoints that allow optimizing queries. GraphQL isn't really doing
anything special around reasoning how to make queries performant, it just provides hooks. 
- Implementation bleeds out to the client. This is avoidable most likely, but since query time seems to be one of the most critical 
considerations for this solution, data models might be more about query efficiency rather than conceptual understanding. As much as 
possible having the data returned from an API match the business models used is generally a good idea, but I have also seen it lead
to some very convoluted REST api designs since overall understanding of how a client would interact with the API is shoved to the side. 
This is true of all APIs really, but it seemed more prevalent in my research of GraphQL. 

# Next Time

The next article will be attempting to rewrite my client using [Apollo](https://www.apollographql.com/), and maybe start doing some 
performance comparisons between the APIs. 
