+++
date = "2017-02-27T14:37:08-08:00"
title = "Wator Simulation in Haskell"
draft = false
tags = ["haskell", "wator"]
+++

For my first blog post, I'm going back in time. Whoo. This is a project I did for one of my college classes for the explicit purpose of getting used to writing a blog around code, so I thought this would be a good start to this whole writing words instead of code thing. Haskell is one of my favorite languages, and this was my first real project I wrote in it. Buckle up. (In case you want to skip all my college level babbling [click here to see the source code](#full-source))

This is a simplified [Wa-Tor simulation](https://en.wikipedia.org/wiki/Wa-Tor). In it, there is a world of size _n_ x _n_ populated by either a Fish, a Shark, or it is empty. In the original Wator simulation, algae is also taken into account, but in this implementation it is assumed that algae is ubiquitous, so it is impossible for any fish to starve since they can always find algae to eat. The world is simulated using an array indexed with two integers to represent a 2d world. We need to also randomly populate the world, so we need to utilize random number generators. So, the following imports are required:
```
import Data.Array
import Data.List
import System.Random
```
Next, we will define the CellState structure which can be a Fish, a Shark, or Empty:
```
data CellState = Empty | Shark Int Int Bool | Fish Int Bool
     deriving (Eq, Show)
```
The Shark and Fish states require some extra information. The Integers for the shark represent the time it takes for a shark to starve and the time it takes for a shark to breed respectively. The starve time will decrease at every time step the shark does not eat a fish, and will reset when a shark manages to eat a fish. The breed counter will decrease at every time step. The Int in the fish state represents the time it takes for a fish to breed. The boolean value in the shark and fish both represent whether or not the animal has already moved in this timestep to avoid sharks or fish that move more than one space per time step. Next, we define global variables to define the size of the world, the time for a fish to breed, the time for a shark to breed, and the time for a shark to starve. These are the most important aspects to change to see a different version of the simulation:
```
-- Initial Size
wSize :: Int
wSize = 50

-- Hard coded breed time for fish
fBreed :: Int
fBreed = 10

-- Hard coded breed time for sharks
sBreed :: Int
sBreed = 10

-- Hard coded starve time for sharks
sStarve :: Int
sStarve = 10
```
Now, we need to create a random number generator and a function that gets a random number between 0 and 2 to assign a random state to each cell. First, we define a random number generator that gets a root equal to the size of the world so each time a different size world is made there will be a different set of random numbers:
```
-- Initial random number generator
generator :: StdGen
generator = mkStdGen wSize
```
Next, we make the function that gets a random number between 0 and 2:
```
getRandomInit :: StdGen -> (Int, StdGen)
getRandomInit gen = randomR (0,2) gen
```
In order to generate a different random number for each cell, we will make a list of random numbers to pass around to the function that initializes the world:
```
mkList :: Int -> StdGen -> [Int] -> [Int]
mkList count gen xs = let (x, g) = getRandomInit gen
                      in
                        if (count == 0) then xs
                        else mkList (count - 1) g ([x] ++ xs)
```
Finally, we can initialize the world. This function will create an Array of the given size by assigning a State to a list of random numbers using a function that converts a number to a state (defined below). Since Haskell does not allow side-effects, to generate "randomness" I created a getNum function that picks various elements in the list of random numbers:
```
-- Make an array of size s with random Sharks, Fish, and Empty cellstates to represent the initial World
mkWorld :: Int -> Array (Int, Int) CellState
mkWorld size = array ((0,0), (size-1,size-1)) [ ((i,j), states !! getNum (i,j)) | i <- [0..size-1], j <- [0..size-1] ]
                          where states = map mkState (mkList (wSize * wSize) generator [])

getNum :: (Int, Int) -> Int
getNum (x,y) = if (x == 0)
                  then y
               else if (y == 0)
                  then x
               else if (mod x 5 == 0)
                  then x*y+wSize
               else if (mod y 5 == 0)
                  then wSize-y
               else if (mod y 4 == 0)
                  then x*wSize+4
               else if (mod x 4 == 0)
                  then x+y+wSize
               else if (mod x 3 == 0)
                  then y-3+wSize
               else if (mod y 3 == 0)
                  then y*wSize
               else y+wSize

-- Function that returns a CellState given a random number between 0 and 2
mkState :: Int -> CellState
mkState x
          | (x == 0)  = Empty
          | (x == 1)  = Fish fBreed False
          | otherwise = Shark sStarve sBreed False
```
Now we can create all the logic of the simulation. This function will update the 4 point neighborhood around the given index. In it, we first check if the given cell is Empty. If it is, then nothing changes. If the cell is a fish, then we make sure it hasn't moved already. If it has, then it will breed if possible. Breeding will create a new fish in an adjacent empty cell and will reset the breed time of the fish that bred. If the fish can't breed, then it will move to an empty space if possible. If the given cell is a Shark, then we check if it has already moved. If not, we check to see if the shark has starved. If it has, then we remove the shark from the world. Next, the shark will try to eat. Using the isFish function, we determine if a fish is adjacent to the shark. If there is a nearby fish, the shark will eat it and the starvation time will be reset. If there are no fish, then the shark will try and move to an empty space:
```
-- Function to update a single cell
updateCell :: Array (Int, Int) CellState -> (Int, Int) -> Array (Int, Int) CellState
updateCell a (x,y) = let north = a ! (mod (x-1+wSize) wSize, y)
                         east  = a ! (x, mod (y+1+wSize) wSize)
                         west  = a ! (x, mod (y-1+wSize) wSize)
                         south = a ! (mod (x+1+wSize) wSize, y)
                         cur   = a ! (x,y)
                      in
                         case cur of
                              Empty                    -> a

                              Fish breed moved         -> if (moved)
                                                             then a
                                                          else if (breed == 0 && north == Empty)
                                                             then a // [ ((x,y), Fish fBreed False), ((mod (x-1+wSize) wSize, y), Fish fBreed False) ]
                                                          else if (breed == 0 && south == Empty)
                                                             then a // [ ((x,y), Fish fBreed False), ((mod (x+1+wSize) wSize, y), Fish fBreed False) ]
                                                          else if (breed == 0 && east == Empty)
                                                             then a // [ ((x,y), Fish fBreed False), ((x, mod (y+1+wSize) wSize), Fish fBreed False) ]
                                                          else if (breed == 0 && west == Empty)
                                                             then a // [ ((x,y), Fish fBreed False), ((x, mod (y-1+wSize) wSize), Fish fBreed False) ]
                                                          else if (north == Empty)
                                                             then a // [ ((x,y), Empty), ((mod (x-1+wSize) wSize, y), Fish (breed - 1) True) ]
                                                          else if (south == Empty)
                                                             then a // [ ((x,y), Empty), ((mod (x+1+wSize) wSize, y), Fish (breed - 1) True) ]
                                                          else if (east == Empty)
                                                             then a // [ ((x,y), Empty), ((x, mod (y+1+wSize) wSize), Fish (breed - 1) True) ]
                                                          else if (west == Empty)
                                                             then a // [ ((x,y), Empty), ((x, mod (y-1+wSize) wSize), Fish (breed - 1) True) ]
                                                          else a // [ ((x,y), Fish (breed - 1) False) ]

                              Shark starve breed moved -> if (moved)
                                                             then a
                                                          else if (starve == 0)
                                                             then a // [ ((x,y), Empty) ]
                                                          else if (breed == 0 && north == Empty)
                                                             then a // [ ((x,y), Shark sStarve sBreed False), ((mod (x-1+wSize) wSize, y), Shark (starve-1) sBreed False) ]
                                                          else if (breed == 0 && south == Empty)
                                                             then a // [ ((x,y), Shark sStarve sBreed False), ((mod (x+1+wSize) wSize, y), Shark (starve-1) sBreed False) ]
                                                          else if (breed == 0 && east == Empty)
                                                             then a // [ ((x,y), Shark sStarve sBreed False), ((x, mod (y+1+wSize) wSize), Shark (starve-1) sBreed False) ]
                                                          else if (breed == 0 && west == Empty)
                                                             then a // [ ((x,y), Shark sStarve sBreed False), ((x, mod (y-1+wSize) wSize), Shark (starve-1) sBreed False) ]
                                                          else if (isFish north)
                                                             then a // [ ((x,y), Empty), ((mod (x-1+wSize) wSize, y), Shark sStarve (breed - 1) True) ]
                                                          else if (isFish south)
                                                             then a // [ ((x,y), Empty), ((mod (x+1+wSize) wSize, y), Shark sStarve (breed - 1) True) ]
                                                          else if (isFish east)
                                                             then a // [ ((x,y), Empty), ((x, mod (y+1+wSize) wSize), Shark sStarve (breed - 1) True) ]
                                                          else if (isFish west)
                                                             then a // [ ((x,y), Empty), ((x, mod (y-1+wSize) wSize), Shark sStarve (breed - 1) True) ]
                                                           else if (north == Empty)
                                                             then a // [ ((x,y), Empty), ((mod (x-1+wSize) wSize, y), Shark (starve-1) (breed - 1) True) ]
                                                          else if (south == Empty)
                                                             then a // [ ((x,y), Empty), ((mod (x+1+wSize) wSize, y), Shark (starve-1) (breed - 1) True) ]
                                                          else if (east == Empty)
                                                             then a // [ ((x,y), Empty), ((x, mod (y+1+wSize) wSize), Shark (starve-1) (breed - 1) True) ]
                                                          else if (west == Empty)
                                                             then a // [ ((x,y), Empty), ((x, mod (y-1+wSize) wSize), Shark (starve-1) (breed - 1) True) ]
                                                          else a // [ ((x,y), Shark (starve - 1) (breed - 1) False) ]

-- Boolean function to test if the cell is a Fish
isFish :: CellState -> Bool
isFish s = case s of
                Fish b m         -> True
                Shark s b m      -> False
                Empty            -> False
```
Now we have to apply the updateCell function to all elements in the array. The updateWorld function does just that:
```
--Function to update the World
updateWorld :: Array (Int, Int) CellState -> Int -> Int -> Array (Int, Int) CellState
updateWorld w width height = let allIndices = [ (i,j) | i <- [0..width-1], j <- [0..height-1] ]
                               in foldl updateCell w allIndices
```
Now we define a function that will update the world a given number of times so we can observe the behavior of the simulation over long periods of time. This function will just recurse the given number of time steps over the updateWorld function, making sure to reset the moved value of each animal between steps (more about that below):
```
-- Function to run through x number of time-steps
timeSteps :: Array (Int, Int) CellState -> Int -> Array (Int, Int) CellState
timeSteps a count = if (count == 0) then a
                    else timeSteps newWorld (count-1)
                           where newWorld = updateWorld (resetAll a wSize wSize) wSize wSize
```
After we update the world, we have to make sure that we reset the moved value for all animals so it is possible for them to move on the next iteration. Using a similar structure as the updateCell and updateWorld functions, we define a function that will reset one animal given its coordinates. Then we make a function that will apply the reset function to all elements in the world:
```
-- Function to reset the moved value an animal cell
resetOne :: Array (Int, Int) CellState -> (Int, Int) -> Array (Int, Int) CellState
resetOne a (x,y) = let cur = a ! (x,y)
                     in
                        case cur of
                             Empty              -> a

                             Fish b moved       -> if (moved)
                                                      then a // [ ((x,y), Fish b False) ]
                                                   else a

                             Shark s b moved    -> if (moved)
                                                      then a // [ ((x,y), Shark s b False) ]
                                                   else a

-- Function to reset the moved value of all cells
resetAll :: Array (Int, Int) CellState -> Int -> Int -> Array (Int, Int) CellState
resetAll a width height = let allIndices = [ (i,j) | i <- [0..width-1], j <- [0..height-1] ]
                            in foldl resetOne a allIndices
```
Next, we have to actually print the world to observe the behavior. Again using the same kind of structure, we define a function that prints a given coordinate, and then we create a function that will apply this print function to all elements in the world. The print function prints '.' for Empty, 'F' for Fish, and 'S' for a Shark. For simple code, there is also a function that makes a list of the print actions and the the printWorld function goes through this list and executes all of the IO actions:
```
-- Function to print a Cell
printCell :: Array (Int, Int) CellState -> (Int, Int) -> IO ()
printCell a (x,y) = let cur = a ! (x,y)
                    in
                       case cur of
                            Empty       -> if (y == wSize-1 && x == wSize-1)
                                              then do putStr ".\n\n"
                                           else if (y == wSize-1)
                                              then do putStr ".\n"
                                           else do putStr ". "
                            Fish b m    -> if (y == wSize-1 && x == wSize-1)
                                              then do putStr "F\n\n"
                                           else if (y == wSize-1)
                                              then do putStr "F\n"
                                           else do putStr "F "
                            Shark s b m -> if (y == wSize-1 && x == wSize-1)
                                              then do putStr "S\n\n"
                                           else if (y == wSize-1)
                                              then do putStr "S\n"
                                           else do putStr "S "

-- Function make a list of IO () actions to print the world
printList :: Array (Int, Int) CellState -> [IO ()]
printList a = [ printCell a (i,j) | i <- [0..wSize-1], j <- [0..wSize-1] ]

-- Function to print the world
printWorld :: [IO ()] -> IO ()
printWorld [] = do return ()
printWorld (x:xs) = do x
                       printWorld xs
```
Finally, we will create the main function that will print the world after each update interval. First, we make a recursive function that will print the updated world, and then recurse over the updated world. The main function simply initializes the world and prints it, then lets the mainStep function take over and print any number of updates. The number of time steps between prints can be altered by changing the value of the pass to the timeSteps function. The number of times to print out the world can be changed by changing the number passed to the mainStep function:
```
-- Recursive function to print out the world at 10 timeStep intervals
mainStep :: Array (Int, Int) CellState -> Int -> IO ()
mainStep world count = if (count == 0)
                          then do return ()
                       else
                          do printWorld $ printList $ timeSteps world 10
                             mainStep (timeSteps world 10) (count-1)

-- Main function to step through and print world
main :: IO ()
main = let world = mkWorld wSize
         in
            do
                printWorld $ printList world
                mainStep world 100
```
## Full Source {#full-source}
```
module Wator (
) where

import Data.Array
import Data.List
import System.Random

data CellState = Empty | Shark Int Int Bool | Fish Int Bool
     deriving (Eq, Show)

-- Initial Size
wSize :: Int
wSize = 50

-- Hard coded breed time for fish
fBreed :: Int
fBreed = 10

-- Hard coded breed time for sharks
sBreed :: Int
sBreed = 10

-- Hard coded starve time for sharks
sStarve :: Int
sStarve = 10

-- Initial random number generator
generator :: StdGen
generator = mkStdGen wSize

getRandomInit :: StdGen -> (Int, StdGen)
getRandomInit gen = randomR (0,2) gen

mkList :: Int -> StdGen -> [Int] -> [Int]
mkList count gen xs = let (x, g) = getRandomInit gen
                      in
                        if (count == 0) then xs
                        else mkList (count - 1) g ([x] ++ xs)

-- Make an array of size s with random Sharks, Fish, and Empty cellstates to represent the initial World
mkWorld :: Int -> Array (Int, Int) CellState
mkWorld size = array ((0,0), (size-1,size-1)) [ ((i,j), states !! getNum (i,j)) | i <- [0..size-1], j <- [0..size-1] ]
                          where states = map mkState (mkList (wSize * wSize) generator [])

getNum :: (Int, Int) -> Int
getNum (x,y) = if (x == 0)
                  then y
               else if (y == 0)
                  then x
               else if (mod x 5 == 0)
                  then x*y+wSize
               else if (mod y 5 == 0)
                  then wSize-y
               else if (mod y 4 == 0)
                  then x*wSize+4
               else if (mod x 4 == 0)
                  then x+y+wSize
               else if (mod x 3 == 0)
                  then y-3+wSize
               else if (mod y 3 == 0)
                  then y*wSize
               else y+wSize

-- Function that returns a CellState given a random number between 0 and 2
mkState :: Int -> CellState
mkState x
          | (x == 0)  = Empty
          | (x == 1)  = Fish fBreed False
          | otherwise = Shark sStarve sBreed False

-- Function to update a single cell
updateCell :: Array (Int, Int) CellState -> (Int, Int) -> Array (Int, Int) CellState
updateCell a (x,y) = let north = a ! (mod (x-1+wSize) wSize, y)
                         east  = a ! (x, mod (y+1+wSize) wSize)
                         west  = a ! (x, mod (y-1+wSize) wSize)
                         south = a ! (mod (x+1+wSize) wSize, y)
                         cur   = a ! (x,y)
                      in
                         case cur of
                              Empty                    -> a

                              Fish breed moved         -> if (moved)
                                                             then a
                                                          else if (breed == 0 && north == Empty)
                                                             then a // [ ((x,y), Fish fBreed False), ((mod (x-1+wSize) wSize, y), Fish fBreed False) ]
                                                          else if (breed == 0 && south == Empty)
                                                             then a // [ ((x,y), Fish fBreed False), ((mod (x+1+wSize) wSize, y), Fish fBreed False) ]
                                                          else if (breed == 0 && east == Empty)
                                                             then a // [ ((x,y), Fish fBreed False), ((x, mod (y+1+wSize) wSize), Fish fBreed False) ]
                                                          else if (breed == 0 && west == Empty)
                                                             then a // [ ((x,y), Fish fBreed False), ((x, mod (y-1+wSize) wSize), Fish fBreed False) ]
                                                          else if (north == Empty)
                                                             then a // [ ((x,y), Empty), ((mod (x-1+wSize) wSize, y), Fish (breed - 1) True) ]
                                                          else if (south == Empty)
                                                             then a // [ ((x,y), Empty), ((mod (x+1+wSize) wSize, y), Fish (breed - 1) True) ]
                                                          else if (east == Empty)
                                                             then a // [ ((x,y), Empty), ((x, mod (y+1+wSize) wSize), Fish (breed - 1) True) ]
                                                          else if (west == Empty)
                                                             then a // [ ((x,y), Empty), ((x, mod (y-1+wSize) wSize), Fish (breed - 1) True) ]
                                                          else a // [ ((x,y), Fish (breed - 1) False) ]

                              Shark starve breed moved -> if (moved)
                                                             then a
                                                          else if (starve == 0)
                                                             then a // [ ((x,y), Empty) ]
                                                          else if (breed == 0 && north == Empty)
                                                             then a // [ ((x,y), Shark sStarve sBreed False), ((mod (x-1+wSize) wSize, y), Shark (starve-1) sBreed False) ]
                                                          else if (breed == 0 && south == Empty)
                                                             then a // [ ((x,y), Shark sStarve sBreed False), ((mod (x+1+wSize) wSize, y), Shark (starve-1) sBreed False) ]
                                                          else if (breed == 0 && east == Empty)
                                                             then a // [ ((x,y), Shark sStarve sBreed False), ((x, mod (y+1+wSize) wSize), Shark (starve-1) sBreed False) ]
                                                          else if (breed == 0 && west == Empty)
                                                             then a // [ ((x,y), Shark sStarve sBreed False), ((x, mod (y-1+wSize) wSize), Shark (starve-1) sBreed False) ]
                                                          else if (isFish north)
                                                             then a // [ ((x,y), Empty), ((mod (x-1+wSize) wSize, y), Shark sStarve (breed - 1) True) ]
                                                          else if (isFish south)
                                                             then a // [ ((x,y), Empty), ((mod (x+1+wSize) wSize, y), Shark sStarve (breed - 1) True) ]
                                                          else if (isFish east)
                                                             then a // [ ((x,y), Empty), ((x, mod (y+1+wSize) wSize), Shark sStarve (breed - 1) True) ]
                                                          else if (isFish west)
                                                             then a // [ ((x,y), Empty), ((x, mod (y-1+wSize) wSize), Shark sStarve (breed - 1) True) ]
                                                           else if (north == Empty)
                                                             then a // [ ((x,y), Empty), ((mod (x-1+wSize) wSize, y), Shark (starve-1) (breed - 1) True) ]
                                                          else if (south == Empty)
                                                             then a // [ ((x,y), Empty), ((mod (x+1+wSize) wSize, y), Shark (starve-1) (breed - 1) True) ]
                                                          else if (east == Empty)
                                                             then a // [ ((x,y), Empty), ((x, mod (y+1+wSize) wSize), Shark (starve-1) (breed - 1) True) ]
                                                          else if (west == Empty)
                                                             then a // [ ((x,y), Empty), ((x, mod (y-1+wSize) wSize), Shark (starve-1) (breed - 1) True) ]
                                                          else a // [ ((x,y), Shark (starve - 1) (breed - 1) False) ]

-- Boolean function to test if the cell is a Fish
isFish :: CellState -> Bool
isFish s = case s of
                Fish b m         -> True
                Shark s b m      -> False
                Empty            -> False

--Function to update the World
updateWorld :: Array (Int, Int) CellState -> Int -> Int -> Array (Int, Int) CellState
updateWorld w width height = let allIndices = [ (i,j) | i <- [0..width-1], j <- [0..height-1] ]
                               in foldl updateCell w allIndices

-- Function to run through x number of time-steps
timeSteps :: Array (Int, Int) CellState -> Int -> Array (Int, Int) CellState
timeSteps a count = if (count == 0) then a
                    else timeSteps newWorld (count-1)
                           where newWorld = updateWorld (resetAll a wSize wSize) wSize wSize

-- Function to reset the moved value an animal cell
resetOne :: Array (Int, Int) CellState -> (Int, Int) -> Array (Int, Int) CellState
resetOne a (x,y) = let cur = a ! (x,y)
                     in
                        case cur of
                             Empty              -> a

                             Fish b moved       -> if (moved)
                                                      then a // [ ((x,y), Fish b False) ]
                                                   else a

                             Shark s b moved    -> if (moved)
                                                      then a // [ ((x,y), Shark s b False) ]
                                                   else a

-- Function to reset the moved value of all cells
resetAll :: Array (Int, Int) CellState -> Int -> Int -> Array (Int, Int) CellState
resetAll a width height = let allIndices = [ (i,j) | i <- [0..width-1], j <- [0..height-1] ]
                            in foldl resetOne a allIndices

-- Function to print a Cell
printCell :: Array (Int, Int) CellState -> (Int, Int) -> IO ()
printCell a (x,y) = let cur = a ! (x,y)
                    in
                       case cur of
                            Empty       -> if (y == wSize-1 && x == wSize-1)
                                              then do putStr ".\n\n"
                                           else if (y == wSize-1)
                                              then do putStr ".\n"
                                           else do putStr ". "
                            Fish b m    -> if (y == wSize-1 && x == wSize-1)
                                              then do putStr "F\n\n"
                                           else if (y == wSize-1)
                                              then do putStr "F\n"
                                           else do putStr "F "
                            Shark s b m -> if (y == wSize-1 && x == wSize-1)
                                              then do putStr "S\n\n"
                                           else if (y == wSize-1)
                                              then do putStr "S\n"
                                           else do putStr "S "

-- Function make a list of IO () actions to print the world
printList :: Array (Int, Int) CellState -> [IO ()]
printList a = [ printCell a (i,j) | i <- [0..wSize-1], j <- [0..wSize-1] ]

-- Function to print the world
printWorld :: [IO ()] -> IO ()
printWorld [] = do return ()
printWorld (x:xs) = do x
                       printWorld xs

-- Recursive function to print out the world at 10 timeStep intervals
mainStep :: Array (Int, Int) CellState -> Int -> IO ()
mainStep world count = if (count == 0)
                          then do return ()
                       else
                          do printWorld $ printList $ timeSteps world 10
                             mainStep (timeSteps world 10) (count-1)

-- Main function to step through and print world
main :: IO ()
main = let world = mkWorld wSize
         in
            do
                printWorld $ printList world
                mainStep world 100

```
