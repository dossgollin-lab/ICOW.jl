# Visualization functions for ICOW

using CairoMakie

"""
    plot_zones(levers::Levers; H_city=17.0) -> Figure

Plot an elevation profile showing how levers define the five protection zones.

# Example

```julia
using ICOW

levers = Levers(W=2.0, R=1.5, D=4.0, B=3.0)
fig = plot_zones(levers)
```
"""
function plot_zones(levers::Levers; H_city::Real=17.0)
    W, R, B, D = levers.W, levers.R, levers.B, levers.D

    # Zone boundaries
    z1_top = W + min(R, B)
    z2_top = W + B
    z3_top = W + B + D

    # Colors (Makie accepts hex strings)
    colors = (
        z0="#CC0099",  # dark magenta
        z1="#008B8B",  # dark cyan (teal)
        z2="#0000CD",  # medium blue
        z3="#FF8C00",  # dark orange
        z4="#228B22",  # forest green
    )

    fig = Figure(size=(700, 250))
    ax = Axis(fig[1, 1],
        xlabel="Elevation (m)",
        limits=((-0.5, H_city + 0.5), (-0.1, 1)),
        xticks=0:2:H_city)
    hideydecorations!(ax)
    hidespines!(ax, :t, :l, :r)

    # Draw horizontal bar segments for each zone
    bar_y = 0.5
    bar_height = 0.35

    function zone_bar!(ax, x_lo, x_hi, color, label)
        poly!(ax, Point2f[(x_lo, bar_y - bar_height / 2), (x_hi, bar_y - bar_height / 2),
                (x_hi, bar_y + bar_height / 2), (x_lo, bar_y + bar_height / 2)],
            color=color, strokecolor=:white, strokewidth=1)
        mid = (x_lo + x_hi) / 2
        text!(ax, mid, bar_y, text=label, color=:white, fontsize=9,
            align=(:center, :center), font=:bold)
    end

    # Draw zones left to right
    zone_bar!(ax, 0, W, colors.z0, "Zone 0\nWithdrawn")
    zone_bar!(ax, W, z1_top, colors.z1, "Zone 1\nResistant")
    if R < B
        zone_bar!(ax, z1_top, z2_top, colors.z2, "Zone 2\nGap")
    end
    zone_bar!(ax, z2_top, z3_top, colors.z3, "Zone 3\nDike-protected")
    zone_bar!(ax, z3_top, H_city, colors.z4, "Zone 4\nAbove-dike")

    # Lever brackets below the bar
    function bracket!(ax, x_lo, x_hi, label, y_pos)
        lines!(ax, [x_lo, x_lo], [y_pos, y_pos - 0.08], color=:gray30, linewidth=1)
        lines!(ax, [x_hi, x_hi], [y_pos, y_pos - 0.08], color=:gray30, linewidth=1)
        lines!(ax, [x_lo, x_hi], [y_pos - 0.08, y_pos - 0.08], color=:gray30, linewidth=1)
        text!(ax, (x_lo + x_hi) / 2, y_pos - 0.12, text=label, fontsize=9,
            align=(:center, :top), color=:gray30)
    end

    y_base = bar_y - bar_height / 2 - 0.02
    bracket!(ax, 0, W, "W", y_base)
    bracket!(ax, W, W + R, "R", y_base)
    bracket!(ax, W, z2_top, "B", y_base - 0.18)
    bracket!(ax, z2_top, z3_top, "D", y_base)

    return fig
end
