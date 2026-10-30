# Native design assets

Logo and SVG controls are exports from the user's approved Prompt Injector Figma design. SVG viewBox and root dimensions are preserved. AppKit's SVG renderer omits blur filters, so the Logo and five category dots also include 3x transparent PNG exports with the authored glow. These PNGs are loaded at logical size; the original SVGs remain as vector sources. Other controls load directly as SVG.

AppIcon.png preserves the authored dark rounded tile and colorful logo, with the surrounding white canvas removed using imagegen. Its exact edit prompt is embedded in PNG metadata. Both the runtime application icon and the generated AppIcon.icns use this transparent source; Apple's sips and iconutil produce the packaged sizes. MenuBar.png remains the monochrome menu-bar template: its 36 pixels display at 18 logical points.

These resources contain no runtime asset URLs. The local design context and private design-file identifiers remain in ignored development artifacts. Dynamic charts and editable text are native views, not flattened screenshots.
