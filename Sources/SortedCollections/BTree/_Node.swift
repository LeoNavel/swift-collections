//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Collections open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

@usableFromInline
internal struct _Node<Key: Comparable, Value> {
  @usableFromInline
  typealias Element = (key: Key, value: Value)
  
  /// Strong reference to the node's underlying data
  @usableFromInline
  internal var storage: Storage
  
  /// Creates a node wrapping a Storage object in order to interact with it.
  /// - Parameter storage: Underlying node storage.
  @inlinable
  @inline(__always)
  internal init(_ storage: Storage) {
    self.storage = storage
  }
  
  /// Creates a node which copies the storage of an existing node.
  @inlinable
  @inline(__always)
  internal init(copyingFrom oldNode: _Node) {
    let capacity = oldNode.storage.header.capacity
    let count = oldNode.storage.header.count
    let totalElements = oldNode.storage.header.totalElements
    let isLeaf = oldNode.storage.header.children == nil
    
    self.init(withCapacity: capacity, isLeaf: isLeaf)
    
    self.storage.header.count = count
    self.storage.header.totalElements = totalElements
    
    oldNode.storage.withUnsafeMutablePointerToElements { oldKeys in
      self.storage.withUnsafeMutablePointerToElements { newKeys in
        newKeys.initialize(from: oldKeys, count: count)
      }
    }
    
    oldNode.storage.header.values.withUnsafeMutablePointerToElements { oldValues in
      self.storage.header.values.withUnsafeMutablePointerToElements { newValues in
        newValues.initialize(from: oldValues, count: count)
      }
    }
    
    oldNode.storage.header.children?.withUnsafeMutablePointerToElements { oldChildren in
      self.storage.header.children!.withUnsafeMutablePointerToElements { newChildren in
        newChildren.initialize(from: oldChildren, count: count + 1)
      }
    }
  }
  
  /// Creates and allocates a new node.
  /// - Parameters:
  ///   - capacity: the maximum potential size of the node.
  ///   - isLeaf: whether or not the node is a leaf (it does not have any children).
  @inlinable
  internal init(withCapacity capacity: Int, isLeaf: Bool) {
    let storage = Storage.create(minimumCapacity: capacity) { _ in
      Header(
        capacity: capacity,
        count: 0,
        totalElements: 0,
        values: Buffer<Value>.create(minimumCapacity: capacity) { _ in BufferHeader() },
        children: isLeaf ? nil
          : Buffer<_Node<Key, Value>>.create(minimumCapacity: capacity + 1) { _ in BufferHeader() }
      )
    }
    
    self.storage = unsafeDowncast(storage, to: Storage.self)
  }
}

// MARK: CoW
extension _Node {
  /// Allows **read-only** access to the underlying data behind the node.
  ///
  /// - Parameter body: A closure with a handle which allows interacting with the node
  /// - Returns: The value the closure body returns, if any.
  @inlinable
  @inline(__always)
  internal func read<R>(_ body: (UnsafeHandle) throws -> R) rethrows -> R {
    return try self.storage.withUnsafeMutablePointers { header, keys in
      try header.pointee.values.withUnsafeMutablePointerToElements { values in
        if let childrenPtr = header.pointee.children {
          return try childrenPtr.withUnsafeMutablePointerToElements { children in
            let handle = UnsafeHandle(
              keys: keys,
              values: values,
              children: children,
              header: header,
              isMutable: false
            )
            return try body(handle)
          }
        } else {
          let handle = UnsafeHandle(
            keys: keys,
            values: values,
            children: nil,
            header: header,
            isMutable: false
          )
          return try body(handle)
        }
      }
    }
  }
  
  /// Allows mutable access to the underlying data behind the node.
  ///
  /// - Parameter body: A closure with a handle which allows interacting with the node
  /// - Returns: The value the closure body returns, if any.
  @inlinable
  @inline(__always)
  internal mutating func update<R>(_ body: (UnsafeHandle) throws -> R) rethrows -> R {
    self.ensureUnique()
    return try self.read { handle in
      defer { handle.checkInvariants() }
      return try body(UnsafeHandle(mutableCopyOf: handle))
    }
  }
  
  /// Ensure that this storage refers to a uniquely held buffer by copying
  /// elements if necessary.
  @inlinable
  internal mutating func ensureUnique() {
    if !isKnownUniquelyReferenced(&self.storage) {
      self = _Node(copyingFrom: self)
    }
  }
}

// MARK: Equatable
extension _Node: Equatable {
  @inlinable
  @inline(__always)
  internal static func ==(lhs: _Node, rhs: _Node) -> Bool {
    return lhs.storage === rhs.storage
  }
}

