set.seed(123)
setwd("~/Dropbox/Research/2025/BartVC/")
library(arrow)
library(ggplot2)
library(dplyr)
library(tidyr)
library(patchwork)
source("postprocessing/plot_funs.R")

# Load results
df <- read_feather("results/with_idx/results_toy_example.feather")

# A demo for VC vs VIP
# Feynman II.11.17
# SNR = 1, n = 1000, p0 = 6, p = 306, seed = 860
df_DART_VIP <- df %>% filter(Algorithm == "DART VIP-measure")
df_DART_VC <- df %>% filter(Algorithm == "DART VC-measure")
df_tmp <- left_join(df_DART_VC, df_DART_VIP,
                    by = c("dataset_name", "random_state", "SNR", "n", "p", "p0",
                           "vip_mu_K10", "vip_rank_mu_K10", "vc_mu_K10", "vc_rank_mu_K10"))
df_demo <- data.frame(vip = df_tmp$vip_mu_K10[[1]],
                      vip_rank = df_tmp$vip_rank_mu_K10[[1]],
                      vc = df_tmp$vc_mu_K10[[1]],
                      vc_rank = df_tmp$vc_rank_mu_K10[[1]])
df_demo <- apply(df_demo, 2, function(x) log1p(x))
df_demo <- apply(df_demo, 2, function(x) (x - min(x)) / (max(x) - min(x)))
df_demo <- as.data.frame(df_demo)
df_demo$idx <- c(rep("Relevant", df_tmp$p0), rep("Irrelevant", df_tmp$p - df_tmp$p0))
df_demo$idx <- factor(df_demo$idx, levels = c("Relevant", "Irrelevant"))
df_demo$vc_idx <- df_demo$vip_idx <- rep("Not selected", df_tmp$p)
df_demo$vc_idx[df_tmp$pos_idx.x[[1]]+1] <- "Selected"
df_demo$vip_idx[df_tmp$pos_idx.y[[1]]+1] <- "Selected"
df_demo$vc_idx <- factor(df_demo$vc_idx, levels = c("Selected", "Not selected"))
df_demo$vip_idx <- factor(df_demo$vip_idx, levels = c("Selected", "Not selected"))

# Identify false negatives
false_negatives <- df_demo %>%
  filter(idx == "Relevant", vip_idx == "Not selected")

# Label position and buffer
label_x <- 0.4
label_y <- 0.4
buffer <- 0.01

# Compute adjusted arrow start points (toward label, but with buffer)
arrow_segments <- false_negatives %>%
  mutate(
    x_start = label_x,
    y_start = label_y - 0.04,
    x_end = vip - sign(vip - label_x) * buffer,
    y_end = vip_rank - sign(vip_rank - label_y) * buffer
  )
arrow_segments$x_end[2] <- arrow_segments$x_end[2] - 0.01
arrow_segments$y_end[2] <- arrow_segments$y_end[2] + 0.01

# Plot
p8l <- ggplot(df_demo, aes(x = vip, y = vip_rank, shape = idx, color = vip_idx)) +
  geom_point(size = 3, alpha = 0.8) +
  scale_shape_manual(values = c("Relevant" = 17, "Irrelevant" = 1)) +
  # geom_star(aes(starshape = idx), size=2.5) +
  scale_color_manual(values = c("Not selected" = "dodgerblue", "Selected" = "tomato")) +
  labs(shape = "Ground Truth", color = "Selection", x = "VIP", y = "VIP Rank") +
  theme_minimal() +
  annotate("text", x = label_x, y = label_y, label = "False Negative", size = 4, fontface = "bold", color = "gray30") +
  geom_segment(data = arrow_segments,
               aes(x = x_start, y = y_start, xend = x_end, yend = y_end),
               inherit.aes = FALSE,
               arrow = arrow(length = unit(0.2, "cm")),
               color = "gray50"
  ) +
  theme(text = element_text(family = "Arial"))

p8r <- ggplot(df_demo, aes(x = vc, y = vc_rank, shape = idx, color = vc_idx)) +
  geom_point(size = 3, alpha = 0.8) +
  scale_shape_manual(values = c("Relevant" = 17, "Irrelevant" = 1)) +
  scale_color_manual(values = c("Not selected" = "dodgerblue", "Selected" = "tomato")) +
  labs(shape = "Ground Truth", color = "Selection", x = "VC", y = "VC Rank") +
  theme_minimal() +
  theme(text = element_text(family = "Arial"))

p8 <- p8l + p8r + plot_layout(guides = "collect") & theme(legend.position = "right")
ggsave("figs/fig8_Scatterplot_DART_VC-measure_vs_VIP-measure.pdf", plot = p8,
       device = cairo_pdf, width = 9, height = 3)