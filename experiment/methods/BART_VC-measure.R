options(java.parameters = c("-Xmx20g", "-XX:ParallelGCThreads=1"))
library(bartMachine)

runBART <- function(dat, seed, rep){
  # Set seed for reproducibility (optional)
  set.seed(seed)
  
  # Prepare input data to bartMachine
  y <- dat[, 1]
  X <- as.data.frame(dat[, -1])
  # R <- 50 # number of chains for BART
  
  bm <- bartMachine(X = X,
                    y = y,
                    num_trees = 20,
                    num_burn_in = 5000,
                    num_iterations_after_burn_in = 5000,
                    run_in_sample = FALSE,
                    serialize = FALSE,
                    seed = seed,
                    verbose = FALSE)
  bart_machine_arr <- bartMachineArr(bm, R = rep)
  
  # Variable inclusion proportion
  vip <- lapply(bart_machine_arr, function(x) get_var_props_over_chain(x))
  vip <- do.call(rbind, vip) # return list as matrix
  vip_rank <- t(apply(vip, 1, function(x) rank(-x)))

  # Variable count
  vc <- lapply(bart_machine_arr, function(x) colMeans(get_var_counts_over_chain(x)))
  vc <- do.call(rbind, vc)
  vc_rank <- t(apply(vc, 1, function(x) rank(-x)))

  return(list(vip = vip, vip_rank = vip_rank, 
              vc = vc, vc_rank = vc_rank)
}
