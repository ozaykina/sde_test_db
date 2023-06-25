drop table if exists results
;

create table results (
 id integer, 
 response text
)
;


-- 1.	Вывести максимальное количество человек в одном бронировании
insert into results
select 1 as id, count(passenger_id) as response 
from bookings.tickets 
group by book_ref order by response desc 
limit 1
;

-- 2.	Вывести количество бронирований с количеством людей больше среднего значения людей на одно бронирование
with cte1 as 
		(select distinct book_ref, count(passenger_id) over(partition by book_ref) as passengers_cnt 
		from bookings.tickets  
		),
cte2 as
		(
		select book_ref, passengers_cnt, avg(passengers_cnt) over () as avg_passengers_cnt 
		from cte1  
		)							
insert into results
select 2 as id, count(*) as response 
from cte2 
where passengers_cnt > avg_passengers_cnt 
;

-- 3.	Вывести количество бронирований, у которых состав пассажиров повторялся два и более раза, среди бронирований с максимальным количеством людей (п.1)?
with cte as (
	select book_ref, count(passenger_id) as lim_pass
	from bookings.tickets group by book_ref order by lim_pass desc limit 1
	),
t1 as (
	select t.book_ref, t.passenger_id, count(t.passenger_id) over(partition by t.book_ref) as passengers_cnt, cte.lim_pass 
	from bookings.tickets t join cte on t.book_ref=cte.book_ref),
t2 as (
	select t.book_ref, t.passenger_id, count(t.passenger_id) over(partition by t.book_ref) as passengers_cnt, cte.lim_pass  
	from bookings.tickets t join cte on t.book_ref=cte.book_ref)
insert into results
select 3 as id, count(t1.book_ref) as response
from t1 join t2 on t1.passenger_id = t2.passenger_id 
where t1.book_ref != t2.book_ref and t1.passengers_cnt = t1.lim_pass and t1.passengers_cnt = t1.lim_pass
;
  
-- 4.	Вывести номера брони и контактную информацию по пассажирам в брони (passenger_id, passenger_name, contact_data) с количеством людей в брони = 3
with cte as (
		select book_ref
		from bookings.tickets 
		group by book_ref
		having count(distinct passenger_id) = 3
	),
cte2 as (
	select t.book_ref,
		string_agg((' passenger id ' || t.passenger_id || ' name ' || t.passenger_name || ' data ' || t.contact_data), ', ') as allpass
	from bookings.tickets t
	where t.book_ref in (select book_ref from cte)	
	group by t.book_ref
) 
insert into results
select 4 as id, cte2.book_ref || cte2.allpass as response
from cte2
;
	
-- 5.	Вывести максимальное количество перелётов на бронь
insert into results
select 5 as id, count(distinct f.flight_id) as response 
from bookings.tickets t join bookings.ticket_flights f on t.ticket_no = f.ticket_no 
group by t.book_ref
order by 2 desc
limit 1
; 

-- 6.	Вывести максимальное количество перелётов на пассажира в одной брони
insert into results
select 6 as id, count(f.flight_id ) 
from bookings.tickets t 
	join bookings.ticket_flights f on t.ticket_no = f.ticket_no join flights fl on fl.flight_id = f.flight_id
group by t.book_ref, t.passenger_id 
order by 2 desc
limit 1
; 

-- 7.	Вывести максимальное количество перелётов на пассажира
insert into results
select 7 as id, count(f.flight_id ) 
from bookings.tickets t 
	join bookings.ticket_flights f on t.ticket_no = f.ticket_no  
group by t.passenger_id 
order by 2 desc
limit 1
; 

-- 8.	Вывести контактную информацию по пассажиру(ам) (passenger_id, passenger_name, contact_data) и общие траты на билеты, для пассажира потратившему минимальное количество денег на перелеты
with cte as ( 
	select
		t.passenger_id,
		t.passenger_name,
		t.contact_data,
		sum(tf.amount) as summ,
		min(sum(tf.amount)) over() as min_summ
	from bookings.tickets t join bookings.ticket_flights tf on tf.ticket_no = t.ticket_no
	group by t.passenger_id, t.passenger_name, t.contact_data 
)	
insert into results
select 8 as id, concat(passenger_id || '|' || passenger_name || '|' || contact_data || '|' || summ) as response
from cte
where summ = min_summ
;

-- 9.	Вывести контактную информацию по пассажиру(ам) (passenger_id, passenger_name, contact_data) и общее время в полётах, для пассажира, который провёл максимальное время в полётах
with cte as(
	select
		t.passenger_id,
		t.passenger_name,
		t.contact_data,
		sum(f.actual_duration) as sumd,
		max(sum(f.actual_duration)) over() as maxsumd
	from bookings.tickets t
		join bookings.ticket_flights tf on t.ticket_no = tf.ticket_no
		join bookings.flights_v f on tf.flight_id = f.flight_id
	where f.status = 'Arrived'
	group by t.passenger_id, t.passenger_name, t.contact_data	
	)
insert into results
select 9 as id, passenger_id || '|' ||passenger_name || '|' || contact_data || '|' || sumd as response
from cte
where sumd = maxsumd
;

-- 10.	Вывести город(а) с количеством аэропортов больше одного
insert into results
select 10 as id, city 
from bookings.airports
group by city
having count(airport_code) > 1
order by city
;

-- 11.	Вывести город(а), у которого самое меньшее количество городов прямого сообщения
with cte as (
	select departure_city, count(distinct arrival_city) as cnt, min(count(distinct arrival_city)) over() as min_cnt
	from bookings.routes
	group by departure_city
)
insert into results
select 11 as id, departure_city
from cte
where cnt = min_cnt
;
 
-- 12.	Вывести пары городов, у которых нет прямых сообщений исключив реверсные дубликаты
insert into results
select 12 as id, city1||'|'||city2 
from 
(
	select ad1.city as city1, ad2.city as city2
		from bookings.airports ad1 join bookings.airports ad2 on ad1.city < ad2.city
	except
	select distinct departure_city, arrival_city from
	(
	select departure_city, arrival_city from routes
	union all
	select arrival_city, departure_city from routes
	) t2
) t1
;

-- 13.	Вывести города, до которых нельзя добраться без пересадок из Москвы?
insert into results
select distinct 13 as id, departure_city as response
from bookings.routes r
where departure_city not in (select arrival_city from routes where departure_city = 'Москва')
	and departure_city != 'Москва'
;

-- 14.	Вывести модель самолета, который выполнил больше всего рейсов
insert into results
select 14 as id, a.model 
from bookings.flights_v f
	join bookings.aircrafts a on f.aircraft_code = a.aircraft_code 
group by f.aircraft_code, a.model
order by count(flight_id) desc
limit 1
;

-- 15.	Вывести модель самолета, который перевез больше всего пассажиров
with cte as 
(
	select
		a.model,
		count(bp.boarding_no) as cnt,
		max(count(bp.boarding_no)) over() as max_cnt
	from bookings.aircrafts a
		join bookings.flights f on a.aircraft_code = f.aircraft_code
		join bookings.boarding_passes bp on f.flight_id = bp.flight_id
	where f.status = 'Arrived'
	group by a.model
) 
insert into results
select 15 as id, model as response
from cte
where cnt = max_cnt
;

-- 16.	Вывести отклонение в минутах суммы запланированного времени перелета от фактического по всем перелётам
insert into results
select 16, EXTRACT(EPOCH FROM sum(actual_duration)-sum(scheduled_duration))/60 as diff
from  bookings.flights_v f
where actual_duration is not null
;

-- 17.	Вывести города, в которые осуществлялся перелёт из Санкт-Петербурга 11 августа 2017
insert into results
select distinct	17 as id, arrival_city as responce
from bookings.flights_v
where departure_city = 'Санкт-Петербург'
and status = 'Arrived'
and date(actual_departure) = '2017-08-11'
;

-- 18.	Вывести перелёт(ы) с максимальной стоимостью всех билетов
with cte as (
	select
		f.flight_id,
		sum(tf.amount) as sum_amount,
		max(sum(tf.amount)) over() as max_sum_amount
	from bookings.flights f
	inner join ticket_flights tf on f.flight_id = tf.flight_id
	group by f.flight_id
)
insert into results
select 18 id, flight_id 
from cte
where sum_amount = max_sum_amount 
;

-- 19.	Выбрать дни в которых было осуществлено минимальное количество перелётов
with cte as 
 (
	select
		date(actual_departure) as act_dep,
		count(*) as cnt,
		min(count(*)) over() as min_cnt
	from bookings.flights 
	where status = 'Departed' or status = 'Arrived'
	group by date(actual_departure)
	order by date(actual_departure)
)  
insert into results
select 19 as id, act_dep
from cte
where cnt = min_cnt
;

-- 20.	Вывести среднее количество вылетов в день из Москвы за 11 августа 2017 года
with cte as(
	select to_char(coalesce(actual_departure_local , scheduled_departure_local), 'YYYY-MM-dd') as dt, count(flight_id) as cnt 
	from bookings.flights_v f
	where to_char(coalesce(actual_departure_local , scheduled_departure_local), 'YYYY-MM-dd') = '2017-08-11'
		and departure_city = 'Москва'
		and status in ('Departed','Arrived')
	group by to_char(coalesce(actual_departure_local , scheduled_departure_local), 'YYYY-MM-dd')
)
insert into results
select 20, avg(cnt) from cte
;

-- 21.	Вывести топ 5 городов у которых среднее время перелета до пункта назначения больше 3 часов
insert into results
select 21, departure_city
from  bookings.routes 
group by departure_city
having EXTRACT(EPOCH FROM avg(duration))/3600 > 3
order by avg(duration) desc
limit 5
;
