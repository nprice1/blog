+++
subtitle = "Turns Out Pretty Hard"
title = "Let's Make A DnD Character: Part 2"
date = "2021-04-30T12:54:24+02:00"
draft = false
series = ["Let's Make a DnD Character"]
tags = ["java", "swagger", "spring", "java11", "flow", "sprites", "dnd"]
+++

I found [an awesome sprite sheet collection](https://github.com/makrohn/Universal-LPC-spritesheet) that included a bunch of
stuff I could use for generating some animated sprites for my generated DnD character I made in 
[Part 1](/post/character-creator.html). My swagger spec shows that this endpoint will take in a `CharacterInfo`, and based 
on those choices I can walk the sprite sheet folder and pick the appropriate body, weapons, and armor. Now the tricky part
is how to easily defined which images to select given some condition in the provided `CharacterInfo`. Since I already have
a fancy `Choice` abstraction, I decided to just extend that a bit.

# AllowedPaths

What this ultimately boils down to is a valid condition based on some value in the `CharacterInfo`, then make a series of
choices based on that. For example, if the character has `Leather` in their equipment, then they should pick a some leather
torso and arm armor:

```json
{
    "conditions": [
        {
            "equipment": [
                "Leather"
            ]
        }
    ],
    "choices": [
        {
            "choose": 1,
            "from": [
                "sheets/torso/leather/chest_{{gender}}.png",
                "sheets/torso/leather/shoulders_{{gender}}.png"
            ]
        },
        {
            "choose": 1,
            "from": [
                "sheets/hands/bracers/{{gender}}/leather_bracers_{{gender}}.png"
            ]
        }
    ]
}
```

Note: I have a special `{{gender}}` entry in there that I will replace with a randomly selected gender when I actually
create the sprite sheet.

The above JSON will check and see if the equipment of the character contains `Leather`, then it will choose one piece of
torso armor and one piece of arm armor. I will expand on this to be a list of choices like this, where the order will be
the layer of the PNG. So I will select the body first, then some facial features and hair, then clothes, then weapons. 
[See the full JSON definition here](https://github.com/nprice1/characterCreator/blob/master/java11/src/main/resources/com/nolanprice/sprite/allowedPaths.json).

This can be translated into this Java model:

```java
public class AllowedPaths {

    public enum InfoAttribute {
        @JsonProperty("equipment")
        EQUIPMENT,
        @JsonProperty("race")
        RACE,
        @JsonProperty("gender")
        GENDER;
    }

    private List<Map<InfoAttribute, List<String>>> conditions;
    private List<Choice<String>> choices;

    public List<Map<InfoAttribute, List<String>>> getConditions() {
        return conditions;
    }

    public List<Choice<String>> getChoices() {
        return choices;
    }
}
```

# Sprite Subscriber (Flow API)

Now that I have an abstraction for getting all of the paths we need to overlay for the final sprite sheet, it's time for 
some more unnecessary asynchronous calls! For this I'm going to play around with the 
[Flow API](https://docs.oracle.com/javase/9/docs/api/java/util/concurrent/Flow.html) since I have never used it before. This
is a pretty terrible use case for this since order is incredibly important, but in my testing it didn't turn out horribly 
so I just stuck with it. At some point I might add a `layer` concept into the abstraction so I can build all the layers
then merge them all together at the very end.

I'm going to make a simple subscriber that expects to be handed a list of paths that it needs to fetch and overlay. I also
want it to be able to report when it is done. I could do that by having it utilize a `CompeltableFuture`, but I decided
instead to use a `CountdownLatch` since I haven't used them much and I know how many times I'm going to run this upfront.
To initialize my subscriber, I just create an empty image of the size of the final sprite sheet, and save the latch I will
use to mark when the subscriber has finished:

```java
public class SpriteSubscriber implements Flow.Subscriber<Set<String>> {

    private static final Logger LOGGER = LoggerFactory.getLogger(SpriteSubscriber.class);

    private static final int WIDTH = 832;
    private static final int HEIGHT = 1344;

    private final BufferedImage spriteSheet;
    private final CountDownLatch latch;
    private Flow.Subscription subscription;

    public SpriteSubscriber(CountDownLatch latch) {
        this.spriteSheet = new BufferedImage(WIDTH, HEIGHT, BufferedImage.TYPE_INT_ARGB);
        this.latch = latch;
    }

    public BufferedImage getSpriteSheet() {
        return spriteSheet;
    }
}
```

This class is going to need to construct the actual file paths for each file, and also fetch them as a `BufferedImage` so I 
can overlay them, which means I need some simple helper methods:

```java
private URI getFilePath(String fileLocation) {
    try {
        return getClass().getResource(fileLocation)
                         .toURI();
    } catch (Exception e) {
        LOGGER.error(String.format("Failed to construct file path: %s", fileLocation), e);
        throw new RuntimeException(e);
    }
}

private BufferedImage readImage(String fileLocation) throws IOException {
    return ImageIO.read(new File(getFilePath(fileLocation)));
}
```

And I also need a method that will overlay transparent images on the base image I created, which was surprisingly simple:

```java
private void overlayPaths(Set<String> paths) throws IOException {
    if (paths.isEmpty()) {
        return;
    }
    Graphics2D g = this.spriteSheet.createGraphics();
    g.setRenderingHint(RenderingHints.KEY_ANTIALIASING,
                       RenderingHints.VALUE_ANTIALIAS_ON);
    for (String path : paths) {
        BufferedImage image = readImage(path);
        g.drawImage(image, 0, 0, null);
    }

    g.dispose();
}
```

Finally I am ready to implement the `Flow.Subscriber` methods:

```java
@Override
public void onSubscribe(Flow.Subscription subscription) {
    this.subscription = subscription;
    subscription.request(1);
}

@Override
public void onNext(Set<String> paths) {
    try {
        overlayPaths(paths);
        latch.countDown();
        subscription.request(1);
    } catch (IOException e) {
        LOGGER.error("Failed to overlay paths", e);
    }
}

@Override
public void onError(Throwable throwable) {
    LOGGER.error("Failed to process message", throwable);
}

@Override
public void onComplete() {
    LOGGER.info("Finished building sprite sheet");
}
```

The `onSubscribe()` function will immediately request the first result, since there is no use waiting. Then for each set of
paths (`onNext()`), it will overlay the paths, tell the latch is has completed a task, and request the next batch of paths. 
Whenever an error occurs, we will just log it. This means that we may end up with a weird sprite sheet missing some layers,
or just an entirely blank one. Not ideal error handling, but it might yield some interesting character designs so I'm just
leaving it as is for now. Finally, whenever the publisher says it is done we log it.

# Sprite Builder

Now I'm ready to actually build the sprite sheet. This will require

1. Determining which paths should be used for the images
2. Overlaying said images

## Determine Allowed Paths

In order to determine the allowed paths, I need a bit of stuff up front:

```java
@Component
public class SpriteBuilder {

    private static final Logger LOGGER = LoggerFactory.getLogger(SpriteBuilder.class);

    private static final List<String> GENDERS = ImmutableList.of("male", "female");
    private static final Random RANDOM = new Random();
    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private static final ExecutorService EXECUTOR = Executors.newFixedThreadPool(10);

    private static final List<AllowedPaths> ALLOWED_PATHS;
    static {
        List<AllowedPaths> allowedPaths = Collections.emptyList();
        try {
            allowedPaths = OBJECT_MAPPER.readValue(SpriteBuilder.class.getResourceAsStream("allowedPaths.json"),
                                                   new TypeReference<>() {});
        } catch (Exception e) {
            LOGGER.error("Failed to load allowed paths mapping file", e);
        }
        ALLOWED_PATHS = allowedPaths;
    }
}
```

This setup will allow selecting a random gender, determining the full list of paths I could select from, and initializes
an `ExecutorService` I can use for the async publisher I will use to tell my fancy subscriber it has work to do. Now that I
have that setup, I can make my function to determine allowed paths based on the provided `CharacterInfo`. I will need to
know the race, list of equipment, and the gender for the character:

```java
private Set<String> evaluateAllowedPaths(AllowedPaths allowedPaths,
                                         String race,
                                         List<String> equipmentNames,
                                         String gender) {
    // Treat conditions as ANDs
    for (Map<AllowedPaths.InfoAttribute, List<String>> condition : allowedPaths.getConditions()) {
        if (condition == null) {
            continue;
        }
        List<String> equipmentConditions = condition.get(AllowedPaths.InfoAttribute.EQUIPMENT);
        if (equipmentConditions != null && !CollectionUtils.containsAny(equipmentConditions, equipmentNames)) {
            return Collections.emptySet();
        }

        List<String> raceConditions = condition.get(AllowedPaths.InfoAttribute.RACE);
        if (raceConditions != null && !raceConditions.contains(race)) {
            return Collections.emptySet();
        }

        List<String> genderConditions = condition.get(AllowedPaths.InfoAttribute.GENDER);
        if (genderConditions != null && !genderConditions.contains(gender)) {
            return Collections.emptySet();
        }
    }
    Set<String> paths = new HashSet<>();
    for (Choice<String> pathChoice : allowedPaths.getChoices()) {
        paths.addAll(ChoiceUtils.makeRandomChoices(pathChoice));
    }
    return paths.stream()
                .map(path -> path.replace("{{gender}}", gender))
                .collect(Collectors.toSet());
}
```

The first loop just explicitly calls out the possible conditions and checks them. Everything within the list provided
in the condition is valid, so it is an `OR` query, where as if there are multiple conditions, both must be true 
(`AND` query). Once I confirm the given condition is satisfied, I can just make a random choice, do my special 
string replacement to ensure the `gender` is accurate for all choices, and go on my way.

Now I am ready for the meat and potatoes of this work: coordinating the flow. This requires creating an instance of the
sprite subscriber defined above, as well as a publisher that will call out every time a batch of paths is ready 
(a new layer). Since I know how possible layers there are, I can just create a countdown latch based on that so the
subscriber can inform me when it is finished:

```java
public byte[] buildSpriteSheet(CharacterInfo characterInfo) throws IOException {
    String race = characterInfo.getRace();
    List<String> equipmentNames = characterInfo.getEquipment()
                                                .stream()
                                                .map(Equipment::getName)
                                                .collect(Collectors.toList());
    String gender = GENDERS.get(RANDOM.nextInt(2));

    SubmissionPublisher<Set<String>> publisher = new SubmissionPublisher<>(EXECUTOR, 10);
    CountDownLatch countDownLatch = new CountDownLatch(ALLOWED_PATHS.size());
    SpriteSubscriber spriteSubscriber = new SpriteSubscriber(countDownLatch);
    publisher.subscribe(spriteSubscriber);
    for (AllowedPaths allowedPaths : ALLOWED_PATHS) {
        Set<String> paths = evaluateAllowedPaths(allowedPaths, race, equipmentNames, gender);
        publisher.offer(paths,
                        200,
                        TimeUnit.MILLISECONDS,
                        (subscriber, strings) -> {
                            subscriber.onError(new RuntimeException("Dropped message"));
                            return false;
                        });
    }
    try {
        countDownLatch.await();
        publisher.close();
        return toByteArray(spriteSubscriber.getSpriteSheet());
    } catch (InterruptedException e) {
        Thread.currentThread()
                .interrupt();
        return null;
    }
}

private byte[] toByteArray(BufferedImage bufferedImage) throws IOException {
    ByteArrayOutputStream baos = new ByteArrayOutputStream();
    ImageIO.write(bufferedImage, "png", baos);
    return baos.toByteArray();
}
```

The most confusing part is the `offer()` call on the publisher. That one takes in the following parameters:

1. The message payload. In this case, a batch of paths representing a layer of the sprite sheet.
1. The timeout for the process to finish before dropping the message.
1. The time unit for the timeout.
1. A function to execute when a message is dropped. My subscriber will just log it in my current implementation, and I
would just leave that layer out. I also return `false` in the function to indicate the publisher should not retry the 
message, since that could have worse results. 

# Get Sprite Sheet API

Now I can implement the API method to return our brand spankin' new sprite sheet:

```java
@RequestMapping("${openapi.characterCreator.base-path:/character-builder/v1}")
public class SpriteApiController implements SpriteApi {

    private static Logger LOGGER = LoggerFactory.getLogger(SpriteApiController.class);

    private final NativeWebRequest request;
    private final SpriteBuilder spriteBuilder;

    @Autowired
    public SpriteApiController(NativeWebRequest request, SpriteBuilder spriteBuilder) {
        this.request = request;
        this.spriteBuilder = spriteBuilder;
    }

    @Override
    public Optional<NativeWebRequest> getRequest() {
        return Optional.ofNullable(request);
    }

    @Override
    public ResponseEntity<byte[]> getSpriteSheet(CharacterInfo characterInfo) {
        try {
            return ResponseEntity.ok(spriteBuilder.buildSpriteSheet(characterInfo));
        } catch (Exception e) {
            LOGGER.error("Failed to generate sprite sheet", e);
            return new ResponseEntity<>(HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

}
```

# Dockerize

Now that I have all my server code done, I can make a simple Dockerfile to just run the command I was using for 
local development:

```dockerfile
FROM maven:3-adoptopenjdk-11

COPY pom.xml pom.xml
COPY src src/

RUN mvn clean package

EXPOSE 8080
ENTRYPOINT mvn package spring-boot:run
```

And I'm all done! The server is officially complete. However, making a sprite sheet is no fun if I can't see it
in action. And having to parse a bunch of JSON to fill out my character sheet sucks. As much as I am a backend fanboy,
the frontend is where this work will really shine. Although it pains me to say it. Turns out though, I had a lot of fun
making the frontend for this app, check it out in [Part 3](/post/character-creator-pt3.html).