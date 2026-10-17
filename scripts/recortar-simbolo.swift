import AppKit
// swift scripts/recortar-simbolo.swift <entrada> <saida> <largura da faixa esquerda>: recorta a faixa esquerda e apara pela transparência
let a = CommandLine.arguments
let img = NSImage(contentsOfFile: a[1])!
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
let faixa = Int(a[3])!
var minX = rep.pixelsWide, minY = rep.pixelsHigh, maxX = 0, maxY = 0
for y in 0..<rep.pixelsHigh { for x in 0..<min(faixa, rep.pixelsWide) {
  if let c = rep.colorAt(x: x, y: y), c.alphaComponent > 0.05 { minX = min(minX,x); maxX = max(maxX,x); minY = min(minY,y); maxY = max(maxY,y) } } }
let w = maxX-minX+1, h = maxY-minY+1, lado = max(w,h)
let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: lado, pixelsHigh: lado, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
let cg = rep.cgImage!.cropping(to: CGRect(x: minX, y: minY, width: w, height: h))!
NSGraphicsContext.current!.cgContext.draw(cg, in: CGRect(x: (lado-w)/2, y: (lado-h)/2, width: w, height: h))
NSGraphicsContext.restoreGraphicsState()
try! out.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[2]))
print("recorte", minX, minY, w, h, "->", lado)
