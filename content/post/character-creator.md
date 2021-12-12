+++
subtitle = "How Hard Can It Be?"
title = "Let's Make A DnD Character"
date = "2021-04-30T10:54:24+02:00"
draft = false
tags = ["java", "swagger", "spring", "java11", "dnd"]
series = ["Let's Make a DnD Character"]
+++

The programming language I am most familiar with is Java. Until recently, I have enjoyed working in Java quite a bit,
it clicks with my brain very well. It was the first language I learned, so it is the most natural for me to use. However,
after working on multiple other projects using other languages, I am forced to come to terms with some severe limitations
of Java. No language is perfect, and Java is still an incredibly popular and powerful language, but it is showing its age. 
At least it is in my opinion. However, this may be because most of what I have done in my career is work on legacy systems.
For example, I have only ever used Java 8 professionally, which is kind of ridiculous. So I started to wonder, is my 
declining interest in Java happening just because I haven't been keeping up? Most of my personal projects are done in other
languages so I can learn some new stuff. So I decided to do my next project using Java 11, specifically to try out some
of the new features and see how easy/hard it would be to get a simple REST API project ready to go.

I wanted a relatively meaty project, and I also wanted to work with React a bit more to get more comfortable with frontend
development. For whatever reason, I thought it might be fun to write an app that will randomly create a DnD character, even
though I have never done that or even played DnD before. After doing some research, I found a few APIs that would help in my
task as well as an open source sprite sheet collection I could use to randomly generate some animations. I thought I could 
bang out this project in a day or two... turns out creating a character was a bit more complicated than I expected. However,
that complication did allow me to work with some interesting aspects of both Java 11 and React. 

If you want to just go straight to the code [checkout the Github repo](https://github.com/nprice1/characterCreator).

# Swagger Spec

Most of my professional work involves creating REST APIs, so I thought the best way to see how Java 11 performs would be
to do what I do every day. This has the added benefit of a bunch of auto code generation I can rely on which is super cool.
After consulting the rules for creating a character in 5e and evaluating the [DnD 5e API](http://www.dnd5eapi.co/), I came
up with this swagger spec:

```yaml
openapi: 3.0.0
servers:
  - url: http://localhost:8080/character-builder/v1
info:
  description: Random D&D 5th Edition Character Creator
  version: 1.0.0
  title: Character Creator
  contact:
    name: nolan@nolanprice.com
paths:
  /info:
    get:
      tags:
        - info
      summary: Generate the characters details (background, class, race, starting items, etc.)
      operationId: getInfo
      responses:
        '200':
          description: Characters info
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/CharacterInfo'
  /sprite:
    post:
      tags:
        - sprite
      summary: Generate the characters sprite sheet
      operationId: getSpriteSheet
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CharacterInfo'
      responses:
        '200':
          description: 'The sprite sheet for the provided character info'
          content:
            image/png:
              schema:
                type: string
                format: binary
components:
  schemas:
    CharacterInfo:
      type: object
      description: The general details of a character
      properties:
        name:
          type: string
          description: The name of the character
        race:
          type: string
          description: The race of the character
        class:
          type: string
          description: The class for the character
        background:
          type: string
          description: The name of the background for the character
        alignment: 
          type: string
          description: The alignment for the character
        strength:
          $ref: '#/components/schemas/AbilityScore'
        dexterity:
          $ref: '#/components/schemas/AbilityScore'
        intelligence:
          $ref: '#/components/schemas/AbilityScore'
        wisdom:
          $ref: '#/components/schemas/AbilityScore'
        constitution:
          $ref: '#/components/schemas/AbilityScore'
        charisma:
          $ref: '#/components/schemas/AbilityScore'
        proficiencyModifier:
          type: integer
          description: The proficiency modifier for the character
        skills:
          type: array
          items:
            type: string
            description: A skill of the character
        proficiencies:
          type: array
          items:
            type: string
            description: A proficiency of the character
        languages:
          type: array
          items:
            type: string
            description: Languages spoken by the character
        equipment:
          type: array
          items: 
            $ref: '#/components/schemas/Equipment'
        speed:
          type: string
          description: The movement speed for the character
        hitDice:
          type: integer
          description: The hit dice for the character
        feature:
          $ref: '#/components/schemas/Feature'
        traits:
          type: array
          items:
            type: string
            description: A personality trait of the character
        ideals:
          type: array
          items:
            type: string
            description: An ideal for the character
        bonds:
          type: array
          items:
            type: string
            description: A bond for the character
        flaws:
          type: array
          items:
            type: string
            description: A flaw of the character
    Feature:
      type: object
      properties:
        name:
          type: string
          description: The name of the feature
        description:
          type: array
          items:
            type: string
            description: The description of the features effects
    AbilityScore:
      type: object
      properties:
        base:
          type: integer
          description: The base stat
        modifier:
          type: integer
          description: The modifier for the stat
        proficient:
          type: boolean
          description: Whether or not the character is proficient with this ability for saving throws
    Equipment:
      type: object
      description: Piece of equipment
      properties:
        name:
          type: string
          description: Name of equipment
        quantity:
          type: integer
          description: The number of the given piece of equipment available
```

It has two endpoints, one for generating most of the stuff required for a character sheet (I ignored weapon damage and 
spells since that was pretty complicated), and one for generating the sprite sheet for the character. Note that the `url`
for my server is very specific, I did that on purpose so the code generator for the client I write will automatically point
to my running backend.

# Server

Now that I have the swagger spec, it is time to make the server.

## Codegen

I chose to use [Spring Boot](https://spring.io/projects/spring-boot) for my server since I have never used it before and
I have had it recommended to me a few times. Now that I have my server chosen, I can use the 
[OpenApi Generator](https://github.com/OpenAPITools/openapi-generator) to generate my code. In order to generate everything
in the correct place, I need to provide a configuration file to the generator. I created a `java11config.json` file with
the following contents:

```json
{
  "basePackage": "com.nolanprice",
  "configPackage": "com.nolanprice.config",
  "apiPackage": "com.nolanprice.controllers",
  "modelPackage": "com.nolanprice.model",
  "groupId": "com.nolanprice",
  "artifactId": "character-creator"
}
```

Now I can auto generate some server stubs:

```bash
docker run --rm -v "${PWD}:/local" openapitools/openapi-generator-cli generate \
    -i /local/swagger.yaml \
    -g spring \
    -c /local/java11config.json \
    -o /local/java11
```

I need to make a couple of modifications to this generated code:

### Modify pom.xml

I need to set the proper Java version to make sure I utilize the new features. I could probably have set this in the 
config somehow, but I didn't want to spend all my time researching. To update the version, change the Java version property:

```xml
<java.version>1.11</java.version>
```

And also update the `maven-compiler-plugin` to use the proper version:

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-compiler-plugin</artifactId>
    <configuration>
        <source>11</source>
        <target>11</target>
    </configuration>
</plugin>
```

### Modify OpenAPI2SpringBoot

I am going to be hitting this endpoint from a different localhost port, so I need to open up our CORS headers to allow
that. Thankfully the code to do that is just commented out here in `webConfigurer()`, so just uncomment it:

```java
@Bean
public WebMvcConfigurer webConfigurer() {
    return new WebMvcConfigurer() {
        @Override
        public void addCorsMappings(CorsRegistry registry) {
            registry.addMapping("/**")
                    .allowedOrigins("*")
                    .allowedMethods("*")
                    .allowedHeaders("Content-Type");
        }
    };
}
```

### Modify controllers/SpriteApi.java

I couldn't get the `MultipartFile` return type to work properly, so instead I just made it a `byte[]` and that seemed
to work much better:

```java
default ResponseEntity<byte[]> getSpriteSheet(@ApiParam(value = ""  )  @Valid @RequestBody(required = false) CharacterInfo characterInfo) {
    return new ResponseEntity<>(HttpStatus.NOT_IMPLEMENTED);

}
```

## Character Info

### DnD API Client

Now that I have the server stub, I can implement the business logic to generate the character info needed for the first 
endpoint. This will rely on making a bunch of HTTP requests to the [DnD 5e API](http://www.dnd5eapi.co/) based on random
choices. Since I have to make a bunch of calls, this is a perfect place for unnecessary asynchronous code! I don't do much
async code in my day to day since it usually isn't necessary, so I thought this would be a good change to work with it as
well as the new `HttpClient` introduced in Java 11. Interacting with an API means creating some model objects, and since
those are super boring you can 
[see them here](https://github.com/nprice1/characterCreator/tree/master/java11/src/main/java/com/nolanprice/dnd) rather
than me copying them in this post. 

The DnD API provides an abstraction for a choice that needs to be made by the person creating the character. Since I want
to create a random character, this means I will need to make random choices. I liked this abstraction, so I also used it
in the sprite sheet generation I will get to in the next part. This means I moved the model out of the `dnd` package, and
I also create a helper class that can make a random choice:

```java
package com.nolanprice;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

@JsonIgnoreProperties(ignoreUnknown = true)
public class Choice<T> {

    private Integer choose;
    private String type;
    private List<T> from;

    public Choice() {
    }

    public Choice(Integer choose, String type, List<T> from) {
        this.choose = choose;
        this.type = type;
        this.from = from;
    }

    public Integer getChoose() {
        return choose;
    }

    public String getType() {
        return type;
    }

    public List<T> getFrom() {
        return from;
    }

}
```

```java
package com.nolanprice;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;

public class ChoiceUtils {

    private static final Random RANDOM = new Random();

    public static <T> List<T> makeRandomChoices(Choice<T> choice) {
        List<T> choices = choice.getFrom();
        int numChoices = choices.size();
        List<Integer> selectedIndexes = new ArrayList<>();
        List<T> selectedChoices = new ArrayList<>();
        for (int i=0; i < choice.getChoose(); i++) {
            int choiceIndex = RANDOM.nextInt(numChoices);
            if (!selectedIndexes.isEmpty()) {
                while (selectedIndexes.contains(choiceIndex)) {
                    choiceIndex = RANDOM.nextInt(numChoices);
                }
            }
            selectedIndexes.add(choiceIndex);
            selectedChoices.add(choices.get(choiceIndex));
        }
        return selectedChoices;
    }

}
```

The `makeRandomChoice()` function will make as many choices as specified in the provided `Choice`, and also keep track
of choices it makes which means there can be no duplicates.

Now I am ready to make our API client. First I start with some constants:

```java
@Component
public class DndApiClient {

    private static final Logger LOGGER = LoggerFactory.getLogger(DndApiClient.class);

    private static final URI BASE_URI = URI.create("https://www.dnd5eapi.co");

    private static final HttpClient CLIENT = HttpClient.newBuilder()
                                                       .version(HttpClient.Version.HTTP_1_1)
                                                       .connectTimeout(Duration.ofSeconds(5))
                                                       .executor(Executors.newFixedThreadPool(10))
                                                       .build();
    private static final Random RANDOM = new Random();
    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    private interface Endpoints {
        String CLASSES = "/api/classes";
        String RACES = "/api/races";
        String BACKGROUNDS = "/api/backgrounds";
        String ALIGNMENTS = "/api/alignments";
    }
}
```
This does the following:

1. Adds the `@Component` annotation to mark the class as injectable.
1. Creates a `Logger` instance I can use for logging anything helpful.
1. Defines the base path for the API calls this class will be making.
1. Creates the new Java 11 HttpClient this class will be using, including a timeout and a custom `Executor`. That part is 
probably superfluous but whatever.
1. A `Random` instance I will use to make some choices for the character.
1. An `ObjectMapper` that I will use to serialize the model objects the API will provide.
1. A helper interface to grab the API endpoints for each of the resources I care about.

Now it is time for some helper methods. I am going to be making requests the API and parsing the results, and I want to do
it asynchronously. To do that, I will define a function that will make an arbitrary call to the API endpoint and use the 
`sendAsync` functionality of the client. Then I will bind a response handler to the resulting `CompletableFuture` and Bob's 
your uncle:

```java
private <T> CompletableFuture<T> executeRequest(URI uri, Class<T> responseClass) {
    HttpRequest request = HttpRequest.newBuilder()
                                     .uri(uri)
                                     .build();
    return CLIENT.sendAsync(request, HttpResponse.BodyHandlers.ofInputStream())
                 .thenApply(response -> parseSafely(response.body(), responseClass));
}

private <T> T parseSafely(InputStream inputStream, Class<T> responseClass) {
    try {
        return OBJECT_MAPPER.readValue(inputStream, responseClass);
    } catch (IOException e) {
        LOGGER.error("Failed to parse response");
        return null;
    }
}
```

There is a common abstraction in the DnD API that I will be using for the major character choices, which are the `Race`, 
`CharacterClass`, `Alignment`, and `Background` of the character. The API provides a list of available options, then I can
choose one value from the list and hit the provided URL to actually fetch the detailed data for our choice. So for example, 
I will hit the `/api/races` endpoint to see the list of races, pick one, then hit the `/api/races/{race}` endpoint to get
the actual data. In order to do that, I need a method that can figure out the URL to hit, and a function that will make 
a random choice for me:

```java
private URI getApiUri(String endpoint) {
    if (!endpoint.startsWith("/")) {
        endpoint = "/" + endpoint;
    }
    return BASE_URI.resolve(endpoint);
}

private URI getApiUri(String endpoint, String index) {
    if (!endpoint.startsWith("/")) {
        endpoint = "/" + endpoint;
    }
    return BASE_URI.resolve(endpoint + "/" + index);
}

private <T> CompletableFuture<T> fetchRandomApiReferenceValue(String endpoint, Class<T> responseClass) {
    return executeRequest(getApiUri(endpoint), ResourceList.class)
            .thenCompose(resourceList -> {
                int chosenClassIndex = RANDOM.nextInt(resourceList.getCount());
                ApiReference apiReference = resourceList.getResults().get(chosenClassIndex);
                URI uri = apiReference.getUrl() != null ? getApiUri(apiReference.getUrl()) : getApiUri(endpoint, apiReference.getIndex());
                return executeRequest(uri, responseClass);
            });
}
```

I had to define two different `getApiUrl` functions because there is an inconsistency in the return values for the API
I'm using. One of the downsides to using other peoples personal projects as an API, but not too hard to work around. The
`fetchRandomApiReferenceValue` function will make an async call to fetch our choices, then use the `thenCompose` method
to bind a second API request based on the choice made and return the whole shebang so the `CompletableFuture` will not 
complete until both API requests are finished. Pretty sweet. 

Now that I have all that, defining the functions to get the stuff I need is super easy:

```java
public CompletableFuture<Race> getRace() {
    return fetchRandomApiReferenceValue(Endpoints.RACES, Race.class);
}

public CompletableFuture<CharacterClass> getCharacterClass() {
    return fetchRandomApiReferenceValue(Endpoints.CLASSES, CharacterClass.class);
}

public CompletableFuture<Background> getBackground() {
    return fetchRandomApiReferenceValue(Endpoints.BACKGROUNDS, Background.class);
}

public CompletableFuture<Alignment> getAlignment() {
    return fetchRandomApiReferenceValue(Endpoints.ALIGNMENTS, Alignment.class);
}
```

Unfortunately I need two other helper methods that are... not as easy. Equipment choices it turns out are pretty 
complicated. The DnD API provides equipment choices as 3 different models: 

1. A normal choice from a list of `ApiReference` objects (where I only need the name)
1. A choice from an `EquipmentCategory`, where I have to fetch all equipment in that category before I can make a choice.
1. A weird combination of the two above, which I think was accidental from the API developers. 

To compensate for the weirdness, I made the `Equipment` model have optional fields to determine if we need to expand the
list of available choices. Expanding the list of choices requires API calls, so the client needs to be able to do that.
First I will handle the simpler `EquipmentOption` case, that is only ever used for selecting from an `EquipmentCategory`:

```java
public CompletableFuture<Choice<Equipment>> expandEquipmentChoices(EquipmentOption equipmentOption) {
    return executeRequest(getApiUri(equipmentOption.getFrom()
                                                   .getEquipmentCategory()
                                                   .getUrl()), EquipmentList.class)
            .thenApply(equipmentList -> {
                List<Equipment> newChoices = equipmentList.getEquipment()
                                                          .stream()
                                                          .map(newEquipment -> new Equipment(newEquipment, 1))
                                                          .collect(Collectors.toList());
                return new Choice<>(equipmentOption.getChoose(), null, newChoices);
            });
}
```

That's not so bad, we just make a call to get the available equipment in the category then map those to the common `Choice`
abstraction. Now for the weirder one, a mixing of normal equipment with equipment categories:

```java
public CompletableFuture<Choice<Equipment>> expandEquipmentChoices(Choice<Equipment> equipmentChoice) {
    List<Equipment> newChoices = new ArrayList<>();
    List<CompletableFuture<Void>> equipmentFutures = new ArrayList<>();
    for (Equipment equipment : equipmentChoice.getFrom()) {
        if (equipment.getEquipmentCategory() != null) {
            CompletableFuture<Void> expandChoicesFuture = executeRequest(getApiUri(equipment.getEquipmentCategory()
                                                                                            .getUrl()),
                                                                         EquipmentList.class)
                    .thenAccept(equipmentList -> {
                        newChoices.addAll(equipmentList.getEquipment()
                                                        .stream()
                                                        .map(newEquipment -> new Equipment(newEquipment, 1))
                                                        .collect(Collectors.toList()));
                    });
            equipmentFutures.add(expandChoicesFuture);
        } else {
            newChoices.add(equipment);
        }
    }
    return CompletableFuture.allOf(equipmentFutures.toArray(new CompletableFuture[] {}))
                            .thenApply(empty -> new Choice<>(equipmentChoice.getChoose(),
                                                             equipmentChoice.getType(),
                                                             newChoices));
}
```

I am very used to working with the `Promise.all()` functionality of Node. It is awesome, you wait for all async processes
to finish, then you get handed the list of results of the promises to do work on. I thought `CompletableFuture.allOf()` was
the Java equivalent. It almost was, except for the critical missing element of NOT GIVING THE RESULTS! So, I resorted to
this mess, where I modify the contents of a list in asynchronous processes, which is a no-no but I don't care, I didn't 
want to have to maintain pointers to each `CompletableFuture` in order to get the damn results, so I just keep a list
of async processes that will mutate a shared object and then return new choices based on that mutated object. Someone better
versed in Java please tell me how I can do this better, because I hate it.

These two helper functions will yield the result of a unified `Choice` that contains all of the expanded options available
so the proper decisions can be made.

## Name

I found a sweet [name generator](https://donjon.bin.sh/fantasy/name/) that could generate DnD-y names for me. It has
various options I can use, including the gender of the character and some options based on the race of the character. Since
gender isn't actually part of the character sheet, it doesn't play into the API so I'm just going to randomly pick a gender
for name generation purposes. Besides, why not have a badass Dragonborn barbarian named Hilda? Since it also takes the
race into account, I will provide that as an argument and the client will look a lot like the DnD API client above:

```java
@Component
public class NameClient {

    private static final Logger LOGGER = LoggerFactory.getLogger(NameClient.class);

    private static final String NAME_URL_TEMPLATE = "https://donjon.bin.sh/name/rpc-name.fcgi?type=%s+%s&n=1";

    private static final List<String> GENDERS = ImmutableList.of("Male", "Female");

    private static final Random RANDOM = new Random();
    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    private static final Map<String, String> RACE_MAPPINGS;
    static {
        Map<String, String> raceMappings = Collections.emptyMap();
        try {
            raceMappings = OBJECT_MAPPER.readValue(NameClient.class.getResourceAsStream("raceMappings.json"),
                                                   new TypeReference<>() {});
        } catch (Exception e) {
            LOGGER.error("Failed to load race mapping file", e);
        }
        RACE_MAPPINGS = raceMappings;
    }

    public CompletableFuture<String> getCharacterName(String race) {
        String gender = GENDERS.get(RANDOM.nextInt(2));
        String mappedRace = RACE_MAPPINGS.get(race);

        HttpRequest request = HttpRequest.newBuilder()
                                         .uri(URI.create(String.format(NAME_URL_TEMPLATE, mappedRace, gender)))
                                         .build();
        return HttpClient.newHttpClient()
                         .sendAsync(request, HttpResponse.BodyHandlers.ofString())
                         .thenApply(HttpResponse::body);
    }

}
```

I did add a bit of fancification there, where I made a JSON configuration file that can be used to map the DnD API race to
the one expected in the name generator, it looks like this:

```json
{
  "Dragonborn": "Draconic",
  "Dwarf": "Dwarvish",
  "Human": "Human",
  "Elf": "Elvish",
  "Gnome": "Dwarvish",
  "Half-Elf": "Elvish",
  "Half-Orc": "Orcish",
  "Halfling": "Halfling",
  "Tiefling": "Drow"
}
```

## CharacterInfo Factory

Now that I have all the pieces for the CharacterInfo response, I can put it all together. To do that, I created a 
`CharacterInfoFactory` class that will make the various API calls as well as map the external models to the ones actually
provided in the API, since most of the DnD API models have way more in them than I actually need. Once I collect all of
the important choices from the DnD API, I need to map them to my own API models. This means I need to figure out the 
following:

1. AbilityScores, which includes the base stats, modifiers, and proficiencies for each stat.
1. Equipment, which is just the name and quantity of the characters starting equipment.
1. Ideals, since these aren't just string list choices
1. Skills and Proficiencies

The factory will need the DnD API client as well as the name client to do its work:

```java
@Component
public class CharacterInfoFactory {

    private static final Logger LOGGER = LoggerFactory.getLogger(CharacterInfoFactory.class);

    private final NameClient nameClient;
    private final DndApiClient dndApiClient;

    @Autowired
    public CharacterInfoFactory(NameClient nameClient, DndApiClient dndApiClient) {
        this.nameClient = nameClient;
        this.dndApiClient = dndApiClient;
    }

}
```

### AbilityScore

To determine all of the base stats, modifiers, and proficiencies for a character, I need to check the `Race` and 
`CharacterClass` provided by the DnD API, then do a few calculations. Instead of simulating dice rolls, I am just going
to go with the standard method of dispersing the values 15, 14, 13, 12, 10, and 8 to each of the stats at random:

```java
private static final List<Integer> STAT_CHOICES = ImmutableList.of(15, 14, 13, 12, 10, 8);
```
Now for each stat, I need to assign on of the choices, calculate the modifier, then check if the character is proficient
in that stat:

```java
private AbilityScore generateAbilityScores(String statAbbreviation,
                                           Integer baseStat,
                                           Race race,
                                           CharacterClass characterClass) {
    Integer bonus = race.getAbilityBonuses()
                        .stream()
                        .filter(abilityScore -> abilityScore.getAbilityScore().getName().equals(statAbbreviation))
                        .map(abilityScore -> abilityScore.getBonus())
                        .reduce(0, Integer::sum);
    boolean proficient = characterClass.getSavingThrows()
                                       .stream()
                                       .anyMatch(reference -> reference.getName().equals(statAbbreviation));
    int stat = baseStat + bonus;
    int modifier = (stat - 10) / 2;
    return new AbilityScore().base(stat)
                             .modifier(modifier)
                             .proficient(proficient);
}
```

### Equipment

For this one I need to rely on those weird helper methods I defined in the DnD API client to make sure all of the available
choices are properly expanded, then choose at random. Thankfully most of the work is done in the client, and so all I need
to do is iterate over the `CharacterClass` and `Background` to find starting equipment and starting equipment choices that
need to be made then call into the client for the hard work. However, I have to resort to that same annoying list 
modification trick to wait for all the `CompletableFutures`, and I hate it:

```java
private List<Equipment> getEquipment(CharacterClass characterClass, Background background) throws
                                                                                            ExecutionException,
                                                                                            InterruptedException {
    Set<com.nolanprice.dnd.Equipment> allEquipment = new HashSet<>();
    allEquipment.addAll(characterClass.getStartingEquipment());
    allEquipment.addAll(background.getStartingEquipment());
    for (Choice<com.nolanprice.dnd.Equipment> choice : characterClass.getStartingEquipmentOptions()) {
        allEquipment.addAll(makeRandomEquipmentChoices(choice));
    }
    for (Choice<com.nolanprice.dnd.Equipment> choice : background.getStartingEquipmentOptions()) {
        allEquipment.addAll(makeRandomEquipmentChoices(choice));
    }
    return allEquipment.stream()
                        .map(this::mapEquipmentFromExternalModel)
                        .filter(Objects::nonNull)
                        .collect(Collectors.toList());
}

private Equipment mapEquipmentFromExternalModel(com.nolanprice.dnd.Equipment dndEquipment) {
    if (dndEquipment.getEquipment() == null) {
        return null;
    }
    return new Equipment().name(dndEquipment.getEquipment()
                                            .getName())
                          .quantity(dndEquipment.getQuantity());
}

private List<com.nolanprice.dnd.Equipment> makeRandomEquipmentChoices(Choice<com.nolanprice.dnd.Equipment> choice) throws
                                                                                                                    ExecutionException,
                                                                                                                    InterruptedException {
    List<com.nolanprice.dnd.Equipment> chosenEquipment = dndApiClient.expandEquipmentChoices(choice)
                                                                     .thenApply(ChoiceUtils::makeRandomChoices)
                                                                     .get();
    List<com.nolanprice.dnd.Equipment> finalEquipment = new ArrayList<>();
    List<CompletableFuture<Void>> expandedChoicesFutures = new ArrayList<>();
    for (com.nolanprice.dnd.Equipment equipment : chosenEquipment) {
        if (equipment.getEquipmentOption() != null) {
            expandedChoicesFutures.add(dndApiClient.expandEquipmentChoices(equipment.getEquipmentOption())
                                                   .thenApply(ChoiceUtils::makeRandomChoices)
                                                   .thenAccept(finalEquipment::addAll));
        } else {
            finalEquipment.add(equipment);
        }
    }
    // Wait for the expanded entries to finish
    CompletableFuture.allOf(expandedChoicesFutures.toArray(new CompletableFuture[] {}))
                     .get();
    return finalEquipment;
}
```

### Skills and Proficiencies

The DnD API lumps the skills and proficiencies together, so rather than iterating the same lists twice I just made an 
overloaded function that will aggregate and choose everything it needs to, then filter into two different lists for skills
and proficiencies. This just boils down to walking the various entries and choices in the `Race`, `CharacterClass`, and
`Background` and making choices when necessary:

```java
private Pair<Set<String>, Set<String>> getSkillsAndProficiencies(Race race, 
                                                                 CharacterClass characterClass, 
                                                                 Background background) {
    List<ApiReference> allProficiencies = new ArrayList<>();

    // First add all guaranteed proficiencies for the race, character class, and background
    allProficiencies.addAll(race.getStartingProficiencies());
    allProficiencies.addAll(characterClass.getProficiencies());
    allProficiencies.addAll(background.getStartingProficiencies());

    // Now choose proficiencies for race and character class if available
    if (race.getStartingProficiencyOptions() != null) {
        allProficiencies.addAll(ChoiceUtils.makeRandomChoices(race.getStartingProficiencyOptions()));
    }

    if (characterClass.getProficiencyChoices() != null && !characterClass.getProficiencyChoices().isEmpty()) {
        for (Choice<ApiReference> choice : characterClass.getProficiencyChoices()) {
            allProficiencies.addAll(ChoiceUtils.makeRandomChoices(choice));
        }
    }

    // Generate separate lists of skill proficiencies and other proficiencies since the API doesnt differentiate
    Set<String> skills = new HashSet<>();
    Set<String> proficiencies = new HashSet<>();
    for (ApiReference reference : allProficiencies) {
        if (reference.getIndex().startsWith("skill-")) {
            skills.add(reference.getName());
        } else {
            proficiencies.add(reference.getName());
        }
    }
    return Pair.of(skills, proficiencies);
}
```

### Ideals

Ideals are super easy to grab, I just need to make a choice and collect the names:

```java
private List<String> getIdeals(Background background) {
    return ChoiceUtils.makeRandomChoices(background.getIdeals())
                      .stream()
                      .map(Ideal::getDesc)
                      .collect(Collectors.toList());
}
```

### Create Character Info

I finally have all the building blocks in place and can actually construct my `CharacterInfo` object. This just means
calling all of the API methods I need at once, waiting for the results, and mapping:

```java
public CharacterInfo createCharacterInfo() {
    // We are going to modify this object
    CharacterInfo characterInfo = new CharacterInfo();
    try {
        // Kick off all requests that don't need any data
        CompletableFuture<Race> raceFuture = dndApiClient.getRace();
        CompletableFuture<CharacterClass> characterClassFuture = dndApiClient.getCharacterClass();
        CompletableFuture<Background> backgroundFuture = dndApiClient.getBackground();
        CompletableFuture<Alignment> alignmentFuture = dndApiClient.getAlignment();

        Race race = raceFuture.get();
        CharacterClass characterClass = characterClassFuture.get();
        Background background = backgroundFuture.get();
        Alignment alignment = alignmentFuture.get();
        String name = nameClient.getCharacterName(race.getName())
                                .get();

        characterInfo.setName(name);
        characterInfo.setRace(race.getName());
        characterInfo.setBackground(background.getName());
        characterInfo.setPropertyClass(characterClass.getName());
        characterInfo.setAlignment(alignment.getName());

        List<Integer> baseStatAllotments = new ArrayList<>(STAT_CHOICES);
        Collections.shuffle(baseStatAllotments);
        characterInfo.setStrength(generateAbilityScores("STR", baseStatAllotments.get(0), race, characterClass));
        characterInfo.setDexterity(generateAbilityScores("DEX", baseStatAllotments.get(1), race, characterClass));
        characterInfo.setIntelligence(generateAbilityScores("INT", baseStatAllotments.get(2), race, characterClass));
        characterInfo.setWisdom(generateAbilityScores("WIS", baseStatAllotments.get(3), race, characterClass));
        characterInfo.setConstitution(generateAbilityScores("CON", baseStatAllotments.get(4), race, characterClass));
        characterInfo.setCharisma(generateAbilityScores("CHA", baseStatAllotments.get(5), race, characterClass));

        Pair<Set<String>, Set<String>> skillsAndProficiencies = getSkillsAndProficiencies(race, characterClass, background);
        characterInfo.setSkills(new ArrayList<>(skillsAndProficiencies.getFirst()));
        characterInfo.setProficiencies(new ArrayList<>(skillsAndProficiencies.getSecond()));

        characterInfo.setLanguages(new ArrayList<>(getLanguages(race, background)));

        characterInfo.setSpeed(String.format("%s feet", race.getSpeed()));
        characterInfo.setHitDice(characterClass.getHitDie());

        Feature feature = new Feature();
        feature.setDescription(background.getFeature().getDesc());
        feature.setName(background.getFeature().getName());
        characterInfo.setFeature(feature);

        characterInfo.setIdeals(getIdeals(background));
        characterInfo.setTraits(ChoiceUtils.makeRandomChoices(background.getPersonalityTraits()));
        characterInfo.setBonds(ChoiceUtils.makeRandomChoices(background.getBonds()));
        characterInfo.setFlaws(ChoiceUtils.makeRandomChoices(background.getFlaws()));

        // For now just assume level 1
        characterInfo.setProficiencyModifier(2);

        characterInfo.setEquipment(getEquipment(characterClass, background));
    } catch (InterruptedException e) {
        Thread.currentThread()
              .interrupt();
    } catch (ExecutionException e) {
        LOGGER.error("Failed to get character info", e);
    }
    return characterInfo;
}
```

# Get Info API

Now that all the pieces are in place, I can actually implement the API method to hand this back. Nothing fancy, just
injecting the `CharacterInfoFactory` and using it to do all the heavy lifting:

```java
@Controller
@RequestMapping("${openapi.characterCreator.base-path:/character-builder/v1}")
public class InfoApiController implements InfoApi {

    private static final Logger LOGGER = LoggerFactory.getLogger(InfoApiController.class);

    private final NativeWebRequest request;
    private final CharacterInfoFactory characterInfoFactory;

    @Autowired
    public InfoApiController(NativeWebRequest request, CharacterInfoFactory characterInfoFactory) {
        this.request = request;
        this.characterInfoFactory = characterInfoFactory;
    }

    @Override
    public Optional<NativeWebRequest> getRequest() {
        return Optional.ofNullable(request);
    }

    @Override
    public ResponseEntity<CharacterInfo> getInfo() {
        try {
            CharacterInfo characterInfo = characterInfoFactory.createCharacterInfo();
            return ResponseEntity.ok(characterInfo);
        } catch (Exception e) {
            LOGGER.error("Failed to generate character", e);
            return new ResponseEntity<>(HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

}
```

# Tune In Next Time

Originally I was going to include the sprite sheet generation and the frontend for the app in one blog post, but this
turned out to be huge so I think I will break this into multiple parts. Check out 
[Part 2](/post/character-creator-pt2.html) for the sprite sheet generation, and [Part 3](/post/character-creator-pt3.html)
for the frontend.