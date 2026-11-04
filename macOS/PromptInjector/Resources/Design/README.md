# Native design assets

Logo and SVG controls are exports from the user's approved Prompt Injector Figma design. SVG viewBox and root dimensions are preserved. AppKit's SVG renderer omits blur filters, so the Logo and five category dots also include 3x transparent PNG exports with the authored glow. These PNGs are loaded at logical size; the original SVGs remain as vector sources. Other controls load directly as SVG.

AppIcon.png preserves the authored dark rounded tile and colorful logo, with the surrounding white canvas removed using imagegen. Its exact edit prompt is embedded in PNG metadata. Both the runtime application icon and the generated AppIcon.icns use this transparent source; Apple's sips and iconutil produce the packaged sizes. MenuBar.png remains the monochrome menu-bar template: its 36 pixels display at 18 logical points.

These resources contain no runtime asset URLs. The local design context and private design-file identifiers remain in ignored development artifacts. Dynamic charts and editable text are native views, not flattened screenshots.

V5 来源 Logo：SourceX.svg、SourceGitHub.svg、SourceReddit.svg 来自 Simple Icons 14.15.0（CC0），用于域名对应的平台标识，保留品牌商标含义。来源：https://cdn.jsdelivr.net/npm/simple-icons@14.15.0/icons/x.svg ，同目录 github.svg / reddit.svg。原五个分类圆点继续使用既有导出，新十色由同尺寸圆点绘制，统一十五色循环。

V7 的 List.svg 与 ExternalLink.svg 为本轮 Figma design-context 返回的原始 SVG，经指定 curl 下载，保留 root/viewBox 尺寸；分别用于卡片／列表切换与来源外链标识。其余品牌、分类和来源图标复用已有资源；macOS 红黄绿控件保持真实系统控件，不使用原型里的装饰椭圆。
