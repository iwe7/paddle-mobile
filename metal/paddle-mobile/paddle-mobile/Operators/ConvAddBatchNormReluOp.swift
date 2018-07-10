//
//  ConvAddBatchNormReluOp.swift
//  paddle-mobile
//
//  Created by liuRuiLong on 2018/7/8.
//  Copyright © 2018年 orange. All rights reserved.
//

import Foundation

class ConvAddBatchNormReluParam<P: PrecisionType>: OpParam {
    typealias ParamPrecisionType = P
    required init(opDesc: OpDesc, inScope: Scope) throws {
        do {
            filter = try ConvAddBatchNormReluParam.inputFilter(paraInputs: opDesc.paraInputs, from: inScope)
            input = try ConvAddBatchNormReluParam.input(inputs: opDesc.inputs, from: inScope)
            output = try ConvAddBatchNormReluParam.output(outputs: opDesc.outputs, from: inScope)
            stride = try ConvAddBatchNormReluParam.getAttr(key: "strides", attrs: opDesc.attrs)
            paddings = try ConvAddBatchNormReluParam.getAttr(key: "paddings", attrs: opDesc.attrs)
            dilations = try ConvAddBatchNormReluParam.getAttr(key: "dilations", attrs: opDesc.attrs)
            epsilon = try ConvAddBatchNormReluParam.getAttr(key: "epsilon", attrs: opDesc.attrs)
            
            groups = try ConvAddBatchNormReluParam.getAttr(key: "groups", attrs: opDesc.attrs)
            variance = try ConvAddBatchNormReluParam.inputVariance(inputs: opDesc.paraInputs, from: inScope)
            bias = try ConvAddBatchNormReluParam.inputBiase(inputs: opDesc.paraInputs, from: inScope)
            scale = try ConvAddBatchNormReluParam.inputScale(inputs: opDesc.paraInputs, from: inScope)
            mean = try ConvAddBatchNormReluParam.inputMean(inputs: opDesc.paraInputs, from: inScope)
            y = try ConvAddBatchNormReluParam.inputY(inputs: opDesc.paraInputs, from: inScope)
        } catch let error {
            throw error
        }
    }
    
    let input: Texture<P>
    
    let variance: Tensor<ParamPrecisionType>
    let bias: Tensor<ParamPrecisionType>
    let mean: Tensor<ParamPrecisionType>
    let scale: Tensor<ParamPrecisionType>
    let y: Tensor<ParamPrecisionType>
    let filter: Tensor<ParamPrecisionType>
    let epsilon: Float32
    var newScale: MTLBuffer?
    var newBiase: MTLBuffer?
    
    var output: Texture<P>
    let stride: [Int32]
    let paddings: [Int32]
    let dilations: [Int32]
    let groups: Int
}

class ConvAddBatchNormReluOp<P: PrecisionType>: Operator<ConvAddBatchNormReluKernel<P>, ConvAddBatchNormReluParam<P>>, Runable, Creator, InferShaperable, Fusion{
    typealias OpType = ConvAddBatchNormReluOp<P>
    
    func inferShape() {
        let inDims = para.input.dim
        let filterDim = para.filter.dim
        let strides = para.stride
        let paddings = para.paddings
        let dilations = para.dilations
        
        var outDim = [inDims[0]]
        for i in 0..<strides.count {
            let dilation: Int = Int(dilations[i])
            let filterSize: Int = filterDim[i + 1]
            let inputSize: Int = inDims[i + 1]
            let padding: Int = Int(paddings[i])
            let stride: Int = Int(strides[i])
            let dKernel = dilation * (filterSize - 1) + 1
            let outputSize = (inputSize + 2 * padding - dKernel) / stride + 1
            outDim.append(outputSize)
        }
        outDim.append(filterDim[0])
        para.output.dim = Dim.init(inDim: outDim)
    }

    func runImpl(device: MTLDevice, buffer: MTLCommandBuffer) throws {
        do {
            try kernel.compute(commandBuffer: buffer, param: para)
        } catch let error {
            throw error
        }
    }
    
    static func fusionNode() -> Node {
        let beginNode = Node.init(inType: gConvType)
        _ = beginNode
            --> Node.init(inType: gElementwiseAdd)
            --> Node.init(inType: gBatchNormType)
            --> Node.init(inType: gReluType)
        return beginNode
    }
    
    static func change() -> [String : [(from: String, to: String)]] {
        return [:]
    }
    
    static func fusionType() -> String {
        return gConvAddBatchNormReluType
    }
}