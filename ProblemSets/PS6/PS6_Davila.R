# Load packages
library(readxl)
library(dplyr)
library(tidyverse)
library(tidyr)
library(ggplot2)

# Set the working directory to the directory containing the script file
script_path <- normalizePath(dirname(rstudioapi::getSourceEditorContext()$path))
setwd(script_path)

# Read in excel data
iss <- read_excel("iss_director.xlsx")
head(iss)

# Clean the dataset
iss_clean <- iss %>%
  drop_na(Ticker) %>%
  filter(!is.na(New_Company_ID)) %>%
  mutate(duality = ifelse(CEO == "Yes" & Chairman == "Yes", 1, 0)) %>%
  filter(!duplicated(IRRC_Director_ID)) %>%
  mutate(independent = ifelse(Board_affiliation == "I", 1, 0),
         independent = ifelse(is.na(independent), 0, independent))  %>%
  mutate(ac_member = ifelse(!is.na(Audit_Committee_Member) & Audit_Committee_Member != "", 1, 0))

# Create plot 1 - board size
plotdata1 <- aggregate(IRRC_Director_ID ~ New_Company_ID + Data_Year, iss, length)

plot1 <- ggplot(plotdata1, aes(x = Data_Year, y = IRRC_Director_ID, color = factor(Data_Year))) +
  geom_point() +
  stat_summary(aes(y = IRRC_Director_ID, group = 1), fun = mean, geom = "line", size = 1, color = "red") +
  labs(x = "Year", y = "Board Size",
       title = "Distribution of Board Size",
       subtitle = "Data Source: ISS") +
  scale_x_continuous(breaks = seq(min(plotdata1$Data_Year), max(plotdata1$Data_Year), by = 1)) +
  scale_color_discrete(name = "Year")

ggsave("PS6a_Davila.png", plot = plot1, dpi = 300)


# Create plot 2 - audit committee size
plot_data2 <- aggregate(ac_member ~ New_Company_ID, data = iss_clean, sum)

plot2 <- ggplot(plot_data2, aes(x = ac_member)) + 
  geom_histogram(binwidth = 1, color = "black", fill = "#00FF00") +
  ggtitle("Distribution of Audit Committee Size") +
  labs(subtitle = "Based on ISS Director Data") +
  xlab("Audit Committee Size") +
  ylab("Number of Firms") +
  geom_text(stat = "count", aes(label = ..count..), vjust = -0.5)

ggsave("PS6b_Davila.png", plot = plot2, dpi = 300)


# Create plot 2 - independent directors
plot_data3 <- iss_clean %>%
  group_by(New_Company_ID) %>%
  summarize(
    pct_independent = sum(independent) / n_distinct(IRRC_Director_ID),
    bin = cut(pct_independent, breaks = c(-1, 0.05, 0.25, 0.5, 0.75, 0.95, 1), labels = c("<5%", "5-25%", "25-50%", "50%-75%", "75%-95%", ">95%")))

plot3 <- ggplot(plot_data3, aes(x = "", fill = bin)) +
  geom_bar(width = 1, color = "white") +
  coord_polar(theta = "y") +
  scale_fill_manual(values = c("<5%" = "#FF7F0E", "5-25%" = "#1B9E77", "25-50%" = "#1F77B4", "50%-75%" = "#E7298A", "75%-95%" = "#D95F02", ">95%" = "#7570B3"), name = "Percentage Range") +
  labs(title = "Percentage of Independent Directors", x = NULL, y = NULL)

ggsave("PS6c_Davila.png", plot = plot3, dpi = 300)