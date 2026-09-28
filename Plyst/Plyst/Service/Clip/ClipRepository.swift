//
//  ClipRepository.swift
//  Plyst
//
//  Created by opfic on 9/28/26.
//

/// Stores clip text and metadata. Image bytes and file lifecycle belong to a separate service.
///
/// Implementations serialize commits and event emission in the same order. Failed writes must preserve
/// the previous state and emit no event. An unchanged update returns the current clip without an event.
/// Storage-specific failures map to ClipRepositoryError, while CancellationError is propagated unchanged.
protocol ClipRepository: Sendable {

    /// Returns an empty array for an empty repository, using the deterministic order defined by ClipSortOrder.
    func fetchAll(order: ClipSortOrder) async throws -> [Clip]

    /// Returns nil when the identifier does not exist.
    func fetch(id: Clip.ID) async throws -> Clip?

    /// Uses the caller's identifier and timestamps. Rejects duplicate identifiers and invalid content.
    /// Emits inserted only after the entire write has committed.
    func insert(_ clip: Clip) async throws

    /// Applies the change to the latest stored snapshot and returns the committed result.
    /// Preserves the identifier, content, and creation time. A missing identifier throws notFound.
    func update(id: Clip.ID, change: ClipUpdate) async throws -> Clip

    /// Removes metadata and emits deleted after commit. A missing identifier throws notFound.
    /// The caller coordinates deletion of an image's original file with the image file service.
    func delete(id: Clip.ID) async throws

    /// Registers an independent subscription before returning. Each stream has one consumer.
    /// All active subscribers receive every subsequent change from this repository instance in commit order.
    /// Uses unbounded buffering with no initial snapshot or replay of changes preceding registration.
    /// Implementations remove the registration in onTermination and finish streams when the repository ends.
    /// Consumers cancel their task to end observation. Lists register before fetching and refetch on events,
    /// rather than applying buffered event snapshots over a newer query result.
    func changes() async -> AsyncStream<ClipRepositoryEvent>
}
