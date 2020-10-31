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

func delay(_ delay: TimeInterval, onQueue queue: DispatchQueue, closure: @escaping () -> ()) {
    queue.asyncAfter(deadline: .now() + delay, execute: closure)
}

func background(qos: DispatchQoS.QoSClass? = nil, closure: @escaping () -> ()) {
    if let qos = qos {
        DispatchQueue.global(qos: qos).async(execute: closure)
    } else {
        DispatchQueue.global().async(execute: closure)
    }
}

func dedupedTask(scope: AnyObject, after: TimeInterval, closure: @escaping () -> ()) {
    DispatchQueue.main.asyncDeduped(target: scope, after: after, execute: closure)
}

extension DispatchQueue {
    static var workItems = [AnyHashable : DispatchWorkItem]()
    static var weakTargets = NSPointerArray.weakObjects()
    static func dedupeIdentifierFor(_ object: AnyObject) -> String {
        return "\(Unmanaged.passUnretained(object).toOpaque())." + String(describing: object)
    }
    
    func asyncDeduped(target: AnyObject, after delay: TimeInterval, execute work: @escaping @convention(block) () -> Void) {
        let dedupeIdentifier = DispatchQueue.dedupeIdentifierFor(target)
        if let existingWorkItem = DispatchQueue.workItems.removeValue(forKey: dedupeIdentifier) {
            existingWorkItem.cancel()
        }
        let workItem = DispatchWorkItem {
            DispatchQueue.workItems.removeValue(forKey: dedupeIdentifier)

            for ptr in DispatchQueue.weakTargets.allObjects {
                if dedupeIdentifier == DispatchQueue.dedupeIdentifierFor(ptr as AnyObject) {
                    work()
                    break
                }
            }
        }

        DispatchQueue.workItems[dedupeIdentifier] = workItem
        DispatchQueue.weakTargets.addPointer(Unmanaged.passUnretained(target).toOpaque())

        asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}
