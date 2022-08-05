import std/strutils
import std/strformat
import os
import times

import "./search/tabu"
import "./state/pairwise"


when isMainModule:
  let
    n = parseInt(paramStr(1))
    k = parseInt(paramStr(2))
    popSize = parseInt(paramStr(3))
    iterations = parseInt(paramStr(4))
    tabuThreshold = parseInt(paramStr(5))
    relinkDepth = parseInt(paramStr(6))

  let start = epochTime()

  # for i in 0..<100:
  #   display(scatter(n, k, popSize, iterations, tabuThreshold, relinkDepth, extend=true))

  display(scatter(n, k, popSize, iterations, tabuThreshold, relinkDepth, extend=true))

  # display(searchRandom(n, k, tabuThreshold))
  # display(tabuRelink(n, k, tabuThreshold, relinkDepth))
  # for n in 3..20:
  #   for i in 0..100:
  #     display(searchRandom(n, k, tabuThreshold))
  #     display(scatter(n, 1, popSize, iterations, tabuThreshold, relinkDepth))
  # display(extensionSearch(n, k, tabuThreshold))
  # searchParallel(n, k, popSize, tabuThreshold)

  let stop = epochTime()

  echo fmt"Time taken: {stop - start:.3f}"
