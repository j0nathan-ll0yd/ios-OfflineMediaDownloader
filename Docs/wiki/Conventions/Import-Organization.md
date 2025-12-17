# Import Organization

## Quick Reference
- **When to use**: All Swift files
- **Enforcement**: Recommended
- **Impact if violated**: Low - Code style consistency

---

## The Rule

Organize imports in this order, separated by blank lines:

1. **System frameworks** (Foundation, UIKit, SwiftUI)
2. **External packages** (ComposableArchitecture, Valet, AVKit)
3. **Local modules** (if using SPM modules)

---

## Examples

### Feature/View Files
```swift
import SwiftUI
import ComposableArchitecture
import AVKit
```

### Dependency Client Files
```swift
import Foundation
import ComposableArchitecture
import UIKit  // For UIDevice, UIPasteboard
```

### Model Files
```swift
import Foundation
import CoreData
```

### Test Files
```swift
import Testing
import ComposableArchitecture

@testable import OfflineMediaDownloader
```

---

## Framework Groupings

### System Frameworks
```swift
import Foundation
import UIKit
import SwiftUI
import CoreData
import AVFoundation
import AVKit
import AuthenticationServices
```

### External Packages
```swift
import ComposableArchitecture
import Valet
```

---

## Correct vs Incorrect

### Correct
```swift
import SwiftUI
import ComposableArchitecture
import AVKit

@Reducer
struct VideoPlayerFeature {
  // ...
}
```

### Incorrect
```swift
// ❌ Wrong: Mixed order, no grouping
import ComposableArchitecture
import AVKit
import SwiftUI
import Foundation

@Reducer
struct VideoPlayerFeature {
  // ...
}
```

---

## Special Cases

### When UIKit is Needed in SwiftUI View
```swift
import SwiftUI
import ComposableArchitecture
import UIKit  // For UIPasteboard access
```

### When Both AVFoundation and AVKit Needed
```swift
import Foundation
import AVFoundation
import AVKit
import ComposableArchitecture
```

---

## Rationale

- **Readability**: Consistent ordering makes imports scannable
- **Dependency clarity**: External dependencies are visually separated
- **Merge conflicts**: Reduces conflicts when multiple developers add imports

---

## Xcode Tip

Xcode can sort imports automatically, but it doesn't group them. Consider using a build phase script or pre-commit hook for consistent formatting.

---

## Related Patterns
- [File-Organization.md](File-Organization.md)
