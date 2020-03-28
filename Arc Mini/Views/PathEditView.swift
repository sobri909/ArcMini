//
//  PathEditView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 23/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

struct PathEditView: View {

    var path: ArcPath
    @ObservedObject var selectedItems: ObservableItems
    var classifierResults: ClassifierResults

    var body: some View {
        List {
            ForEach(Array(classifierResults), id: \.name) { result in
                Button(action: {
                    self.path.trainActivityType(to: result.name)
                }) {
                    HStack {
                        if self.pathTypeMatches(result) {
                            Text(result.name.displayName.capitalized.localised())
                                .font(.system(size: 17, weight: .semibold))
                        } else {
                            Text(result.name.displayName.capitalized.localised())
                                .font(.system(size: 17, weight: .regular))
                        }
                        Spacer()
                        Text(String(format: "%.0f", result.normalisedScore(in: self.classifierResults) * 100))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(UIColor.arcGray1))
                    }
                }
            }
        }
        .onAppear {
            self.selectedItems.items.removeAll()
            self.selectedItems.items.insert(self.path)
        }
    }

    func pathTypeMatches(_ result: ClassifierResultItem) -> Bool {
        guard path.manualActivityType else { return false }
        return result.name == path.activityType
    }

}

//struct PathEditView_Previews: PreviewProvider {
//    static var previews: some View {
//        PathEditView()
//    }
//}
