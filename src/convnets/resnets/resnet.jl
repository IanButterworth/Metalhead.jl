"""
    ResNet(depth::Integer; pretrain = false, inchannels = 3, nclasses = 1000)

Creates a ResNet model with the specified depth.
((reference)[https://arxiv.org/abs/1512.03385])

# Arguments

  - `depth`: one of `[18, 34, 50, 101, 152]`. The depth of the ResNet model.
  - `pretrain`: set to `true` to load the model with pre-trained weights for ImageNet
  - `inchannels`: The number of input channels.
  - `nclasses`: the number of output classes

!!! warning
    
    `ResNet` does not currently support pretrained weights.

Advanced users who want more configuration options will be better served by using [`resnet`](#).
"""
struct ResNet
    layers::Any
end
@functor ResNet

function ResNet(depth::Integer; pretrain = false, inchannels = 3, nclasses = 1000)
    _checkconfig(depth, keys(RESNET_CONFIGS))
    layers = resnet(RESNET_CONFIGS[depth]...; inchannels, nclasses)
    if pretrain
        loadpretrain!(layers, string("ResNet", depth))
    end
    return ResNet(layers)
end

(m::ResNet)(x) = m.layers(x)

backbone(m::ResNet) = m.layers[1]
classifier(m::ResNet) = m.layers[2]

"""
    WideResNet(depth::Integer; pretrain = false, inchannels = 3, nclasses = 1000)

Creates a Wide ResNet model with the specified depth. The model is the same as ResNet
except for the bottleneck number of channels which is twice larger in every block.
The number of channels in outer 1x1 convolutions is the same.
((reference)[https://arxiv.org/abs/1605.07146])

# Arguments

  - `depth`: one of `[18, 34, 50, 101, 152]`. The depth of the Wide ResNet model.
  - `pretrain`: set to `true` to load the model with pre-trained weights for ImageNet
  - `inchannels`: The number of input channels.
  - `nclasses`: the number of output classes

!!! warning
    
    `WideResNet` does not currently support pretrained weights.

Advanced users who want more configuration options will be better served by using [`resnet`](#).
"""
struct WideResNet
    layers::Any
end
@functor WideResNet

function WideResNet(depth::Integer; pretrain = false, inchannels = 3, nclasses = 1000)
    _checkconfig(depth, [50, 101])
    layers = resnet(RESNET_CONFIGS[depth]...; base_width = 128, inchannels, nclasses)
    if pretrain
        loadpretrain!(layers, string("WideResNet", depth))
    end
    return WideResNet(layers)
end

(m::WideResNet)(x) = m.layers(x)

backbone(m::WideResNet) = m.layers[1]
classifier(m::WideResNet) = m.layers[2]