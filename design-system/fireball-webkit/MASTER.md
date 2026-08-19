# Fireball WebKit design system

**Direction:** Quiet cosmic flight deck
**Dials:** variance 6/10 · motion 3/10 · density 5/10

This system adapts UI/UX Pro Max guidance to a privacy browser while keeping
SwiftUI and Apple platform conventions ahead of brand decoration.

## Brand

- `Brand/FireballMeteorMark.png` is the canonical transparent master.
- `FireballMark` in the asset catalog is the in-app mark. It is decorative when
  placed beside visible `Fireball` text and meaningful only when it has its own
  accessibility label.
- The iOS app icon uses an opaque deep-green field because App Store icons must
  not depend on alpha.

## Semantic colors

| Role | Dark | Light-ready counterpart |
| --- | --- | --- |
| Background | `#070907` | `#F5F2E9` |
| Panel | `#10140F` | `#FFFFFF` |
| Raised | `#181E17` | `#E9EDE5` |
| Primary text | `#F4F1E8` | `#121511` |
| Secondary text | `#A8B0A6` | `#4B554B` |
| Meteor orange | `#FF5A1F` | `#C83E0B` |
| Electric lime | `#B8FF3D` | `#326B00` |
| Destructive | semantic system red | semantic system red |

- Use semantic SwiftUI type styles and Dynamic Type; no fixed body sizes.
- Spacing follows 4/8pt increments. Primary touch targets are at least 44×44pt.
- Prefer SF Symbols for controls and the brand mark only for identity.

## Platform behavior

- Respect safe areas, system gestures, VoiceOver order, keyboard commands,
  reduced motion and accessibility text sizes.
- Use native sheets, menus, confirmation dialogs and materials. Blur indicates
  hierarchy/dismissal, not decoration.
- The bottom chrome is a dock: navigation/address first, then no more than five
  labeled top-level actions. Labels remain available to accessibility even when
  visually compact.
- Profiles own persistent WebKit data stores. Spaces own tab collections.
  Private tabs, history and snapshots never become decorative sync claims.
- Orange identifies Burner/private context; lime indicates active protection or
  the primary Go action. Always include a text/icon cue besides color.

## Visual language

- Use a calm dark field, a subtle meteor trajectory and one hero mark. Avoid
  terminal cosplay, purple AI gradients, fake telemetry and excessive cards.
- Cards use 14–22pt continuous radii, one-pixel boundaries and gentle material
  separation. Press feedback changes opacity/surface, never layout bounds.
- Home hierarchy: brand/flight status → one useful search action → concise
  privacy flight plan → shortcuts. Browsing content remains the focus.
