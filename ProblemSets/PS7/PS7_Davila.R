library(mice)
library(modelsummary)
library(dplyr)

# Set the working directory to the directory containing the script file
script_path <- normalizePath(dirname(rstudioapi::getSourceEditorContext()$path))
setwd(script_path)

# Load wages.csv as a data frame
wages <- read_csv("wages.csv")

# Drop observations where hgc or tenure are missing
wages <- wages[complete.cases(wages[,c("hgc", "tenure")]),]

# Produce a summary table
datasummary_skim(wages, histogram = FALSE)


# Create a copy of the original data frame and fill the missing with mean
wages_mean <- wages
mean_logwage <- mean(wages$logwage, na.rm = TRUE)  # Compute mean log wage
wages_mean$logwage[is.na(wages_mean$logwage)] <- mean_logwage


# Create a copy of the original data frame and fill the missing with predicted value
wages_predicted <- wages
model <- lm(logwage ~ hgc + college + tenure + I(tenure^2) + age + married, data = wages)
wages_predicted$logwage[!complete.cases(wages_predicted)] <- predict(model, wages_predicted[!complete.cases(wages_predicted),])


# Create a data frame and fill the missing using mice
wages_mice <- mice(wages, m = 5, printFlag = FALSE)


# Estimate models
mod <- list()
mod[['Listwise deletion']] <- lm(logwage ~ hgc + college + tenure + I(tenure^2) + age + married, data = wages)
mod[['Fill mean']] <- lm(logwage ~ hgc + college + tenure + I(tenure^2) + age + married, data = wages_mean)
mod[['Fill predicted']] <- lm(logwage ~ hgc + college + tenure + I(tenure^2) + age + married, data = wages_predicted)
mod[['Mice']] <- with(wages_mice, lm(logwage ~ hgc + college + tenure + I(tenure^2) + age + married))

# Pool results
mod[['Mice']] <- mice::pool(mod[['Mice']])

# Summarize
modelsummary(mod, stars = TRUE)
