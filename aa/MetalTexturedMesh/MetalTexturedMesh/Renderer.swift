/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The Renderer class. This is the reason for the sample. Here you'll find all the detail about how to setup and interact with Metal types to render content to the screen. This type conforms to MTKViewDelegate and performs the rendering in the appropriate call backs. It is created in the ViewController.viewDidLoad() method.
*/

import Metal
import simd
import MetalKit

struct Constants {
    var modelViewProjectionMatrix = matrix_identity_float4x4
    var normalMatrix = matrix_identity_float3x3
}

@objc
class Renderer : NSObject, MTKViewDelegate
{
    weak var view: MTKView!

    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let renderPipelineState: MTLRenderPipelineState
    let depthStencilState: MTLDepthStencilState
    let sampler: MTLSamplerState
    let texture: MTLTexture
    let mesh: Mesh

    var time = TimeInterval(0.0)
    var constants = Constants()

    init?(mtkView: MTKView) {
        
        view = mtkView
        
        // Use 4x MSAA multisampling
        view.sampleCount = 4
        // Clear to solid white
        view.clearColor = MTLClearColorMake(1, 1, 1, 1)
        // Use a BGRA 8-bit normalized texture for the drawable
        view.colorPixelFormat = .bgra8Unorm
        // Use a 32-bit depth buffer
        view.depthStencilPixelFormat = .depth32Float
        
        // Ask for the default Metal device; this represents our GPU.
        if let defaultDevice = MTLCreateSystemDefaultDevice() {
            device = defaultDevice
        }
        else {
            print("Metal is not supported")
            return nil
        }
        
        // Create the command queue we will be using to submit work to the GPU.
        commandQueue = device.makeCommandQueue()

        // Compile the functions and other state into a pipeline object.
        do {
            renderPipelineState = try Renderer.buildRenderPipelineWithDevice(device, view: mtkView)
        }
        catch {
            print("Unable to compile render pipeline state")
            return nil
        }

        mesh = Mesh(cubeWithSize: 1.0, device: device)!
        
        do {
            texture = try Renderer.buildTexture(name: "checkerboard", device)
        }
        catch {
            print("Unable to load texture from main bundle")
            return nil
        }

        // Make a depth-stencil state that passes when fragments are nearer to the camera than previous fragments
        depthStencilState = Renderer.buildDepthStencilStateWithDevice(device, compareFunc: .less, isWriteEnabled: true)
        
        // Make a texture sampler that wraps in both directions and performs bilinear filtering
        sampler = Renderer.buildSamplerStateWithDevice(device, addressMode: .repeat, filter: .linear)
        
        super.init()
        
        // Now that all of our members are initialized, set ourselves as the drawing delegate of the view
        view.delegate = self
        view.device = device
    }
    
    class func buildRenderPipelineWithDevice(_ device: MTLDevice, view: MTKView) throws -> MTLRenderPipelineState {
        // The default library contains all of the shader functions that were compiled into our app bundle
        let library = device.newDefaultLibrary()!
        
        // Retrieve the functions that will comprise our pipeline
        let vertexFunction = library.makeFunction(name: "vertex_transform")
        let fragmentFunction = library.makeFunction(name: "fragment_lit_textured")
        
        // A render pipeline descriptor describes the configuration of our programmable pipeline
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "Render Pipeline"
        pipelineDescriptor.sampleCount = view.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    class func buildTexture(name: String, _ device: MTLDevice) throws -> MTLTexture {
        let textureLoader = MTKTextureLoader(device: device)
        let asset = NSDataAsset.init(name: name)
        if let data = asset?.data {
            return try textureLoader.newTexture(with: data, options: [:])
        } else {
            fatalError("Could not load image \(name) from an asset catalog in the main bundle")
        }
    }
    
    class func buildSamplerStateWithDevice(_ device: MTLDevice,
                                           addressMode: MTLSamplerAddressMode,
                                           filter: MTLSamplerMinMagFilter) -> MTLSamplerState
    {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = addressMode
        samplerDescriptor.tAddressMode = addressMode
        samplerDescriptor.minFilter = filter
        samplerDescriptor.magFilter = filter
        return device.makeSamplerState(descriptor: samplerDescriptor)
    }

    class func buildDepthStencilStateWithDevice(_ device: MTLDevice,
                                                compareFunc: MTLCompareFunction,
                                                isWriteEnabled: Bool) -> MTLDepthStencilState
    {
        let desc = MTLDepthStencilDescriptor()
        desc.depthCompareFunction = compareFunc
        desc.isDepthWriteEnabled = isWriteEnabled
        return device.makeDepthStencilState(descriptor: desc)
    }
    
    func updateWithTimestep(_ timestep: TimeInterval)
    {
        // We keep track of time so we can animate the various transformations
        time = time + timestep
        
        let modelToWorldMatrix = matrix4x4_rotation(Float(time) * 0.5, vector_float3(0.7, 1, 0))
        
        // So that the figure doesn't get distorted when the window changes size or rotates,
        // we factor the current aspect ration into our projection matrix. We also select
        // sensible values for the vertical view angle and the distances to the near and far planes.
        let viewSize = self.view.bounds.size
        let aspectRatio = Float(viewSize.width / viewSize.height)
        let verticalViewAngle = radians_from_degrees(65)
        let nearZ: Float = 0.1
        let farZ: Float = 100.0
        let projectionMatrix = matrix_perspective(verticalViewAngle, aspectRatio, nearZ, farZ)
        
        let viewMatrix = matrix_look_at(0, 0, 2.5, 0, 0, 0, 0, 1, 0)

        // The combined model-view-projection matrix moves our vertices from model space into clip space
        let mvMatrix = matrix_multiply(viewMatrix, modelToWorldMatrix);
        constants.modelViewProjectionMatrix = matrix_multiply(projectionMatrix, mvMatrix)
        constants.normalMatrix = matrix_inverse_transpose(matrix_upper_left_3x3(mvMatrix))
    }

    func render(_ view: MTKView) {
        // Our animation will be dependent on the frame time, so that regardless of how
        // fast we're animating, the speed of the transformations will be roughly constant.
        let timestep = 1.0 / TimeInterval(view.preferredFramesPerSecond)
        updateWithTimestep(timestep)
        
        // Our command buffer is a container for the work we want to perform with the GPU.
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        // Ask the view for a configured render pass descriptor. It will have a loadAction of
        // MTLLoadActionClear and have the clear color of the drawable set to our desired clear color.
        let renderPassDescriptor = view.currentRenderPassDescriptor
        
        if let renderPassDescriptor = renderPassDescriptor {
            // Create a render encoder to clear the screen and draw our objects
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            
            renderEncoder.pushDebugGroup("Draw Cube")
            
            // Since we specified the vertices of our triangles in counter-clockwise
            // order, we need to switch from the default of clockwise winding.
            renderEncoder.setFrontFacing(.counterClockwise)
            
            renderEncoder.setDepthStencilState(depthStencilState)

            // Set the pipeline state so the GPU knows which vertex and fragment function to invoke.
            renderEncoder.setRenderPipelineState(renderPipelineState)
            
            // Bind the buffer containing the array of vertex structures so we can
            // read it in our vertex shader.
            renderEncoder.setVertexBuffer(mesh.vertexBuffer, offset:0, at:0)
            
            // Bind the uniform buffer so we can read our model-view-projection matrix in the shader.
            renderEncoder.setVertexBytes(&constants, length: MemoryLayout<Constants>.size, at: 1)
            
            // Bind our texture so we can sample from it in the fragment shader
            renderEncoder.setFragmentTexture(texture, at: 0)
            
            // Bind our sampler state so we can use it to sample the texture in the fragment shader
            renderEncoder.setFragmentSamplerState(sampler, at: 0)

            // Issue the draw call to draw the indexed geometry of the mesh
            renderEncoder.drawIndexedPrimitives(type: mesh.primitiveType,
                                                indexCount: mesh.indexCount,
                                                indexType: mesh.indexType,
                                                indexBuffer: mesh.indexBuffer,
                                                indexBufferOffset: 0)

            renderEncoder.popDebugGroup()
            
            // We are finished with this render command encoder, so end it.
            renderEncoder.endEncoding()
            
            // Tell the system to present the cleared drawable to the screen.
            if let drawable = view.currentDrawable
            {
                commandBuffer.present(drawable)
            }
        }
        
        // Now that we're done issuing commands, we commit our buffer so the GPU can get to work.
        commandBuffer.commit()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // respond to resize
    }

    @objc(drawInMTKView:)
    func draw(in metalView: MTKView)
    {
        render(metalView)
    }
}
