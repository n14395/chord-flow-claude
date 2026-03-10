#!/usr/bin/env python3
"""Generate the ChordFlow app icon as SVG, then convert to PNGs at all required sizes."""

import math
import os
import subprocess
import sys

# App color scheme from DesignTokens.swift
COLORS = {
    "base": "#0E0F1D",
    "background": "#1A1B2E",
    "surface": "#252740",
    "elevated": "#2F3152",
    "border": "#3A3D5C",
    "textPrimary": "#F0F0F5",
    "textSecondary": "#8B8DA3",
    "tonic": "#F5A623",  # amber/gold
    "dominant": "#4A90D9",  # blue
    "subdominant": "#7ED321",  # green
    "borrowed": "#D94A8C",  # pink/magenta
}

# Icon dimensions (SVG coordinate space)
SIZE = 1024
CENTER = SIZE / 2
CORNER_RADIUS = SIZE * 0.22  # iOS-style rounded rect

# Ring geometry (matching original icon proportions)
OUTER_RING_R = SIZE * 0.33  # outer chord ring radius
INNER_RING_R = SIZE * 0.195  # inner ring radius
NODE_RADIUS_LARGE = SIZE * 0.042  # top & bottom nodes
NODE_RADIUS_SMALL = SIZE * 0.035  # side nodes

# 6 nodes positioned like original: top, upper-right, lower-right, bottom, lower-left, upper-left
# Angles in degrees (0 = top, clockwise)
NODE_ANGLES = [0, 60, 120, 180, 240, 300]

# Color assignment for each node (clockwise from top):
# Top=tonic, UR=dominant, LR=subdominant, Bottom=borrowed, LL=subdominant, UL=dominant
NODE_COLORS = [
    COLORS["tonic"],  # top - amber/gold
    COLORS["dominant"],  # upper-right - blue
    COLORS["subdominant"],  # lower-right - green
    COLORS["borrowed"],  # bottom - pink
    COLORS["subdominant"],  # lower-left - green
    COLORS["dominant"],  # upper-left - blue
]

NODE_SIZES = [
    NODE_RADIUS_LARGE,  # top (slightly larger)
    NODE_RADIUS_SMALL,  # upper-right
    NODE_RADIUS_SMALL,  # lower-right
    NODE_RADIUS_LARGE,  # bottom (slightly larger)
    NODE_RADIUS_SMALL,  # lower-left
    NODE_RADIUS_SMALL,  # upper-left
]


def point_on_circle(cx, cy, r, angle_deg):
    """Return (x, y) for a point on a circle. 0 degrees = top, clockwise."""
    rad = math.radians(angle_deg - 90)  # -90 so 0 deg = top
    return cx + r * math.cos(rad), cy + r * math.sin(rad)


def hex_to_rgb(h):
    """Convert '#RRGGBB' to (r, g, b) floats 0-1."""
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4))


def lerp_color(c1, c2, t):
    """Linearly interpolate between two hex colors."""
    r1, g1, b1 = hex_to_rgb(c1)
    r2, g2, b2 = hex_to_rgb(c2)
    r = r1 + (r2 - r1) * t
    g = g1 + (g2 - g1) * t
    b = b1 + (b2 - b1) * t
    return f"#{int(r * 255):02x}{int(g * 255):02x}{int(b * 255):02x}"


def generate_svg():
    """Generate the icon SVG string."""
    # Compute node positions
    nodes = []
    for i, angle in enumerate(NODE_ANGLES):
        x, y = point_on_circle(CENTER, CENTER, OUTER_RING_R, angle)
        nodes.append((x, y, NODE_COLORS[i], NODE_SIZES[i]))

    # Build SVG
    svg = []
    svg.append(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">'
    )

    # Definitions: gradients, filters
    svg.append("  <defs>")

    # Outer ring gradient - subtle multi-color sweep
    svg.append('    <linearGradient id="ringGrad" x1="0" y1="0" x2="1" y2="1">')
    svg.append(
        f'      <stop offset="0%" stop-color="{COLORS["tonic"]}" stop-opacity="0.6"/>'
    )
    svg.append(
        f'      <stop offset="33%" stop-color="{COLORS["dominant"]}" stop-opacity="0.5"/>'
    )
    svg.append(
        f'      <stop offset="66%" stop-color="{COLORS["subdominant"]}" stop-opacity="0.5"/>'
    )
    svg.append(
        f'      <stop offset="100%" stop-color="{COLORS["borrowed"]}" stop-opacity="0.6"/>'
    )
    svg.append("    </linearGradient>")

    # Inner ring gradient
    svg.append('    <linearGradient id="innerRingGrad" x1="0" y1="0" x2="0" y2="1">')
    svg.append(
        f'      <stop offset="0%" stop-color="{COLORS["tonic"]}" stop-opacity="0.7"/>'
    )
    svg.append(
        f'      <stop offset="100%" stop-color="{COLORS["tonic"]}" stop-opacity="0.35"/>'
    )
    svg.append("    </linearGradient>")

    # Center glow
    svg.append(f'    <radialGradient id="centerGlow" cx="50%" cy="50%" r="50%">')
    svg.append(
        f'      <stop offset="0%" stop-color="{COLORS["tonic"]}" stop-opacity="0.15"/>'
    )
    svg.append(
        f'      <stop offset="60%" stop-color="{COLORS["tonic"]}" stop-opacity="0.05"/>'
    )
    svg.append(
        f'      <stop offset="100%" stop-color="{COLORS["base"]}" stop-opacity="0"/>'
    )
    svg.append("    </radialGradient>")

    # Glow filters for nodes
    svg.append(
        '    <filter id="nodeGlow" x="-50%" y="-50%" width="200%" height="200%">'
    )
    svg.append(
        '      <feGaussianBlur in="SourceGraphic" stdDeviation="8" result="blur"/>'
    )
    svg.append("      <feMerge>")
    svg.append('        <feMergeNode in="blur"/>')
    svg.append('        <feMergeNode in="SourceGraphic"/>')
    svg.append("      </feMerge>")
    svg.append("    </filter>")

    # Play button shadow
    svg.append(
        '    <filter id="playShadow" x="-20%" y="-20%" width="140%" height="140%">'
    )
    svg.append(
        '      <feDropShadow dx="0" dy="2" stdDeviation="4" flood-color="#000" flood-opacity="0.3"/>'
    )
    svg.append("    </filter>")

    svg.append("  </defs>")

    # Background rounded rectangle
    svg.append(
        f'  <rect x="0" y="0" width="{SIZE}" height="{SIZE}" rx="{CORNER_RADIUS}" '
        f'fill="{COLORS["base"]}"/>'
    )

    # Subtle border
    inset = 8
    svg.append(
        f'  <rect x="{inset}" y="{inset}" width="{SIZE - 2 * inset}" height="{SIZE - 2 * inset}" '
        f'rx="{CORNER_RADIUS - inset}" fill="none" stroke="{COLORS["border"]}" stroke-width="3" '
        f'stroke-opacity="0.5"/>'
    )

    # Center glow
    svg.append(
        f'  <circle cx="{CENTER}" cy="{CENTER}" r="{SIZE * 0.35}" fill="url(#centerGlow)"/>'
    )

    # Outer ring track (subtle background)
    svg.append(
        f'  <circle cx="{CENTER}" cy="{CENTER}" r="{OUTER_RING_R}" '
        f'fill="none" stroke="{COLORS["elevated"]}" stroke-width="14" stroke-opacity="0.4"/>'
    )

    # Outer ring (gradient stroke)
    svg.append(
        f'  <circle cx="{CENTER}" cy="{CENTER}" r="{OUTER_RING_R}" '
        f'fill="none" stroke="url(#ringGrad)" stroke-width="12"/>'
    )

    # Connection arcs between nodes (segments of the outer ring with node colors)
    # Draw colored arc segments between adjacent nodes
    for i in range(len(nodes)):
        j = (i + 1) % len(nodes)
        x1, y1, c1, _ = nodes[i]
        x2, y2, c2, _ = nodes[j]
        mid_color = lerp_color(c1, c2, 0.5)
        # Draw a thicker arc segment
        angle_start = NODE_ANGLES[i]
        angle_end = NODE_ANGLES[j]
        if angle_end <= angle_start:
            angle_end += 360

        # SVG arc from node i to node j
        sx, sy = point_on_circle(CENTER, CENTER, OUTER_RING_R, angle_start)
        ex, ey = point_on_circle(CENTER, CENTER, OUTER_RING_R, angle_end)
        large_arc = 0  # each segment is 60 degrees
        svg.append(
            f'  <path d="M {sx:.1f} {sy:.1f} A {OUTER_RING_R:.1f} {OUTER_RING_R:.1f} 0 {large_arc} 1 {ex:.1f} {ey:.1f}" '
            f'fill="none" stroke="{mid_color}" stroke-width="10" stroke-opacity="0.25" stroke-linecap="round"/>'
        )

    # Inner ring track
    svg.append(
        f'  <circle cx="{CENTER}" cy="{CENTER}" r="{INNER_RING_R}" '
        f'fill="none" stroke="{COLORS["elevated"]}" stroke-width="10" stroke-opacity="0.3"/>'
    )

    # Inner ring (tonic-colored gradient)
    svg.append(
        f'  <circle cx="{CENTER}" cy="{CENTER}" r="{INNER_RING_R}" '
        f'fill="none" stroke="url(#innerRingGrad)" stroke-width="8"/>'
    )

    # Inner filled disc (subtle)
    svg.append(
        f'  <circle cx="{CENTER}" cy="{CENTER}" r="{INNER_RING_R - 8}" '
        f'fill="{COLORS["background"]}" fill-opacity="0.6"/>'
    )

    # Node circles (with glow)
    for x, y, color, radius in nodes:
        # Glow halo
        svg.append(
            f'  <circle cx="{x:.1f}" cy="{y:.1f}" r="{radius * 1.6:.1f}" '
            f'fill="{color}" fill-opacity="0.15"/>'
        )
        # Main node
        svg.append(
            f'  <circle cx="{x:.1f}" cy="{y:.1f}" r="{radius:.1f}" '
            f'fill="{color}" filter="url(#nodeGlow)"/>'
        )
        # Highlight (top-left shine)
        highlight_r = radius * 0.5
        hx = x - radius * 0.25
        hy = y - radius * 0.25
        svg.append(
            f'  <circle cx="{hx:.1f}" cy="{hy:.1f}" r="{highlight_r:.1f}" '
            f'fill="white" fill-opacity="0.25"/>'
        )

    # Play button triangle
    play_size = SIZE * 0.1
    # Equilateral triangle pointing right, centered
    # Offset slightly right to look visually centered
    offset_x = play_size * 0.08
    px1 = CENTER - play_size * 0.42 + offset_x  # left point
    py1 = CENTER - play_size * 0.52
    px2 = CENTER - play_size * 0.42 + offset_x
    py2 = CENTER + play_size * 0.52
    px3 = CENTER + play_size * 0.58 + offset_x  # right point
    py3 = CENTER

    svg.append(
        f'  <polygon points="{px1:.1f},{py1:.1f} {px2:.1f},{py2:.1f} {px3:.1f},{py3:.1f}" '
        f'fill="{COLORS["textPrimary"]}" fill-opacity="0.9" filter="url(#playShadow)"/>'
    )

    svg.append("</svg>")
    return "\n".join(svg)


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_dir = os.path.join(
        script_dir, "Xcode", "Media.xcassets", "AppIcon.appiconset"
    )
    svg_path = os.path.join(script_dir, "icon.svg")

    # Generate SVG
    svg_content = generate_svg()
    with open(svg_path, "w") as f:
        f.write(svg_content)
    print(f"Generated SVG: {svg_path}")

    # Convert to PNGs at all required sizes
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    for s in sizes:
        png_name = f"app-icon-{s}.png"
        png_path = os.path.join(output_dir, png_name)
        subprocess.run(
            [
                "rsvg-convert",
                "-w",
                str(s),
                "-h",
                str(s),
                svg_path,
                "-o",
                png_path,
            ],
            check=True,
        )
        print(f"  {png_name} ({s}x{s})")

    # Also generate the iOS universal 1024x1024
    print(f"\nAll icons generated in {output_dir}")

    # Clean up SVG (keep for reference)
    print(f"SVG kept at {svg_path}")


if __name__ == "__main__":
    main()
