/*
Copyright (C) 2016 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
The renderer class for the Game of Life sample. Responsible for enqueuing compute and render work on the GPU.
*/

#import "AAPLRenderer.h"

static const NSUInteger kTextureCount = 3;
static const CGFloat kInitialAliveProbability = 0.1;
static const uint8_t kCellValueAlive = 0;
static const uint8_t kCellValueDead = 255;

static const NSInteger kMaxInflightBuffers = 3;

@interface AAPLRenderer ()
@property (nonatomic, weak) MTKView *view;
@property (nonatomic, weak) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLLibrary> library;
@property (nonatomic, strong) id<MTLRenderPipelineState> renderPipelineState;
@property (nonatomic, strong) id<MTLComputePipelineState> simulationPipelineState;
@property (nonatomic, strong) id<MTLComputePipelineState> activationPipelineState;
@property (nonatomic, strong) id<MTLSamplerState> samplerState;
@property (nonatomic, strong) NSMutableArray<id<MTLTexture>> *textureQueue;
@property (nonatomic, strong) id<MTLTexture> currentGameStateTexture;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic, strong) id<MTLTexture> colorMap;
@property (nonatomic, strong) NSMutableArray<NSValue *> *activationPoints;
@property (nonatomic, strong) dispatch_semaphore_t inflightSemaphore;
@property (nonatomic, strong) NSDate *nextResizeTimestamp;
@end

@implementation AAPLRenderer

#pragma mark - Initializer

- (instancetype)initWithView:(MTKView *)view
{
    if (view.device == nil) {
        NSLog(@"Cannot create renderer without the view already having an associated Metal device");
        return nil;
    }
    
    if ((self = [super init]))
    {
        _view = view;
        _view.delegate = self;
        
        _device = _view.device;
        _library = [_device newDefaultLibrary];
        _commandQueue = [_device newCommandQueue];
        
        _activationPoints = [NSMutableArray array];
        _textureQueue = [NSMutableArray arrayWithCapacity:kTextureCount];
        
        [self buildRenderResources];
        [self buildRenderPipeline];
        [self buildComputePipelines];
        
        [self reshapeWithDrawableSize:_view.drawableSize];

        self.inflightSemaphore = dispatch_semaphore_create(kMaxInflightBuffers);
    }
    
    return self;
}

#pragma mark - Resource and Pipeline Creation

#if TARGET_OS_IOS || TARGET_OS_TV
- (CGImageRef)CGImageForImageNamed:(NSString *)imageName {
    UIImage *image = [UIImage imageNamed:imageName];
    return [image CGImage];
}
#else
- (CGImageRef)CGImageForImageNamed:(NSString *)imageName {
    NSImage *image = [NSImage imageNamed:imageName];
    return [image CGImageForProposedRect:NULL context:nil hints:nil];
}
#endif

- (void)buildRenderResources
{
    NSError *error = nil;
    
    // Use MTKTextureLoader to load a texture we will use to colorize the simulation
    MTKTextureLoader *textureLoader = [[MTKTextureLoader alloc] initWithDevice:_device];
    CGImageRef colorMapCGImage = [self CGImageForImageNamed:@"colormap"];
    _colorMap = [textureLoader newTextureWithCGImage:colorMapCGImage options:@{} error:&error];
    _colorMap.label = @"Color Map";
    
    if (!_colorMap)
    {
        NSLog(@"Could not create color map texture from main bundle: %@", error);
    }
    
    // Vertex data for a full-screen quad. The first two numbers in each row represent
    // the x, y position of the point in normalized coordinates. The second two numbers
    // represent the texture coordinates for the corresponding position.
    static const float vertexData[] = {
        -1,  1, 0, 0,
        -1, -1, 0, 1,
         1, -1, 1, 1,
         1, -1, 1, 1,
         1,  1, 1, 0,
        -1,  1, 0, 0,
    };
    
    // Create a buffer to hold the static vertex data
    _vertexBuffer = [_device newBufferWithBytes:vertexData
                                         length:sizeof(vertexData)
                                        options:MTLResourceCPUCacheModeDefaultCache | MTLResourceStorageModeShared];
    _vertexBuffer.label = @"Fullscreen Quad Vertices";
}

- (void)buildRenderPipeline {
    NSError *error = nil;
    
    // Retrieve the functions we need to build the render pipeline
    id<MTLFunction> vertexProgram = [_library newFunctionWithName:@"lighting_vertex"];
    id<MTLFunction> fragmentProgram = [_library newFunctionWithName:@"lighting_fragment"];

    // Create a vertex descriptor that describes a vertex with two float2 members:
    // position and texture coordinates
    MTLVertexDescriptor *vertexDescriptor = [MTLVertexDescriptor new];
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0;
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[1].offset = sizeof(float) * 2;
    vertexDescriptor.attributes[1].bufferIndex = 0;
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat2;
    vertexDescriptor.layouts[0].stride = sizeof(float) * 4;
    vertexDescriptor.layouts[0].stepRate = 1;
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    
    // Describe and create a render pipeline state
    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.label = @"Fullscreen Quad Pipeline";
    pipelineStateDescriptor.vertexFunction = vertexProgram;
    pipelineStateDescriptor.fragmentFunction = fragmentProgram;
    pipelineStateDescriptor.vertexDescriptor = vertexDescriptor;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = self.view.colorPixelFormat;
    _renderPipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
    if (!_renderPipelineState)
    {
        NSLog(@"Failed to create render pipeline state, error %@", error);
    }
}

- (void)reshapeWithDrawableSize:(CGSize)drawableSize
{
    // Select a grid size that matches the size of the view in points
    CGFloat scale = self.view.layer.contentsScale;
    MTLSize proposedGridSize = MTLSizeMake(drawableSize.width / scale, drawableSize.height / scale, 1);
    
    if (_gridSize.width != proposedGridSize.width || _gridSize.height != proposedGridSize.height) {
        _gridSize = proposedGridSize;
        [self buildComputeResources];
    }
}

- (void)buildComputeResources
{
    [_textureQueue removeAllObjects];
    _currentGameStateTexture = nil;

    // Create a texture descriptor for the textures we will use to hold the
    // game grid. Each frame, the texture we previously used to draw becomes
    // the texture we use to update the simulation, so every texture is marked
    // as readable and writeable.
    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Uint
                                                                                          width:_gridSize.width
                                                                                         height:_gridSize.height
                                                                                      mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    
    for (NSUInteger i = 0; i < kTextureCount; ++i) {
        id<MTLTexture> texture = [_device newTextureWithDescriptor:descriptor];
        texture.label = [NSString stringWithFormat:@"Game State %d", (int)i];
        [_textureQueue addObject:texture];
    }
    
    // In order to make the simulation visually interesting, we need to seed it with
    // an initial game state that has some living and some dead cells. Here, we create
    // a temporary buffer that holds the initial, randomly-generated game state.
    uint8_t *randomGrid = (uint8_t *)malloc(_gridSize.width * _gridSize.height);
    for (NSUInteger i = 0; i < _gridSize.width; ++i)
    {
        for (NSUInteger j = 0; j < _gridSize.height; ++j)
        {
            uint8_t alive = drand48() < kInitialAliveProbability ? kCellValueAlive : kCellValueDead;
            randomGrid[j * _gridSize.width + i] = alive;
        }
    }
    
    // The texture that will be read from at the start of the simulation is the one
    // at the end of the queue we use to store textures, so we overwrite its
    // contents with the simulation seed data.
    id<MTLTexture> currentReadTexture = [_textureQueue lastObject];
    
    [currentReadTexture replaceRegion:MTLRegionMake2D(0, 0, _gridSize.width, _gridSize.height)
                          mipmapLevel:0
                            withBytes:randomGrid
                          bytesPerRow:_gridSize.width];
    
    free(randomGrid);
}

- (void)buildComputePipelines
{
    NSError *error = nil;
    
    _commandQueue = [_device newCommandQueue];
    
    // The main compute pipeline runs the game of life simulation each frame
    MTLComputePipelineDescriptor *descriptor = [MTLComputePipelineDescriptor new];
    descriptor.computeFunction = [_library newFunctionWithName:@"game_of_life"];
    descriptor.label = @"Game of Life";
    _simulationPipelineState = [_device newComputePipelineStateWithDescriptor:descriptor
                                                                      options:MTLPipelineOptionNone
                                                                   reflection:nil
                                                                        error:&error];
    
    if (!_simulationPipelineState)
    {
        NSLog(@"Error when compiling simulation pipeline state: %@", error);
    }
    
    // The secondary compute pipeline activates cells near a point the user has
    // touched or clicked, making the simulation interactive
    descriptor.computeFunction = [_library newFunctionWithName:@"activate_random_neighbors"];
    descriptor.label = @"Activate Random Neighbors";
    _activationPipelineState = [_device newComputePipelineStateWithDescriptor:descriptor
                                                                      options:MTLPipelineOptionNone
                                                                   reflection:nil
                                                                        error:&error];
    
    if (!_activationPipelineState)
    {
        NSLog(@"Error when compiling activation pipeline state: %@", error);
    }
    
    // Create a sampler state we can use in the compute kernel to read the
    // game state texture, wrapping around the edges in each direction.
    MTLSamplerDescriptor *samplerDescriptor = [MTLSamplerDescriptor new];
    samplerDescriptor.sAddressMode = MTLSamplerAddressModeRepeat;
    samplerDescriptor.tAddressMode = MTLSamplerAddressModeRepeat;
    samplerDescriptor.minFilter = MTLSamplerMinMagFilterNearest;
    samplerDescriptor.magFilter = MTLSamplerMinMagFilterNearest;
    samplerDescriptor.normalizedCoordinates = YES;
    _samplerState = [_device newSamplerStateWithDescriptor:samplerDescriptor];
}

#pragma mark - Interactivity

- (void)activateRandomCellsInNeighborhoodOfCell:(CGPoint)cell
{
    // Here, we simply store the point that was touched/clicked. After the next
    // simulation step, we will activate some random neighbors in the vicinity
    // of the touch point(s).
    [self.activationPoints addObject:[NSValue valueWithBytes:&cell objCType:@encode(CGPoint)]];
}

#pragma mark - Render and Compute Encoding

- (void)encodeComputeWorkInBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    // The grid we read from to update the simulation is the one that was last displayed on the screen
    id<MTLTexture> readTexture = [self.textureQueue lastObject];
    // The grid we write the new game state to is the one at the head of the queue
    id<MTLTexture> writeTexture = [self.textureQueue firstObject];
    
    // Create a compute command encoder with which we can ask the GPU to do compute work
    id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];
    
    // For updating the game state, we divide our grid up into square threadgroups and
    // determine how many we need to dispatch in order to cover the entire grid
    MTLSize threadsPerThreadgroup = MTLSizeMake(16, 16, 1);
    MTLSize threadgroupCount = MTLSizeMake(ceil((float)self.gridSize.width / threadsPerThreadgroup.width),
                                           ceil((float)self.gridSize.height / threadsPerThreadgroup.height),
                                           1);
    
    // Configure the compute command encoder and dispatch the actual work
    [commandEncoder setComputePipelineState:self.simulationPipelineState];
    [commandEncoder setTexture:readTexture atIndex:0];
    [commandEncoder setTexture:writeTexture atIndex:1];
    [commandEncoder setSamplerState:self.samplerState atIndex:0];
    [commandEncoder dispatchThreadgroups:threadgroupCount threadsPerThreadgroup:threadsPerThreadgroup];
    
    // If the user has interacted with the simulation, we now need to dispatch a smaller
    // amount of work to activate random cells near the points they have clicked/touched
    if (self.activationPoints.count > 0)
    {
        // We need the positions to be in a buffer in order to read them in the compute
        // kernel, but since the data is so small, creating a Metal buffer explicitly is
        // unnecessary. Instead, we copy the positions into a temporary array, then
        // use the setBytes:length:atIndex: method to pass them in via an implicit buffer.
        size_t byteCount = self.activationPoints.count * 2 * sizeof(uint32_t);
        uint32_t *cellPositions = (uint32_t *)malloc(byteCount);
        [self.activationPoints enumerateObjectsUsingBlock:^(NSValue *value, NSUInteger i, BOOL *stop) {
            CGPoint point;
            [value getValue:&point];
            cellPositions[i * 2]     = point.x;
            cellPositions[i * 2 + 1] = point.y;
        }];
        
        // Since we have only a small number of points (< 10), we can handle all of them
        // in a single threadgroup. We just make it as wide as the number of points. Each
        // thread will pick up one position and activate some of its neighbors, randomly.
        MTLSize threadsPerThreadgroup = MTLSizeMake(self.activationPoints.count, 1, 1);
        MTLSize threadgroupCount = MTLSizeMake(1, 1, 1);
        
        [commandEncoder setComputePipelineState:self.activationPipelineState];
        [commandEncoder setTexture:writeTexture atIndex:0];
        [commandEncoder setBytes:cellPositions length:byteCount atIndex:0];
        [commandEncoder dispatchThreadgroups:threadgroupCount threadsPerThreadgroup:threadsPerThreadgroup];
        
        [self.activationPoints removeAllObjects];
        free(cellPositions);
    }
    
    [commandEncoder endEncoding];
    
    // Rotate the queue so the texture we just wrote can be in-flight for the next couple of frames
    self.currentGameStateTexture = [self.textureQueue firstObject];
    [self.textureQueue removeObjectAtIndex:0];
    [self.textureQueue addObject:self.currentGameStateTexture];
}

- (void)encodeRenderWorkInBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    MTLRenderPassDescriptor *renderPassDescriptor = self.view.currentRenderPassDescriptor;
    
    if(renderPassDescriptor != nil)
    {
        // Create a render command encoder, which we can use to encode draw calls into the buffer
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        
        // Configure the render encoder for drawing the full-screen quad, then issue the draw call
        [renderEncoder setRenderPipelineState:self.renderPipelineState];
        [renderEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
        [renderEncoder setFragmentTexture:self.currentGameStateTexture atIndex:0];
        [renderEncoder setFragmentTexture:self.colorMap atIndex:1];
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        
        [renderEncoder endEncoding];
        
        // Present the texture we just rendered on the screen
        [commandBuffer presentDrawable:self.view.currentDrawable];
    }
}

#pragma mark - MTKView Delegate Methods

// Called whenever view changes orientation or layout is changed
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    // Since we need to restart the simulation when the drawable size changes,
    // coalesce rapid changes (such as during window resize) into less frequent
    // updates to avoid re-creating expensive resources too often.
    static const NSTimeInterval resizeHysteresis = 0.200;
    self.nextResizeTimestamp = [NSDate dateWithTimeIntervalSinceNow:resizeHysteresis];
    dispatch_after(dispatch_time(0, resizeHysteresis * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if ([self.nextResizeTimestamp timeIntervalSinceNow] <= 0) {
            NSLog(@"Restarting simulation after window was resized...");
            [self reshapeWithDrawableSize:self.view.drawableSize];
        }
    });
}

// Called whenever the view needs to render
- (void)drawInMTKView:(nonnull MTKView *)view
{
    dispatch_semaphore_wait(self.inflightSemaphore, DISPATCH_TIME_FOREVER);
    
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    
    __block dispatch_semaphore_t blockSemaphore = self.inflightSemaphore;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        dispatch_semaphore_signal(blockSemaphore);
    }];
    
    [self encodeComputeWorkInBuffer:commandBuffer];
    
    [self encodeRenderWorkInBuffer:commandBuffer];

    [commandBuffer commit];
}

@end

