# Load required libraries
library(jsonlite)
library(tidyverse)

# Download historical events data in JSON format
system('wget -O dates.json "https://www.vizgr.org/historical-events/search.php?format=json&begin_date=00000101&end_date=20230209&lang=en"')


# Print the file to console
system('cat dates.json')

# Load the JSON data into a data frame
mylist <- fromJSON('dates.json')
mydf <- bind_rows(mylist$result[-1])

# Check the type
class(mydf)
class(mydf$date)

# List first 10 rows
head(mydf, n = 10)
