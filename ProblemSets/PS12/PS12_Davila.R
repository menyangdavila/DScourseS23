library(modelsummary)
library(sampleSelection)

# Set the working directory to the directory containing the script file
script_path <- normalizePath(dirname(rstudioapi::getSourceEditorContext()$path))
setwd(script_path)

# Read in excel data
wages <- read.csv("wages12.csv")

# Format the college, married, and union variables as factors
wages$college<- as.factor(wages$college)
wages$married <- as.factor(wages$married)
wages$union <- as.factor(wages$union)

# Create a summary table
datasummary_skim(wages, histogram = FALSE, output = 'latex')

# Drop observations where hgc or tenure are missing
wages_drop <- wages[complete.cases(wages[,c("logwage", "hgc", "union", "college", "exper")]),]

# Create a copy of the original data frame and fill the missing with mean
wages_mean <- wages
mean_logwage <- mean(wages$logwage, na.rm = TRUE)  # Compute mean log wage
wages_mean$logwage[is.na(wages_mean$logwage)] <- mean_logwage

# Create a new variable called valid which flags non-missing log wage observations
wages$valid <- !is.na(wages$logwage)

# Recode log wage variable so that invalid observations are now equal to 0
wages$logwage[is.na(wages$logwage)] <- 0


# Estimate models
mod <- list()
mod[['Listwise deletion']] <- lm(logwage ~ hgc + union + college + exper + I(exper^2), data = wages_drop)
mod[['Fill mean']] <- lm(logwage ~ hgc + union + college + exper + I(exper^2), data = wages_mean)
mod[['Heckit']] <- selection(selection = valid ~ hgc + union + college + exper + married + kids,
                             outcome = logwage ~ hgc + union + college + exper + I(exper^2),
                             data = wages, method = "2step")

# Summarize
modelsummary(mod, stars = TRUE, step = "outcome", output = 'latex')


# estimate probit and get predicted probabilities
estim <- glm(union ~ hgc + union + college + exper + married + kids,family=binomial(link='probit'),data=wages)
print(summary(estim))
wages$predProbit <- predict(estim, newdata = wages, type = "response")
print(summary(wages$predProbit))

# Change coefficients on married and kids to equal zero
estim$coefficients["married"] <- 0
estim$coefficients["kids"] <- 0

# Compute predicted probabilities associated with new parameter values
wages$predProbit_cf <- predict(estim, newdata = wages, type = "response")
print(summary(wages$predProbit_cf))

# Compare the average of each set of predicted probabilities
mean_orig <- mean(wages$predProbit)
mean_new <- mean(wages$predProbit_cf)
diff <- mean_orig - mean_new
diff
