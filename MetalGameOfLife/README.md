# MetalGameOfLife: Data-parallel Programming with the MTLComputeCommandEncoder in Metal

This sample demonstrates the use of data-parallel programming with the MTLComputeCommandEncoder in Metal on OS X, iOS, and tvOS. It implements a version of Conway's Game of Life, a simulation that plays out over time on a two-dimensional grid of cells. 

At each step of the simulation, whether a cell continues in its current state or becomes alive or dead is determined by a series of rules based on the state of its eight nearest neighbors:

  1. Any living cell with fewer than two living neighbors dies
  2. Any living cell with two or three living neighbors continues to live
  3. Any living cell with more than three living neighbors dies
  4. Any dead cell with exactly three living neighbors becomes alive

The central object of the simulation is the renderer, which is created by the view controller and set as the delegate of the view controller's root MTKView. The renderer is responsible for two major tasks, both of which are performed with the aid of the GPU. The first task is calculating the game state from the previous frame's game state. The renderer maintains a collection of single-channel MTLTextures to represent the game grid. Each frame, it applies the rules of the game to the pixels of the most recent game state texture, evolving the simulation by one step. This is done on the GPU by dispatching a set of threadgroups that solve the simulation in parallel, running a kernel function once for each cell (pixel). The second task of the renderer is drawing. Once the new game state is known, the renderer draws a rectangle that covers the entire view, sampling the newly-produced game state texture, and applying a color map to signify whether a cell is alive, or if it is not alive, how long it has been dead.

The simulation is interactive. On OS X, clicking and dragging the mouse in the simulation window activates cells at random in the vicinity of the cursor. Similarly on tvOS, the cursor follows touches on the Touch surface of the Siri remote. On iOS, multitouch can be used to activate cells in the vincinity of several cells at once.

This sample uses features of MetalKit, including MTKView and MTKTextureLoader, to simplify working with Metal.

## Requirements

iOS, tvOS, or OS X device supporting Metal
 
### Build
 
Xcode 7.2, iOS 9.0 SDK, tvOS 9.1 SDK, OS X 10.11 SDK
 
### Runtime
 
iOS 9.0, tvOS 9.1, or OS X 10.11
 
Copyright (C) 2016 Apple Inc. All rights reserved.
