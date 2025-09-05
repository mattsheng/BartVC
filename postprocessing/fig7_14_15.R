set.seed(123)
setwd("~/Dropbox/Research/2025/BartVC/")
library(arrow)
library(ggplot2)
library(dplyr)
library(tidyr)
library(patchwork)
source("postprocessing/plot_funs.R")

# Load results
df_DART_VIP <- read_feather("results/with_idx/results_DART_VIP-measure.feather")
df_DART_VC <- read_feather("results/with_idx/results_DART_VC-measure.feather") %>% 
  filter(Algorithm == "DART VC-measure (L=10)") %>%
  mutate(Algorithm = case_match(Algorithm,
                                "DART VC-measure (L=10)" ~ "DART VC-measure"))
df <- bind_rows(df_DART_VIP, df_DART_VC)

# Convert SNR to factor to maintain the order
df <- df %>%
  mutate(SNR = ifelse(SNR == 0, "noiseless", as.character(SNR)))
df$SNR <- factor(df$SNR, levels = c("0.25", "0.5", "1", "2", "5", "10", "15", "20", "noiseless"))

# Convert Algorithm to factor to maintain the order
df$Algorithm <- factor(df$Algorithm, levels = c("DART VC-measure", "DART VIP-measure"))

# Average over `random_state`
summary_df <- df %>%
  group_by(dataset_name, n, SNR, Algorithm) %>%
  summarize(TPR = mean(TPR), 
            FPR = mean(FPR),
            F1 = mean(F1),
            .groups = 'drop')
summary_df_2 <- summary_df %>%
  group_by(n, SNR, Algorithm) %>%
  summarize(TPR = mean(TPR), 
            FPR = mean(FPR),
            F1 = mean(F1),
            .groups = 'drop')

# F1
F1_summary <- summary_df_2 %>% 
  select(n, SNR, Algorithm, F1) %>%
  rename(mean_value = F1)
p7 <- feynman_SR_plot(F1_summary, xlab = "SNR", ylab = expression(F[1]), title = "")
ggsave("figs/fig7_F1_DART_VC-measure_vs_VIP-measure.pdf", plot = p7,
       device = cairo_pdf, width = 10, height = 6.5)

# TPR
TPR_summary <- summary_df_2 %>% 
  select(n, SNR, Algorithm, TPR) %>%
  rename(mean_value = TPR)
p14 <- feynman_SR_plot(TPR_summary, xlab = "SNR", ylab = "TPR", title = "")
ggsave("figs/fig14_TPR_DART_VC-measure_vs_VIP-measure.pdf", plot = p14,
       device = cairo_pdf, width = 10, height = 6.5)

# FPR
FPR_summary <- summary_df_2 %>% 
  select(n, SNR, Algorithm, FPR) %>%
  rename(mean_value = FPR)
p15 <- feynman_SR_plot(FPR_summary, xlab = "SNR", ylab = "FPR", title = "")
ggsave("figs/fig15_FPR_DART_VC-measure_vs_VIP-measure.pdf.pdf", plot = p15,
       device = cairo_pdf, width = 10, height = 6.5)

