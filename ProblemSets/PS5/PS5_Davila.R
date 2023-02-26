library(tidyverse)
library(rvest)
library(jsonlite)
library(httr)

# list of female CEOs
url <- 'https://en.wikipedia.org/wiki/List_of_women_CEOs_of_Fortune_500_companies'
html_path <- '#mw-content-text > div.mw-parser-output > table'
df <- read_html(url) %>% html_nodes(html_path) %>% html_table() %>% '[['(1)

write.csv(df, "female_ceo.csv", row.names = FALSE)


# CVS income statement from 1985 to 2022
cvs_income_statement <- 
  fromJSON("https://financialmodelingprep.com/api/v3/income-statement/CVS?limit=120&apikey=d0d7223e4f0b0869108913dc744cb728") %>%
  as_tibble()
cvs_income_statement

cvs_income_statement %>% 
  select(calendarYear, revenue) %>% 
  ggplot(aes(x=calendarYear, y=revenue)) + 
  geom_point(alpha=0.5) +
  labs(
    x = "Calendar Year", y = "Revenue",
    title = "CVS Revenues by Year",
    caption = "Source: Financial Modeling Prep"
  )