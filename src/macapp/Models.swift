import Foundation
import SwiftUI

struct Snapshot: Codable, Identifiable {
    var id: String { date }
    var date: String
    var boc: Double, cmb: Double, wechat: Double, alipay: Double
    var usdCNY: Double, otherCNY: Double
    var sgdBalance: Double?, sgdRate: Double = 1, legacySGDCNY: Double?
    var creditLimit: Double = 0, available: Double?, legacyDebt: Double?
    var salary: Double?, fund: Double?, otherIncome: Double?, investment: Double?
    var note: String = ""
    var sgdCNY: Double { sgdBalance.map { $0 * sgdRate } ?? legacySGDCNY ?? 0 }
    var debt: Double { available.map { creditLimit - $0 } ?? legacyDebt ?? 0 }
    var cny: Double { boc + cmb + wechat + alipay + otherCNY }
    var assets: Double { cny + usdCNY + sgdCNY }
    var net: Double { assets - debt }
    var liquidNet: Double { cny + sgdCNY - debt }
    var income: Double { (salary ?? 0) + (fund ?? 0) + (otherIncome ?? 0) }
    var hasFlows: Bool { salary != nil && fund != nil && otherIncome != nil && investment != nil }
    var calendarDate: Date { Dates.format.date(from: date) ?? Date(timeIntervalSince1970: 0) }
}

enum Dates {
    static let format: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current; return f }()
    static func key(_ date: Date) -> String { format.string(from: date) }
    static func cycle(_ s: Snapshot) -> String {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        let d = cal.component(.day, from: s.calendarDate) > 15 ? cal.date(byAdding: .month, value: 1, to: s.calendarDate)! : s.calendarDate
        return String(key(d).prefix(7))
    }
}
struct Month: Identifiable {
    var id: String; var start: String; var end: String
    var salary = 0.0, fund = 0.0, other = 0.0, expense = 0.0
    var complete = true
    var income: Double { salary + fund + other }
}
func monthSummary(_ records: [Snapshot]) -> [Month] {
    let rows = records.sorted { $0.date < $1.date }
    var months: [String: Month] = [:]
    for i in rows.indices.dropFirst() {
        let r = rows[i], previous = rows[i-1], key = Dates.cycle(r)
        var m = months[key] ?? Month(id: key, start: previous.date, end: r.date)
        m.end = r.date; m.salary += r.salary ?? 0; m.fund += r.fund ?? 0; m.other += r.otherIncome ?? 0
        m.complete = m.complete && r.hasFlows
        m.expense += r.income - (r.investment ?? 0) - r.liquidNet + previous.liquidNet
        months[key] = m
    }
    return months.values.sorted { $0.id < $1.id }
}
func money(_ x: Double) -> String { x.formatted(.number.precision(.fractionLength(2))) }
func entry(_ x: Double?) -> String { x.map { String(format: "%.2f", $0) } ?? "" }
enum LedgerError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

struct Draft {
    var date = Date()
    var boc = "0", cmb = "0", wechat = "0", alipay = "0", usd = "0", otherAssets = "0"
    var sgd = "", rate = "1", limit = "0", available = ""
    var salary = "0", fund = "0", other = "0", investment = "0", note = ""
    var editingID: String? = nil
    var legacySGD: Double? = nil, legacyDebt: Double? = nil
    static func starting(from r: Snapshot?) -> Draft {
        var d = Draft()
        if let r { d.boc = entry(r.boc); d.cmb = entry(r.cmb); d.wechat = entry(r.wechat); d.alipay = entry(r.alipay); d.usd = entry(r.usdCNY); d.otherAssets = entry(r.otherCNY) }
        return d
    }
    static func editing(_ r: Snapshot) -> Draft {
        var d = starting(from:r); d.date = r.calendarDate; d.sgd = entry(r.sgdBalance); d.rate = String(r.sgdRate); d.limit = entry(r.creditLimit); d.available = entry(r.available)
        d.salary = entry(r.salary); d.fund = entry(r.fund); d.other = entry(r.otherIncome); d.investment = entry(r.investment); d.note = r.note
        d.editingID = r.date; d.legacySGD = r.legacySGDCNY; d.legacyDebt = r.legacyDebt; return d
    }
    func number(_ text: String, _ label: String, nonnegative: Bool = true) throws -> Double {
        let normalized = text.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        guard let value = Double(normalized), value.isFinite, !nonnegative || value >= 0 else { throw LedgerError.message("请填写有效的\(label)。") }
        return value
    }
    func snapshot() throws -> Snapshot {
        let raw = sgd.trimmingCharacters(in: .whitespaces).isEmpty && legacySGD != nil ? nil : try number(sgd,"新币余额")
        let av = available.trimmingCharacters(in: .whitespaces).isEmpty && legacyDebt != nil ? nil : try number(available,"当前可用额度")
        let fx = try number(rate,"新币汇率"); guard fx > 0 else { throw LedgerError.message("新币汇率需大于0。") }
        func flow(_ text: String, _ label: String) throws -> Double? { if editingID != nil && text.isEmpty { return nil }; return try number(text,label,nonnegative:false) }
        return Snapshot(date:Dates.key(date),boc:try number(boc,"银行卡 A余额"),cmb:try number(cmb,"银行卡 B余额"),wechat:try number(wechat,"微信余额"),alipay:try number(alipay,"支付宝余额"),usdCNY:try number(usd,"美元资产人民币等值"),otherCNY:try number(otherAssets,"其他资产"),sgdBalance:raw,sgdRate:fx,legacySGDCNY:legacySGD,creditLimit:try number(limit,"信用卡额度"),available:av,legacyDebt:legacyDebt,salary:try flow(salary,"工资收入"),fund:try flow(fund,"公积金收入"),otherIncome:try flow(other,"其余收入"),investment:try flow(investment,"证券净入金"),note:note)
    }
}

@MainActor final class Ledger: ObservableObject {
    @Published var records: [Snapshot] = []
    @Published var page = "看板"
    @Published var draft = Draft()
    @Published var advanced = false
    @Published var busy = false
    @Published var status = ""
    @Published var error = ""
    var savingTask: Task<Void,Never>?
    let file: URL
    private var readFailure = false
    init(directory: URL? = nil, fixture: [Snapshot]? = nil) {
        let dir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("SnapshotLedger")
        file = dir.appendingPathComponent("snapshots.json")
        if let fixture { records = fixture }
        else {
            let source: URL? = FileManager.default.fileExists(atPath:file.path) ? file : nil
            do { if let source { records = try JSONDecoder().decode([Snapshot].self,from:Data(contentsOf:source)) } }
            catch { self.error = "账本读取失败：\(error.localizedDescription)"; readFailure = true }
        }
        records.sort { $0.date < $1.date }; draft = Draft.starting(from:records.last)
    }
    func newRecord() { draft = Draft.starting(from:records.last); page = "记录快照"; status = ""; error = "" }
    func edit(_ r: Snapshot) { draft = .editing(r); page = "记录快照"; status = ""; error = "" }
    func save() {
        guard !busy else { return }
        do {
            guard !readFailure else { throw LedgerError.message("现有账本读取失败，已停止保存以保护原文件。") }
            let record = try draft.snapshot()
            if records.contains(where:{$0.date == record.date && $0.date != draft.editingID}) { throw LedgerError.message("这一天已有快照，请从历史记录中编辑。") }
            var next = records.filter { $0.date != draft.editingID }; next.append(record); next.sort { $0.date < $1.date }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]; let bytes = try encoder.encode(next)
            busy = true; error = ""; status = "正在保存快照…"
            savingTask = Task { @MainActor in
                await Task.yield()
                guard !Task.isCancelled else { busy = false; status = "已取消，快照未保存"; return }
                do {
                    try FileManager.default.createDirectory(at:file.deletingLastPathComponent(),withIntermediateDirectories:true)
                    // Atomic local commit; no task suspension between commit and published state.
                    try bytes.write(to:file,options:.atomic)
                    records = next; draft = Draft.starting(from:records.last); status = "已保存 \(record.date) 的快照"; page = "看板"
                } catch { self.error = "保存失败：\(error.localizedDescription)"; status = "" }
                busy = false
            }
        } catch { self.error = error.localizedDescription }
    }
    func cancel() { savingTask?.cancel() }
    func csv() -> String {
        func q(_ s: String) -> String { "\"" + s.replacingOccurrences(of:"\"",with:"\"\"") + "\"" }
        var lines = ["日期,银行卡 A,银行卡 B,微信,支付宝,美元资产CNY,新币余额SGD,汇率,新币等值CNY,其他资产,信用卡额度,可用额度,信用卡待还,工资,公积金,其余收入,证券净入金,净资产,备注"]
        for r in records { let values = [r.date,entry(r.boc),entry(r.cmb),entry(r.wechat),entry(r.alipay),entry(r.usdCNY),entry(r.sgdBalance),String(r.sgdRate),entry(r.sgdCNY),entry(r.otherCNY),entry(r.creditLimit),entry(r.available),entry(r.debt),entry(r.salary),entry(r.fund),entry(r.otherIncome),entry(r.investment),entry(r.net),r.note]; lines.append(values.map(q).joined(separator:",")) }
        return "\u{FEFF}" + lines.joined(separator:"\r\n")
    }
}
