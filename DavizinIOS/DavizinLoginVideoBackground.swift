import SwiftUI
import AVFoundation

struct DavizinLoginVideoBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.start()
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {}

    final class PlayerView: UIView {
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?

        override class var layerClass: AnyClass { AVPlayerLayer.self }

        private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        func start() {
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
}
