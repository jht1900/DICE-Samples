
```bash
-- 2017-09-22 Sat ----------------------------------------------------------------------------
Attempt to convert MetalVideoCapture to osx,
ran into few problems.
# /Users/epdev/Desktop/-0DICE-Samples/DICE-Samples/MetalVideoCapture/MetalVideoCapture.xcodeproj 
Search for TARGET_IOS to find issues.
```

# MetalVideoCapture

This sample demonstrates how to stream captured video textures (from the
front facing camera on an iOS device) into a 3D scene rendered with
Metal. The video texture is combined with an environment map reflection
from a cubemap (which is also rendered seperatly as the starfield
skybox) and a 2D mipmap PVRTC texture (copper metal texture). 

AAPLRenderer.mm is the core of the project and where the magic happens.
The render is based on Metal and uses AVFoundation capture APIs to
obtain video from the camera. Each frame of video is obtained as an
individual Metal texture via CVMetalTextureRef and CVMetalTextureCache
APIs. The quad spinning in space is renderered by mixing the various
textures on the GPU

## Requirements

### Build

iOS 9 SDK

### Runtime

iOS 9, 64 bit device

Copyright (C) 2015 Apple Inc. All rights reserved.
