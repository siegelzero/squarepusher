#!/usr/bin/python3
import sys

from typing import List, Tuple


def read_lines(path: str) -> List[str]:
    with open(path, 'r') as foo:
        return [line.strip() for line in foo.readlines() if line.strip()]


def read_squares(lines: List[str], n: int) -> List[List[str]]:
    return [lines[n*i:n*(i + 1)] for i in range(len(lines)//n)]


def group_squares(squares: List[List[str]], k: int):
    seqs = [squares[i::k] for i in range(k)]
    return list(zip(*seqs))


def standardize_group(group, n: int, k: int) -> str:
    first_row = group[0][0]
    targets = [f" {i} " for i in range(n)]
    mapping = dict(zip(first_row, targets))
    group_rows = []

    for i in range(n):
        rows = []
        for square in group:
            row = square[i]
            for symbol, numeral in mapping.items():
                row = row.replace(symbol, numeral).replace("  ", " ").strip()
            rows.append(row)
        group_rows.append(rows)

    group_rows.sort()
    return ' '.join([' '.join([r[i] for r in group_rows]) for i in range(k)])


if __name__ == "__main__":
    n = int(sys.argv[1])
    k = int(sys.argv[2])
    path = sys.argv[3]

    lines = read_lines(path)
    squares = read_squares(lines, n)
    groups = group_squares(squares, k)
    for group in groups:
        print(standardize_group(group, n, k))
