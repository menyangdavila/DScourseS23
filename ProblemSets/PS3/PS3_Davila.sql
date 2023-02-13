mode csv

import /home/ouecon003/DScourseS23/ProblemSets/PS3/FL_insurance_sample.csv mydata; --read in data

SELECT * FROM mydata LIMIT 10; --show first ten rows

SELECT DISTINCT county FROM mydata; --select unique values of country variable

SELECT AVG(tiv_2012 - tiv_2011) AS avg_appreciation FROM mydata; --compute the average property appreciation from 2011 to 2012

SELECT construction, COUNT(*) AS frequency FROM mydata GROUP BY construction; -- create frequency table by construction variable
 
