library(sf)
library(dplyr)
library(ggplot2)
library(leaflet)
library(tidyr)
library(factoextra)
library(car)

metrics <- st_read("output/city_rivers_metrics.gpkg")


# examine segment geometry with par metric
leaflet(metrics) %>%
  addTiles() %>%
  addPolygons(color = "blue", weight = 1, fillOpacity = 0.6,
              label = ~as.character(cs_par))

# create id column
metrics$id <- 1:nrow(metrics)

# check outliers
vars <- metrics[, c("cs_a", "cs_par", "cs_osr", "sn_l", "rn_l", "sn_d", "rn_d", "b_c", "b_d", "sa_a_m", "sa_a_sd", "rc_sin", "rc_cr_n", "rc_cr_d", "rs_a_p", "id")]

vars_df <- st_drop_geometry(vars)
pairs(vars_df)

# histogram to check outliers
df_long <- vars_df %>%
  pivot_longer(cols = everything(), names_to = "variable", values_to = "value")

ggplot(df_long, aes(x = value)) +
  geom_histogram(bins = 30) +
  facet_wrap(~ variable, scales = "free")
# I found extremes in cs_par, and after checking the geometry in qgis one by one from highest cs_par,
# I decide to delete the ones above 0.02
ggplot(vars_df, aes(x = cs_par)) +
  geom_histogram(bins = 30)

# rc_sin also had extremes, so I excluded values above 100
ggplot(vars_df, aes(x = rc_sin)) +
  geom_histogram(bins = 30)

vars_clean <- vars_df |>
  filter(cs_par <= 0.02, rc_sin <= 100)
nrow(vars_df)
nrow(vars_clean) # 25 samples deleted

ggplot(vars_clean, aes(x = cs_par)) +
  geom_histogram(bins = 30)
ggplot(vars_clean, aes(x = rc_sin)) +
  geom_histogram(bins = 30)
pairs(vars_clean)

# check NULL and ID number
colSums(is.na(vars_clean))
na_rows <- which(!complete.cases(vars_clean))
na_ids <- vars_clean$id[na_rows]
print(na_ids)


vars_clean_nona <- vars_clean[complete.cases(vars_clean), ]
ggplot(vars_clean_nona, aes(x = cs_par)) +
  geom_histogram(bins = 30)
ggplot(vars_clean_nona, aes(x = rc_sin)) +
  geom_histogram(bins = 30)
# sa_a_sd has 8 NA values, since mean has value and sd is NULL, we just delete the samples?
#metrics_clean$sa_a_sd[is.na(metrics_clean$sa_a_sd)] <- 0 # and not to set sd =0

nrow(vars_clean_nona)
# check correlation
cor_matrix <- cor(select(vars_clean, -id), use = "complete.obs")

print(round(cor_matrix, 2))
#write.csv(round(cor_matrix,2), "output_yw/correlation_cleaned.csv")

# if no sample deleted, (before cleaning) ,sn_l & b_c =0.87 ; sn_d & b_d =0.87, so maybe remove one/two of them
# but after checking VIF, both showed low vif <10, so they are kept

# if we use cleaned data, sn_l & b_c =0.87 ; sn_d & b_d =0.91, so maybe remove one/two of them
#  after checking VIF, both showed low vif <4 (bc3.2, snl2.3; bd2.7; snd3.2), so they are all kept
# but we can also check anoter dataset that delete b_d, b_l

plot(vars_clean$sn_d, vars_clean$b_d)
abline(lm(b_d ~ sn_d, data = vars_clean), col = "red")

plot(vars_clean$sn_l, vars_clean$b_c)
abline(lm(b_c ~ sn_l, data = vars_clean), col = "red")

# check VIF
lm1 <- lm(sn_l ~ ., data = vars_clean)
vif(lm1)

lm2 <- lm(b_c ~ ., data = vars_clean)
vif(lm2)

lm3 <- lm(sn_d ~ ., data = vars_clean)
vif(lm3)

lm4 <- lm(b_d ~ ., data = vars_clean)
vif(lm4)

vars_ <- vars_df[, !(names(vars_df) == "b_d")]


# vars_new <- vars_clean %>% select(-sn_l, -sn_d)
vars_new <- vars_clean %>% select(-b_c, -b_d)
View(vars_new)

#------------------------------# scale
vars_scaled <- scale(select(vars_clean_nona, -id))
colSums(is.na(vars_scaled))
head(vars_scaled)
View(vars_clean)

#------------------------------# determine opitmal k

fviz_nbclust(vars_scaled, kmeans, method = "silhouette", k.max = 9, nstart = 20)


#------------------------------## kmeans clustering

set.seed(0)  # The number 0 is just a fixed choice. You can also use 10, 345, etc.

# Choose the number of clusters based on the elbow plot
k <- 4

# Run K-means clustering on the standardized data
kmeans_result <- kmeans(vars_scaled, centers = k, nstart = 20)

# Add the cluster labels
cluster_df <- data.frame(
  id = vars_clean_nona$id,
  cluster = as.factor(kmeans_result$cluster)
)
metrics_clustered <- left_join(metrics, cluster_df, by = "id")

View(metrics_clustered)
table(metrics_clustered$cluster)
nrow(vars_clean_nona)

print(kmeans_result)
plot(metrics_clustered["cluster"],
     border = NA)

# visualize the clusters in map
library(leaflet)
pal <- colorFactor("Set1", domain = metrics_clustered$cluster)

leaflet(metrics_clustered) %>%
  addTiles() %>%
  addPolygons(
    fillColor = ~pal(cluster),
    color = "white",
    weight = 0.5,
    fillOpacity = 0.8,
    label = ~paste("Cluster:", cluster)
  ) %>%
  addLegend(
    pal = pal,
    values = ~cluster,
    title = "Cluster"
  )

#------------------------------######## revert to original data
# Get the cluster centers (in standardized form)
scaled_centers <- round(kmeans_result$centers,4)

# Print them
print("Cluster centers (standardized):")
print(round(scaled_centers,2))

# Convert the centers back to original scale: x * SD + mean
original_centers <- t(apply(
  scaled_centers, 1,
  function(x) x * attr(vars_scaled, "scaled:scale") + attr(vars_scaled, "scaled:center")
))

original_centers <- round(original_centers, 5)


# Print the real-world values
print("Cluster centers (original):")
print(original_centers)

cluster_center_df <- as.data.frame(original_centers)
View(cluster_center_df)
library(writexl)
#write_xlsx(cluster_center_df, "output_yw/cluster_c1.xlsx")

#------------------------------## find the representative sample for each cluster

# Get the cluster center for each row, based on its assigned cluster
assigned_centers <- kmeans_result$centers[kmeans_result$cluster, ]

# Compute Euclidean distance from each point to its own cluster center
cluster_dist <- sqrt(rowSums((vars_scaled - assigned_centers)^2))

# Add to the spatial data
cluster_df <- data.frame(
  id = vars_clean_nona$id,
  cluster = as.factor(kmeans_result$cluster),
  dist_to_center = cluster_dist
)

metrics_clustered <- left_join(metrics, cluster_df, by = "id")
# st_write(metrics_clustered, "output_yw/metrics_clusteringv1.gpkg")

# For each cluster, find the row with the minimum distance
closest_ids <- metrics_clustered %>%
  filter(!is.na(cluster)) %>%
  group_by(cluster) %>%
  slice_min(order_by = dist_to_center, n = 1, with_ties = FALSE) %>%
  select(cluster, id, dist_to_center)

print(closest_ids)
# 137, 597, 456, 172
leaflet(metrics_clustered[metrics_clustered$id == 137, ]) %>%
  addTiles() %>%
  addPolygons(
    fillColor = "red",
    color = "black",
    weight = 2,
    fillOpacity = 0.3,
    label = ~paste("cluster:", cluster)
  )


table(metrics_clustered$cluster)
# check the mean of real samples, different from the k-means cluter center
metrics_clustered %>%
  group_by(cluster) %>%
  summarise(across(where(is.numeric), mean))

# 20250613
# -------------------------------# PCA to visualize cluster in 2d
library(FactoMineR)
library(factoextra)

# run PCA
pca_result <- PCA(vars_scaled, graph = FALSE)

# Biplot visual
fviz_pca_biplot(pca_result,
                geom.ind = "point",
                col.ind = as.factor(kmeans_result$cluster),
                addEllipses = TRUE,
                label = "var",
                col.var = "black",
                repel = TRUE,
                legend.title = "Cluster")

# PC1 and PC2 variable contribution
fviz_contrib(pca_result, choice = "var", axes = 1, top = 10)
fviz_contrib(pca_result, choice = "var", axes = 2, top = 10)

# dim explaination % ranked
fviz_screeplot(pca_result, addlabels = TRUE)

##################### top10 identified

top10_samples <- metrics_clustered %>%
  filter(!is.na(cluster)) %>%
  group_by(cluster) %>%
  arrange(dist_to_center) %>%
  mutate(rank = row_number()) %>%
  slice_head(n = 10)




