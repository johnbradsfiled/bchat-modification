import PromiseKit
import WebRTC

public protocol WebRTCBChatDelegate : AnyObject {
    var videoCapturer: RTCVideoCapturer { get }
    
    func webRTCIsConnected()
    func isRemoteVideoDidChange(isEnabled: Bool)
    func dataChannelDidOpen()
    func didReceiveHangUpSignal()
    func reconnectIfNeeded()
}

/// See https://webrtc.org/getting-started/overview for more information.
public final class WebRTCBChat : NSObject, RTCPeerConnectionDelegate {
    public weak var delegate: WebRTCBChatDelegate?
    public let uuid: String
    private let contactBChatID: String
    private var queuedICECandidates: [RTCIceCandidate] = []
    private var iceCandidateSendTimer: Timer?
    
    private lazy var defaultICEServer: TurnServerInfo? = {
        let url = Bundle.main.url(forResource: "BChat-Turn-Server", withExtension: nil)!
        let data = try! Data(contentsOf: url)
        let json = try! JSONSerialization.jsonObject(with: data, options: [ .fragmentsAllowed ]) as! JSON
        return TurnServerInfo(attributes: json, random: 2)
    }()
    
    internal lazy var factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
    }()
    
    /// Represents a WebRTC connection between the user and a remote peer. Provides methods to connect to a
    /// remote peer, maintain and monitor the connection, and close the connection once it's no longer needed.
    internal lazy var peerConnection: RTCPeerConnection? = {
        let configuration = RTCConfiguration()
        if let defaultICEServer = defaultICEServer {
            configuration.iceServers = [ RTCIceServer(urlStrings: defaultICEServer.urls, username: defaultICEServer.username, credential: defaultICEServer.password) ]
        }
        configuration.sdpSemantics = .unifiedPlan
        let constraints = RTCMediaConstraints(mandatoryConstraints: [:], optionalConstraints: [:])
        return factory.peerConnection(with: configuration, constraints: constraints, delegate: self)
    }()
    
    // Audio
    internal lazy var audioSource: RTCAudioSource = {
        let constraints = RTCMediaConstraints(mandatoryConstraints: [:], optionalConstraints: [:])
        return factory.audioSource(with: constraints)
    }()
    
    internal lazy var audioTrack: RTCAudioTrack = {
        return factory.audioTrack(with: audioSource, trackId: "ARDAMSa0")
    }()
    
    // Video
    public lazy var localVideoSource: RTCVideoSource = {
        let result = factory.videoSource()
        result.adaptOutputFormat(toWidth: 360, height: 780, fps: 30)
        return result
    }()
    
    internal lazy var localVideoTrack: RTCVideoTrack = {
        return factory.videoTrack(with: localVideoSource, trackId: "ARDAMSv0")
    }()
    
    internal lazy var remoteVideoTrack: RTCVideoTrack? = {
        return peerConnection?.transceivers.first { $0.mediaType == .video }?.receiver.track as? RTCVideoTrack
    }()
    
    // Data Channel
    internal var dataChannel: RTCDataChannel?
    
    // MARK: Error
    public enum Error : LocalizedError {
        case noThread
        
        public var errorDescription: String? {
            switch self {
            case .noThread: return "Couldn't find thread for contact."
            }
        }
    }
    
    // MARK: Initialization
    public static var current: WebRTCBChat?
    
    public init(for contactBChatID: String, with uuid: String) {
        RTCAudioSession.sharedInstance().useManualAudio = true
        RTCAudioSession.sharedInstance().isAudioEnabled = false
        self.contactBChatID = contactBChatID
        self.uuid = uuid
        super.init()
        let mediaStreamTrackIDS = ["ARDAMS"]
        peerConnection?.add(audioTrack, streamIds: mediaStreamTrackIDS)
        peerConnection?.add(localVideoTrack, streamIds: mediaStreamTrackIDS)
        // Configure audio bchat
        configureAudioSession()
        
        // Data channel
        if let dataChannel = createDataChannel() {
            dataChannel.delegate = self
            self.dataChannel = dataChannel
        }
    }
    
    // MARK: Signaling
    public func sendPreOffer(_ message: CallMessage, in thread: TSThread, using transaction: YapDatabaseReadWriteTransaction) -> Promise<Void> {
        SNLog("[Calls] Sending pre-offer message.")
        let (promise, seal) = Promise<Void>.pending()
        DispatchQueue.main.async {
            MessageSender.sendNonDurably(message, in: thread, using: transaction).done2 {
                SNLog("[Calls] Pre-offer message has been sent.")
                seal.fulfill(())
            }.catch2 { error in
                seal.reject(error)
            }
        }
        return promise
    }
    
    public func sendOffer(to bchatuserID: String, using transaction: YapDatabaseReadWriteTransaction, isRestartingICEConnection: Bool = false) -> Promise<Void> {
        SNLog("[Calls] Sending offer message.")
        guard let thread = TSContactThread.fetch(for: bchatuserID, using: transaction) else { return Promise(error: Error.noThread) }
        let (promise, seal) = Promise<Void>.pending()
        peerConnection?.offer(for: mediaConstraints(isRestartingICEConnection)) { [weak self] sdp, error in
            if let error = error {
                seal.reject(error)
            } else {
                guard let self = self, let sdp = self.correctSessionDescription(sdp: sdp) else { preconditionFailure() }
                self.peerConnection?.setLocalDescription(sdp) { error in
                    if let error = error {
                        print("Couldn't initiate call due to error: \(error).")
                        return seal.reject(error)
                    }
                }
                DispatchQueue.main.async {
                    let message = CallMessage()
                    message.sentTimestamp = NSDate.millisecondTimestamp()
                    message.uuid = self.uuid
                    message.kind = .offer
                    message.sdps = [ sdp.sdp ]
                    MessageSender.sendNonDurably(message, in: thread, using: transaction).done2 {
                        seal.fulfill(())
                    }.catch2 { error in
                        seal.reject(error)
                    }
                }
            }
        }
        return promise
    }
    
    public func sendAnswer(to bchatuserID: String, using transaction: YapDatabaseReadWriteTransaction) -> Promise<Void> {
        SNLog("[Calls] Sending answer message.")
        guard let thread = TSContactThread.fetch(for: bchatuserID, using: transaction) else { return Promise(error: Error.noThread) }
        let (promise, seal) = Promise<Void>.pending()
        peerConnection?.answer(for: mediaConstraints(false)) { [weak self] sdp, error in
            if let error = error {
                seal.reject(error)
            } else {
                guard let self = self, let sdp = self.correctSessionDescription(sdp: sdp) else { preconditionFailure() }
                self.peerConnection?.setLocalDescription(sdp) { error in
                    if let error = error {
                        print("Couldn't accept call due to error: \(error).")
                        return seal.reject(error)
                    }
                }
                DispatchQueue.main.async {
                    let message = CallMessage()
                    message.uuid = self.uuid
                    message.kind = .answer
                    message.sdps = [ sdp.sdp ]
                    MessageSender.sendNonDurably(message, in: thread, using: transaction).done2 {
                        seal.fulfill(())
                    }.catch2 { error in
                        seal.reject(error)
                    }
                }
            }
        }
        return promise
    }
    
    private func queueICECandidateForSending(_ candidate: RTCIceCandidate) {
        queuedICECandidates.append(candidate)
        DispatchQueue.main.async {
            self.iceCandidateSendTimer?.invalidate()
            self.iceCandidateSendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
                self.sendICECandidates()
            }
        }
    }
    
    private func sendICECandidates() {
        Storage.write { transaction in
            let candidates = self.queuedICECandidates
            guard let thread = TSContactThread.fetch(for: self.contactBChatID, using: transaction) else { return }
            SNLog("[Calls] Batch sending \(candidates.count) ICE candidates.")
            let message = CallMessage()
            let sdps = candidates.map { $0.sdp }
            let sdpMLineIndexes = candidates.map { UInt32($0.sdpMLineIndex) }
            let sdpMids = candidates.map { $0.sdpMid! }
            message.uuid = self.uuid
            message.kind = .iceCandidates(sdpMLineIndexes: sdpMLineIndexes, sdpMids: sdpMids)
            message.sdps = sdps
            self.queuedICECandidates.removeAll()
            MessageSender.sendNonDurably(message, in: thread, using: transaction).retainUntilComplete()
        }
    }
    
    public func endCall(with bchatuserID: String, using transaction: YapDatabaseReadWriteTransaction) {
        guard let thread = TSContactThread.fetch(for: bchatuserID, using: transaction) else { return }
        let message = CallMessage()
        message.uuid = self.uuid
        message.kind = .endCall
        SNLog("[Calls] Sending end call message.")
        MessageSender.sendNonDurably(message, in: thread, using: transaction).retainUntilComplete()
    }
    
    public func dropConnection() {
        peerConnection?.close()
    }
    
    private func mediaConstraints(_ isRestartingICEConnection: Bool) -> RTCMediaConstraints {
        var mandatory: [String:String] = [
            kRTCMediaConstraintsOfferToReceiveAudio : kRTCMediaConstraintsValueTrue,
            kRTCMediaConstraintsOfferToReceiveVideo : kRTCMediaConstraintsValueTrue,
        ]
        if isRestartingICEConnection { mandatory[kRTCMediaConstraintsIceRestart] = kRTCMediaConstraintsValueTrue }
        let optional: [String:String] = [:]
        return RTCMediaConstraints(mandatoryConstraints: mandatory, optionalConstraints: optional)
    }
    
    private func correctSessionDescription(sdp: RTCSessionDescription?) -> RTCSessionDescription? {
        guard let sdp = sdp else { return nil }
        let cbrSdp = sdp.sdp.description.replace(regex: "(a=fmtp:111 ((?!cbr=).)*)\r?\n", with: "$1;cbr=1\r\n")
        let finalSdp = cbrSdp.replace(regex: ".+urn:ietf:params:rtp-hdrext:ssrc-audio-level.*\r?\n", with: "")
        return RTCSessionDescription(type: sdp.type, sdp: finalSdp)
    }
    
    // MARK: Peer connection delegate
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange state: RTCSignalingState) {
        SNLog("[Calls] Signaling state changed to: \(state).")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        SNLog("[Calls] Peer connection did add stream.")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        SNLog("[Calls] Peer connection did remove stream.")
    }
    
    public func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        SNLog("[Calls] Peer connection should negotiate.")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange state: RTCIceConnectionState) {
        SNLog("[Calls] ICE connection state changed to: \(state).")
        if state == .connected {
            delegate?.webRTCIsConnected()
        } else if state == .disconnected {
            if self.peerConnection?.signalingState == .stable {
                delegate?.reconnectIfNeeded()
            }
        }
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange state: RTCIceGatheringState) {
        SNLog("[Calls] ICE gathering state changed to: \(state).")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        queueICECandidateForSending(candidate)
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        SNLog("[Calls] \(candidates.count) ICE candidate(s) removed.")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        SNLog("[Calls] Data channel opened.")
    }
}

extension WebRTCBChat {
    public func configureAudioSession(outputAudioPort: AVAudioSession.PortOverride = .none) {
        let audioSession = RTCAudioSession.sharedInstance()
        audioSession.lockForConfiguration()
        do {
            try audioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
            try audioSession.setMode(AVAudioSession.Mode.voiceChat.rawValue)
            try audioSession.overrideOutputAudioPort(outputAudioPort)
            try audioSession.setActive(true)
        } catch let error {
            SNLog("Couldn't set up WebRTC audio bchat due to error: \(error)")
        }
        audioSession.unlockForConfiguration()
    }
    
    public func audioSessionDidActivate(_ audioSession: AVAudioSession) {
        RTCAudioSession.sharedInstance().audioSessionDidActivate(audioSession)
        RTCAudioSession.sharedInstance().isAudioEnabled = true
        configureAudioSession()
    }
    
    public func audioSessionDidDeactivate(_ audioSession: AVAudioSession) {
        RTCAudioSession.sharedInstance().audioSessionDidDeactivate(audioSession)
        RTCAudioSession.sharedInstance().isAudioEnabled = false
    }
    
    public func mute() {
        audioTrack.isEnabled = false
    }
    
    public func unmute() {
        audioTrack.isEnabled = true
    }
    
    public func turnOffVideo() {
        localVideoTrack.isEnabled = false
        sendJSON(["video": false])
    }
    
    public func turnOnVideo() {
        localVideoTrack.isEnabled = true
        sendJSON(["video": true])
    }
    
    public func hangUp() {
        sendJSON(["hangup": true])
    }
}
