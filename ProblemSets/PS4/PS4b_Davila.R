library(sparklyr)
library(tidyverse)
library(dplyr)

# Set up a connection to Spark
spark_install(version = "3.0.0")
sc <- spark_connect(master = "local")

# Create table 
data(iris)
df1 <- as_tibble(iris)

# Copy it to Spark
df <- copy_to(sc, df1)

# Verify type
class(df1)
class(df)

# View the first few rows
head(df1)
head(df)

# List first 6 rows
df %>% 
  select(Sepal_Length, Species) %>% 
  head(6) %>% 
  print()

# List first 6 rows with length larger than 5.5
df %>% 
  filter(Sepal_Length > 5.5) %>% 
  head(6) %>% 
  print()

# Combine the two exercises
df %>% 
  filter(Sepal_Length > 5.5) %>% 
  select(Sepal_Length, Species) %>% 
  head(6) %>% 
  print()

# Compute average length and number of observations by three species
df2 <- df %>% 
  group_by(Species) %>% 
  summarize(mean = mean(Sepal_Length, na.rm = TRUE), count = n()) %>% 
  head() %>% 
  print()

# Sort RDD by Species
df2 %>%
  as.data.frame() %>%
  arrange(Species)
