#!/usr/bin/env python3
"""Valida os assets de decoração entregues (base de tile 32x32).

Histórico: este arquivo nasceu em T001 como reescalonador (caixa alvo 200x112,
filtro NEAREST). Depois que os assets foram refeitos fora do jogo com proporções
derivadas da base de 32x32 (atualização de 2026-10-03), o script passou a ser
SOMENTE VALIDADOR: ele não escreve, não reescala e não restaura nenhum PNG.
Reescalonar de novo a partir de ``assets/decoracao/_originais/`` desfaría a arte
entrega.

O que ele confere (research.md R1, SC-027, FR-029):

1. os nomes declarados em ``GameConfig.DECORATION_LIBRARIES`` existem nas
   pastas de ``GameConfig.DECORATION_PATHS``;
2. nenhum PNG dessas pastas ficou fora da biblioteca;
3. cada altura está na faixa da SC-027 (3% a 35% da área visível de 480 px);
4. a proporção preservada frente ao original em ``_originais/`` (quando há
   backup correspondente), com aviso a partir de 10% de desvio;
5. se o Godot já gerou o ``.import`` de cada PNG;
6. se os ``weight`` (percentual de apresentação, FR-036/FR-037) de cada
   biblioteca somam 100 pontos.

Uso:
    python3 tools/resize_decoration_assets.py
"""

from __future__ import annotations

import re
import struct
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DECORACAO_DIR = REPO_ROOT / "assets" / "decoracao"
ORIGINAIS_DIR = DECORACAO_DIR / "_originais"
GAME_CONFIG = REPO_ROOT / "src" / "config" / "game_config.gd"

# SC-027 revisada: altura entre 3% e 35% da área visível (480 px).
ALTURA_VISIVEL = 480.0
ALTURA_MIN_PCT = 3.0
ALTURA_MAX_PCT = 35.0

# Base de tile usada na preparação dos assets.
TILE = 32

# Desvio de proporção frente ao original: acima de 10% vira aviso, acima de
# 35% é falha (a premissa de uso dos assets admite ajuste para a grade de
# tiles, mas não reenquadramento livre).
DESVIO_AVISO_PCT = 10.0
DESVIO_MAXIMO_PCT = 35.0

# Assets renomeados na refeição dos PNGs: o backup em _originais/ continua com
# o nome antigo e é ele que serve de referência de proporção.
BACKUP_POR_ASSET = {
    "deserto/deserto_arvore01": "deserto/deserto_coqueiro01",
    "deserto/deserto_arvore02": "deserto/deserto_coqueiro02",
    "deserto/deserto_casa": "deserto/deserto_ruina",
    "floresta/floresta_serra": "floresta/floresta_serralheria",
}


def dimensoes(png: Path) -> tuple[int, int]:
    """Lê a caixa do IHDR sem depender de biblioteca externa."""
    data = png.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"não é um PNG válido: {png}")
    return struct.unpack(">II", data[16:24])


def ler_bibliotecas() -> tuple[dict[str, list[tuple[str, bool, float]]], dict[str, str]]:
    """Lê DECORATION_LIBRARIES (asset, repeatable, weight) e DECORATION_PATHS."""
    texto = GAME_CONFIG.read_text(encoding="utf-8")

    libs: dict[str, list[tuple[str, bool, float]]] = {}
    bloco = re.search(r"DECORATION_LIBRARIES: Dictionary = \{(.*?)\n\}", texto, re.S)
    if bloco is None:
        sys.exit(f"DECORATION_LIBRARIES não encontrada em {GAME_CONFIG}")

    ambiente = None
    for linha in bloco.group(1).splitlines():
        cabeca = re.match(r'\s*"(\w+)": \[', linha)
        if cabeca:
            ambiente = cabeca.group(1)
            libs[ambiente] = []
        entrada = re.search(
            r'"asset":\s*"([^"]+)".*?"repeatable":\s*(true|false).*?"weight":\s*([\d.]+)',
            linha,
        )
        if entrada and ambiente:
            libs[ambiente].append(
                (entrada.group(1), entrada.group(2) == "true", float(entrada.group(3)))
            )

    caminhos: dict[str, str] = {}
    for ambiente, caminho in re.findall(
        r'"(\w+)":\s*"(res://assets/decoracao/[^"]+)"', texto
    ):
        caminhos[ambiente] = caminho

    return libs, caminhos


def validar() -> tuple[list[str], list[str]]:
    falhas: list[str] = []
    avisos: list[str] = []

    libs, caminhos = ler_bibliotecas()
    if not libs:
        falhas.append("nenhuma biblioteca de decoração declarada")
        return falhas, avisos

    min_px = ALTURA_VISIVEL * ALTURA_MIN_PCT / 100.0
    max_px = ALTURA_VISIVEL * ALTURA_MAX_PCT / 100.0

    print(
        f"{'ambiente':10} {'asset':22} {'tamanho':10} {'tiles':11} "
        f"{'altura':8} {'desvio':8} {'peso':7}"
    )

    declarados: set[Path] = set()
    for ambiente in sorted(libs):
        caminho = caminhos.get(ambiente, "")
        if not caminho:
            falhas.append(f"{ambiente}: sem DECORATION_PATHS correspondente")
            continue
        pasta = REPO_ROOT / caminho.replace("res://", "")

        soma_pesos = 0.0
        for asset, repetivel, peso in libs[ambiente]:
            soma_pesos += peso
            png = pasta / f"{asset}.png"
            declarados.add(png)

            if not png.exists():
                falhas.append(f"{ambiente}: asset declarado ausente: {png.relative_to(REPO_ROOT)}")
                continue

            largura, altura = dimensoes(png)

            if not (min_px <= altura <= max_px):
                falhas.append(
                    f"{ambiente}/{asset}: altura {altura}px = "
                    f"{altura / ALTURA_VISIVEL * 100:.0f}% da área visível, fora da "
                    f"faixa de {ALTURA_MIN_PCT:.0f}% a {ALTURA_MAX_PCT:.0f}% (SC-027)"
                )

            if not Path(str(png) + ".import").exists():
                avisos.append(
                    f"{ambiente}/{asset}: sem .import — abrir o editor Godot para reimportar"
                )

            desvio_txt = "-"
            chave = f"{pasta.name}/{asset}"
            backup_rel = BACKUP_POR_ASSET.get(chave, chave)
            backup = ORIGINAIS_DIR / f"{backup_rel}.png"
            if backup.exists():
                ow, oh = dimensoes(backup)
                sx, sy = largura / ow, altura / oh
                desvio = abs(sx - sy) / max(sx, sy) * 100.0
                desvio_txt = f"{desvio:.1f}%"
                if desvio > DESVIO_MAXIMO_PCT:
                    falhas.append(
                        f"{ambiente}/{asset}: proporção deslocou {desvio:.1f}% do original "
                        f"({ow}x{oh}), acima de {DESVIO_MAXIMO_PCT:.0f}%"
                    )
                elif desvio > DESVIO_AVISO_PCT:
                    avisos.append(
                        f"{ambiente}/{asset}: proporção ajustada em {desvio:.1f}% frente ao "
                        f"original ({ow}x{oh}) — esperado no encaixe na grade de {TILE}px"
                    )
            else:
                avisos.append(f"{ambiente}/{asset}: sem backup em _originais/ para comparar")

            relativo = "OK" if largura % TILE == 0 or altura % TILE == 0 else "sem eixo %d" % TILE
            tiles = f"{largura / TILE:.2f}x{altura / TILE:.2f}"
            print(
                f"{ambiente:10} {asset:22} {largura}x{altura:<5} {tiles:11} "
                f"{altura / ALTURA_VISIVEL * 100:5.0f}% {desvio_txt:8} "
                f"{'rep' if repetivel else '   '} {relativo:12} "
                f"{peso:5.1f}%"
            )

        if abs(soma_pesos - 100.0) > 0.01:
            falhas.append(
                f"{ambiente}: percentuais de apresentação somam {soma_pesos:.1f}, "
                "esperado 100.0"
            )

        arquivos = sorted(pasta.glob("*.png")) if pasta.is_dir() else []
        for png in arquivos:
            if png not in declarados:
                falhas.append(
                    f"{ambiente}: PNG fora da biblioteca: {png.relative_to(REPO_ROOT)}"
                )

    return falhas, avisos


def main() -> int:
    if not DECORACAO_DIR.is_dir():
        sys.exit(f"Diretório de decoração não encontrado: {DECORACAO_DIR}")

    print("validação dos assets de decoração (nenhum arquivo é alterado)")
    print(
        f"base de tile {TILE}x{TILE}, altura entre {ALTURA_MIN_PCT:.0f}% e "
        f"{ALTURA_MAX_PCT:.0f}% da área visível de {ALTURA_VISIVEL:.0f}px\n"
    )

    falhas, avisos = validar()

    print()
    for aviso in avisos:
        print(f"AVISO: {aviso}")

    if falhas:
        print("\nFALHA:")
        for falha in falhas:
            print(f"  - {falha}")
        return 1

    total = sum(len(v) for v in ler_bibliotecas()[0].values())
    print(
        f"OK: {total} assets declarados existem, com altura na faixa da SC-027 "
        "e percentuais somando 100 por ambiente"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
