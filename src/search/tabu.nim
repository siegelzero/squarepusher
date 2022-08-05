import std/algorithm
import std/random
import std/sequtils
import std/strformat
import cpuinfo
import threadpool
import times

import "../state/pairwise"
import pool


randomize()


proc bestMoves(state: var PairwiseSquaresState): seq[PositionValue] =
  let n = state.n
  var
    bestMoveCost = high(int) 
    oldValue: int

  for (idx, i, j) in state.positions:
    oldValue = state[idx, i, j]

    for newValue in 0..<n:
      if newValue == oldValue:
        continue

      state.set(idx, i, j, newValue)

      if state.tabu[idx][newValue + n*i + n*n*j] <= state.iteration or state.cost < state.bestCost:
      # if state.tabu[idx][newValue + n*i + n*n*j] <= state.iteration:
      #   state.set(idx, i, j, newValue)
        if state.cost < bestMoveCost:
          result = @[(idx, i, j, newValue)]
          bestMoveCost = state.cost
        elif state.cost == bestMoveCost:
          result.add((idx, i, j, newValue))

    state.set(idx, i, j, oldValue)


proc applyBestMove(state: var PairwiseSquaresState) {.inline.} =
  var moves = state.bestMoves()

  if moves.len > 0:
    let (idx, i, j, newValue) = sample(moves)
    state.set(idx, i, j, newValue, mark=true)


proc tabuImprove*(state: PairwiseSquaresState,
                  threshold: int,
                  verbose: bool = false): PairwiseSquaresState =
  var
    current = deepCopy(state)
    bestSquares = state.squares
    then = epochTime()
    blockSize = 100000
    lastImprovement = 0
    now, rate: float

  current.bestCost = state.cost
  current.resetTabu()

  while current.iteration - lastImprovement < threshold:
    current.applyBestMove()

    if verbose and current.iteration > 0 and current.iteration mod blockSize == 0:
      now = epochTime()
      rate = float(blockSize) / (now - then)
      then = now
      echo fmt"Iteration: {current.iteration}  Current: {current.cost}  Best: {current.bestCost}  Rate: {rate:.3f} it/sec"

    if current.cost < current.bestCost:
      lastImprovement = current.iteration
      current.bestCost = current.cost
      bestSquares = current.squares

    if current.cost == 0:
      break

    current.iteration += 1

  current.loadSquares(bestSquares)
  return current


iterator batchImprove*(states: seq[PairwiseSquaresState],
                       tabuThreshold: int,
                       verbose:bool = false): PairwiseSquaresState =
  var
    jobs: seq[FlowVarBase]

  for state in states:
    jobs.add(spawn state.tabuImprove(tabuThreshold, verbose=verbose))

  for job in jobs:
    yield ^FlowVar[PairwiseSquaresState](job)


proc searchRandom*(n, k, threshold: int,
                   verbose: bool = false,
                   extend: bool = false): PairwiseSquaresState =
  var state = newPairwiseSquaresState(n, k, extend=extend)

  # improve result
  let start = epochTime()
  result = state.tabuImprove(threshold, verbose=verbose)

  let totalTime = epochTime() - start
  let rate = float(result.iteration + 1) / totalTime
  echo fmt"Found: {result.cost}    Time Elapsed: {totalTime:.3f}    Rate: {rate:.3f} iterations/sec"
  if result.cost == 0:
    result.saveState()
    echo "Found Solution"


proc relinkPath*(A, B: PairwiseSquaresState): seq[PairwiseSquaresState] =
  var
    moves: seq[PositionValue]
    bestMoves: seq[int]
    bestFound, bestMoveCost, ncost: int
    bestImprovements: seq[PairwiseSquaresState]
    current = deepCopy(A)

  bestFound = current.cost
  bestImprovements = @[current]

  for idx in 0..<A.squares.len:
    for i in 0..<A.n:
      for j in 0..<A.n:
        if A[idx, i, j] != B[idx, i, j]:
          moves.add((idx, i, j, B[idx, i, j]))

  echo fmt"Relinking from {A.cost} to {B.cost} (path length {moves.len})"

  while moves.len > 0:
    bestMoves = @[]
    bestMoveCost = 100000

    for mi in 0..<moves.len:
      var (idx, i, j, value) = moves[mi]

      ncost = current.moveCost(idx, i, j, value)

      if ncost == bestMoveCost:
        bestMoves.add(mi)
      elif ncost < bestMoveCost:
        bestMoveCost = ncost
        bestMoves = @[mi]

    let ri = sample(bestMoves)
    var (idx, i, j, newValue) = moves[ri]

    current.set(idx, i, j, newValue)
    moves.del(ri)

    if float(current.n)*rand(1.0) <= 1.0:
      # keep path entry with probability 1/n
      result.add(deepCopy(current))


proc buildPopulation(n, k, keep, tabuDepth: int, extend: bool = false): seq[PairwiseSquaresState] =
  let N = countProcessors()
  var initial: seq[PairwiseSquaresState]

  for i in 0..<max(keep, N):
    initial.add(newPairwiseSquaresState(n, k, extend = extend))

  var improved = batchImprove(initial, tabuDepth, verbose = true).toSeq
  improved.sort(cmp)
  result = improved[0..<keep]


proc scatter*(n, k, popSize, iterations, tabuDepth, relinkDepth: int,
              extend: bool = false): PairwiseSquaresState =
  var
    candidates: CandidatePool
    found: seq[PairwiseSquaresState]
    path: seq[PairwiseSquaresState]
    count: int

  echo fmt"Building Initial Population (size {popSize})"
  for candidate in buildPopulation(n, k, popSize, tabuDepth, extend=extend):
    if candidate.cost == 0:
      candidate.saveState()
      echo "Found Solution"
      return candidate
    candidates.entries.add(candidate)

  candidates.updateBounds()
  candidates.poolStatistics()
  
  for iter in 0..<iterations:
    found = @[]
    count = 0
    echo fmt"Scatter Search iteration {iter + 1} of {iterations}"
    for (first, second) in candidates.pairs:
      count += 1
      echo ""
      path = first.relinkPath(second)
      echo fmt"Relinking pair {first.cost} {second.cost} ({count} / {popSize*(popSize - 1) div 2}) (path entries {path.len})"

      var bestEntryCost = min(first.cost, second.cost)
      var bestEntry: PairwiseSquaresState
      var foundImprovement = false

      for entry in path.batchImprove(relinkDepth, verbose = true):
        if entry.cost < bestEntryCost:
          foundImprovement = true
          if entry.cost == 0:
            echo "Found Solution"
            entry.saveState()
            return entry
          bestEntry = entry
          bestEntryCost = entry.cost

      if foundImprovement:
        echo fmt"Adding {bestEntry.cost} to candidate pool"
        found.add(bestEntry)

    echo ""
    candidates.update(deduplicate(found))

    echo ""
    echo "Building Random Population"
    for candidate in buildPopulation(n, k, popSize div 2, tabuDepth, extend=extend):
      if candidate.cost == 0:
        echo "Found Solution"
        candidate.saveState()
        return candidate
      echo fmt"Keeping {candidate.cost}"
      candidates.replaceMaxCost(candidate)
    candidates.poolStatistics()

    echo ""
    echo "Optimizing pool"
    var newCandidates: seq[PairwiseSquaresState]
    for candidate in batchImprove(candidates.entries, tabuDepth, verbose=true):
      if candidate.cost == 0:
        echo "Found Solution"
        candidate.saveState()
        return candidate
      echo fmt"Keeping {candidate.cost}"
      newCandidates.add(candidate)
    candidates.update(deduplicate(newCandidates))

  candidates.entries.sort(cmp)
  result = candidates.entries[0]
  echo fmt"Found {result.cost}"
