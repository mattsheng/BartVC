options(java.parameters = c("-Xmx20g", "-XX:ParallelGCThreads=1"))
library(dartMachine)

runBART <- function(dat, seed, rep){
  # Set seed for reproducibility (optional)
  set.seed(seed)
  seeds <- sample.int(10000, size = rep)
  
  # Prepare input data to bartMachine
  y <- dat[, 1]
  X <- as.data.frame(dat[, -1])

  vip <- matrix(NA, nrow = rep, ncol = ncol(X))
  vc <- matrix(NA, nrow = rep, ncol = ncol(X))
  s <- matrix(NA, nrow = rep, ncol = ncol(X))

  for (r in 1:rep) {
    dm <- bartMachine(X = X,
                      y = y,
                      num_trees = 20,
                      num_burn_in = 5000,
                      num_iterations_after_burn_in = 5000,
                      run_in_sample = FALSE,
                      serialize = FALSE,
                      seed = seeds[r],
                      verbose = FALSE,
                      do_ard = TRUE)
    vc_full <- get_var_counts_over_chain(dm)
    vip[r, ] <- get_var_props_over_chain(dm)
    vc[r, ] <- colMeans(vc_full)
    s[r, ] <- colMeans(vc_full > 0)
  }

  vip_rank <- t(apply(vip, 1, function(x) rank(-x)))
  vc_rank <- t(apply(vc, 1, function(x) rank(-x)))
  
  return(list(vip = vip, vip_rank = vip_rank, 
              vc = vc, vc_rank = vc_rank, 
              s = s))
}