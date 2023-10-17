import CallKit

extension BChatCallManager: CXProviderDelegate {
    public func providerDidReset(_ provider: CXProvider) {
        AssertIsOnMainThread()
        currentCall?.endBChatCall()
    }
    
    public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        AssertIsOnMainThread()
        if startCallAction() {
            action.fulfill()
        } else {
            action.fail()
        }
    }
    
    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        AssertIsOnMainThread()
        print("[CallKit] Perform CXAnswerCallAction")
        guard let call = self.currentCall else { return action.fail() }
        if CurrentAppContext().isMainAppAndActive {
            if answerCallAction() {
                action.fulfill()
            } else {
                action.fail()
            }
        } else {
            call.answerBChatCallInBackground(action: action)
        }
    }
    
    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("[CallKit] Perform CXEndCallAction")
        AssertIsOnMainThread()
        if endCallAction() {
            action.fulfill()
        } else {
            action.fail()
        }
    }
    
    public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        print("[CallKit] Perform CXSetMutedCallAction, isMuted: \(action.isMuted)")
        AssertIsOnMainThread()
        if setMutedCallAction(isMuted: action.isMuted) {
            action.fulfill()
        } else {
            action.fail()
        }
    }
    
    public func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        // TODO: set on hold
    }
    
    public func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        // TODO: handle timeout
    }
    
    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("[CallKit] Audio bchat did activate.")
        AssertIsOnMainThread()
        guard let call = self.currentCall else { return }
        call.webRTCBChat.audioSessionDidActivate(audioSession)
        if call.isOutgoing && !call.hasConnected { CallRingTonePlayer.shared.startPlayingRingTone() }
    }
    
    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("[CallKit] Audio bchat did deactivate.")
        AssertIsOnMainThread()
        guard let call = self.currentCall else { return }
        call.webRTCBChat.audioSessionDidDeactivate(audioSession)
    }
}

