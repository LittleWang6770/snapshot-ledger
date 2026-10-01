import AppKit
import SwiftUI

// All fixtures below are fictitious, unrelated to any user ledger.
@MainActor func sampleRows() -> [Snapshot] {
    var rows:[Snapshot] = []
    for i in 0..<4 {
        let date = "2001-0\(i+6)-15"
        let cash:Double = 18000 + Double(i) * 6000
        let stocks:Double = 25000 + Double(i) * 1500
        let available:Double = 30000 + Double(i) * 1500
        let row = Snapshot(date:date,boc:2000,cmb:cash,wechat:900,alipay:100,usdCNY:stocks,otherCNY:0,sgdBalance:200,sgdRate:2,legacySGDCNY:nil,creditLimit:60000,available:available,legacyDebt:nil,salary:12000,fund:800,otherIncome:0,investment:0,note:"")
        rows.append(row)
    }
    return rows
}

@MainActor func testModels() throws {
    var draft = Draft(); draft.limit="60000"; draft.rate="2"; draft.sgd="100";draft.available="30000"
    let r=try draft.snapshot();precondition(abs(r.sgdCNY-200)<0.001);precondition(r.debt==30000)
    draft.sgd="0";draft.available="60000";let zero = try draft.snapshot();precondition(zero.debt==0)
    draft.sgd="";do {_ = try draft.snapshot();fatalError("blank accepted")}catch{}
    draft.sgd="nan";do {_ = try draft.snapshot();fatalError("NaN accepted")}catch{}
    let sample=sampleRows();let months=monthSummary(sample);precondition(months.count==3)
    precondition(months[0].income == 12800)
    var extra = months[0]; extra.other = 500; precondition(extra.income == 13300)
    precondition(ChartSelection.snapshot(at: sample[1].calendarDate.addingTimeInterval(86400), records: sample)?.id == sample[1].id)
    precondition(ChartSelection.snapshot(at: Date(), records: []) == nil)
    precondition(ChartSelection.tooltipX(0, width: 500) == 122 && ChartSelection.tooltipX(500, width: 500) == 378)
    let before=sample[0],after=sample[1];precondition(abs(months[0].expense-(after.income-after.liquidNet+before.liquidNet))<0.001)
    let bytes=try JSONEncoder().encode(sample);let roundtrip=try JSONDecoder().decode([Snapshot].self,from:bytes);precondition(roundtrip[3].net==sample[3].net)
    print("Model tests passed: FX, debt, zero, blank/NaN, period reconciliation, JSON round trip, combined income, nearest chart sample, tooltip edges")
}

@MainActor func integrationTests(_ directory:URL) async throws {
    let dir=directory.appendingPathComponent(UUID().uuidString)
    let empty = Ledger(directory: dir.appendingPathComponent("fresh-install")); precondition(empty.records.isEmpty)
    let model=Ledger(directory:dir,fixture:sampleRows())
    model.newRecord();model.draft.limit="60000";model.draft.rate="2";model.draft.date=Dates.format.date(from:"2001-10-05")!;model.draft.sgd="100";model.draft.available="30000"
    model.save();await model.savingTask?.value
    precondition(model.error.isEmpty && model.records.count==5)
    let first=try Data(contentsOf:model.file)
    let reopened=Ledger(directory:dir);precondition(reopened.records.count==5 && reopened.records.last?.sgdCNY==200)
    model.newRecord();model.draft.limit="60000";model.draft.rate="2";model.draft.date=Dates.format.date(from:"2001-10-05")!;model.draft.sgd="100";model.draft.available="30000";model.save()
    precondition(model.error.contains("已有快照") && model.records.count==5)
    model.newRecord();model.draft.limit="60000";model.draft.rate="2";model.draft.date=Dates.format.date(from:"2001-10-15")!;model.draft.sgd="100";model.draft.available="30000";model.save();model.cancel();await model.savingTask?.value
    let unchanged=try Data(contentsOf:model.file);precondition(unchanged==first && model.status.contains("已取消"))
    let block=dir.appendingPathComponent("not-a-directory");try Data("fixture".utf8).write(to:block)
    let failing=Ledger(directory:block,fixture:sampleRows());failing.newRecord();failing.draft.limit="60000";failing.draft.rate="2";failing.draft.sgd="100";failing.draft.available="30000";failing.save();await failing.savingTask?.value
    precondition(failing.error.contains("保存失败") && failing.records.count==4)
    precondition(model.csv().contains("新币余额SGD"))
    print("Integration tests passed: atomic save/reopen, duplicate date, cancel, write failure, CSV export")
}

@MainActor func capture<V:View>(_ view:V,name:String,size:NSSize,directory:URL) throws {
    let window=NSWindow(contentRect:NSRect(origin:.zero,size:size),styleMask:[.titled,.closable],backing:.buffered,defer:false)
    let host=NSHostingView(rootView:view.font(.system(size:13)).foregroundStyle(Theme.ink).preferredColorScheme(.light).environment(\.locale, Locale(identifier:"zh_CN")));host.frame=NSRect(origin:.zero,size:size);window.contentView=host
    window.setContentSize(size);window.orderFront(nil);host.layoutSubtreeIfNeeded()
    RunLoop.current.run(until:Date().addingTimeInterval(0.3))
    guard let rep=host.bitmapImageRepForCachingDisplay(in:host.bounds) else {throw LedgerError.message("无法生成界面预览")}
    host.cacheDisplay(in:host.bounds,to:rep)
    guard let png=rep.representation(using:.png,properties:[:]) else {throw LedgerError.message("无法编码界面预览")}
    try png.write(to:directory.appendingPathComponent(name+".png"));window.orderOut(nil)
}

@MainActor func renderQA(_ dir:URL) throws {
    try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
    for state in ["empty","results","form","advanced","saving","failure","success","cancelled"] {
        let model=Ledger(directory:dir.appendingPathComponent("isolated-"+state),fixture:state=="empty" ? [] : sampleRows())
        switch state {
        case "form","advanced":model.newRecord();model.draft.limit="60000";model.draft.rate="2";model.draft.sgd="250";model.draft.available="30000";model.advanced=state=="advanced"
        case "saving":model.busy=true;model.status="正在保存快照…"
        case "failure":model.page="历史记录";model.error="保存失败：测试用只读文件夹。原记录未被替换。"
        case "success":model.status="已保存 2001-09-30 的快照"
        case "cancelled":model.status="已取消，快照未保存"
        default:break
        }
        try capture(LedgerView(model:model),name:state,size:NSSize(width:980,height:720),directory:dir)
    }
    let model=Ledger(directory:dir,fixture:sampleRows())
    try capture(LedgerView(model:model).dashboard.padding(24).background(Theme.background).frame(width:760),name:"dashboard-full",size:NSSize(width:760,height:1050),directory:dir)
    model.newRecord();model.draft.limit="60000";model.draft.rate="2";model.advanced=true;model.draft.sgd="250";model.draft.available="30000"
    try capture(LedgerView(model:model).form.padding(24).background(Theme.background).frame(width:730),name:"form-full",size:NSSize(width:730,height:1120),directory:dir)
    for date in ["2001-06-15", "2001-09-15"] {
        try capture(Card(title:"财富增长") { WealthChart(records:sampleRows(),previewSelection:date) }.padding(24).background(Theme.background),name:"wealth-hover-"+date,size:NSSize(width:670,height:370),directory:dir)
    }
    try capture(Card(title:"每月收入与支出") { MonthlyChart(months:monthSummary(sampleRows()),previewSelection:"2001-09") }.padding(24).background(Theme.background),name:"monthly-hover",size:NSSize(width:670,height:370),directory:dir)
    print("Rendered 13 synthetic UI states including chart tooltips; no personal ledger modified")
}

@MainActor final class AppDelegate:NSObject,NSApplicationDelegate {
    var window:NSWindow?
    func applicationDidFinishLaunching(_ notification:Notification) {
        let model=Ledger()
        let w=NSWindow(contentRect:NSRect(x:0,y:0,width:1180,height:880),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        w.title="财务快照";w.minSize=NSSize(width:980,height:748);w.contentView=NSHostingView(rootView:LedgerView(model:model));w.center();w.makeKeyAndOrderFront(nil);window=w;NSApp.activate(ignoringOtherApps:true)
        let menu=NSMenu();let appItem=NSMenuItem();let appMenu=NSMenu();appMenu.addItem(withTitle:"退出财务快照",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q");appItem.submenu=appMenu;menu.addItem(appItem)
        let editItem=NSMenuItem(title:"编辑",action:nil,keyEquivalent:"");let editMenu=NSMenu(title:"编辑")
        for (name,key,action) in [("撤销","z","undo:"),("剪切","x","cut:"),("复制","c","copy:"),("粘贴","v","paste:"),("全选","a","selectAll:")] {editMenu.addItem(withTitle:name,action:NSSelectorFromString(action),keyEquivalent:key)}
        editItem.submenu=editMenu;menu.addItem(editItem);NSApp.mainMenu=menu
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {true}
}

MainActor.assumeIsolated {
if CommandLine.arguments.contains("--self-test") {do {try testModels()}catch {fatalError(error.localizedDescription)}}
else if let idx=CommandLine.arguments.firstIndex(of:"--integration-test"),CommandLine.arguments.count>idx+1 {
    Task { @MainActor in
        do {try await integrationTests(URL(fileURLWithPath:CommandLine.arguments[idx+1]));exit(0)}catch {fatalError(error.localizedDescription)}
    }
    RunLoop.main.run()
}
else if let idx=CommandLine.arguments.firstIndex(of:"--render-qa"),CommandLine.arguments.count>idx+1 {
    let app=NSApplication.shared
    app.setActivationPolicy(.accessory)
    do {try renderQA(URL(fileURLWithPath:CommandLine.arguments[idx+1]))}catch {fatalError(error.localizedDescription)}
} else {
    let app=NSApplication.shared
    app.setActivationPolicy(.regular);let delegate=AppDelegate();app.delegate=delegate;withExtendedLifetime(delegate) { app.run() }
}
}
