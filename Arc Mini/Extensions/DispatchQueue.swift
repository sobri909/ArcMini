//
//  DispatchQueue.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 7/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import Foundation

func onMain(_ closure: @escaping () -> ()) {
    if Thread.isMainThread {
        closure()
    } else {
        DispatchQueue.main.async(execute: closure)
    }
}

func delay(_ delay: TimeInterval, closure: @escaping () -> ()) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: closure)
}

func background(qos: DispatchQoS.QoSClass? = nil, closure: @escaping () -> ()) {
    if let qos = qos {
        DispatchQueue.global(qos: qos).async(execute: closure)
    } else {
        DispatchQueue.global().async(execute: closure)
    }
}
