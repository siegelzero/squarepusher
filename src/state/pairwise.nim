import std/random
import std/strutils
import std/strformat

import square


randomize()


type
  Position* = (int, int, int)
  PositionValue* = (int, int, int, int)

  PairwiseSquaresState* = ref object
    # n: dimension of each square
    n*: int

    # k: number of squares
    k*: int

    # k squares squares[0], squares[1], ..., squares[k - 1]
    squares*: seq[SquareState] 

    # pairCounts[i][j] for 0 <= i < j < k is a n x n array P
    # P[a][b] is the number of times the pair (a, b) appears in the two squares
    # Then the two Latin Squares are orthogonal if P[a][b] == 1 for all entries 0 <= a <= b <= n - 1
    pairCounts*: seq[seq[seq[seq[int]]]]
    cost*: int

    bestCost*: int
    iteration*: int
    tabu*: seq[seq[int]]


func `[]`*(state: PairwiseSquaresState, idx, i, j: int): int {.inline.} =
  state.squares[idx].square[i][j]


iterator positions*(state: PairwiseSquaresState): Position =
  for idx in 0..<state.k:
    let start = (if idx == 0: 1 else: 0)
    for i in 1..<state.n:
      for j in start..<state.n:
        yield (idx, i, j)


proc resetTabu*(state: var PairwiseSquaresState) =
  let n = state.n
  state.tabu = @[]
  for idx in 0..<state.k:
    state.tabu.add(newSeq[int](n*n*n))
  state.iteration = 0


proc display*(state: PairwiseSquaresState) =
  for idx in 0..<state.k:
    for i in 0..<state.n:
      echo state.squares[idx].square[i]
    echo ""


func distance*(A, B: PairwiseSquaresState): int =
  for (idx, i, j) in A.positions:
    if A[idx, i, j] != B[idx, i, j]:
      result += 1


proc set*(state: var PairwiseSquaresState,
          idx, i, j, newValue: int,
          mark: bool = false) {.inline.} =
  let
    n = state.n
    k = state.k
    oldValue = state.squares[idx].square[i][j]

  # Update the square entry and adjust the pair cost
  state.cost += state.squares[idx].set(i, j, newValue)

  for l in 0..<idx:
    var a = state[l, i, j]
    state.pairCounts[l][idx][a][oldValue] -= 1
    if state.pairCounts[l][idx][a][oldValue] == 0:
      state.cost += 1
    state.pairCounts[l][idx][a][newValue] += 1
    if state.pairCounts[l][idx][a][newValue] == 1:
      state.cost -= 1

  for l in (idx + 1)..<k:
    var b = state[l, i, j]
    state.pairCounts[idx][l][oldValue][b] -= 1
    if state.pairCounts[idx][l][oldValue][b] == 0:
      state.cost += 1
    state.pairCounts[idx][l][newValue][b] += 1
    if state.pairCounts[idx][l][newValue][b] == 1:
      state.cost -= 1

  if mark:
    state.tabu[idx][oldValue + n*i + n*n*j] = state.iteration + 1 + rand(k*n)


proc loadSquares*(state: var PairwiseSquaresState, squares: seq[SquareState]) =
  for idx in 0..<squares.len:
    for i in 0..<state.n:
      for j in 0..<state.n:
        state.set(idx, i, j, squares[idx].square[i][j])


proc loadKMOLS*(n, k: int): seq[SquareState] =
  var
    states: File
    lines, entries: seq[string]
    square: SquareState
    value: int

  # Load all states
  states = open(fmt"data/state_{n}_{k}.txt", fmRead)
  for line in states.lines:
    lines.add(line)
  states.close()

  entries = lines.sample().split(" ")

  for idx in 0..<k:
    square = randomSquareState(n)
    for i in 0..<n:
      for j in 0..<n:
        value = parseInt(entries[n*n*idx + n*i + j])
        discard square.set(i, j, value)
    result.add(square)


proc newPairwiseSquaresState*(n, k: int, extend = false): PairwiseSquaresState =
  var squares: seq[SquareState]

  proc newPairCounts(): seq[seq[seq[seq[int]]]] =
    for idx1 in 0..<k:
      var entries: seq[seq[seq[int]]] = @[]
      for idx2 in  0..<k:
        var grid: seq[seq[int]] = @[]
        for k in 0..<n:
          grid.add(newSeq[int](n))
        entries.add(grid)
      result.add(entries)

  result = PairwiseSquaresState()
  result.k = k
  result.n = n
  result.cost = 0
  result.pairCounts = newPairCounts()
  result.resetTabu()

  if extend:
    for square in loadKMOLS(n, k - 1):
      squares.add(square)
    squares.add(randomSquareState(n))
  else:
    for i in 0..<k:
      squares.add(randomSquareState(n))

  for square in squares:
    result.squares.add(square)
    result.cost += square.cost

  result.loadSquares(squares)

  for idx1 in 0..<k:
    var A = squares[idx1]
    for idx2 in (idx1 + 1)..<k:
      var B = squares[idx2]
      for i in 0..<n:
        for j in 0..<n:
          var a = A.square[i][j]
          var b = B.square[i][j]
          result.pairCounts[idx1][idx2][a][b] += 1

  for idx1 in 0..<k:
    for idx2 in (idx1 + 1)..<k:
      for i in 0..<n:
        for j in 0..<n:
          if result.pairCounts[idx1][idx2][i][j] == 0:
            result.cost += 1

  result.bestCost = result.cost


# func loadSquareStates*(states: seq[SquareState]): PairwiseSquaresState =
#   let state = states[0]
#   let n = state.square.len
#   let k = states.len
#   result = PairwiseSquaresState()

#   result.cost = 0
#   for state in states:
#     result.squares.add(state)
#     result.cost += state.cost

#   result.pairCounts = newPairCounts(n, k)

#   result.k = k
#   result.n = n
#   result.resetTabu()

#   for idx1 in 0..<k:
#     var A = states[idx1]
#     for idx2 in (idx1 + 1)..<k:
#       var B = states[idx2]
#       for i in 0..<n:
#         for j in 0..<n:
#           var a = A.square[i][j]
#           var b = B.square[i][j]
#           result.pairCounts[idx1][idx2][a][b] += 1

#   for idx1 in 0..<k:
#     for idx2 in (idx1 + 1)..<k:
#       for i in 0..<n:
#         for j in 0..<n:
#           if result.pairCounts[idx1][idx2][i][j] == 0:
#             result.cost += 1

#   result.bestCost = result.cost


proc moveCost*(state: var PairwiseSquaresState, idx, i, j, newValue: int): int =
  let
    oldCost = state.cost
    oldValue = state.squares[idx].square[i][j]

  state.set(idx, i, j, newValue)
  result = state.cost - oldCost
  state.set(idx, i, j, oldValue)


proc saveState*(state: PairwiseSquaresState) =
  var
    entries: seq[string]
    output: File

  doAssert state.cost == 0

  for idx in 0..<state.k:
    for i in 0..<state.n:
      for j in 0..<state.n:
        entries.add(fmt"{state.squares[idx].square[i][j]}")
        if j + 1 < state.n:
          entries.add(" ")
      if i + 1 < state.n:
        entries.add(" ")
    if idx + 1 < state.k:
      entries.add(" ")

  output = open(fmt"data/state_{state.n}_{state.k}.txt", fmAppend)
  output.writeLine(entries)
  output.close()



proc `[]=`*(state: var PairwiseSquaresState, idx, i, j, value: int) {.inline.} =
  state.set(idx, i, j, value)

proc `[]^=`*(state: var PairwiseSquaresState, idx, i, j, value: int) {.inline.} =
  state.set(idx, i, j, value)

func `==`*(A, B: PairwiseSquaresState): bool {.inline.} =
  A.distance(B) == 0

func cmp*(A, B: PairwiseSquaresState): int =
  cmp(A.cost, B.cost)
