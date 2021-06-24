SHOW SERVER_ENCODING;

1. В каких городах больше одного аэропорта?

select city, count(city) from airports -- Выводим города, в которых есть аэропорты и считаем количество городов (по сути кол-во аэропортов)
group by city  -- Группируем по городу
having count(city) > 1 --Прописываем условие, где выводим только те города, которые повторяются более 1 раза

2. В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета?

select airport_name from airports a, flights f  -- Выводим название аэропорта используя таблицы аэропорты и рейсы
where f.aircraft_code in (select aircraft_code from aircrafts where range = (select max(range) from aircrafts)) -- Выбираем рейсы того самолета, код которого совпадает с кодом самолета имеющего максимальную дальность перелета
and (a.airport_code = f.departure_airport or a.airport_code = f.arrival_airport) -- И делаем связку, где искомый код аэропорта совпадает с кодом аэропортов вылета или прилета в рейсах
group by airport_name -- Группируем по названию аэропорта, чтобы избежать дублирования


3. Вывести 10 рейсов с максимальным временем задержки вылета

select flight_id, flight_no, actual_departure-scheduled_departure as delay from flights f -- Выводим идентификатор рейса, номер рейса и задержку на рейсе из таблицы рейсов
where actual_departure is not null -- Учитываем условие, что фактическое время отправления не равно нулю
order by actual_departure-scheduled_departure desc -- Сортируем по времени задержи от большего к меньшему. Задержку рассчитываем вычитая фактическое время отправления из планового 
limit 10 -- Устанавливаем лимит на вывод 10 строк

4. Были ли брони, по которым не были получены посадочные талоны?

/* select b.book_ref, t.book_ref, t.ticket_no, bp.boarding_no, tf.ticket_no, tf.flight_id, bp.ticket_no, bp.flight_id from bookings b */

select count(b.book_ref) from bookings as b -- Считаем сколько броней в таблице без посадочного талона
left join tickets t on b.book_ref = t.book_ref -- По идентификатору присоединяем таблицу билетов
left join ticket_flights tf on t.ticket_no = tf.ticket_no -- По идентификатору присоединяем таблицу перелетов
left join boarding_passes bp on tf.flight_id = bp.flight_id and tf.ticket_no = bp.ticket_no -- По двум идентификаторам (у посадочных составной уникальный идентификатор по номеру рейса и номеру билета) присоединяем таблицу с посадочными талонами 
where bp.ticket_no is null -- Пишем условие, что выводим только те данные, в которых отсутствуют данные по номеру билета (или можно было указать отсутствуют по номеру рейса) 

5. Найдите свободные места для каждого рейса, их % отношение к общему количеству мест в самолете.
Добавьте столбец с накопительным итогом - суммарное накопление количества вывезенных пассажиров из каждого аэропорта на каждый день. Т.е. в этом столбце должна отражаться накопительная сумма - сколько человек уже вылетело из данного аэропорта на этом или более ранних рейсах за день.
- Оконная функция
- Подзапросы

select cast(f.scheduled_departure as date) as dat, f.departure_airport, f.flight_id, al.all_seat, tf.ticket_buy, al.all_seat-tf.ticket_buy as free_seat, coalesce(round((al.all_seat-tf.ticket_buy)/al.all_seat::numeric*100,2),100) as procent_free_seat, 
coalesce(sum(tf.ticket_buy) over (partition by f.departure_airport, cast(f.scheduled_departure as date) ORDER BY f.departure_airport, f.scheduled_departure RANGE UNBOUNDED PRECEDING),0) as total
from flights f -- Выводим таблицу из имеющихся рейсов с сортировкой по датам (без времени) и аэропорту. Выводим все имеющиеся места в самолете, сколько тикетов куплено на рейсе и данные по свободным местам (вычитаем из всех мест количество купленных билетов). В procent_free_seat считаем процентное соотноешние свободных мест к общему числу мест с округлением до 2 цифр после запятой. Так как есть рейсы, где еще не было продаж билетом (и данные там NULL) с помощью coalesce подменяем null на 100%, так как на таких рейсов свободно 100% билетов. Группируем и считаем накопительный итог по дате и аэропорту 
left join (select aircraft_code, count(seat_no) as all_seat from seats group by aircraft_code) as al on al.aircraft_code = f.aircraft_code -- Присоединяем данные по тому, сколько мест содержится в каждом самолете
left join (select flight_id, count (ticket_no) as ticket_buy from ticket_flights tf group by flight_id) as tf on f.flight_id = tf.flight_id -- Присоединяем данные по тому, сколько купленных билетов (считаем кол-во тикетов)
order by f.departure_airport, dat -- Группируем


6. Найдите процентное соотношение перелетов по типам самолетов от общего количества.
- Подзапрос 
- Оператор ROUND

select aircraft_code, round(count(aircraft_code)/(select count(DISTINCT flight_id)::numeric from flights)*100,2) from flights --Выводим номер самолета и процентное отношение, которое расчитываем как общее кол-во рейсов деленное на количество рейсов каждого самолета с округлением до двух знаков
group by aircraft_code --Группируем результаты по номеру самолета


7. Были ли города, в которые можно  добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета?
- CTE

with cte_economy as ( -- Собираем таблицу которая формируется из данных по номеру городу и стоимости билета для эконом-класса
select tf.flight_id, a2.city, tf.fare_conditions, tf.amount  from flights f
left join ticket_flights tf on f.flight_id = tf.flight_id 
left join airports a2 on f.arrival_airport = a2.airport_code
where tf.fare_conditions = 'Economy'
group by tf.flight_id, a2.city, tf.fare_conditions, tf.amount), -- Группируем данные
cte_business as ( -- Собираем таблицу которая формируется из данных по городу и стоимости билета для бизнес-класса
select tf.flight_id, a2.city, tf.fare_conditions, tf.amount  from flights f
left join ticket_flights tf on f.flight_id = tf.flight_id 
left join airports a2 on f.arrival_airport = a2.airport_code
where tf.fare_conditions = 'Business'
group by tf.flight_id, a2.city, tf.fare_conditions, tf.amount) -- Группируем данные
select cb.city from cte_economy ce, cte_business cb -- Выводим список городов (Таких городов нет)
where ce.flight_id = cb.flight_id and cb.amount < ce.amount -- Пишем условие, что код перелета в экономе должен совпадать с кодом перелета в бизнесе и цена в бизнесе меньше цены эконома

8. Между какими городами нет прямых рейсов?
- Декартово произведение в предложении FROM
- Самостоятельно созданные представления
- Оператор except

create view no_code_flights as -- создаем представление, которое содержит между какими аэропортами нет прямых рейсов
select a.airport_code as departure_airport, f.arrival_airport from airports a, flights f  -- выводим список кодов аэропортов отправления и прибытия 
group by a.airport_code, f.arrival_airport -- 104 код аэропорта, 10816 комбинаций аэропортов
except select f.departure_airport, f.arrival_airport from flights f -- исключаем из всех комбинаций те комбинации, где есть прямые рейсы из аэропорта в другой аэропорт. 
group by f.departure_airport, f.arrival_airport -- Группируем и получаем 618 комбинаций 

select a.city as city_departure, a2.city as city_arrival from no_code_flights ncf -- выводим данные из представления
left join airports a on ncf.departure_airport = a.airport_code -- сопоставляем код аэропорта отправлений с названиемгорода
left join airports a2 on ncf.arrival_airport  = a2.airport_code -- сопоставляем код аэропорта прибытия с названием города
group by a.city, a2.city -- Группируем, чтобы получить уникальные значения. Между 9 837 городами нет прямых рейсов



select *, row_number() over (partition by customer_id order by rental_date) as rent_number from rental 

create materialized view bts_film as 
explain analyze
select r.rental_id, r.customer_id,i.inventory_id, f.film_id, f.title, f.special_features from rental r
left join inventory i on r.inventory_id = i.inventory_id
left join film f on f.film_id = i.film_id 
where f.special_features::text like '%Behind the Scenes%'
--where f.special_features = '{Behind the Scenes}' 
--where f.special_features in ('{Behind the Scenes}');
with no data


refresh materialized view bts_film 

--explain analyze
select customer_id, count(film_id) as count_film from bts_film
group by customer_id
order by customer_id 

explain analyze
select count(f.film_id) as count_film from rental r
join inventory i on r.inventory_id = i.inventory_id
join film f on f.film_id = i.film_id 
where f.special_features::text like '%Behind the Scenes%'


select r.customer_id, count(f.film_id) as count_film from film f
left join inventory i on f.film_id = i.film_id 
right join rental r on r.inventory_id = i.inventory_id
where f.special_features::text like '%Behind the Scenes%'
group by customer_id

select distinct cu.first_name  || ' ' || cu.last_name as name, 
	count(ren.iid) over (partition by cu.customer_id)
from customer cu
full outer join 
	(select *, r.inventory_id as iid, inv.sf_string as sfs, r.customer_id as cid
	from rental r 
	full outer join 
		(select *, unnest(f.special_features) as sf_string
		from inventory i
		full outer join film f on f.film_id = i.film_id) as inv 
		on r.inventory_id = inv.inventory_id) as ren 
	on ren.cid = cu.customer_id 
where ren.sfs like '%Behind the Scenes%'
order by count desc