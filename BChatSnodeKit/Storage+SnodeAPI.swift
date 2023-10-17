import BChatUtilitiesKit

extension Storage {

    // MARK: - Snode Pool
    
    private static let snodePoolCollection = "BeldexSnodePoolCollection"
    private static let lastSnodePoolRefreshDateCollection = "BeldexLastSnodePoolRefreshDateCollection"

    public func getSnodePool() -> Set<Snode> {
        var result: Set<Snode> = []
        Storage.read { transaction in
            transaction.enumerateKeysAndObjects(inCollection: Storage.snodePoolCollection) { _, object, _ in
                guard let snode = object as? Snode else { return }
                result.insert(snode)
            }
        }
        return result
    }

    public func setSnodePool(to snodePool: Set<Snode>, using transaction: Any) {
        clearSnodePool(in: transaction)
        snodePool.forEach { snode in
            (transaction as! YapDatabaseReadWriteTransaction).setObject(snode, forKey: snode.description, inCollection: Storage.snodePoolCollection)
        }
    }

    public func clearSnodePool(in transaction: Any) {
        (transaction as! YapDatabaseReadWriteTransaction).removeAllObjects(inCollection: Storage.snodePoolCollection)
    }
    
    public func getLastSnodePoolRefreshDate() -> Date? {
        var result: Date?
        Storage.read { transaction in
            result = transaction.object(forKey: "lastSnodePoolRefreshDate", inCollection: Storage.lastSnodePoolRefreshDateCollection) as? Date
        }
        return result
    }
    
    public func setLastSnodePoolRefreshDate(to date: Date, using transaction: Any) {
        (transaction as! YapDatabaseReadWriteTransaction).setObject(date, forKey: "lastSnodePoolRefreshDate", inCollection: Storage.lastSnodePoolRefreshDateCollection)
    }



    // MARK: - Swarm
    
    private static func getSwarmCollection(for publicKey: String) -> String {
        return "BeldexSwarmCollection-\(publicKey)"
    }

    public func getSwarm(for publicKey: String) -> Set<Snode> {
        var result: Set<Snode> = []
        let collection = Storage.getSwarmCollection(for: publicKey)
        Storage.read { transaction in
            transaction.enumerateKeysAndObjects(inCollection: collection) { _, object, _ in
                guard let snode = object as? Snode else { return }
                result.insert(snode)
            }
        }
        return result
    }

    public func setSwarm(to swarm: Set<Snode>, for publicKey: String, using transaction: Any) {
        clearSwarm(for: publicKey, in: transaction)
        let collection = Storage.getSwarmCollection(for: publicKey)
        swarm.forEach { snode in
            (transaction as! YapDatabaseReadWriteTransaction).setObject(snode, forKey: snode.description, inCollection: collection)
        }
    }

    public func clearSwarm(for publicKey: String, in transaction: Any) {
        let collection = Storage.getSwarmCollection(for: publicKey)
        (transaction as! YapDatabaseReadWriteTransaction).removeAllObjects(inCollection: collection)
    }



    // MARK: - Last Message Hash

    private static let lastMessageHashCollection = "BeldexLastMessageHashCollection"

    public func getLastMessageHashInfo(for snode: Snode, namespace: Int, associatedWith publicKey: String) -> JSON? {
        let key = namespace == SnodeAPI.defaultNamespace ? "\(snode.address):\(snode.port).\(publicKey)" : "\(snode.address):\(snode.port).\(publicKey).\(namespace)"
        var result: JSON?
        Storage.read { transaction in
            result = transaction.object(forKey: key, inCollection: Storage.lastMessageHashCollection) as? JSON
        }
        if let result = result {
            guard result["hash"] as? String != nil else { return nil }
            guard result["expirationDate"] as? NSNumber != nil else { return nil }
        }
        return result
    }

    public func getLastMessageHash(for snode: Snode, namespace: Int, associatedWith publicKey: String) -> String? {
        return getLastMessageHashInfo(for: snode, namespace: namespace, associatedWith: publicKey)?["hash"] as? String
    }

    public func setLastMessageHashInfo(for snode: Snode, namespace: Int, associatedWith publicKey: String, to lastMessageHashInfo: JSON, using transaction: Any) {
        let key = namespace == SnodeAPI.defaultNamespace ? "\(snode.address):\(snode.port).\(publicKey)" : "\(snode.address):\(snode.port).\(publicKey).\(namespace)"
        guard lastMessageHashInfo.count == 2 && lastMessageHashInfo["hash"] as? String != nil && lastMessageHashInfo["expirationDate"] as? NSNumber != nil else { return }
        (transaction as! YapDatabaseReadWriteTransaction).setObject(lastMessageHashInfo, forKey: key, inCollection: Storage.lastMessageHashCollection)
    }

    public func pruneLastMessageHashInfoIfExpired(for snode: Snode, namespace: Int, associatedWith publicKey: String) {
        guard let lastMessageHashInfo = getLastMessageHashInfo(for: snode, namespace: namespace, associatedWith: publicKey),
            (lastMessageHashInfo["hash"] as? String) != nil, let expirationDate = (lastMessageHashInfo["expirationDate"] as? NSNumber)?.uint64Value else { return }
        let now = NSDate.millisecondTimestamp()
        if now >= expirationDate {
            Storage.writeSync { transaction in
                self.removeLastMessageHashInfo(for: snode, namespace: namespace, associatedWith: publicKey, using: transaction)
            }
        }
    }

    public func removeLastMessageHashInfo(for snode: Snode, namespace: Int, associatedWith publicKey: String, using transaction: Any) {
        let key = namespace == SnodeAPI.defaultNamespace ? "\(snode.address):\(snode.port).\(publicKey)" : "\(snode.address):\(snode.port).\(publicKey).\(namespace)"
        (transaction as! YapDatabaseReadWriteTransaction).removeObject(forKey: key, inCollection: Storage.lastMessageHashCollection)
    }



    // MARK: - Received Messages

    private static let receivedMessagesCollection = "BeldexReceivedMessagesCollection"
    
    public func getReceivedMessages(for publicKey: String) -> Set<String> {
        var result: Set<String>?
        Storage.read { transaction in
            result = transaction.object(forKey: publicKey, inCollection: Storage.receivedMessagesCollection) as? Set<String>
        }
        return result ?? []
    }
    
    public func setReceivedMessages(to receivedMessages: Set<String>, for publicKey: String, using transaction: Any) {
        (transaction as! YapDatabaseReadWriteTransaction).setObject(receivedMessages, forKey: publicKey, inCollection: Storage.receivedMessagesCollection)
    }
}
