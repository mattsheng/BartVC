library(ABCforest)

runBART <- function(dat, seed, rep){
  set.seed(seed)
  
  # Prepare input data to bartMachine
  y <- dat[, 1]
  X <- as.data.frame(dat[, -1])

  abc_fit <- ABC_TREE(y = y, X = X,
                      nrep = 1000,
                      burnin = 200,
                      keep = 2)
  s <- process.abc(abc_fit, top = 100, method = "top")

  return(list(s = s))
}
