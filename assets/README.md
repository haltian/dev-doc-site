# Asset Organization

This directory structure follows the **Asset Organization** principle from the project constitution.

## Directory Structure

```
static/assets/
├── images/       # Photos, screenshots, icons (WebP preferred, PNG fallback)
├── diagrams/     # Technical diagrams, architecture drawings (SVG preferred)
└── data/         # CSV, JSON, and other data files
```

## Naming Convention

All assets MUST follow this naming pattern:

```
{section}-{description}-{version}.{ext}
```

### Examples

**Good naming:**
```
thingsee-architecture-v1.svg
wirepas-mesh-topology-v2.png
api-authentication-flow-v1.drawio
device-specifications-2025.csv
security-data-flow-v3.svg
```

**Bad naming:**
```
image1.png           ❌ Not descriptive
diagram.svg          ❌ No context
final_FINAL.png      ❌ Unclear versioning
my-drawing.svg       ❌ Not specific enough
```

## File Format Guidelines

### Images
- **WebP**: Preferred for photos and screenshots (better compression)
- **PNG**: Use when WebP not supported or for transparency needs
- **SVG**: Required for logos and simple graphics (scalable)

### Diagrams
- **SVG**: Preferred for technical diagrams (export from Draw.io, Figma, etc.)
- **PNG**: Only if SVG not possible, minimum 2x resolution
- **Source files**: Keep `.drawio`, `.fig`, or `.sketch` files alongside exports

### Data Files
- **CSV**: Tabular data, device specifications
- **JSON**: Structured data, API examples

## Optimization

Before committing assets:

1. **Images**: Optimize with tools like ImageOptim, TinyPNG
2. **SVG**: Remove unnecessary metadata, minify
3. **Size limit**: Individual files should be <500KB when possible

## Referencing Assets in Markdown

```markdown
<!-- Image -->
![Architecture Overview](/assets/images/thingsee-architecture-v1.svg)

<!-- Diagram with caption -->
![Wirepas Mesh Topology](/assets/diagrams/wirepas-mesh-topology-v2.png)
*Figure 1: Wirepas mesh network showing gateway and sensor nodes*

<!-- Data file download -->
[Download Device Specifications (CSV)](/assets/data/device-specifications-2025.csv)
```

## Version Control

- Increment version number when making significant changes
- Keep old versions if they're referenced in documentation
- Document version changes in git commit messages

## Unused Assets

Run periodic audits to identify and remove assets not referenced by any content:

```bash
# Check for unreferenced assets (example)
grep -r "assets/" content/ | grep -oP 'assets/[^)]+' | sort | uniq
```

## Constitution Compliance

✅ This structure complies with:
- **Principle III**: Asset Organization (NON-NEGOTIABLE)
- Clear naming conventions enforced
- Source files stored alongside exports
- Version control for all assets
