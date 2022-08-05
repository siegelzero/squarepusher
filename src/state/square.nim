import std/random
import std/sequtils


randomize()


type
  SquareState* = object
    n: int
    square*: seq[seq[int]]
    rcounts, ccounts: seq[seq[int]]
    rcost*, ccost*: seq[int]
    cost*: int


func `[]`*(state: SquareState, i, j: int): int {.inline} =
  state.square[i][j]


proc initSquareState(n: int): SquareState =
  result.n = n
  result.square = newSeqWith(n, newSeq[int](n))
  result.rcounts = newSeqWith(n, newSeq[int](n))
  result.ccounts = newSeqWith(n, newSeq[int](n))
  result.rcost = newSeq[int](n)
  result.ccost = newSeq[int](n)


proc loadValues*(square: seq[seq[int]]): SquareState =
  let n = len(square)
  result = initSquareState(n)

  for i in 0..<n:
    for j in 0..<n:
      result.square[i][j] = square[i][j]

  for i in 0..<n:
    for j in 0..<n:
      let entry = result.square[i][j]
      result.rcounts[i][entry] += 1

  for j in 0..<n:
    for i in 0..<n:
      let entry = result.square[i][j]
      result.ccounts[j][entry] += 1

  for i in 0..<n:
    for e in result.rcounts[i]:
      if e == 0:
        result.rcost[i] += 1
    for e in result.ccounts[i]:
      if e == 0:
        result.ccost[i] += 1

  for e in result.rcost:
    result.cost += e

  for e in result.ccost:
    result.cost += e


proc randomSquareState*(n: int): SquareState =
  var square = newSeqWith(n, newSeq[int](n))
  for j in 0..<n:
    square[0][j] = j
  for i in 1..<n:
    square[i][0] = i
    for j in 1..<n:
      square[i][j] = rand(n - 1)
  result = loadValues(square)
  

func set*(state: var SquareState, i, j, newValue: int): int {.inline} =
  # Sets entry at position i, j to newValue
  let oldCost = state.cost
  let oldValue = state.square[i][j]

  state.square[i][j] = newValue

  # Update rcounts for the row by adding contribution of new value
  state.rcounts[i][newValue] += 1
  if state.rcounts[i][newValue] == 1:
    state.cost -= 1
    state.rcost[i] -= 1

  # Similarly for the column counts
  state.ccounts[j][newValue] += 1
  if state.ccounts[j][newValue] == 1:
    state.cost -= 1
    state.ccost[j] -= 1

  # Update rcounts for the row by removing contribution of old value
  state.rcounts[i][oldValue] -= 1
  if state.rcounts[i][oldValue] == 0:
    state.cost += 1
    state.rcost[i] += 1

  # Similarly for the column counts
  state.ccounts[j][oldValue] -= 1
  if state.ccounts[j][oldValue] == 0:
    state.cost += 1
    state.ccost[j] += 1

  result = state.cost - oldCost


when isMainModule:
  import times

  let start = cpuTime()

  let square = @[@[0, 1, 2], @[1, 2, 0], @[2, 0, 1]]
  var state = loadValues(square)

  assert state.n == 3

  assert state.square == square
  assert state.rcounts == @[@[1, 1, 1], @[1, 1, 1], @[1, 1, 1]]
  assert state.ccounts == @[@[1, 1, 1], @[1, 1, 1], @[1, 1, 1]]

  assert state.rcost == @[0, 0, 0]
  assert state.ccost == @[0, 0, 0]
  assert state.cost == 0

  discard state.set(2, 2, 2)

  assert state.square == @[@[0, 1, 2], @[1, 2, 0], @[2, 0, 2]]
  assert state.rcounts == @[@[1, 1, 1], @[1, 1, 1], @[1, 0, 2]]
  assert state.ccounts == @[@[1, 1, 1], @[1, 1, 1], @[1, 0, 2]]

  assert state.rcost == @[0, 0, 1]
  assert state.ccost == @[0, 0, 1]
  assert state.cost == 2

  let stop = cpuTime()
  echo "Time taken: ", stop - start
