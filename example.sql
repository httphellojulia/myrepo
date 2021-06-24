SHOW SERVER_ENCODING;

1. В каких городах больше одного аэропорта?

select city, count(city) from airports 
group by city 
having count(city) > 1 

2. В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета?

select airport_name from airports a, flights f  
where f.aircraft_code in (select aircraft_code from aircrafts where range = (select max(range) from aircrafts)) 
and (a.airport_code = f.departure_airport or a.airport_code = f.arrival_airport) 
group by airport_name 


3. Вывести 10 рейсов с максимальным временем задержки вылета

select flight_id, flight_no, actual_departure-scheduled_departure as delay from flights f
where actual_departure is not null 
order by actual_departure-scheduled_departure desc 
limit 10 

4. Были ли брони, по которым не были получены посадочные талоны?

select count(b.book_ref) from bookings as b 
left join tickets t on b.book_ref = t.book_ref 
left join ticket_flights tf on t.ticket_no = tf.ticket_no 
left join boarding_passes bp on tf.flight_id = bp.flight_id and tf.ticket_no = bp.ticket_no
where bp.ticket_no is null 

5. Найдите свободные места для каждого рейса, их % отношение к общему количеству мест в самолете.

select cast(f.scheduled_departure as date) as dat, f.departure_airport, f.flight_id, al.all_seat, tf.ticket_buy, al.all_seat-tf.ticket_buy as free_seat, coalesce(round((al.all_seat-tf.ticket_buy)/al.all_seat::numeric*100,2),100) as procent_free_seat, 
coalesce(sum(tf.ticket_buy) over (partition by f.departure_airport, cast(f.scheduled_departure as date) ORDER BY f.departure_airport, f.scheduled_departure RANGE UNBOUNDED PRECEDING),0) as total
from flights f
left join (select aircraft_code, count(seat_no) as all_seat from seats group by aircraft_code) as al on al.aircraft_code = f.aircraft_code
left join (select flight_id, count (ticket_no) as ticket_buy from ticket_flights tf group by flight_id) as tf on f.flight_id = tf.flight_id 
order by f.departure_airport, dat 


6. Найдите процентное соотношение перелетов по типам самолетов от общего количества.

select aircraft_code, round(count(aircraft_code)/(select count(DISTINCT flight_id)::numeric from flights)*100,2) from flights 
group by aircraft_code 


7. Были ли города, в которые можно  добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета?

with cte_economy as ( 
select tf.flight_id, a2.city, tf.fare_conditions, tf.amount  from flights f
left join ticket_flights tf on f.flight_id = tf.flight_id 
left join airports a2 on f.arrival_airport = a2.airport_code
where tf.fare_conditions = 'Economy'
group by tf.flight_id, a2.city, tf.fare_conditions, tf.amount), 
cte_business as ( 
select tf.flight_id, a2.city, tf.fare_conditions, tf.amount  from flights f
left join ticket_flights tf on f.flight_id = tf.flight_id 
left join airports a2 on f.arrival_airport = a2.airport_code
where tf.fare_conditions = 'Business'
group by tf.flight_id, a2.city, tf.fare_conditions, tf.amount) 
select cb.city from cte_economy ce, cte_business cb 
where ce.flight_id = cb.flight_id and cb.amount < ce.amount 

8. Между какими городами нет прямых рейсов?

create view no_code_flights as 
select a.airport_code as departure_airport, f.arrival_airport from airports a, flights f
group by a.airport_code, f.arrival_airport 
except select f.departure_airport, f.arrival_airport from flights f
group by f.departure_airport, f.arrival_airport 

select a.city as city_departure, a2.city as city_arrival from no_code_flights ncf 
left join airports a on ncf.departure_airport = a.airport_code 
left join airports a2 on ncf.arrival_airport  = a2.airport_code 
group by a.city, a2.city 