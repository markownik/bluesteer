#!/usr/bin/env swift
// Rasterises an SVG with AppKit:  render-icon.swift <in.svg> <size> <out.png>
import AppKit

let args = CommandLine.arguments
guard args.count == 4, let size = Int(args[2]) else { print("usage: render-icon.swift <in.svg> <size> <out.png>"); exit(64) }
guard let image = NSImage(contentsOfFile: args[1]) else { print("cannot load \(args[1])"); exit(1) }
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high
image.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[3]))
