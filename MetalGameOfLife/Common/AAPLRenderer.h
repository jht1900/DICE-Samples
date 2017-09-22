/*
Copyright (C) 2016 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
The renderer class for the Game of Life sample. Responsible for enqueuing compute and render work on the GPU.
*/

@import Foundation;
@import MetalKit;

@interface AAPLRenderer : NSObject <MTKViewDelegate>

@property (nonatomic, readonly) MTLSize gridSize;

/// Creates a new renderer and makes it the delegate of the view.
/// The grid size of the simulation is derived from the current
/// drawableSize of the view
- (instancetype)initWithView:(MTKView *)view;

/// Brings random cells in the neighborhood of the provided cell
/// coordinates to life. Can be used with touch or mouse inputs
/// to add interactivity to the simulation.
- (void)activateRandomCellsInNeighborhoodOfCell:(CGPoint)cell;

@end
