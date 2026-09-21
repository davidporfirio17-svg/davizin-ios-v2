import SwiftUI
import AVFoundation

final class DavizinLoginVideoView: UIView {
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        clipsToBounds = true
        start()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
        clipsToBounds = true
        start()
    }

    private func start() {
        guard let url = Bundle.main.url(forResource: "login_background", withExtension: "mp4") else { return }
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer()
        queue.isMuted = true
        queue.actionAtItemEnd = .none
        looper = AVPlayerLooper(player: queue, templateItem: item)
        player = queue
        playerLayer.player = queue
        playerLayer.videoGravity = .resizeAspectFill
        queue.play()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { player?.play() } else { player?.pause() }
    }
}

struct DavizinLoginVideoBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> DavizinLoginVideoView {
        DavizinLoginVideoView()
    }

    func updateUIView(_ uiView: DavizinLoginVideoView, context: Context) {}
}
