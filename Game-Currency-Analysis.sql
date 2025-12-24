/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор:Галыгин Дмитрий 
 * Дата:01.10.2025
*/



-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),group_city_days AS (
SELECT
   fi.id,
   CASE 
   	 WHEN c.city = 'Санкт-Петербург' THEN 'Санкт_Петербург'
   	 ELSE 'ЛенОбл'
     END AS region,
   CASE 
   	 WHEN a.days_exposition >= '1' AND a.days_exposition <= '31' THEN 'до месяца'
   	 WHEN a.days_exposition >= '31' AND a.days_exposition <= '90' THEN 'до трех месяцаев'
   	 WHEN a.days_exposition >= '91' AND a.days_exposition <= '180' THEN 'полугода'
   	 WHEN a.days_exposition >= '181' THEN 'более полугода'
     ELSE 'активные объявелния'
     END AS activity_period,
     a.last_price,
     f.total_area,
     a.last_price/f.total_area AS metr_price,
     f.rooms,
     f.balcony
FROM real_estate.city AS c
LEFT JOIN real_estate.flats AS f USING(city_id)
RIGHT JOIN real_estate.advertisement AS a USING(id)
RIGHT JOIN real_estate.TYPE AS t USING(type_id)
INNER JOIN filtered_id AS fi ON fi.id=f.id
WHERE t.TYPE = 'город'
AND a.first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'
)
SELECT 
    region,
    activity_period,
    COUNT(id) AS total_advertisement,
    ROUND(COUNT(*)/(SUM(COUNT(*)) OVER(PARTITION BY region)) :: NUMERIC, 2) *100 AS perc_advertisement,
	ROUND(AVG(last_price) :: NUMERIC, 2) AS avg_flat_price,
	MAX(last_price) AS max_flat_price,
	MIN(last_price) AS min_flat_price,
	ROUND(AVG(total_area) :: NUMERIC, 2) AS avg_area,
	MAX(total_area) AS max_area,
	MIN(total_area) AS min_area,
    ROUND(AVG(metr_price) :: NUMERIC, 2) AS avg_metr_price,
    MAX(metr_price) AS max_metr_price,
    MIN(metr_price) AS min_metr_price,
    ROUND(AVG(rooms) :: NUMERIC, 2) AS avg_rooms,
    MAX(rooms) AS max_rooms,
    MIN(rooms) AS min_rooms,
    ROUND(AVG(balcony) :: NUMERIC, 2) AS avg_balcony,
    MAX(balcony) AS max_balcony,
    MIN(balcony) AS min_balcony
FROM group_city_days
GROUP BY region, activity_period
ORDER BY region


-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
first_last_month AS (
SELECT
    fi.id,
    EXTRACT(YEAR FROM a.first_day_exposition) AS year,
    DATE_TRUNC('month', a.first_day_exposition) :: DATE AS first_month,
    DATE_TRUNC('month', a.first_day_exposition + a.days_exposition :: int) :: DATE AS last_month,
    f.total_area,
    a.last_price/f.total_area AS metr_price
 FROM real_estate.advertisement AS a 
 JOIN real_estate.flats AS f USING(id)
 RIGHT JOIN real_estate.TYPE AS t USING(type_id)
 FULL JOIN filtered_id AS fi ON fi.id=f.id
 WHERE t.TYPE = 'город'
 ),
 last_month_info AS (
 SELECT 
    RANK() OVER(ORDER BY COUNT(id) ASC) AS rank_month,
    last_month,
    COUNT(id) AS total_adv,
    ROUND(COUNT(id)/(SELECT COUNT(*) FROM first_last_month) :: NUMERIC,2 ) AS perc_total_adv,
    ROUND(AVG(metr_price) :: NUMERIC, 2) AS avg_metr_price,
    ROUND(AVG(total_area) :: NUMERIC, 2) AS avg_area
 FROM first_last_month
 WHERE last_month BETWEEN '2015-01-01' AND '2018-12-01' 
       AND last_month IS NOT NULL
 GROUP BY last_month
 ORDER BY last_month
 ),
first_month_info AS (
 SELECT
    RANK() OVER(ORDER BY COUNT(id) ASC) AS rank_month,
    first_month,
    COUNT(id) AS total_adv,
    ROUND(COUNT(id)/(SELECT COUNT(*) FROM first_last_month) :: NUMERIC,2 ) AS perc_total_adv,
    ROUND(AVG(metr_price) :: NUMERIC, 2) AS avg_metr_price,
    ROUND(AVG(total_area) :: NUMERIC, 2) AS avg_area
 FROM first_last_month
 WHERE first_month BETWEEN '2015-01-01' AND '2018-12-01'
 GROUP BY first_month
 ORDER BY first_month
 )
 SELECT
 *
 FROM last_month_info AS li
 FULL JOIN first_month_info AS fi ON li.last_month=fi.first_month

### ДАЛЕЕ ОПИСАНИЕ ВЫПОЛНЕННОГО АНАЛИЗА


Проект первого модуля: анализ данных для агентства недвижимости
Автор:  Галыгин Дмитрий
Дата: 01.10.2025


Задача 1. Время активности объявлений
Чтобы спланировать эффективную бизнес-стратегию на рынке недвижимости, заказчику нужно определить — по времени активности объявления — самые привлекательные для работы сегменты недвижимости Санкт-Петербурга и городов Ленинградской области.
Проанализируйте результаты и опишите их. Ответы на такие вопросы:
1. Какие категории объявлений являются самыми распространёнными в Санкт-Петербурге и городах Ленинградской области?
Напишите ваш ответ здесь
Хочу начать с того, что все данные с которыми я работал и по которым делал следующие выводы, были отфильтрованы от аномальных/неадекватных для наших расчетов значений в колонках: кол-ва балконов, кол-во комнат, площади и высоты потолка. 
Так же были взяты значения исключительно типа населенного пункта – «город» и в период с 2015 по 2018 года включительно.
По длительности:
1.1.	ЛенОбл: 
— по категории «более полугода»- 873 
— по категории «до трех месяцев» - 858
— по категории «полгода» - 553
— по категории «до месяца» - 348
— по категории «активные объявления» - 198
Таблица с количеством объявлений и процентным соотношением от общего числа объявлений  
1.2.	Подобная градация у объявлений Санкт-Петербурга:
— по категории «более полугода»- 3506
— по категории «до трех месяцев» - 2991
— по категории «полгода» - 2244
— по категории «до месяца» - 1823
— по категории «активные объявления» - 653
Таблица с количеством объявлений и процентным соотношением оттобщего числа объявлений
 
2.	Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, количество комнат и балконов и другие параметры, влияют на время активности объявлений? Как эти зависимости варьируют между регионами?
Напишите ваш ответ здесь
Напрямую на длительность объявлений влияют все максимумы, кроме балконов и комнат, их градация повторяет градацию времени активности объявлений.
Максимальная и минимальная стоимость квартир существенно отличаются, особенно максимальные стоимости: у ЛенОбл- 29 500 000 р, у С-П – 330 000 000р, минимальные стоимости отличаются примерно в 3 раза в сторону С-П, соответственно так же и стоимость одного квадратного метра больше у С-П. Но при этом квадратура отличается не намного.
Хочу добавить, что по средней цене за квартиру категория « активных объявлений» является топовой, хотя при этом макисмальная цена почти самая низкая из всех, а вот минимальная цена, наоборот- самая высокая. Аналогичная ситуация со стоимостью за метр. А вот все критерии площади у этой категории самые высокие, и по количеству комнат в среднем более 2, то есть скорее всего это трехкомнатные квартиры (преимузестенно), значит можно вывести гипотезу о том, что такие квартиры продаются хуже.
3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?
Напишите ваш ответ здесь
Если рассмотреть каждую область в отдельности, то по процентным соотношениям категорий объявлений они очень близки, как и по многим параметрам, кроме одного- стоимости квартиры (ну и стоимость одного метра кв. соответственно) Тут мои мысли остаются без изменений
Задача 2. Сезонность объявлений
Заказчику важно понять сезонные тенденции на рынке недвижимости Санкт-Петербурга и Ленинградской области — то есть для всего региона, чтобы выявить периоды с повышенной активностью продавцов и покупателей недвижимости. Это поможет спланировать маркетинговые кампании и выбрать сроки для выхода на рынок.
Проанализируйте результаты и опишите их. Ответы на такие вопросы:
1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? А в какие — по снятию? Это показывает динамику активности покупателей.
Напишите ваш ответ здесь
В этой части работы так же все данные с которыми я работал и по которым делал следующие выводы, были отфильтрованы от аномальных/неадекватных для наших расчетов значений в колонках: кол-ва балконов, кол-во комнат, площади и высоты потолка.
1.1.	По публикации объявлений топовый месяц: февраль 2018- 836 объявлений, минимальное количество объявлений: апрель 2015 – 38 объявлений

1.2.	По снятию объявлений топовй месяц: январь 2018 – 740 объявлений, минимальное количество объявлений: декабрь 2016 – 75 объявлений

Топ-5 по месяцев по количеству снятых объявлений:

Антитоп-5 месяцев по количеству снятых объявлений:
 
2. Совпадают ли периоды активной публикации объявлений и периоды, когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
Напишите ваш ответ здесь
Слева таблица с топ-10 месяцами по снятию,  а справа эти же месяца, но с информацией по публикации объявлений (ранжирование месяцев происходило по принципу количества объявлений в месяце)
   
Можно сказать, что зависимость в периоде есть, топу объявлений по снятию соответсвует 6 позиций из топа публикации, это больше 50%, но честно говря, не заню что с эьтой информацией делать дальше)
3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? Что можно сказать о зависимости этих параметров от месяца?
Напишите ваш ответ здесь
Анализируя месяца по снятию объявления по причине продажи квартиры: средняя стоимость за кв. метр варьируется от  94679.86 р. До 109 619.76 р, но при этом цен разбросаны по месяцами закономерности нет,  выделяется только январь 2017 – 126 508.08 р. По площади ситуация такая же как и с ценой за кв. метр, ценник равномерно «гуляет» по месяцам.
Аналогична ситуация и с месяцами публикации объявлений на продажу
Общие выводы и рекомендации
Исходя из результатов анализа: нет зависимости в продаже по месяцам и одинаковому процентному соотношению категорий по длительности жизни объявлений, но существенной разницы в цене по продаже квартир. Я сделал вывод, что лучше заниматься продажей квартир в С-П, так как это банально выгоднее, если конечно затраты на рекламу и продвижении этих объявлений так же не кратно больше, чем у ЛенОбл. Соответственно. Если сам процесс продажи не кратно затрате и профит от этого намного больше, то лучше заниматься продажей квартир в С-П.
Хочу добавить, исходя из пункта 2.2. можно вывести гипотезу: если есть засисимоть периода продаж и публикации, то можно попробовтаь публиковать объявлегния заранее до периоодов продажи, чтобы подготовитть почву заранее, возможно так процесс продажи будет более контролируемый и управляемый.

