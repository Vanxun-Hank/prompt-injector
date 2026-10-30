# Native design assets

Logo and SVG controls are exports from the user's approved Prompt Injector Figma design. SVG viewBox and root dimensions are preserved. AppKit's SVG renderer omits blur filters, so the Logo and five category dots also include 3x transparent PNG exports with the authored glow. These PNGs are loaded at logical size; the original SVGs remain as vector sources. Other controls load directly as SVG.

AppIcon.png and MenuBar.png are the previously authored application icon and monochrome menu-bar template. The build produces AppIcon.icns with Apple's iconutil; the 36-pixel menu image is displayed at 18 logical points as a system template.

These resources contain no runtime asset URLs. The local design context and private design-file identifiers remain in ignored development artifacts. Dynamic charts and editable text are native views, not flattened screenshots.
