import Foundation
import YcodeAssistant
import YcodeIDECore

extension VisualComponentNode {
    public convenience init(assistNode: YcodeAssistant.VisualComponentNode) {
        self.init(
            id: assistNode.id,
            type: VisualComponentType(rawValue: assistNode.type.rawValue) ?? .vStack,
            name: assistNode.name,
            children: assistNode.children.map { VisualComponentNode(assistNode: $0) },
            properties: assistNode.properties,
            isLocked: assistNode.isLocked,
            isHidden: assistNode.isHidden
        )
    }

    public func toAssistNode() -> YcodeAssistant.VisualComponentNode {
        YcodeAssistant.VisualComponentNode(
            id: id,
            type: YcodeAssistant.VisualComponentType(rawValue: type.rawValue) ?? .vStack,
            name: name,
            properties: properties,
            children: children.map { $0.toAssistNode() },
            customCode: nil,
            isLocked: isLocked,
            isHidden: isHidden
        )
    }
}

extension VisualUIArtboard {
    public convenience init(assistArtboard: YcodeAssistant.VisualUIArtboard) {
        self.init(
            id: assistArtboard.id,
            name: assistArtboard.name,
            deviceFrame: assistArtboard.deviceFrame,
            rootNode: VisualComponentNode(assistNode: assistArtboard.rootNode),
            customSwiftUISource: assistArtboard.customSwiftUISource,
            appearance: assistArtboard.appearance,
            isPortrait: assistArtboard.isPortrait,
            dynamicTypeSize: assistArtboard.dynamicTypeSize,
            previewScale: assistArtboard.previewScale,
            showSafeAreas: assistArtboard.showSafeAreas
        )
    }

    public func toAssistArtboard() -> YcodeAssistant.VisualUIArtboard {
        YcodeAssistant.VisualUIArtboard(
            id: id,
            name: name,
            deviceFrame: deviceFrame,
            rootNode: rootNode.toAssistNode(),
            customSwiftUISource: customSwiftUISource,
            appearance: appearance,
            isPortrait: isPortrait,
            dynamicTypeSize: dynamicTypeSize,
            previewScale: previewScale,
            showSafeAreas: showSafeAreas
        )
    }
}

extension VisualUIScene {
    public convenience init(assistScene: YcodeAssistant.VisualUIScene) {
        self.init(
            id: assistScene.id,
            artboards: assistScene.artboards.map { VisualUIArtboard(assistArtboard: $0) },
            selectedNodeIDs: assistScene.selectedNodeIDs,
            activeArtboardID: assistScene.activeArtboardID,
            currentFramework: VisualUIFramework(rawValue: assistScene.currentFramework.rawValue) ?? .swiftUI,
            zoomScale: assistScene.zoomScale,
            panOffsetX: assistScene.panOffsetX,
            panOffsetY: assistScene.panOffsetY
        )
    }

    public func toAssistScene() -> YcodeAssistant.VisualUIScene {
        YcodeAssistant.VisualUIScene(
            id: id,
            artboards: artboards.map { $0.toAssistArtboard() },
            selectedNodeIDs: selectedNodeIDs,
            activeArtboardID: activeArtboardID,
            currentFramework: YcodeAssistant.VisualUIFramework(rawValue: currentFramework.rawValue) ?? .swiftUI,
            zoomScale: zoomScale,
            panOffsetX: panOffsetX,
            panOffsetY: panOffsetY
        )
    }
}

extension VisualUIDocument {
    public convenience init(assistDocument: YcodeAssistant.VisualUIDocument) {
        self.init(scene: VisualUIScene(assistScene: assistDocument.scene))
        self.filePath = assistDocument.filePath
        self.isDirty = assistDocument.isDirty
    }

    public func toAssistDocument() -> YcodeAssistant.VisualUIDocument {
        let doc = YcodeAssistant.VisualUIDocument(scene: scene.toAssistScene())
        doc.filePath = filePath
        doc.isDirty = isDirty
        return doc
    }
}
