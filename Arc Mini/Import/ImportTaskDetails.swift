//
//  ImportTaskDetails.swift
//  Arc
//
//  Created by Matt Greenfield on 19/3/21.
//  Copyright © 2021 Big Paua. All rights reserved.
//

import SwiftUI

struct ImportTaskDetails: View {
    
    @State var task: ImportTask
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Import Task Details")
                    .font(.system(size: 18, weight: .bold))
                    .frame(height: 44)
                HStack {
                    Text("State")
                        .font(.system(size: 16, weight: .regular))
                    Spacer()
                    Text(task.state.rawValue)
                        .font(.system(size: 16, weight: .regular))
                        .opacity(0.5)
                }
                .frame(height: 40)
                if let totalSamples = task.totalSamples {
                    HStack {
                        Text("Total samples")
                            .font(.system(size: 16, weight: .regular))
                        Spacer()
                        Text("\(totalSamples)")
                            .font(.system(size: 16, weight: .regular))
                            .opacity(0.5)
                    }
                    .frame(height: 40)
                    HStack {
                        Text("Imported samples")
                            .font(.system(size: 16, weight: .regular))
                        Spacer()
                        Text("\(task.importedSamples)")
                            .font(.system(size: 16, weight: .regular))
                            .opacity(0.5)
                    }
                    .frame(height: 40)
                    HStack {
                        Text("Existing samples skipped")
                            .font(.system(size: 16, weight: .regular))
                        Spacer()
                        Text("\(task.existingSamples)")
                            .font(.system(size: 16, weight: .regular))
                            .opacity(0.5)
                    }
                    .frame(height: 40)
                    HStack {
                        Text("Deferred samples")
                            .font(.system(size: 16, weight: .regular))
                        Spacer()
                        Text("\(task.deferredSamples)")
                            .font(.system(size: 16, weight: .regular))
                            .opacity(0.5)
                    }
                    .frame(height: 40)
                    HStack {
                        Text("Errored samples")
                            .font(.system(size: 16, weight: .regular))
                        Spacer()
                        Text("\(task.erroredSamples)")
                            .font(.system(size: 16, weight: .regular))
                            .opacity(0.5)
                    }
                    .frame(height: 40)
                    
                    if task.canRedoWithoutDependents {
                        Spacer().frame(height: 20)
                        Rectangle().fill(Color(0xE2E2E2)).frame(height: .onePixel)
                        Spacer().frame(height: 20)
                        Button {
                            ArcImporter.highlander.importSamples(from: task.url, ignoringMissingDependents: true)
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            Text("Retry import ignoring missing dependents")
                                .font(.system(size: 16, weight: .regular))
                        }
                        .frame(height: 40)
                    }
                    
                    if !task.errors.isEmpty {
                        Spacer().frame(height: 20)
                        Rectangle().fill(Color(0xE2E2E2)).frame(height: .onePixel)
                        Spacer().frame(height: 30)
                        
                        Text("Errors")
                            .font(.system(size: 18, weight: .bold))
                            .frame(height: 44)
                        let errors = Array(Set(task.errors.map { $0.localizedDescription }))
                        ForEach(errors, id: \.self) { error in
                            Text(error)
                                .font(.system(size: 12, weight: .regular))
                                .padding([.top, .bottom], 8)
                                .lineLimit(4)
                                .fixedSize(horizontal: false, vertical: true)
                            Rectangle().fill(Color(0xE2E2E2)).frame(height: .onePixel)
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}
