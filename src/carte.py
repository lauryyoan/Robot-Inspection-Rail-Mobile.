# -*- coding: utf-8 -*-
"""carte.py — Carte lineaire d'etat hydrique le long du rail (livrable sujet)."""

COULEURS = {"sain": "#2ecc71", "vigilance": "#f1c40f",
            "stress_modere": "#e67e22", "stress_severe": "#e74c3c"}


def generer(lignes, chemin_png, titre="Carte lineaire d'etat hydrique"):
    """Genere le graphe position -> score de stress.

    lignes : liste de dicts (les lignes du CSV de campagne).
    """
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.patches import Patch

    xs, scores, couleurs, hums = [], [], [], []
    for l in lignes:
        if l["score_stress"] is None:
            continue
        xs.append(float(l["position_x_m"]))
        scores.append(float(l["score_stress"]))
        couleurs.append(COULEURS.get(l["niveau"], "#95a5a6"))
        hums.append(float(l["humidite_sol_pct"]) if l["humidite_sol_pct"] else None)

    if not xs:
        raise ValueError("Aucune ligne avec score pour tracer la carte")

    fig, ax = plt.subplots(figsize=(10, 4.5))
    ax.bar(xs, scores, width=0.15, color=couleurs, edgecolor="#333",
           linewidth=0.8, zorder=3, label="Score de stress")
    ax.plot(xs, scores, color="#2c3e50", marker="o", linewidth=1,
            markersize=4, zorder=4)
    ax.set_ylim(0, 1)
    ax.set_yticks([0, 0.25, 0.5, 0.75, 1.0])
    ax.set_yticklabels(["0\nsain", "0.25", "0.50", "0.75", "1.0\nstress severe"])
    ax.set_xlabel("Position sur le rail (m)")
    ax.set_ylabel("Score de stress hydrique")
    ax.set_title(titre)
    ax.grid(axis="y", alpha=0.3, zorder=0)

    if any(h is not None for h in hums):
        ax2 = ax.twinx()
        hx = [x for x, h in zip(xs, hums) if h is not None]
        hy = [h for h in hums if h is not None]
        ax2.plot(hx, hy, "b--", alpha=0.6, marker="s", markersize=3,
                 label="Humidite du sol (%)")
        ax2.set_ylabel("Humidite du sol (%)", color="b")
        ax2.set_ylim(0, 100)
        ax2.tick_params(axis="y", labelcolor="b")

    legendes = [Patch(facecolor=c, label=n.replace("_", " "))
                for n, c in COULEURS.items()]
    ax.legend(handles=legendes, loc="upper left", fontsize=8, ncol=4)

    fig.tight_layout()
    fig.savefig(chemin_png, dpi=120)
    plt.close(fig)
    return chemin_png
