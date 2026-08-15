import AppKit

guard CommandLine.arguments.count >= 3 else {
    print("Usage: swift crop_icon.swift <input.jpg> <output.png>")
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]

guard let image = NSImage(contentsOfFile: inputPath),
      let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let cgImage = bitmap.cgImage else {
    print("Error loading image")
    exit(1)
}

let width = cgImage.width
let height = cgImage.height

var minX = width
var maxX = 0
var minY = height
var maxY = 0

let colorSpace = CGColorSpaceCreateDeviceRGB()
let bytesPerPixel = 4
let bytesPerRow = bytesPerPixel * width
let rawData = UnsafeMutablePointer<UInt8>.allocate(capacity: height * bytesPerRow)

guard let context = CGContext(
    data: rawData,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    exit(1)
}

context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

for y in 0..<height {
    for x in 0..<width {
        let offset = (y * bytesPerRow) + (x * bytesPerPixel)
        let r = rawData[offset]
        let g = rawData[offset + 1]
        let b = rawData[offset + 2]
        
        if r < 240 || g < 240 || b < 240 {
            if x < minX { minX = x }
            if x > maxX { maxX = x }
            if y < minY { minY = y }
            if y > maxY { maxY = y }
        }
    }
}

let cropWidth = maxX - minX
let cropHeight = maxY - minY
let cropRect = CGRect(x: minX, y: height - maxY, width: cropWidth, height: cropHeight)

if let croppedCGImage = cgImage.cropping(to: cropRect) {
    let newRep = NSBitmapImageRep(cgImage: croppedCGImage)
    if let pngData = newRep.representation(using: .png, properties: [:]) {
        try? pngData.write(to: URL(fileURLWithPath: outputPath))
        print("Cropped icon saved successfully to \(outputPath)")
    }
}
