import SwiftUI
import Charts
import AppKit

enum Theme {
    static let background = Color(hex:0xF6F9FA), border = Color(hex:0xE3E5E6), ink = Color(hex:0x202426), secondary = Color(hex:0x667078)
    static let accent = Color(hex:0x3D647A), selected = Color(hex:0xEAF0F4), input = Color(hex:0xF3F5F6), danger = Color(hex:0xA74740)
    static let palette: [Color] = [accent,Color(hex:0x688A80),Color(hex:0xB39563),Color(hex:0xB36C65)]
}
extension Color { init(hex:UInt32) { self.init(.sRGB,red:Double((hex>>16)&255)/255,green:Double((hex>>8)&255)/255,blue:Double(hex&255)/255,opacity:1) } }
struct Card<Content:View>: View {
    var title:String; var number:String? = nil; @ViewBuilder var content:Content
    var body:some View { VStack(alignment:.leading,spacing:16) { HStack(spacing:9) { if let number { Text(number).font(.system(size:12,weight:.semibold)).foregroundStyle(Theme.accent).frame(width:23,height:23).background(Theme.selected,in:Circle()) };Text(title).font(.system(size:15,weight:.semibold)) };content }.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(.white,in:RoundedRectangle(cornerRadius:12)).overlay(RoundedRectangle(cornerRadius:12).stroke(Theme.border,lineWidth:1)) }
}
struct PrimaryButton: ButtonStyle { @Environment(\.isEnabled) var enabled; func makeBody(configuration:Configuration)->some View { configuration.label.font(.system(size:13,weight:.medium)).padding(.horizontal,18).frame(height:38).foregroundStyle(.white).background(configuration.isPressed ? Color(hex:0x315469) : Theme.accent,in:RoundedRectangle(cornerRadius:7)).opacity(enabled ? 1 : 0.45) } }
struct MoneyField:View {
    var title:String; @Binding var value:String; var unit = "CNY"
    @FocusState var focused:Bool
    var body:some View { VStack(alignment:.leading,spacing:7) { Text(title).font(.system(size:12)).foregroundStyle(Theme.secondary); HStack { TextField("填写金额",text:$value).textFieldStyle(.plain).monospacedDigit().accessibilityLabel(title).focused($focused);Text(unit).font(.system(size:11)).foregroundStyle(Theme.secondary) }.padding(.horizontal,11).frame(height:35).background(Theme.input,in:RoundedRectangle(cornerRadius:7)).overlay(RoundedRectangle(cornerRadius:7).stroke(focused ? Theme.accent : .clear,lineWidth:1.5)) } }
}
struct LedgerView:View {
    @ObservedObject var model:Ledger
    let grid = [GridItem(.flexible()),GridItem(.flexible())]
    var body:some View {
        VStack(spacing:0) {
            VStack(spacing:6) { Image(nsImage: NSImage(named:"AppIcon") ?? NSImage()).resizable().scaledToFit().frame(width:58,height:58);Text("财务快照").font(.system(size:27,weight:.semibold));Text("记下余额，看看财富怎样变化").font(.system(size:12)).foregroundStyle(Theme.secondary) }.padding(.top,16).padding(.bottom,20)
            HStack(alignment:.top,spacing:20) {
                sidebar.frame(width:208)
                VStack(spacing:8) { ScrollView { VStack(spacing:16) { if model.page == "看板" { dashboard } else if model.page == "记录快照" { form } else { history } }.padding(.bottom,20).padding(.trailing,2) };feedback }.frame(maxWidth:.infinity).padding(.bottom,16)
            }.padding(.horizontal,28)
        }.foregroundStyle(Theme.ink).font(.system(size:13)).background(Theme.background).frame(minWidth:980,minHeight:720).preferredColorScheme(.light).environment(\.locale, Locale(identifier:"zh_CN"))
    }
    var sidebar:some View {
        VStack(spacing:16) {
            Card(title:"我的账本") { VStack(alignment:.leading,spacing:8) { Text("\(model.records.count) 次快照").font(.system(size:22,weight:.semibold));Text(model.records.last.map{"最近记录 \($0.date)"} ?? "还没有记录").font(.system(size:12)).foregroundStyle(Theme.secondary) } }
            VStack(spacing:5) { ForEach(["看板","记录快照","历史记录"],id:\.self) { page in Button { model.page = page } label:{HStack { Image(systemName:page=="看板" ? "chart.bar.xaxis" : page=="记录快照" ? "square.and.pencil" : "clock").frame(width:20);Text(page);Spacer() }.padding(11).background(model.page==page ? Theme.selected : .clear,in:RoundedRectangle(cornerRadius:7)) }.buttonStyle(.plain).disabled(model.busy) } }
            Card(title:"记录方式") { VStack(alignment:.leading,spacing:9) { Text("每月 5、15、25 日和月底");Text("也可以按自己的节奏记录。收入填写距上次快照的发生额。").font(.system(size:12)).foregroundStyle(Theme.secondary) } }
            VStack(alignment:.leading,spacing:10) { Text("保存在本机，与 Excel 分开维护").font(.system(size:12)).foregroundStyle(Theme.secondary);Text(model.file.path).font(.system(size:11)).foregroundStyle(Theme.secondary).lineLimit(1).truncationMode(.middle).help(model.file.path);Button("导出快照 CSV…",action:exportCSV).disabled(model.records.isEmpty || model.busy) }.frame(maxWidth:.infinity,alignment:.leading).padding(.horizontal,3)
        }
    }
    @ViewBuilder var dashboard:some View {
        if let last = model.records.last {
            HStack { VStack(alignment:.leading,spacing:5) { Text("财务总览").font(.system(size:18,weight:.semibold));Text("截至 \(last.date) · 金额为人民币").font(.system(size:12)).foregroundStyle(Theme.secondary) };Spacer();Button("记录新快照",action:model.newRecord).buttonStyle(PrimaryButton()) }
            LazyVGrid(columns:grid,spacing:14) { metric("净资产",last.net);metric("待还欠款",last.debt);metric("人民币资产",last.cny);metric("美元资产 · 折人民币",last.usdCNY) }
            Card(title:"财富增长") { WealthChart(records:model.records);Text("移到记录点查看金额。新币等值 ¥\(money(last.sgdCNY)) 另计入净资产。").font(.system(size:12)).foregroundStyle(Theme.secondary) }
            Card(title:"每月收入与支出") { let months = monthSummary(model.records); if months.filter(\.complete).isEmpty { Text("补全期间收入后，即可查看收支图表。").foregroundStyle(Theme.secondary) } else { MonthlyChart(months:months);Text("收入含工资、公积金和其余收入；移到柱子查看金额。支出按快照余额估算，证券入金已剔除。").font(.system(size:12)).foregroundStyle(Theme.secondary) } }
        } else { Card(title:"从第一张快照开始",number:"1") { Text("填入账户余额和当前可用额度，建立你的财务起点。").foregroundStyle(Theme.secondary);Button("记录第一张快照",action:model.newRecord).buttonStyle(PrimaryButton()) } }
    }
    func metric(_ title:String,_ amount:Double)->some View { VStack(alignment:.leading,spacing:10) {Text(title).font(.system(size:12)).foregroundStyle(Theme.secondary);Text("¥\(money(amount))").font(.system(size:24,weight:.semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)}.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(.white,in:RoundedRectangle(cornerRadius:12)).overlay(RoundedRectangle(cornerRadius:12).stroke(Theme.border)) }
    var form:some View {
        VStack(spacing:16) {
            HStack { Text(model.draft.editingID == nil ? "记录快照" : "编辑快照").font(.system(size:18,weight:.semibold));Spacer();DatePicker("记录日期",selection:$model.draft.date,displayedComponents:.date).labelsHidden().fixedSize() }
            Card(title:"账户余额",number:"1") { Text("人民币账户已带入上次余额，请更新为今天的数值。").font(.system(size:12)).foregroundStyle(Theme.secondary);LazyVGrid(columns:grid,spacing:12) {MoneyField(title:"银行卡 A",value:$model.draft.boc);MoneyField(title:"银行卡 B",value:$model.draft.cmb);MoneyField(title:"微信",value:$model.draft.wechat);MoneyField(title:"支付宝",value:$model.draft.alipay);MoneyField(title:"美元资产 · 折人民币",value:$model.draft.usd);MoneyField(title:"其他人民币资产",value:$model.draft.otherAssets)} }
            Card(title:"额度与换算",number:"2") { LazyVGrid(columns:grid,alignment:.leading,spacing:13) {MoneyField(title:"当前可用额度",value:$model.draft.available);MoneyField(title:"新币余额",value:$model.draft.sgd,unit:"SGD");calculation("信用卡待还",value:creditPreview);calculation("新币人民币等值",value:sgdPreview)};DisclosureGroup("额度与汇率",isExpanded:$model.advanced) { HStack(spacing:14) {MoneyField(title:"信用卡总额度",value:$model.draft.limit);MoneyField(title:"新币汇率",value:$model.draft.rate,unit:"CNY/SGD")}.padding(.top,10) };if model.draft.editingID != nil {Text("历史记录未填原币或可用额度时，保留原来的折算值与欠款。").font(.system(size:12)).foregroundStyle(Theme.secondary)} }
            Card(title:"本次期间收支",number:"3") {Text("从上次快照之后算起，没有发生填 0。").font(.system(size:12)).foregroundStyle(Theme.secondary);LazyVGrid(columns:grid,spacing:12) {MoneyField(title:"工资收入",value:$model.draft.salary);MoneyField(title:"公积金收入",value:$model.draft.fund);MoneyField(title:"其余收入",value:$model.draft.other);MoneyField(title:"证券净入金 · 转入为正",value:$model.draft.investment)};TextField("备注（可选）",text:$model.draft.note).textFieldStyle(.roundedBorder) }
            HStack {Text("保存后自动更新看板与历史记录").font(.system(size:12)).foregroundStyle(Theme.secondary);Spacer();Button("保存快照",action:model.save).buttonStyle(PrimaryButton()).keyboardShortcut("s",modifiers:.command) }
        }.disabled(model.busy)
    }
    var creditPreview:Double? { if let v = Double(model.draft.available),let limit = Double(model.draft.limit) {return limit-v};return model.draft.legacyDebt }
    var sgdPreview:Double? { if let v = Double(model.draft.sgd),let rate = Double(model.draft.rate) {return v*rate};return model.draft.legacySGD }
    func calculation(_ label:String,value:Double?)->some View {VStack(alignment:.leading,spacing:5) {Text(label).font(.system(size:12)).foregroundStyle(Theme.secondary);Text(value.map{"¥\(money($0))"} ?? "填写后自动计算").font(.system(size:17,weight:.semibold)).foregroundStyle(Theme.accent).monospacedDigit()} }
    var history:some View { VStack(spacing:16) {Card(title:"历史快照") { if model.records.isEmpty {Text("还没有快照").foregroundStyle(Theme.secondary)} else {ForEach(model.records.reversed()) { r in HStack {VStack(alignment:.leading,spacing:5) {Text(r.date).fontWeight(.medium);Text("待还 ¥\(money(r.debt))").font(.system(size:12)).foregroundStyle(Theme.secondary)};Spacer();Text("净资产 ¥\(money(r.net))").monospacedDigit();Button("编辑") {model.edit(r)}};if r.id != model.records.first?.id {Divider()} } } };Card(title:"月度收支（估算）") {ForEach(monthSummary(model.records)) {m in VStack(alignment:.leading,spacing:7) {Text("\(m.id)   \(m.start.suffix(5)) — \(m.end.suffix(5))").fontWeight(.medium);Text(m.complete ? "收入 ¥\(money(m.income))　支出 ¥\(money(m.expense))" : "请补全本期收入或证券入金数据").foregroundStyle(Theme.secondary)};Divider()} } } }
    @ViewBuilder var feedback:some View {
        if model.busy { VStack(alignment:.leading,spacing:8) { HStack {ProgressView().controlSize(.small);Text("保存中");Spacer();Text("估算中").foregroundStyle(Theme.secondary);Button("取消",action:model.cancel)};Text(model.status).font(.system(size:12)).foregroundStyle(Theme.secondary) }.padding(16).background(.white,in:RoundedRectangle(cornerRadius:12)) }
        else if !model.error.isEmpty {Text(model.error).foregroundStyle(Theme.danger).padding(14).frame(maxWidth:.infinity,alignment:.leading).background(Color(hex:0xFAF1F0),in:RoundedRectangle(cornerRadius:8))}
        else if !model.status.isEmpty {Text(model.status).foregroundStyle(Theme.accent).frame(maxWidth:.infinity,alignment:.leading).padding(12)}
    }
    func exportCSV() {let panel=NSSavePanel();panel.nameFieldStringValue="财务快照.csv";panel.allowedContentTypes=[.commaSeparatedText];if panel.runModal() == .OK,let url=panel.url {do {try model.csv().write(to:url,atomically:true,encoding:.utf8);model.status="已导出快照 CSV"}catch {model.error="导出失败：\(error.localizedDescription)"}}}
}
