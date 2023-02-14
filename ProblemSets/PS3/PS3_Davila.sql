CREATE TABLE florida_insurance (
    policyID INT,
    statecode TEXT,
    county TEXT,
    eq_site_limit REAL,
    hu_site_limit REAL,
    fl_site_limit REAL,
    fr_site_limit REAL,
    tiv_2011 REAL,
    tiv_2012 REAL,
    eq_site_deductible REAL,
    hu_site_deductible REAL,
    fl_site_deductible REAL,
    fr_site_deductible REAL,
    point_latitude REAL,
    point_longitude REAL,
    line TEXT,
    construction TEXT,
    point_granularity INT
);

.mode csv
.import /home/ouecon003/DScourseS23/ProblemSets/PS3/FL_insurance_sample.csv florida_insurance

SELECT * FROM florida_insurance LIMIT 10;

SELECT DISTINCT county FROM florida_insurance;

SELECT AVG(tiv_2012 - tiv_2011) AS avg_appreciation FROM florida_insurance;

SELECT construction, COUNT(*) AS frequency FROM florida_insurance GROUP BY construction; 
