/*
Business Request-1 City Level Fare and Trip Summary Report
Generate a report that displays the total trips, average fare per km, average fare per trip, and
the percentage contribution of each city's trips to the overall trips. This report will help in
assessing trip volume, pricing efficiency, and each city's contribution to the overall trip count.

Fields:

· city_name
· total_trips
· avg_fare_per_km
· avg_fare_per_trip
· %_contribution_to_total_trips

*/
select city_name, 
	count(trip_id) as total_trips,
    round(sum(fare_amount)/sum(distance_travelled_km),2) as avg_fare_per_km,
    round(sum(fare_amount)/count(trip_id),2) as avg_fare_per_trip,
    round(count(trip_id)*100/(select count(*) from trips_db.fact_trips),2) as pct_contribution_to_total_trips
from trips_db.dim_city as c
join trips_db.fact_trips as ft
	on c.city_id = ft.city_id
group by city_name;

-- ------------------------------------------------------------------------------------------------------------------
/*
Business Report-2 Monthly City-Level Trips Target Performance Report
Generate a report that evaluates the target performance for trips at the monthly and city
level. For each city and month, compare the actual total trips with the target trips and
categorise the performance as follows:

. If actual trips are greater than target trips, mark it as "Above Target".
. If actual trips are less than or equal to target trips, mark it as "Below Target".

Additionally, calculate the % difference between actual and target trips to quantify the
performance gap.

Fields:

· City_name
. month_name
· actual_trips
· target_trips
· performance_status
· %_difference

*/
create TEMPORARY TABLE city_actual_performance
select 
	c.city_id, 
	c.city_name, 
    date_format(ft.date,"%M") as month_name, 
    count(trip_id) as actual_trips
from dim_city as c
join fact_trips as ft
	on c.city_id = ft.city_id
group by 1,2,3;

select city_name, month_name, actual_trips, total_target_trips as target_trips,
case
	when actual_trips>total_target_trips then "Above Target"
    else "Below Target"
end as performance_status,
round((actual_trips-total_target_trips)*100/total_target_trips,2) as pct_difference
from city_actual_performance as cap
join targets_db.monthly_target_trips as mtt
on cap.city_id = mtt.city_id and cap.month_name = date_format(mtt.month, "%M");
   
-- --------------------------------------------------------------------------------------------------------------------
/*
Business Request-3 City-Level Repeat Passanger Trip Frequency Report
Generate a report that shows the percentage distribution of repeat passengers by the
number of trips they have taken in each city. Calculate the percentage of repeat passengers
who took 2 trips, 3 trips, and so on, up to 10 trips.

Each column should represent a trip count category, displaying the percentage of repeat
passengers who fall into that category out of the total repeat passengers for that city.

This report will help identify cities with high repeat trip frequency, which can indicate strong
customer loyalty or frequent usage patterns.

· Fields: city_name, 2-Trips, 3-Trips, 4-Trips, 5-Trips, 6-Trips, 7-Trips, 8-Trips, 9-Trips,
10-Trips

*/

SELECT 
    city_name,
    SUM(CASE WHEN trip_count = "2-Trips" THEN pct_of_repeat_passenger ELSE 0 END) AS Trips_2,
    SUM(CASE WHEN trip_count = "3-Trips" THEN pct_of_repeat_passenger ELSE 0 END) AS Trips_3,
    SUM(CASE WHEN trip_count = "4-Trips" THEN pct_of_repeat_passenger ELSE 0 END) AS Trips_4,
    SUM(CASE WHEN trip_count = "5-Trips" THEN pct_of_repeat_passenger ELSE 0 END) AS Trips_5,
    SUM(CASE WHEN trip_count = "6-Trips" THEN pct_of_repeat_passenger ELSE 0 END) AS Trips_6,
    SUM(CASE WHEN trip_count = "7-Trips" THEN pct_of_repeat_passenger ELSE 0 END) AS Trips_7,
    SUM(CASE WHEN trip_count = "8-Trips" THEN pct_of_repeat_passenger ELSE 0 END) AS Trips_8,
    SUM(CASE WHEN trip_count = "9-Trips" THEN pct_of_repeat_passenger ELSE 0 END) AS Trips_9,
    SUM(CASE WHEN trip_count = "10-Trips" THEN pct_of_repeat_passenger ELSE 0 END) AS Trips_10
FROM (
    SELECT 
        city_name, 
        trip_count, 
        repeat_passenger_count,
        ROUND(repeat_passenger_count * 100 / SUM(repeat_passenger_count) OVER(PARTITION BY city_name), 2) AS pct_of_repeat_passenger
    FROM (
        SELECT 
            city_name, 
            trip_count, 
            SUM(repeat_passenger_count) AS repeat_passenger_count
        FROM 
            dim_city AS c
        JOIN 
            dim_repeat_trip_distribution AS rtd
        ON 
            c.city_id = rtd.city_id
        GROUP BY 
            city_name, trip_count
    ) AS counting_repeat_passengers
) AS table2
GROUP BY 
    city_name;
-- -------------------------------------------------------------------------------------------------------------------
/*
Business Request-4 Indentify Cities with Highest and Lowest Total New Passengers
Generate a report that calculates the total new passengers for each city and ranks them
based on this value. Identify the top 3 cities with the highest number of new passengers as
well as the bottom 3 cities with the lowest number of new passengers, categorising them as
"Top 3" or "Bottom 3" accordingly.

Fields

· city_name
· total_new_passengers
. city_category ("Top 3" or "Bottom 3")

*/

with ranked_cities as
(SELECT
	city_name, 
    count(trip_id) as total_new_passengers,
    DENSE_RANK() OVER (ORDER BY count(trip_id) DESC) AS drd,
	DENSE_RANK() OVER (ORDER BY count(trip_id) ASC) AS dra 
from dim_city as c
join fact_trips as ft
	on c.city_id = ft.city_id
where passenger_type = "new"
group by city_name)
SELECT 
        city_name,
        total_new_passengers,
        CASE
            WHEN drd <= 3 THEN "Top 3"
            WHEN dra <= 3 THEN "Bottom 3"
        END AS city_category
    FROM ranked_cities
WHERE drd<=3 or dra<=3
ORDER BY total_new_passengers DESC;

-- ------------------------------------------------------------------------------------------------------------------
/*
Business Request-5 Identify Month with Highest Revenue for each city
Generate a report that identifies the month with the highest revenue for each city. For each
city, display the month_name, the revenue amount for that month, and the percentage
contribution of that month's revenue to the city's total revenue.

Fields

· city_name
. highest_revenue_month
. revenue
· percentage_contribution (%)

*/

select
	city_name, 
    month_name as highest_revenue_month, 
    revenue,
    percentage_contribution
from
(select 
	city_name, 
    month_name, 
    revenue, 
    -- sum(revenue) over(partition by city_name) as total_revenue,
    round(revenue*100/sum(revenue) over(partition by city_name),2) as percentage_contribution,
    DENSE_RANK() over(PARTITION BY city_name order by revenue desc) as dr
from
(select 
	city_name,
    date_format(date, "%M") as month_name,
    sum(fare_amount) as revenue
from dim_city as c
join fact_trips as ft
	on c.city_id = ft.city_id
group by 1,2) as table1) as table2
where dr=1;

-- ---------------------------------------------------------------------------------------------------------------------
/*
Business Request-6 Repeat Passenger Rate Analysi
Generate a report that calculates two metrics:

1. Monthly Repeat Passenger Rate: Calculate the repeat passenger rate for each city
and month by comparing the number of repeat passengers to the total passengers.
2. City-wide Repeat Passenger Rate: Calculate the overall repeat passenger rate for
each city, considering all passengers across months.

These metrics will provide insights into monthly repeat trends as well as the overall repeat
behaviour for each city.

Fields:

· city_name
month
total passengers
repeat_passengers
. monthly_repeat_passenger_rate (%): Repeat passenger rate at the city and
month level
· city_repeat_passenger_rate (%): Overall repeat passenger rate for each city,
aggregated across months
*/
select 
	city_name,
    date_format(month, "%M") as month,
    total_passengers,
    repeat_passengers,
    round(repeat_passengers*100/total_passengers,2) as monthly_repeat_passenger_rate,
    -- round(repeat_passengers*100/sum(repeat_passengers) over(partition by city_name),2) as pct_share_in_overall_repeat_passengers,
    -- round(repeat_passengers*100/sum(total_passengers) over(partition by city_name),2) as pct_share_of_monthly_repeat_passengers_wrt_overall_passengers_throughout,
    round(sum(repeat_passengers) over(partition by city_name)*100/sum(total_passengers) over(partition by city_name),2) as city_repeat_passenger_rate
from dim_city as c
join fact_passenger_summary as fps
	on c.city_id = fps.city_id;
    
    
