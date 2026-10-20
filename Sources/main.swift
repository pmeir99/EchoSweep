import SwiftUI
import AppKit

struct Track: Identifiable {
 let id: URL
 let fp: String
 let size: Int64
}
@MainActor final class Library: ObservableObject {
 @Published var groups: [[Track]] = []
 @Published var scanning = false
 @Published var count = 0
 @Published var selected = Set<URL>()
 @Published var folder: URL?
 func choose() {
  let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = false
  if p.runModal() == .OK, let u = p.url { folder = u; scan(u) }
 }
 func scan(_ root: URL) {
  guard !scanning else { return }; scanning = true; count = 0; groups = []; selected = []
  Task.detached {
   let access = root.startAccessingSecurityScopedResource()
   defer { if access { root.stopAccessingSecurityScopedResource() } }
   let extensions: Set<String> = ["mp3","m4a","aac","flac","wav","aiff","ogg","opus"]
   let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])
   var map: [String:[Track]] = [:]
   while let u = files?.nextObject() as? URL {
    guard extensions.contains(u.pathExtension.lowercased()) else { continue }
    if let fp = Fingerprint.get(u) {
     let size = Int64((try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
     map[fp, default: []].append(Track(id:u,fp:fp,size:size))
    }
    let groups = map.values.filter { $0.count > 1 }.map { $0.sorted { $0.size > $1.size } }
    await MainActor.run { self.count += 1; self.groups = groups }
   }
   await MainActor.run { self.scanning = false }
  }
 }
 func trash() {
  let a = NSAlert(); a.messageText = "Move \(selected.count) files to Trash?"; a.informativeText = "Check selections before proceeding. Files can be restored from Trash."; a.addButton(withTitle:"Move to Trash"); a.addButton(withTitle:"Cancel")
  guard a.runModal() == .alertFirstButtonReturn else { return }
  for u in selected { try? FileManager.default.trashItem(at:u,resultingItemURL:nil) }
  if let folder { scan(folder) }
 }
}
enum Fingerprint {
 static func get(_ url:URL)->String? {
  let bundled = Bundle.main.resourceURL?.appendingPathComponent("bin/fpcalc").path ?? ""
  let binary = FileManager.default.isExecutableFile(atPath:bundled) ? bundled : "/opt/homebrew/bin/fpcalc"
  guard FileManager.default.isExecutableFile(atPath:binary) else { return nil }
  let p = Process(); p.executableURL = URL(fileURLWithPath:binary); p.arguments = ["-json","-length","120",url.path]
  let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
  do { try p.run(); let data = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
   guard p.terminationStatus == 0, let obj = try JSONSerialization.jsonObject(with:data) as? [String:Any] else { return nil }
   return obj["fingerprint"] as? String
  } catch { return nil }
 }
}
struct MainView: View {
 @StateObject private var library = Library()
 var body: some View {
  NavigationSplitView {
   VStack(alignment:.leading,spacing:20) {
    Label("EchoSweep",systemImage:"waveform.circle.fill").font(.title2.bold())
    Text("Your music, without the repeats.").foregroundStyle(.secondary)
    Button("Choose Folder or Drive",systemImage:"externaldrive") { library.choose() }.buttonStyle(.borderedProminent).disabled(library.scanning)
    if let folder = library.folder { Text(folder.lastPathComponent).font(.caption).foregroundStyle(.secondary) }
    Divider()
    Label("\(library.count) files analyzed",systemImage:"music.note.list")
    Label("\(library.groups.count) duplicate groups",systemImage:"square.on.square")
    Spacer()
    Text("Nothing is removed automatically.").font(.caption).foregroundStyle(.secondary)
   }.padding(22).frame(minWidth:240,maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
  } detail: {
   VStack(spacing:0) {
    HStack {
     VStack(alignment:.leading) { Text("Duplicate Music").font(.largeTitle.bold()); Text(library.scanning ? "Scanning your music…" : "Review acoustic matches").foregroundStyle(.secondary) }
     Spacer()
     if library.scanning { ProgressView().controlSize(.small) }
     if !library.selected.isEmpty { Button("Trash Selected (\(library.selected.count))",role:.destructive) { library.trash() } }
    }.padding(24)
    Divider()
    if library.groups.isEmpty { ContentUnavailableView(library.scanning ? "Scanning" : "No Duplicates Yet",systemImage:"waveform",description:Text("Choose a folder or external drive to scan.")).frame(maxWidth:.infinity,maxHeight:.infinity) }
    else { ScrollView { LazyVStack(spacing:16) {
     ForEach(library.groups.indices,id:\.self) { i in
      VStack(alignment:.leading,spacing:12) {
       Text(library.groups[i][0].id.deletingPathExtension().lastPathComponent).font(.headline)
       ForEach(library.groups[i]) { track in
        HStack {
         Toggle("",isOn:Binding(get:{library.selected.contains(track.id)},set:{ if $0 { library.selected.insert(track.id) } else { library.selected.remove(track.id) } })).labelsHidden()
         VStack(alignment:.leading) { Text(track.id.lastPathComponent).lineLimit(1); Text(track.id.deletingLastPathComponent().path).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
         Spacer()
         Text(ByteCountFormatter.string(fromByteCount:track.size,countStyle:.file)).font(.caption).foregroundStyle(.secondary)
         Button { NSWorkspace.shared.activateFileViewerSelecting([track.id]) } label: { Image(systemName:"arrow.up.forward.square") }.buttonStyle(.borderless)
        }
       }
      }.padding(16).background(.regularMaterial,in:RoundedRectangle(cornerRadius:18))
     }
    }.padding(24) } }
   }.frame(minWidth:650,minHeight:500)
  }
 }
}
@main struct EchoSweep: App { var body: some Scene { WindowGroup { MainView() } } }
