//
//  LineChart.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 9/12/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI

struct LineChart: View {
    var data: LineChartDatasets
    var config = LineChartConfig()
    
    // MARK: -
    
    var body: some View {
        GeometryReader { metrics in
            HStack {
                VStack {
                    Text("\(data.yRange.upperBound, specifier: config.yLabelSpecifier ?? ".0f")")
                        .font(.system(size: 7))
                    Spacer()
                    Text("\(config.fixedMinimumY ?? data.yRange.lowerBound, specifier: config.yLabelSpecifier ?? ".0f")")
                        .font(.system(size: 7))
                }
                ZStack {
                    ForEach(data.datasets) { dataset in
                        Line(data: dataset, datasets: data, fixedMinimumY: config.fixedMinimumY)
                            .stroke(Color.black, lineWidth: 1)
                    }
                }
            }
        }
    }
    
    struct Line: Shape {
        var data: LineChartDataset
        var datasets: LineChartDatasets
        var fixedMinimumY: Double?

        func path(in rect: CGRect) -> Path {
            var path = Path()
            let yRange = (fixedMinimumY ?? datasets.yRange.lowerBound)...datasets.yRange.upperBound
            for point in data.points {
                let xPct = CGFloat(datasets.xRange.position(of: point.x))
                let yPct = 1.0 - CGFloat(yRange.position(of: point.y))
                if path.isEmpty {
                    path.move(to: CGPoint(x: rect.minX + rect.width * xPct,
                                          y: rect.minY + rect.height * yPct))
                } else {
                    path.addLine(to: CGPoint(x: rect.minX + rect.width * xPct,
                                             y: rect.minY + rect.height * yPct))
                }
            }
            return path
        }
    }
}

// MARK: - Style

struct LineChartConfig {
    var fixedMinimumY: Double?
    var yLabelSpecifier: String?
}

// MARK: - Data

struct LineChartDatasets {
    let datasets: [LineChartDataset]
    let xRange: ClosedRange<Double>
    let yRange: ClosedRange<Double>
    
    init(datasets: [LineChartDataset]) {
        self.datasets = datasets
        let minX = datasets.map { $0.xRange.lowerBound }.min()!
        let maxX = datasets.map { $0.xRange.upperBound }.max()!
        self.xRange = minX...maxX
        let minY = datasets.map { $0.yRange.lowerBound }.min()!
        let maxY = datasets.map { $0.yRange.upperBound }.max()!
        self.yRange = minY...maxY
    }
}

struct LineChartDataset: Identifiable {
    let id = UUID()
    let points: [Point]
    let xRange: ClosedRange<Double>
    let yRange: ClosedRange<Double>
    
    init(yValues: [Double]) {
        self.points = yValues.enumerated().map { Point(Double($0), $1) }
        self.xRange = 0...Double(yValues.count - 1)
        self.yRange = yValues.min()!...yValues.max()!
    }

    init(xyValues: [(Double, Double)]) {
        self.points = xyValues.map { Point($0, $1) }
        let xValues = xyValues.map { $0.0 }
        let yValues = xyValues.map { $0.1 }
        self.xRange = xValues.min()!...xValues.max()!
        self.yRange = yValues.min()!...yValues.max()!
    }
    
    struct Point {
        let x: Double
        let y: Double
        init(_ x: Double, _ y: Double) {
            self.x = x
            self.y = y
        }
    }
}

extension ClosedRange where Bound == Double {
    func position(of element: Double) -> Double {
        let groundedRange = upperBound - lowerBound
        let groundedElement = element - lowerBound
        return groundedElement / groundedRange
    }
}

// MARK: - Preview

struct LineChart_Previews: PreviewProvider {
    static var previews: some View {
        LineChart(
            data: LineChartDatasets(
                datasets: [
                    LineChartDataset(xyValues: [
                        (1607596192.922, 0.0),
                        (1607596204.828, 0.5787951617238238),
                        (1607596211.4390001, 1.3292385496552752),
                        (1607596219.0939999, 1.7018959543386003),
                        (1607596256.654, 2.5079560965903442)
                    ]),
                    LineChartDataset(xyValues: [
                        (1607596329.2610002, 1.0451223087818156),
                        (1607596331.7059999, 1.0073937636639945),
                        (1607596332.501, 1.0647881005377342),
                        (1607596333.069, 1.1958407446554424),
                        (1607596334.4229999, 1.337053266012501)
                    ])
                ]
            )
        )
        .frame(height: 400)
        .border(Color.red, width: 1)
    }
}
