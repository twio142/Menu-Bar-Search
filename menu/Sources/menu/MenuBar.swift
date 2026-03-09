//
//  MenuBar.swift
//
//
//  Created by Benzi  on 20/12/2022.
//

import Cocoa
import Foundation

class MenuBar {
  var menuBar: AXUIElement?
  let initState: AXError

  init(for app: NSRunningApplication) {
    let axApp = AXUIElementCreateApplication(app.processIdentifier)
    var menuBarValue: CFTypeRef?
    initState = AXUIElementCopyAttributeValue(axApp, kAXMenuBarAttribute as CFString, &menuBarValue)
    if initState == .success {
      menuBar = (menuBarValue as! AXUIElement)
    }
  }

  func click(pathIndices: [Int]) {
    guard let menuBar = menuBar else {
      return
    }
    clickMenu(menu: menuBar, pathIndices: pathIndices, currentIndex: 0)
  }

  func load(_ options: MenuGetterOptions) -> [MenuItem] {
    guard let menuBar = menuBar else {
      return []
    }
    return MenuGetter.loadSync(menuBar: menuBar, options: options)
  }

  func loadAsync(_ options: MenuGetterOptions) -> [MenuItem] {
    guard let menuBar = menuBar else {
      return []
    }
    return MenuGetter.loadAsync(menuBar: menuBar, options: options)
  }
}
