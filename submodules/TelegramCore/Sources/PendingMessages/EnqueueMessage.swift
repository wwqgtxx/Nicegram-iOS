import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

public enum EnqueueMessageGrouping {
    case none
    case auto
}

public enum EnqueueMessage {
    case message(text: String, attributes: [MessageAttribute], inlineStickers: [MediaId: Media], mediaReference: AnyMediaReference?, replyToMessageId: MessageId?, localGroupingKey: Int64?, correlationId: Int64?, bubbleUpEmojiOrStickersets: [ItemCollectionId])
    // MARK: Nicegram (asCopy)
    case forward(source: MessageId, threadId: Int64?, grouping: EnqueueMessageGrouping, attributes: [MessageAttribute], correlationId: Int64?, asCopy: Bool = false)
    
    public func withUpdatedReplyToMessageId(_ replyToMessageId: MessageId?) -> EnqueueMessage {
        switch self {
        case let .message(text, attributes, inlineStickers, mediaReference, _, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets):
            return .message(text: text, attributes: attributes, inlineStickers: inlineStickers, mediaReference: mediaReference, replyToMessageId: replyToMessageId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
        case .forward:
            return self
        }
    }
    
    public func withUpdatedAttributes(_ f: ([MessageAttribute]) -> [MessageAttribute]) -> EnqueueMessage {
        switch self {
        case let .message(text, attributes, inlineStickers, mediaReference, replyToMessageId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets):
            return .message(text: text, attributes: f(attributes), inlineStickers: inlineStickers, mediaReference: mediaReference, replyToMessageId: replyToMessageId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
        case let .forward(source, threadId, grouping, attributes, correlationId, asCopy):
            return .forward(source: source, threadId: threadId, grouping: grouping, attributes: f(attributes), correlationId: correlationId, asCopy: asCopy)
        }
    }
    
    public func withUpdatedGroupingKey(_ f: (Int64?) -> Int64?) -> EnqueueMessage {
        switch self {
        case let .message(text, attributes, inlineStickers, mediaReference, replyToMessageId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets):
            return .message(text: text, attributes: attributes, inlineStickers: inlineStickers, mediaReference: mediaReference, replyToMessageId: replyToMessageId, localGroupingKey: f(localGroupingKey), correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
        case .forward:
            return self
        }
    }

    public func withUpdatedCorrelationId(_ value: Int64?) -> EnqueueMessage {
        switch self {
        case let .message(text, attributes, inlineStickers, mediaReference, replyToMessageId, localGroupingKey, _, bubbleUpEmojiOrStickersets):
            return .message(text: text, attributes: attributes, inlineStickers: inlineStickers, mediaReference: mediaReference, replyToMessageId: replyToMessageId, localGroupingKey: localGroupingKey, correlationId: value, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
        case let .forward(source, threadId, grouping, attributes, _, asCopy):
            return .forward(source: source, threadId: threadId, grouping: grouping, attributes: attributes, correlationId: value, asCopy: asCopy)
        }
    }
    
    public var groupingKey: Int64? {
        if case let .message(_, _, _, _, _, localGroupingKey, _, _) = self {
            return localGroupingKey
        } else {
            return nil
        }
    }
}

private extension EnqueueMessage {
    var correlationId: Int64? {
        switch self {
        case let .message(_, _, _, _, _, _, correlationId, _):
            return correlationId
        case let .forward(_, _, _, _, correlationId, _):
            return correlationId
        }
    }
    
    var bubbleUpEmojiOrStickersets: [ItemCollectionId] {
        switch self {
        case let .message(_, _, _, _, _, _, _, bubbleUpEmojiOrStickersets):
            return bubbleUpEmojiOrStickersets
        case .forward:
            return []
        }
    }
}

func augmentMediaWithReference(_ mediaReference: AnyMediaReference) -> Media {
    if let file = mediaReference.media as? TelegramMediaFile {
        if file.partialReference != nil {
            return file
        } else {
            return file.withUpdatedPartialReference(mediaReference.partial)
        }
    } else if let image = mediaReference.media as? TelegramMediaImage {
        if image.partialReference != nil {
            return image
        } else {
            return image.withUpdatedPartialReference(mediaReference.partial)
        }
    } else {
        return mediaReference.media
    }
}

private func convertForwardedMediaForSecretChat(_ media: Media) -> Media {
    if let file = media as? TelegramMediaFile {
        return TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min ... Int64.max)), partialReference: file.partialReference, resource: file.resource, previewRepresentations: file.previewRepresentations, videoThumbnails: file.videoThumbnails, immediateThumbnailData: file.immediateThumbnailData, mimeType: file.mimeType, size: file.size, attributes: file.attributes)
    } else if let image = media as? TelegramMediaImage {
        return TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: Int64.random(in: Int64.min ... Int64.max)), representations: image.representations, immediateThumbnailData: image.immediateThumbnailData, reference: image.reference, partialReference: image.partialReference, flags: [])
    } else {
        return media
    }
}

private func filterMessageAttributesForOutgoingMessage(_ attributes: [MessageAttribute]) -> [MessageAttribute] {
    return attributes.filter { attribute in
        switch attribute {
            case _ as TextEntitiesMessageAttribute:
                return true
            case _ as InlineBotMessageAttribute:
                return true
            case _ as OutgoingMessageInfoAttribute:
                return false
            case _ as OutgoingContentInfoMessageAttribute:
                return true
            case _ as ReplyMarkupMessageAttribute:
                return true
            case _ as OutgoingChatContextResultMessageAttribute:
                return true
            case _ as AutoremoveTimeoutMessageAttribute:
                return true
            case _ as NotificationInfoMessageAttribute:
                return true
            case _ as OutgoingScheduleInfoMessageAttribute:
                return true
            case _ as EmbeddedMediaStickersMessageAttribute:
                return true
            case _ as EmojiSearchQueryMessageAttribute:
                return true
            case _ as ForwardOptionsMessageAttribute:
                return true
            case _ as SendAsMessageAttribute:
                return true
            default:
                return false
        }
    }
}

private func filterMessageAttributesForForwardedMessage(_ attributes: [MessageAttribute], forwardedMessageIds: Set<MessageId>? = nil) -> [MessageAttribute] {
    return attributes.filter { attribute in
        switch attribute {
            case _ as TextEntitiesMessageAttribute:
                return true
            case _ as InlineBotMessageAttribute:
                return true
            case _ as NotificationInfoMessageAttribute:
                return true
            case _ as OutgoingScheduleInfoMessageAttribute:
                return true
            case _ as ForwardOptionsMessageAttribute:
                return true
            case _ as SendAsMessageAttribute:
                return true
            case let attribute as ReplyMessageAttribute:
                if let forwardedMessageIds = forwardedMessageIds {
                    return forwardedMessageIds.contains(attribute.messageId)
                } else {
                    return false
                }
            default:
                return false
        }
    }
}

func opportunisticallyTransformMessageWithMedia(network: Network, postbox: Postbox, transformOutgoingMessageMedia: TransformOutgoingMessageMedia, mediaReference: AnyMediaReference, userInteractive: Bool) -> Signal<AnyMediaReference?, NoError> {
    return transformOutgoingMessageMedia(postbox, network, mediaReference, userInteractive)
    |> timeout(2.0, queue: Queue.concurrentDefaultQueue(), alternate: .single(nil))
}

// MARK: Nicegram (asCopy)
private func forwardedMessageToBeReuploaded(transaction: Transaction, id: MessageId, asCopy: Bool = false) -> Message? {
    if let message = transaction.getMessage(id) {
        // MARK: Nicegram (asCopy)
        if message.id.namespace != Namespaces.Message.Cloud || asCopy {
            return message
        } else {
            return nil
        }
    } else {
        return nil
    }
}

private func opportunisticallyTransformOutgoingMedia(network: Network, postbox: Postbox, transformOutgoingMessageMedia: TransformOutgoingMessageMedia, messages: [EnqueueMessage], userInteractive: Bool) -> Signal<[(Bool, EnqueueMessage)], NoError> {
    var hasMedia = false
    loop: for message in messages {
        switch message {
            case let .message(_, _, _, mediaReference, _, _, _, _):
                if mediaReference != nil {
                    hasMedia = true
                    break loop
                }
            case .forward:
                break
        }
    }
    
    if !hasMedia {
        return .single(messages.map { (true, $0) })
    }
    
    var signals: [Signal<(Bool, EnqueueMessage), NoError>] = []
    for message in messages {
        switch message {
            case let .message(text, attributes, inlineStickers, mediaReference, replyToMessageId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets):
                if let mediaReference = mediaReference {
                    signals.append(opportunisticallyTransformMessageWithMedia(network: network, postbox: postbox, transformOutgoingMessageMedia: transformOutgoingMessageMedia, mediaReference: mediaReference, userInteractive: userInteractive)
                    |> map { result -> (Bool, EnqueueMessage) in
                        if let result = result {
                            return (true, .message(text: text, attributes: attributes, inlineStickers: inlineStickers, mediaReference: .standalone(media: result.media), replyToMessageId: replyToMessageId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets))
                        } else {
                            return (false, .message(text: text, attributes: attributes, inlineStickers: inlineStickers, mediaReference: mediaReference, replyToMessageId: replyToMessageId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets))
                        }
                    })
                } else {
                    signals.append(.single((false, message)))
                }
            case .forward:
                signals.append(.single((false, message)))
        }
    }
    return combineLatest(signals)
}

public func enqueueMessages(account: Account, peerId: PeerId, messages: [EnqueueMessage]) -> Signal<[MessageId?], NoError> {
    let signal: Signal<[(Bool, EnqueueMessage)], NoError>
    if let transformOutgoingMessageMedia = account.transformOutgoingMessageMedia {
        signal = opportunisticallyTransformOutgoingMedia(network: account.network, postbox: account.postbox, transformOutgoingMessageMedia: transformOutgoingMessageMedia, messages: messages, userInteractive: true)
    } else {
        signal = .single(messages.map { (false, $0) })
    }
    return signal
    |> mapToSignal { messages -> Signal<[MessageId?], NoError> in
        return account.postbox.transaction { transaction -> [MessageId?] in
            return enqueueMessages(transaction: transaction, account: account, peerId: peerId, messages: messages)
        }
    }
}

public func enqueueMessagesToMultiplePeers(account: Account, peerIds: [PeerId], messages: [EnqueueMessage]) -> Signal<[MessageId], NoError> {
    let signal: Signal<[(Bool, EnqueueMessage)], NoError>
    if let transformOutgoingMessageMedia = account.transformOutgoingMessageMedia {
        signal = opportunisticallyTransformOutgoingMedia(network: account.network, postbox: account.postbox, transformOutgoingMessageMedia: transformOutgoingMessageMedia, messages: messages, userInteractive: true)
    } else {
        signal = .single(messages.map { (false, $0) })
    }
    return signal
    |> mapToSignal { messages -> Signal<[MessageId], NoError> in
        return account.postbox.transaction { transaction -> [MessageId] in
            var messageIds: [MessageId] = []
            for peerId in peerIds {
                for id in enqueueMessages(transaction: transaction, account: account, peerId: peerId, messages: messages, disableAutoremove: false, transformGroupingKeysWithPeerId: true) {
                    if let id = id {
                        messageIds.append(id)
                    }
                }
            }
            return messageIds
        }
    }
}

public func resendMessages(account: Account, messageIds: [MessageId]) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Void in
        var removeMessageIds: [MessageId] = []
        for (peerId, ids) in messagesIdsGroupedByPeerId(messageIds) {
            var messages: [EnqueueMessage] = []
            for id in ids {
                if let message = transaction.getMessage(id), !message.flags.contains(.Incoming) {
                    removeMessageIds.append(id)
                    
                    var filteredAttributes: [MessageAttribute] = []
                    var replyToMessageId: MessageId?
                    var bubbleUpEmojiOrStickersets: [ItemCollectionId] = []
                    inner: for attribute in message.attributes {
                        if let attribute = attribute as? ReplyMessageAttribute {
                            replyToMessageId = attribute.messageId
                        } else if let attribute = attribute as? OutgoingMessageInfoAttribute {
                            bubbleUpEmojiOrStickersets = attribute.bubbleUpEmojiOrStickersets
                            continue inner
                        } else {
                            filteredAttributes.append(attribute)
                        }
                    }
                    
                    messages.append(.message(text: message.text, attributes: filteredAttributes, inlineStickers: [:], mediaReference: message.media.first.flatMap(AnyMediaReference.standalone), replyToMessageId: replyToMessageId, localGroupingKey: message.groupingKey, correlationId: nil, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets))
                }
            }
            let _ = enqueueMessages(transaction: transaction, account: account, peerId: peerId, messages: messages.map { (false, $0) })
        }
        _internal_deleteMessages(transaction: transaction, mediaBox: account.postbox.mediaBox, ids: removeMessageIds, deleteMedia: false)
    }
}

func enqueueMessages(transaction: Transaction, account: Account, peerId: PeerId, messages: [(Bool, EnqueueMessage)], disableAutoremove: Bool = false, transformGroupingKeysWithPeerId: Bool = false) -> [MessageId?] {
    var forwardedMessageIds = Set<MessageId>()
    for (_, message) in messages {
        if case let .forward(sourceId, _, _, _, _, _) = message {
            forwardedMessageIds.insert(sourceId)
        }
    }
    
    var updatedMessages: [(Bool, EnqueueMessage)] = []
    outer: for (transformedMedia, message) in messages {
        var updatedMessage = message
        if transformGroupingKeysWithPeerId {
            updatedMessage = updatedMessage.withUpdatedGroupingKey { groupingKey -> Int64? in
                if let groupingKey = groupingKey {
                    return groupingKey &+ peerId.toInt64()
                } else {
                    return nil
                }
            }
        }
        switch message {
            case let .message(_, attributes, _, _, replyToMessageId, _, _, _):
                if let replyToMessageId = replyToMessageId, replyToMessageId.peerId != peerId, let replyMessage = transaction.getMessage(replyToMessageId) {
                    var canBeForwarded = true
                    if replyMessage.id.namespace != Namespaces.Message.Cloud {
                        canBeForwarded = false
                    }
                    inner: for media in replyMessage.media {
                        if media is TelegramMediaAction {
                            canBeForwarded = false
                            break inner
                        }
                    }
                    if canBeForwarded {
                        updatedMessages.append((true, .forward(source: replyToMessageId, threadId: nil, grouping: .none, attributes: attributes, correlationId: nil)))
                    }
                }
            // MARK: Nicegram (asCopy)
            case let .forward(sourceId, threadId, _, _, _, asCopy):
                if let sourceMessage = forwardedMessageToBeReuploaded(transaction: transaction, id: sourceId, asCopy: asCopy) {
                    var mediaReference: AnyMediaReference?
                    // MARK: Nicegram (asCopy)
                    if sourceMessage.id.peerId.namespace == Namespaces.Peer.SecretChat || asCopy {
                        if let media = sourceMessage.media.first {
                            mediaReference = .standalone(media: media)
                        }
                    }
                    // MARK: Nicegram
                    let localGroupingKey: Int64? = asCopy ? sourceMessage.groupingKey : nil
                    updatedMessages.append((transformedMedia, .message(text: sourceMessage.text, attributes: sourceMessage.attributes, inlineStickers: [:], mediaReference: mediaReference, replyToMessageId: threadId.flatMap { MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: $0)) }, localGroupingKey: localGroupingKey, correlationId: nil, bubbleUpEmojiOrStickersets: [])))
                    continue outer
                }
        }
        updatedMessages.append((transformedMedia, updatedMessage))
    }
    
    if let peer = transaction.getPeer(peerId), let accountPeer = transaction.getPeer(account.peerId) {
        let peerPresence = transaction.getPeerPresence(peerId: peerId)
        
        var storeMessages: [StoreMessage] = []
        var timestamp = Int32(account.network.context.globalTime())
        switch peerId.namespace {
            case Namespaces.Peer.CloudChannel, Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudUser:
                if let topIndex = transaction.getTopPeerMessageIndex(peerId: peerId, namespace: Namespaces.Message.Cloud) {
                    timestamp = max(timestamp, topIndex.timestamp)
                }
            default:
                break
        }
        
        var addedHashtags: [String] = []
        var emojiItems: [RecentEmojiItem] = []
        
        var localGroupingKeyBySourceKey: [Int64: Int64] = [:]
        
        var globallyUniqueIds: [Int64] = []
        for (transformedMedia, message) in updatedMessages {
            var attributes: [MessageAttribute] = []
            var flags = StoreMessageFlags()
            flags.insert(.Unsent)
            
            var randomId: Int64 = 0
            arc4random_buf(&randomId, 8)
            var infoFlags = OutgoingMessageInfoFlags()
            if transformedMedia {
                infoFlags.insert(.transformedMedia)
            }
            attributes.append(OutgoingMessageInfoAttribute(uniqueId: randomId, flags: infoFlags, acknowledged: false, correlationId: message.correlationId, bubbleUpEmojiOrStickersets: message.bubbleUpEmojiOrStickersets))
            globallyUniqueIds.append(randomId)
            
            switch message {
                case let .message(text, requestedAttributes, inlineStickers, mediaReference, replyToMessageId, localGroupingKey, _, _):
                    for (_, file) in inlineStickers {
                        transaction.storeMediaIfNotPresent(media: file)
                    }
                
                    var peerAutoremoveTimeout: Int32?
                    if let peer = peer as? TelegramSecretChat {
                        var isAction = false
                        if let _ = mediaReference?.media as? TelegramMediaAction {
                            isAction = true
                        }
                        if !disableAutoremove, let messageAutoremoveTimeout = peer.messageAutoremoveTimeout, !isAction {
                            peerAutoremoveTimeout = messageAutoremoveTimeout
                        }
                    } else if let cachedData = transaction.getPeerCachedData(peerId: peer.id), !disableAutoremove {
                        var isScheduled = false
                        for attribute in requestedAttributes {
                            if let _ = attribute as? OutgoingScheduleInfoMessageAttribute {
                                isScheduled = true
                            }
                        }
                        
                        if !isScheduled {
                            var messageAutoremoveTimeout: Int32?
                            if let cachedData = cachedData as? CachedUserData {
                                if case let .known(value) = cachedData.autoremoveTimeout {
                                    messageAutoremoveTimeout = value?.effectiveValue
                                }
                            } else if let cachedData = cachedData as? CachedGroupData {
                                if case let .known(value) = cachedData.autoremoveTimeout {
                                    messageAutoremoveTimeout = value?.effectiveValue
                                }
                            } else if let cachedData = cachedData as? CachedChannelData {
                                if case let .known(value) = cachedData.autoremoveTimeout {
                                    messageAutoremoveTimeout = value?.effectiveValue
                                }
                            }
                            
                            if let messageAutoremoveTimeout = messageAutoremoveTimeout {
                                peerAutoremoveTimeout = messageAutoremoveTimeout
                            }
                        }
                    }
                    
                    for attribute in filterMessageAttributesForOutgoingMessage(requestedAttributes) {
                        if let attribute = attribute as? AutoremoveTimeoutMessageAttribute {
                            if let _ = peer as? TelegramSecretChat {
                                peerAutoremoveTimeout = nil
                                attributes.append(attribute)
                            } else {
                                attributes.append(AutoclearTimeoutMessageAttribute(timeout: attribute.timeout, countdownBeginTime: nil))
                            }
                        } else {
                            attributes.append(attribute)
                        }
                    }
                    
                    if let peerAutoremoveTimeout = peerAutoremoveTimeout {
                        attributes.append(AutoremoveTimeoutMessageAttribute(timeout: peerAutoremoveTimeout, countdownBeginTime: nil))
                    }
                        
                    if let replyToMessageId = replyToMessageId, replyToMessageId.peerId == peerId {
                        var threadMessageId: MessageId?
                        if let replyMessage = transaction.getMessage(replyToMessageId) {
                            threadMessageId = replyMessage.effectiveReplyThreadMessageId
                        }
                        attributes.append(ReplyMessageAttribute(messageId: replyToMessageId, threadMessageId: threadMessageId))
                    }
                    var mediaList: [Media] = []
                    if let mediaReference = mediaReference {
                        let augmentedMedia = augmentMediaWithReference(mediaReference)
                        mediaList.append(augmentedMedia)
                    }
                    
                    if let file = mediaReference?.media as? TelegramMediaFile, file.isVoice || file.isInstantVideo {
                        if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup || peerId.namespace == Namespaces.Peer.SecretChat {
                            attributes.append(ConsumableContentMessageAttribute(consumed: false))
                        }
                    }
                    
                    var entitiesAttribute: TextEntitiesMessageAttribute?
                    for attribute in attributes {
                        if let attribute = attribute as? TextEntitiesMessageAttribute {
                            entitiesAttribute = attribute
                            var maybeNsText: NSString?
                            for entity in attribute.entities {
                                if case .Hashtag = entity.type {
                                    let nsText: NSString
                                    if let maybeNsText = maybeNsText {
                                        nsText = maybeNsText
                                    } else {
                                        nsText = text as NSString
                                        maybeNsText = nsText
                                    }
                                    var entityRange = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
                                    if entityRange.location + entityRange.length > nsText.length {
                                        entityRange.location = max(0, nsText.length - entityRange.length)
                                        entityRange.length = nsText.length - entityRange.location
                                    }
                                    if entityRange.length > 1 {
                                        entityRange.location += 1
                                        entityRange.length -= 1
                                        let hashtag = nsText.substring(with: entityRange)
                                        addedHashtags.append(hashtag)
                                    }
                                } else if case let .CustomEmoji(_, fileId) = entity.type {
                                    let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
                                    if let file = inlineStickers[mediaId] as? TelegramMediaFile {
                                        emojiItems.append(RecentEmojiItem(.file(file)))
                                    } else if let file = transaction.getMedia(mediaId) as? TelegramMediaFile {
                                        emojiItems.append(RecentEmojiItem(.file(file)))
                                    }
                                }
                            }
                            break
                        }
                    }
                                    
                    let (tags, globalTags) = tagsForStoreMessage(incoming: false, attributes: attributes, media: mediaList, textEntities: entitiesAttribute?.entities, isPinned: false)
                    
                    var localTags: LocalMessageTags = []
                    for media in mediaList {
                        if let media = media as? TelegramMediaMap, media.liveBroadcastingTimeout != nil {
                            localTags.insert(.OutgoingLiveLocation)
                        }
                    }
                    
                    var messageNamespace = Namespaces.Message.Local
                    var effectiveTimestamp = timestamp
                    var sendAsPeer: Peer?
                    for attribute in attributes {
                        if let attribute = attribute as? OutgoingScheduleInfoMessageAttribute {
                            if attribute.scheduleTime == scheduleWhenOnlineTimestamp, let presence = peerPresence as? TelegramUserPresence, case let .present(statusTimestamp) = presence.status, statusTimestamp >= timestamp {
                            } else {
                                messageNamespace = Namespaces.Message.ScheduledLocal
                                effectiveTimestamp = attribute.scheduleTime
                            }
                        } else if let attribute = attribute as? SendAsMessageAttribute {
                            if let peer = transaction.getPeer(attribute.peerId) {
                                sendAsPeer = peer
                            }
                        }
                    }
                
                    let authorId: PeerId?
                    if let sendAsPeer = sendAsPeer {
                        authorId = sendAsPeer.id
                    } else if let peer = peer as? TelegramChannel {
                        if case .broadcast = peer.info {
                            authorId = peer.id
                        } else if case .group = peer.info, peer.hasPermission(.canBeAnonymous) {
                            authorId = peer.id
                        } else {
                            authorId = account.peerId
                        }
                    }  else {
                        authorId = account.peerId
                    }
                    
                    if messageNamespace != Namespaces.Message.ScheduledLocal {
                        attributes.removeAll(where: { $0 is OutgoingScheduleInfoMessageAttribute })
                    }
                                        
                    if let peer = peer as? TelegramChannel {
                        switch peer.info {
                            case let .broadcast(info):
                                if messageNamespace != Namespaces.Message.ScheduledLocal {
                                    attributes.append(ViewCountMessageAttribute(count: 1))
                                }
                                if info.flags.contains(.messagesShouldHaveSignatures) {
                                    attributes.append(AuthorSignatureMessageAttribute(signature: accountPeer.debugDisplayTitle))
                                }
                            case .group:
                                break
                        }
                    }
                    
                    var threadId: Int64?
                    if let replyToMessageId = replyToMessageId {
                        if let message = transaction.getMessage(replyToMessageId) {
                            if let threadIdValue = message.threadId {
                                threadId = threadIdValue
                            } else if let channel = message.peers[message.id.peerId] as? TelegramChannel, case .group = channel.info {
                                threadId = makeMessageThreadId(replyToMessageId)
                            }
                        }
                    }
                    
                    storeMessages.append(StoreMessage(peerId: peerId, namespace: messageNamespace, globallyUniqueId: randomId, groupingKey: localGroupingKey, threadId: threadId, timestamp: effectiveTimestamp, flags: flags, tags: tags, globalTags: globalTags, localTags: localTags, forwardInfo: nil, authorId: authorId, text: text, attributes: attributes, media: mediaList))
                case let .forward(source, threadId, grouping, requestedAttributes, _, _):
                    let sourceMessage = transaction.getMessage(source)
                    if let sourceMessage = sourceMessage, let author = sourceMessage.author ?? sourceMessage.peers[sourceMessage.id.peerId] {
                        var messageText = sourceMessage.text
                        
                        if let peer = peer as? TelegramSecretChat {
                            var isAction = false
                            for media in sourceMessage.media {
                                if let _ = media as? TelegramMediaAction {
                                    isAction = true
                                }
                            }
                            if !disableAutoremove, let messageAutoremoveTimeout = peer.messageAutoremoveTimeout, !isAction {
                                attributes.append(AutoremoveTimeoutMessageAttribute(timeout: messageAutoremoveTimeout, countdownBeginTime: nil))
                            }
                        } else if let cachedData = transaction.getPeerCachedData(peerId: peer.id), !disableAutoremove {
                            var isScheduled = false
                            for attribute in attributes {
                                if let _ = attribute as? OutgoingScheduleInfoMessageAttribute {
                                    isScheduled = true
                                    break
                                }
                            }
                            
                            if !isScheduled {
                                var messageAutoremoveTimeout: Int32?
                                if let cachedData = cachedData as? CachedUserData {
                                    if case let .known(value) = cachedData.autoremoveTimeout {
                                        messageAutoremoveTimeout = value?.effectiveValue
                                    }
                                } else if let cachedData = cachedData as? CachedGroupData {
                                    if case let .known(value) = cachedData.autoremoveTimeout {
                                        messageAutoremoveTimeout = value?.effectiveValue
                                    }
                                } else if let cachedData = cachedData as? CachedChannelData {
                                    if case let .known(value) = cachedData.autoremoveTimeout {
                                        messageAutoremoveTimeout = value?.effectiveValue
                                    }
                                }
                                
                                if let messageAutoremoveTimeout = messageAutoremoveTimeout {
                                    attributes.append(AutoremoveTimeoutMessageAttribute(timeout: messageAutoremoveTimeout, countdownBeginTime: nil))
                                }
                            }
                        }
                        
                        var forwardInfo: StoreMessageForwardInfo?
                        
                        var hideSendersNames = false
                        var hideCaptions = false
                        for attribute in requestedAttributes {
                            if let attribute = attribute as? ForwardOptionsMessageAttribute {
                                hideSendersNames = attribute.hideNames
                                hideCaptions = attribute.hideCaptions
                                break
                            }
                        }
                        
                        if hideCaptions {
                            for media in sourceMessage.media {
                                if media is TelegramMediaImage || media is TelegramMediaFile {
                                    messageText = ""
                                    break
                                }
                            }
                        }
                        
                        if sourceMessage.id.namespace == Namespaces.Message.Cloud && peerId.namespace != Namespaces.Peer.SecretChat {
                            attributes.append(ForwardSourceInfoAttribute(messageId: sourceMessage.id))
                        
                            if peerId == account.peerId {
                                attributes.append(SourceReferenceMessageAttribute(messageId: sourceMessage.id))
                            }
                            
                            attributes.append(contentsOf: filterMessageAttributesForForwardedMessage(requestedAttributes))
                            attributes.append(contentsOf: filterMessageAttributesForForwardedMessage(sourceMessage.attributes, forwardedMessageIds: forwardedMessageIds))
                            
                            var sourceReplyMarkup: ReplyMarkupMessageAttribute? = nil
                            var sourceSentViaBot = false
                            for attribute in attributes {
                                if let attribute = attribute as? ReplyMarkupMessageAttribute {
                                    sourceReplyMarkup = attribute
                                } else if let _ = attribute as? InlineBotMessageAttribute {
                                    sourceSentViaBot = true
                                }
                            }
                            
                            if let sourceReplyMarkup = sourceReplyMarkup {
                                var rows: [ReplyMarkupRow] = []
                                loop: for row in sourceReplyMarkup.rows {
                                    var buttons: [ReplyMarkupButton] = []
                                    for button in row.buttons {
                                        if case .url = button.action {
                                            buttons.append(button)
                                        } else if case .urlAuth = button.action {
                                            buttons.append(button)
                                        } else if case let .switchInline(samePeer, query) = button.action, sourceSentViaBot {
                                            let samePeer = samePeer && peerId == sourceMessage.id.peerId
                                            let updatedButton = ReplyMarkupButton(title: button.titleWhenForwarded ?? button.title, titleWhenForwarded: button.titleWhenForwarded,  action: .switchInline(samePeer: samePeer, query: query))
                                            buttons.append(updatedButton)
                                        } else {
                                            rows.removeAll()
                                            break loop
                                        }
                                    }
                                    rows.append(ReplyMarkupRow(buttons: buttons))
                                }
                                
                                if !rows.isEmpty {
                                    attributes.append(ReplyMarkupMessageAttribute(rows: rows, flags: sourceReplyMarkup.flags, placeholder: sourceReplyMarkup.placeholder))
                                }
                            }
                            
                            if hideSendersNames {
                                
                            } else if let sourceForwardInfo = sourceMessage.forwardInfo {
                                forwardInfo = StoreMessageForwardInfo(authorId: sourceForwardInfo.author?.id, sourceId: sourceForwardInfo.source?.id, sourceMessageId: sourceForwardInfo.sourceMessageId, date: sourceForwardInfo.date, authorSignature: sourceForwardInfo.authorSignature, psaType: nil, flags: [])
                            } else {
                                if sourceMessage.id.peerId != account.peerId {
                                    var hasHiddenForwardMedia = false
                                    for media in sourceMessage.media {
                                        if let file = media as? TelegramMediaFile {
                                            if file.isMusic {
                                                hasHiddenForwardMedia = true
                                            }
                                        }
                                    }
                                    
                                    if !hasHiddenForwardMedia {
                                        var sourceId: PeerId? = nil
                                        var sourceMessageId: MessageId? = nil
                                        if case let .channel(peer) = messageMainPeer(EngineMessage(sourceMessage)), case .broadcast = peer.info {
                                            sourceId = peer.id
                                            sourceMessageId = sourceMessage.id
                                        }
                                        
                                        var authorSignature: String?
                                        for attribute in sourceMessage.attributes {
                                            if let attribute = attribute as? AuthorSignatureMessageAttribute {
                                                authorSignature = attribute.signature
                                                break
                                            }
                                        }
                                        
                                        let psaType: String? = nil
                                        
                                        forwardInfo = StoreMessageForwardInfo(authorId: author.id, sourceId: sourceId, sourceMessageId: sourceMessageId, date: sourceMessage.timestamp, authorSignature: authorSignature, psaType: psaType, flags: [])
                                    }
                                } else {
                                    forwardInfo = nil
                                }
                            }
                        } else {
                            attributes.append(contentsOf: filterMessageAttributesForOutgoingMessage(sourceMessage.attributes))
                        }
                                                
                        var messageNamespace = Namespaces.Message.Local
                        var entitiesAttribute: TextEntitiesMessageAttribute?
                        var effectiveTimestamp = timestamp
                        var sendAsPeer: Peer?
                        var threadId: Int64? = threadId
                        for attribute in attributes {
                            if let attribute = attribute as? TextEntitiesMessageAttribute {
                                entitiesAttribute = attribute
                            } else if let attribute = attribute as? OutgoingScheduleInfoMessageAttribute {
                                if attribute.scheduleTime == scheduleWhenOnlineTimestamp, let presence = peerPresence as? TelegramUserPresence, case let .present(statusTimestamp) = presence.status, statusTimestamp >= timestamp {
                                } else {
                                    messageNamespace = Namespaces.Message.ScheduledLocal
                                    effectiveTimestamp = attribute.scheduleTime
                                }
                            } else if let attribute = attribute as? ReplyMessageAttribute {
                                if let threadMessageId = attribute.threadMessageId {
                                    threadId = makeMessageThreadId(threadMessageId)
                                }
                            } else if let attribute = attribute as? SendAsMessageAttribute {
                                if let peer = transaction.getPeer(attribute.peerId) {
                                    sendAsPeer = peer
                                }
                            }
                        }
                        
                        let authorId: PeerId?
                        if let sendAsPeer = sendAsPeer {
                            authorId = sendAsPeer.id
                        } else if let peer = peer as? TelegramChannel {
                            if case .broadcast = peer.info {
                                authorId = peer.id
                            } else if case .group = peer.info, peer.hasPermission(.canBeAnonymous) {
                                authorId = peer.id
                            } else {
                                authorId = account.peerId
                            }
                        }  else {
                            authorId = account.peerId
                        }
                        
                        if messageNamespace != Namespaces.Message.ScheduledLocal {
                            attributes.removeAll(where: { $0 is OutgoingScheduleInfoMessageAttribute })
                        }
                        
                        let (tags, globalTags) = tagsForStoreMessage(incoming: false, attributes: attributes, media: sourceMessage.media, textEntities: entitiesAttribute?.entities, isPinned: false)
                        
                        let localGroupingKey: Int64?
                        switch grouping {
                            case .none:
                                localGroupingKey = nil
                            case .auto:
                                if let groupingKey = sourceMessage.groupingKey {
                                    if let generatedKey = localGroupingKeyBySourceKey[groupingKey] {
                                        localGroupingKey = generatedKey
                                    } else {
                                        let generatedKey = Int64.random(in: Int64.min ... Int64.max)
                                        localGroupingKeyBySourceKey[groupingKey] = generatedKey
                                        localGroupingKey = generatedKey
                                    }
                                } else {
                                    localGroupingKey = nil
                                }
                        }
                        
                        var augmentedMediaList = sourceMessage.media.map { media -> Media in
                            return augmentMediaWithReference(.message(message: MessageReference(sourceMessage), media: media))
                        }
                        
                        if peerId.namespace == Namespaces.Peer.SecretChat {
                            augmentedMediaList = augmentedMediaList.map(convertForwardedMediaForSecretChat)
                        }
                                                
                        storeMessages.append(StoreMessage(peerId: peerId, namespace: messageNamespace, globallyUniqueId: randomId, groupingKey: localGroupingKey, threadId: threadId, timestamp: effectiveTimestamp, flags: flags, tags: tags, globalTags: globalTags, localTags: [], forwardInfo: forwardInfo, authorId: authorId, text: messageText, attributes: attributes, media: augmentedMediaList))
                    }
            }
        }
        var messageIds: [MessageId?] = []
        if !storeMessages.isEmpty {
            for emojiItem in emojiItems {
                if let entry = CodableEntry(emojiItem) {
                    let id: RecentEmojiItemId
                    switch emojiItem.content {
                    case let .file(file):
                        id = RecentEmojiItemId(file.fileId)
                    case let .text(text):
                        id = RecentEmojiItemId(text)
                    }
                    transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.LocalRecentEmoji, item: OrderedItemListEntry(id: id.rawValue, contents: entry), removeTailIfCountExceeds: 20)
                }
            }
            
            let globallyUniqueIdToMessageId = transaction.addMessages(storeMessages, location: .Random)
            for globallyUniqueId in globallyUniqueIds {
                messageIds.append(globallyUniqueIdToMessageId[globallyUniqueId])
            }
            
            if peerId.namespace == Namespaces.Peer.CloudUser {
                if case .notIncluded = transaction.getPeerChatListInclusion(peerId) {
                    transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: nil, minTimestamp: nil))
                }
            }
        }
        for hashtag in addedHashtags {
            addRecentlyUsedHashtag(transaction: transaction, string: hashtag)
        }
        return messageIds
    } else {
        return []
    }
}
