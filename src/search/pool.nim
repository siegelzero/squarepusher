import std/strformat

import "../state/pairwise"


type
  CandidatePool* = object
    maxCost*, minCost*: int
    maxLen*: int
    entries*: seq[PairwiseSquaresState]


proc poolStatistics*(pool: CandidatePool) =
  var poolSum: int

  for e in pool.entries:
    poolSum += e.cost

  echo ""
  echo fmt"Pool max: {pool.maxCost}"
  echo fmt"Pool mean: {float(poolSum) / float(pool.entries.len)}"
  echo fmt"Pool min: {pool.minCost}"
  echo ""


proc updateBounds*(pool: var CandidatePool) =
  var
    cost: int
    maxCost = 0
    minCost = 10000

  for i in 0..<pool.entries.len:
    cost = pool.entries[i].cost
    if cost < minCost:
      minCost = cost
    if cost > maxCost:
      maxCost = cost

  pool.minCost = minCost
  pool.maxCost = maxCost


proc replaceMostSimilar*(pool: var CandidatePool, entry: PairwiseSquaresState) =
  var
    distance, minIndex: int
    minDistance = 10000
    other: PairwiseSquaresState
    found = false

  for i in 0..<pool.entries.len:
    other = pool.entries[i]
    if entry.cost <= other.cost:
      distance = entry.distance(pool.entries[i])
      if distance < minDistance:
        minDistance = distance
        minIndex = i
        found = true

  if found:
    echo fmt"Replacing {pool.entries[minIndex].cost} with {entry.cost} (distance: {minDistance})"
    pool.entries[minIndex] = entry
    pool.updateBounds()
  else:
    echo fmt"Not replacing entry"


proc replaceMaxCost*(pool: var CandidatePool, entry: PairwiseSquaresState) =
  var
    maxIndex: int
    other: PairwiseSquaresState

  for i in 0..<pool.entries.len:
    other = pool.entries[i]
    if other.cost == pool.maxCost:
      maxIndex = i

  echo fmt"Replacing {pool.entries[maxIndex].cost} with {entry.cost}"
  pool.entries[maxIndex] = entry
  pool.updateBounds()


proc update*(pool: var CandidatePool, entries: seq[PairwiseSquaresState]) =
  for e in entries:
    pool.replaceMostSimilar(e)
  

iterator pairs*(pool: CandidatePool): (PairwiseSquaresState, PairwiseSquaresState) =
  for i in 0..<pool.entries.len:
    for j in 0..<i:
      yield (pool.entries[i], pool.entries[j])
  