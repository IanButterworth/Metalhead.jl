"""
    resnextblock(inplanes, outplanes, cardinality, downsample = false)

Create a basic residual block as defined in the paper for ResNeXt
([reference](https://arxiv.org/abs/1611.05431)).

# Arguments:
- `inplanes`: the number of input feature maps
- `outplanes`: the number of output feature maps 
- `cardinality`: the number of groups to use for the convolution
- `width`: the number of feature maps in each group in the bottleneck
- `downsample`: set to `true` to downsample the input
"""
function resnextblock(inplanes, outplanes, cardinality, width, widen_factor, downsample = false)
    stride = downsample ? 2 : 1

    width_ratio = outplanes / (widen_factor * 128.0)
    hidden_channels = cardinality * floor(width * width_ratio)

    return Chain(conv_bn((1, 1), inplanes, hidden_channels; stride = 1, bias = false)...,
        conv_bn((3, 3), hidden_channels, hidden_channels;
            stride = stride, pad = 1, bias = false, groups = cardinality)...,
        conv_bn((1, 1), hidden_channels, outplanes; stride = 1, bias = false)...)
end

"""
    resnext(connection = (x, y) -> @. relu(x) + relu(y); channel_config, block_config, 
            cardinality, nclasses = 1000)
    
Create a ResNeXt model
([reference](https://arxiv.org/abs/1611.05431)).

# Arguments
- `cardinality`: the number of groups to use for the convolution
- `width`: the number of feature maps in each group in the bottleneck
- `connection`: the binary function applied to the output of residual and skip paths in a block
- `block_config`: a list of the number of residual blocks at each stage
- `nclasses`: the number of output classes
"""
function resnext(cardinality, width, widen_factor = 2, connection = (x, y) -> @. relu(x) + relu(y);
    block_config, nclasses = 1000)
    inplanes = 64
    baseplanes = 128
    layers = []
    append!(layers, conv_bn((7, 7), 3, inplanes; stride = 2, pad = (3, 3)))
    push!(layers, MaxPool((3, 3), stride = (2, 2), pad = (1, 1)))
    for (i, nrepeats) in enumerate(block_config)
        # output planes within a block
        outplanes = baseplanes * widen_factor
        # push first skip connection on using first residual
        # downsample the residual path if this is the first repetition of a block
        push!(layers, Parallel(connection, resnextblock(inplanes, outplanes, cardinality, width, widen_factor, i != 1),
            skip_projection(inplanes, outplanes, i != 1)))
        # push remaining skip connections on using second residual
        inplanes = outplanes
        for _ in 2:nrepeats
            push!(layers, Parallel(connection, resnextblock(inplanes, outplanes, cardinality, width, widen_factor, false),
                skip_identity(inplanes, outplanes, false)))
        end
        baseplanes = outplanes
    end

    return Chain(Chain(layers...),
        Chain(AdaptiveMeanPool((1, 1)), flatten, Dense(inplanes, nclasses)))
end

"""
    ResNeXt(cardinality, width; block_config, nclasses = 1000)
    
Create a ResNeXt model
([reference](https://arxiv.org/abs/1611.05431)).

# Arguments
- `cardinality`: the number of groups to use for the convolution
- `width`: the number of feature maps in each group in the bottleneck
- `nclasses`: the number of output classes
"""
struct ResNeXt
    layers
end

function ResNeXt(cardinality, width; block_config, nclasses = 1000)
    layers = resnext(cardinality, width; block_config, nclasses)
    ResNeXt(layers)
end

@functor ResNeXt

(m::ResNeXt)(x) = m.layers(x)

backbone(m::ResNeXt) = m.layers[1]
classifier(m::ResNeXt) = m.layers[2]

const resnext_config = Dict(
    50 => (3, 4, 6, 3),
    101 => (3, 4, 23, 3)
)

"""
    ResNeXt(; config::Int = 50, cardinality = 32, width = 4, pretrain = false, nclasses = 1000)

Create a ResNeXt model with specified configuration. Currently supported values are (50, 101).
([reference](https://arxiv.org/abs/1611.05431)).
Set `pretrain = true` to load the model with pre-trained weights for ImageNet.

!!! warning
    `ResNeXt` does not currently support pretrained weights.

See also [`Metalhead.resnext`](#).
"""
function ResNeXt(; config::Int = 50, cardinality = 32, width = 4, pretrain = false, nclasses = 1000)
    @assert config in keys(resnext_config) "`config` must be one of $(sort(collect(keys(resnext_config))))"

    model = ResNeXt(cardinality, width; block_config = resnext_config[config], nclasses)
    pretrain && loadpretrain!(model, string("ResNeXt", config))
    model
end