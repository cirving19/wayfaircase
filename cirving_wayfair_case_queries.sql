--Q1: Based on 2018 ACS 5-year census data, which 10 zip codes have the highest population?
--selects top 10 zip codes by population
select geo_id, total_pop
from `bigquery-public-data.census_bureau_acs.zip_codes_2018_5yr`
order by total_pop desc
limit 10;

--Q2: What is the typical income range and education level for each of these zip codes?
--selects top 10 zip codes by population
with top10 as (
  select *
  from `bigquery-public-data.census_bureau_acs.zip_codes_2018_5yr`
  order by total_pop desc
  limit 10
),

--turns wide data into long data with unpivot and selects the income range with the largest number of indviduals for each zip code
income_ranges as (
  select geo_id,
    array_agg(struct(income_range, count) order by count desc limit 1)[offset(0)].income_range as typical_income,
    array_agg(struct(income_range, count) order by count desc limit 1)[offset(0)].count as pop_count
  from (
    select *
    from top10
    unpivot (
      count for income_range in (
        income_less_10000,
        income_10000_14999,
        income_15000_19999,
        income_20000_24999,
        income_25000_29999,
        income_30000_34999,
        income_35000_39999,
        income_40000_44999,
        income_45000_49999,
        income_50000_59999,
        income_60000_74999,
        income_75000_99999,
        income_100000_124999,
        income_125000_149999,
        income_150000_199999,
        income_200000_or_more
    )
  )
)
  group by geo_id
),

--turns wide data into long data with unpivot and selects education level with the largest number of individuals for each zip code
education_levels as (
  select geo_id,
    array_agg(struct(education_level, count) order by count desc limit 1)[offset(0)].education_level as typical_education,
    array_agg(struct(education_level, count) order by count desc limit 1)[offset(0)].count as pop_count
  from (
    select *
    from top10
    unpivot (
      count for education_level in (
        high_school_diploma,
	associates_degree,
	bachelors_degree,
	less_one_year_college,
	masters_degree,
	one_year_more_college,
	less_than_high_school_graduate,
	high_school_including_ged,
	bachelors_degree_2,
	graduate_professional_degree,
	some_college_and_associates_degree
    )
  )
)
  group by geo_id
)

--returns zip code, typical income, and typical education for each zip code based on the above ctes
select i.geo_id, i.typical_income, e.typical_education
from income_ranges i
join education_levels e
on i.geo_id = e.geo_id;

--Q3: Of these zip codes, which had the largest change in population from the 2017 5-year data?
--joins 2018 and 2017 data and calculates the difference between the 2018 population and 2017 population for each zip code in the top ten zipcodes by population
with pop_change as (
  select n.geo_id, n.total_pop, o.total_pop, (n.total_pop - o.total_pop) as population_change
  from `bigquery-public-data.census_bureau_acs.zip_codes_2018_5yr` n
  join `bigquery-public-data.census_bureau_acs.zip_codes_2017_5yr` o
  on n.geo_id = o.geo_id
  where n.geo_id in (
    select geo_id
    from `bigquery-public-data.census_bureau_acs.zip_codes_2018_5yr`
    order by total_pop desc
    limit 10
  )
)

--returns zip code and change in population from 2017 to 2018 for the zip code with the largest difference
select geo_id, population_change
from pop_change
order by population_change desc
limit 1;

--Q4: Expanding to look across the top 200 zip codes by population for 2018, is there any correlation between total population and typical education level?
--selects top 200 zip codes by population
with top200 as (
  select *
  from `bigquery-public-data.census_bureau_acs.zip_codes_2018_5yr`
  order by total_pop desc
  limit 200
),

--turns wide data into long data with unpivot and selects education level with the largest number of individuals for each zip code
education_levels as (
  select geo_id,
    array_agg(struct(education_level, count) order by count desc limit 1)[offset(0)].education_level as typical_education,
    array_agg(struct(education_level, count) order by count desc limit 1)[offset(0)].count as pop_count
  from (
    select *
    from top200
    unpivot (
      count for education_level in (
        high_school_diploma,
	associates_degree,
	bachelors_degree,
	less_one_year_college,
	masters_degree,
	one_year_more_college,
	less_than_high_school_graduate,
	high_school_including_ged,
	bachelors_degree_2,
	graduate_professional_degree,
	some_college_and_associates_degree
    )
  )
)
group by geo_id
),

--assigns a numerical score to each existing education level increasing in value from lowest to highest
education_numeric as (
  select t.geo_id, t.total_pop, e.typical_education,
    case e.typical_education
    when 'less_than_high_school_graduate' then 1
    when 'high_school_including_ged' then 2
    when 'high_school_diploma' then 3
    when 'less_one_year_college' then 4
    when 'one_year_more_college' then 5
    when 'some_college_and_associates_degree' then 6
    when 'associates_degree' then 7
    when 'bachelors_degree' then 8
    when 'bachelors_degree_2' then 8 --also has a score of 8 because bachelors_degree and bachelors_degree_2 would be the same level of education
    when 'masters_degree' then 9
    when 'graduate_professional_degree' then 10
    else null
    end as education_score
  from top200 t
  left join education_levels e
  on t.geo_id = e.geo_id 
)

--utilizes the total population and numerical education score to calculate and return the correlation between the variables and the percent of variance in education score explained by total population
select corr(total_pop,education_score) as correlation, pow(corr(total_pop,education_score),2) as variance_explained
from education_numeric;
