library(BartMixVs)

runBART <- function(dat, seed, rep){
  # Set seed for reproducibility (optional)
  set.seed(seed)
  
  # Prepare input data to bartMachine
  y <- dat[, 1]
  X <- as.data.frame(dat[, -1])
  colnames(X) <- paste("x.", seq(from = 1, to = ncol(X), by = 1), sep = "")

  mixvs <- permute.vs(x.train = X, y.train = y,
                      ntree = 20,
                      npermute = rep,
                      nskip = 5000,
                      ndpost = 5000, 
                      plot = FALSE)

  if (length(mixvs$vip.imp.names) == 0) {
    idx_vip <- NA
  } else {
    idx_vip <- sort(mixvs$vip.imp.cols) - 1
  }
  
  if (length(mixvs$mi.imp.names) == 0) {
    idx_mi <- NA
    mi <- NA
  } else {
    idx_mi <- sort(mixvs$mi.imp.cols) - 1
    mi <- mixvs$median.mi
    mi_order <- match(x = colnames(X), table = names(mi))
    mi <- mi[mi_order]
  }
  
  return(list(idx_vip = idx_vip, 
              idx_mi = idx_mi,
              mi = mi))
}