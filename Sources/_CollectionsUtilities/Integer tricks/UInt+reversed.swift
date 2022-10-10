//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Collections open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

extension UInt {
  @inlinable
  public var _reversed: UInt {
    // https://graphics.stanford.edu/~seander/bithacks.html#ReverseParallel
    var shift: UInt = UInt(UInt.bitWidth)
    var mask: UInt = ~0;
    var result = self
    while true {
      shift &>>= 1
      guard shift > 0 else { break }
      mask ^= mask &<< shift
      result = ((result &>> shift) & mask) | ((result &<< shift) & ~mask)
    }
    return result
  }
}
