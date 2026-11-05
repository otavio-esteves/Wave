"""Plot actual Godot heightfield diagnostics; never launch the game renderer."""

import argparse
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


def street_profile(report, row=4):
    edges = {(edge["a"], edge["b"]): edge["points"] for edge in report["streets"]}
    points = []
    for column in range(20):
        edge = edges[(row * 21 + column, row * 21 + column + 1)]
        points.extend(edge[:-1])
    points.append(edge[-1])
    points = np.asarray(points)
    distance = np.r_[0, np.cumsum(np.linalg.norm(np.diff(points[:, [0, 2]], axis=0), axis=1))]
    return distance, points[:, 1] - report["min_height_m"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    reports = [json.loads(path.read_text()) for path in [args.before, args.after]]
    fig = plt.figure(figsize=(14, 9), layout="constrained")
    grid = fig.add_gridspec(2, 2, height_ratios=[2.3, 1])
    axes = [fig.add_subplot(grid[0, index]) for index in range(2)]
    for ax, report, title in zip(axes, reports, ["Antes — relevo suave", "Depois — colinas e vale urbano"]):
        heights = np.asarray(report["height_grid"]) - report["min_height_m"]
        xs = np.linspace(-report["half_width"], report["half_width"], heights.shape[1])
        zs = np.linspace(-report["half_depth"], report["half_depth"], heights.shape[0])
        image = ax.pcolormesh(xs, zs, heights, cmap="terrain", shading="auto", vmin=0, vmax=60, rasterized=True)
        ax.contour(xs, zs, heights, levels=np.arange(5, 61, 5), colors="#384939", linewidths=0.35, alpha=0.55)
        for edge in report["streets"]:
            points = np.asarray(edge["points"])
            points = points[np.r_[np.arange(0, len(points) - 1, 4), len(points) - 1]]
            ax.plot(points[:, 0], points[:, 2], color="white", linewidth=0.5, alpha=0.8)
        for x, label in [(-1050, "Jardins do Vale"), (80, "Vila Aurora"), (1050, "Centro Horizonte")]:
            ax.text(x, -1150, label, ha="center", fontsize=8, bbox=dict(facecolor="white", alpha=0.8, edgecolor="none", pad=2))
        ax.set(title=title, xlabel="Oeste → leste (m)", ylabel="Norte / sul (m)", aspect="equal")
        ax.set_title(title + f"\nDesnível nas ruas: {report['street_max_height_m']-report['street_min_height_m']:.1f} m | inclinação máxima: {report['max_street_grade']*100:.1f}%", fontsize=11)
    fig.colorbar(image, ax=axes, label="Elevação acima do ponto mais baixo do terreno (m)", shrink=0.85)
    profile = fig.add_subplot(grid[1, :])
    for report, label, color in zip(reports, ["Antes", "Depois"], ["#647985", "#8c592f"]):
        distance, heights = street_profile(report)
        profile.plot(distance, heights, color=color, label=label, linewidth=2)
    profile.set(xlabel="Distância ao longo da mesma avenida, do oeste ao leste (m)", ylabel="Elevação relativa (m)", ylim=(0, 65))
    profile.grid(alpha=0.2)
    profile.legend(loc="upper right")
    fig.suptitle("Wave · diagnóstico do relevo nos mesmos 200 quarteirões\nDados da malha e das ruas; não é uma captura renderizada do jogo.", fontsize=14)
    fig.savefig(args.output, dpi=160)
    plt.close(fig)


if __name__ == "__main__":
    main()
