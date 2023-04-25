# Set the working directory to the directory containing the script file
script_path <- normalizePath(dirname(rstudioapi::getSourceEditorContext()$path))
setwd(script_path)

# Read in excel data
raw_sample <- read.csv("PS11_Davila.csv")

# If expert_acc if missing then fill with 0
raw_sample$expert_acc[is.na(raw_sample$expert_acc)] <- 0
raw_sample<- na.omit(raw_sample, subset = c("mgr_404_t", "mgr_404_tm1", "turnover", "segment_bus", "foreign_currency", "ceq", "mkt_cap", "roa", "cfo_a", "large_auditor"))


# Show summary stats for the prediction model
library(modelsummary)
prediction_sample <- raw_sample[, c("mgr_404_t", "mgr_404_tm1", "turnover", "segment_bus", "foreign_currency", "ceq", "mkt_cap", "roa", "cfo_a", "large_auditor")]
datasummary_skim(prediction_sample, histogram = FALSE, output = 'latex')

# Get model summary and predicted value using probit model
library(plm)
library(tidyverse)
raw_sample$fyear <- as.factor(raw_sample$fyear)
raw_sample$ff12 <- as.factor(raw_sample$ff12)



probit_fe <- plm(mgr_404_t ~ mgr_404_tm1+turnover+mgr_404_tm1*turnover+segment_bus+foreign_currency+ceq+mkt_cap+roa+cfo_a+large_auditor,
                 data = raw_sample,
                 index = c("fyear", "ff12"),
                 model = "within",
                 effect = "twoways",
                 method = "bprobit")

modelsummary(probit_fe, stars = TRUE, output = 'latex')



# Create a new data frame with turnover = 1 or 0 for all observations, predict the value
new_data1 <- raw_sample
new_data1$turnover <- 1
predicted_1 <- predict(probit_fe, newdata = new_data1)
raw_sample$predicted_change <- predicted_1

new_data2 <- raw_sample
new_data2$turnover <- 0
predicted_0 <- predict(probit_fe, newdata = new_data2)
raw_sample$predicted_unchange <- predicted_0


# Calculate the shopping incentive
raw_sample$shopping <- raw_sample$predicted_unchange - raw_sample$predicted_change
head(raw_sample)


# Estimate the audit committee turnover model
# First show the summary stats for the audit committee turnover model
turnover_sample <- raw_sample[, c("shopping", "turnover", "duality", "bd_size", "size", "leverage", "roa", "loss", "mkt_adj_ret", "btm", "ins_own_t", "analyst_coverage", "exchange")]
datasummary_skim(turnover_sample, histogram = FALSE, output = 'latex')

probit_turnover <- plm(turnover ~ shopping+duality+bd_size+size+leverage+roa+loss+mkt_adj_ret+btm+ins_own_t+analyst_coverage+exchange,
                 data = raw_sample,
                 index = c("fyear", "ff12"),
                 model = "within",
                 effect = "twoways",
                 method = "bprobit")

modelsummary(probit_turnover, stars = TRUE, output = 'latex')



# create two separate data frames for observations based on whether CEO also serves as the board chair
duality1 <- raw_sample[raw_sample$duality == 1,]
duality0 <- raw_sample[raw_sample$duality == 0,]

# Cross-sectional test
mod <- list()
mod[['CEO Duality - Yes']] <- plm(turnover ~ shopping+duality+bd_size+size+leverage+roa+loss+mkt_adj_ret+btm+ins_own_t+analyst_coverage+exchange,
                                  data = duality1,
                                  index = c("fyear", "ff12"),
                                  model = "within",
                                  effect = "twoways",
                                  method = "bprobit")

mod[['CEO Duality - No']] <- plm(turnover ~ shopping+duality+bd_size+size+leverage+roa+loss+mkt_adj_ret+btm+ins_own_t+analyst_coverage+exchange,
                                 data = duality0,
                                 index = c("fyear", "ff12"),
                                 model = "within",
                                 effect = "twoways",
                                 method = "bprobit")
# Summarize
modelsummary(mod, stars = TRUE, output = 'latex')




# Visualize data 1
library(ggplot2)
theme_set(theme_bw())  

# Data Prep
raw_sample$`Industry` <- raw_sample$ff12
raw_sample$shopping_z <- round((raw_sample$shopping - mean(raw_sample$shopping))/sd(raw_sample$shopping), 2)  # compute normalized mpg
raw_sample$`Incentive`<- raw_sample$shopping_z
raw_sample$shopping_type <- ifelse(raw_sample$shopping_z < 0, "below", "above")  # above / below avg flag
raw_sample <- raw_sample[order(raw_sample$shopping_z), ]  # sort

# Diverging Barcharts
my_plot1 <- ggplot(raw_sample, aes(x=`Industry`, y=`Incentive`, label=shopping_z)) + 
  geom_bar(stat='identity', aes(fill=shopping_type), width=.5)  +
  scale_fill_manual(name="Turnover Incentive", 
                    labels = c("Above Average", "Below Average"), 
                    values = c("above"="#00ba38", "below"="#f8766d")) + 
  labs(subtitle="Normalised Conditional Probabilites", 
       title= "Audit Committee Turnover Incentive") + 
  coord_flip()

ggsave("figure1.png", my_plot1, width = 6, height = 4, dpi = 300)





# Visualize data 2
library(scales)
theme_set(theme_classic())
year_shopping <- aggregate(raw_sample$shopping, by=list(raw_sample$ff12), FUN=mean)
colnames(year_shopping ) <- c("Year", "Incentive")
# Plot
my_plot2 <- ggplot(year_shopping, aes(x=Year, y=Incentive)) + 
  geom_point(col="tomato2", size=3) +   # Draw points
  geom_segment(aes(x=Year, 
                   xend=Year, 
                   y=min(Incentive), 
                   yend=max(Incentive)), 
               linetype="dashed", 
               size=0.1) +   # Draw dashed lines
  labs(title="Audit Committee Turnover Incentive", 
       subtitle="Year Vs Avg. Incentive") +  
  coord_flip()

ggsave("figure2.png", my_plot2, width = 6, height = 4, dpi = 300)
