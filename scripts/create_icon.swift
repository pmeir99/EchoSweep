import AppKit
import Foundation
let output = CommandLine.arguments[1]
let root = URL(fileURLWithPath: output, isDirectory: true)
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
for size in [16,32,64,128,256,512,1024] {
 let image = NSImage(size:NSSize(width:size,height:size))
 image.lockFocus()
 let s = CGFloat(size)
 let bounds = NSRect(x:0,y:0,width:s,height:s)
 let bg = NSBezierPath(roundedRect:bounds.insetBy(dx:s*0.025,dy:s*0.025),xRadius:s*0.24,yRadius:s*0.24)
 NSColor(calibratedRed:0.12,green:0.28,blue:0.40,alpha:1).setFill(); bg.fill()
 let ring = NSBezierPath(ovalIn:bounds.insetBy(dx:s*0.19,dy:s*0.19))
 ring.lineWidth=s*0.065
 NSColor(calibratedRed:0.67,green:0.90,blue:0.95,alpha:0.8).setStroke(); ring.stroke()
 let wave = NSBezierPath()
 let heights:[CGFloat] = [0.12,0.28,0.45,0.21,0.39,0.17,0.31]
 for (i,h) in heights.enumerated() {
  let x = s*(0.28+CGFloat(i)*0.073)
  wave.move(to:NSPoint(x:x,y:s*(0.5-h/2)))
  wave.line(to:NSPoint(x:x,y:s*(0.5+h/2)))
 }
 wave.lineWidth=s*0.035; wave.lineCapStyle = .round
 NSColor.white.setStroke(); wave.stroke()
 image.unlockFocus()
 guard let tiff=image.tiffRepresentation, let rep=NSBitmapImageRep(data:tiff), let png=rep.representation(using:.png,properties:[:]) else { fatalError("Icon rendering failed") }
 let suffix = size == 1024 ? "512x512@2x" : size == 64 ? "32x32@2x" : size == 128 ? "128x128" : size == 256 ? "256x256" : size == 512 ? "512x512" : size == 32 ? "32x32" : "16x16"
 try png.write(to:root.appendingPathComponent("icon_\(suffix).png"))
}
