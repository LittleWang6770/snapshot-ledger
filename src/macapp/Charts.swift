import SwiftUI
import Charts

// Both charts inspect actual stored samples, never interpolated money values.
enum ChartSelection {
    static func snapshot(at date: Date, records: [Snapshot]) -> Snapshot? {
        records.min { abs($0.calendarDate.timeIntervalSince(date)) < abs($1.calendarDate.timeIntervalSince(date)) }
    }
    static func tooltipX(_ x: CGFloat, width: CGFloat) -> CGFloat {
        min(max(x, 122), max(122, width - 122))
    }
}

struct AmountTooltip: View {
    var title: String
    var rows: [(String, Double, Color)]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12, weight: .semibold))
            ForEach(rows.indices, id: \.self) { i in
                HStack(spacing: 7) {
                    Circle().fill(rows[i].2).frame(width: 6, height: 6)
                    Text(rows[i].0).foregroundStyle(Theme.secondary)
                    Spacer(minLength: 8)
                    Text("¥\(money(rows[i].1))").monospacedDigit().fontWeight(.medium)
                }.font(.system(size: 12))
            }
        }.padding(12).frame(width: 240).background(.white, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.border))
            .shadow(color: .black.opacity(0.09), radius: 8, y: 3).allowsHitTesting(false)
    }
}

struct WealthChart: View {
    var records: [Snapshot]
    @State private var selectedID: String? = nil
    init(records: [Snapshot], previewSelection: String? = nil) {
        self.records = records; _selectedID = State(initialValue: previewSelection)
    }
    var selected: Snapshot? { records.first { $0.id == selectedID } }
    var body: some View {
        Chart {
            ForEach(records) { r in
                LineMark(x: .value("日期", r.calendarDate), y: .value("金额", r.cny)).foregroundStyle(by: .value("类型", "人民币资产")).symbol(Circle())
                LineMark(x: .value("日期", r.calendarDate), y: .value("金额", r.usdCNY)).foregroundStyle(by: .value("类型", "美元资产")).symbol(Circle())
                LineMark(x: .value("日期", r.calendarDate), y: .value("金额", r.debt)).foregroundStyle(by: .value("类型", "待还欠款")).symbol(Circle())
            }
            if let r = selected {
                RuleMark(x: .value("日期", r.calendarDate)).foregroundStyle(Theme.secondary.opacity(0.5)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartForegroundStyleScale(domain: ["人民币资产", "美元资产", "待还欠款"], range: [Theme.palette[0], Theme.palette[1], Theme.palette[3]])
        .chartLegend(position: .bottom, alignment: .leading)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let anchor = proxy.plotFrame {
                    let plot = geometry[anchor]
                    ZStack(alignment: .topLeading) {
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    guard plot.contains(location), let date = proxy.value(atX: location.x - plot.minX, as: Date.self) else { selectedID = nil; return }
                                    selectedID = ChartSelection.snapshot(at: date, records: records)?.id
                                case .ended: selectedID = nil
                                }
                            }
                        if let r = selected, let x = proxy.position(forX: r.calendarDate) {
                            AmountTooltip(title: r.date + " · 人民币", rows: [("人民币资产", r.cny, Theme.palette[0]), ("美元资产折合", r.usdCNY, Theme.palette[1]), ("待还欠款", r.debt, Theme.palette[3])])
                                .position(x: ChartSelection.tooltipX(plot.minX + x, width: geometry.size.width), y: plot.minY + 62)
                        }
                    }
                }
            }
        }.frame(height: 230)
        .onChange(of: records.map(\.id)) { _, _ in selectedID = nil }
        .help("将鼠标移到记录点附近，查看当天三类金额；美元资产以人民币显示。")
    }
}

struct MonthlyChart: View {
    var months: [Month]
    @State private var selectedID: String? = nil
    init(months: [Month], previewSelection: String? = nil) {
        self.months = months; _selectedID = State(initialValue: previewSelection)
    }
    var completeMonths: [Month] { months.filter(\.complete) }
    var selected: Month? { completeMonths.first { $0.id == selectedID } }
    var body: some View {
        Chart {
            ForEach(completeMonths) { m in
                BarMark(x: .value("账期", m.id), y: .value("金额", m.income)).foregroundStyle(by: .value("类型", "收入")).position(by: .value("类型", "收入"))
                    .opacity(selectedID == nil || selectedID == m.id ? 1 : 0.4)
                BarMark(x: .value("账期", m.id), y: .value("金额", m.expense)).foregroundStyle(by: .value("类型", "支出")).position(by: .value("类型", "支出"))
                    .opacity(selectedID == nil || selectedID == m.id ? 1 : 0.4)
            }
        }
        .chartForegroundStyleScale(domain: ["收入", "支出"], range: [Theme.palette[0], Theme.palette[3]])
        .chartLegend(position: .bottom, alignment: .leading)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let anchor = proxy.plotFrame {
                    let plot = geometry[anchor]
                    ZStack(alignment: .topLeading) {
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    guard plot.contains(location) else { selectedID = nil; return }
                                    selectedID = proxy.value(atX: location.x - plot.minX, as: String.self)
                                case .ended: selectedID = nil
                                }
                            }
                        if let m = selected, let x = proxy.position(forX: m.id) {
                            AmountTooltip(title: m.id + " · " + m.start.suffix(5) + "—" + m.end.suffix(5), rows: [("收入（含公积金）", m.income, Theme.palette[0]), ("支出", m.expense, Theme.palette[3])])
                                .position(x: ChartSelection.tooltipX(plot.minX + x, width: geometry.size.width), y: plot.minY + 49)
                        }
                    }
                }
            }
        }.frame(height: 225)
        .onChange(of: completeMonths.map(\.id)) { _, _ in selectedID = nil }
        .help("将鼠标移到柱子上，查看本账期收入与支出；收入含工资、公积金及其余收入。")
    }
}
