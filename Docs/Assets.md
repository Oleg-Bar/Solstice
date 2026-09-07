# Источники локальных ресурсов

Карты Земли: Solar System Scope / INOVE, на основе данных NASA, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). [Источник и условия](https://edu.solarsystemscope.com/textures/). Загружены 5 сентября 2026. Исходники 8192 × 4096; при загрузке преобразуются в RGBA и уменьшаются до 4096 × 2048 для GPU. При диаметре Земли около 2016 пикселей на экране 5K это даёт примерно один texel на пиксель видимой полусферы, сохраняя экранную детализацию и заметно снижая память по сравнению с 6K-картами. Цвет и освещение изменяются шейдером.

| Файл | Источник |
|---|---|
| earth-day.jpg | https://edu.solarsystemscope.com/textures/download/8k_earth_daymap.jpg |
| earth-night.jpg | https://edu.solarsystemscope.com/textures/download/8k_earth_nightmap.jpg |
| earth-clouds.jpg | https://edu.solarsystemscope.com/textures/download/8k_earth_clouds.jpg |
| moon.jpg | https://svs.gsfc.nasa.gov/vis/a000000/a004700/a004720/lroc_color_2k.jpg |
| milky-way.jpg | https://cdn.eso.org/images/large/eso0932a.jpg |

Текстуры локальные, не обновляются в реальном времени. IP-геолокация отдельно обращается к ipwho.is.

Луна: NASA Scientific Visualization Studio / Ernie Wright; NASA/GSFC/Arizona State University, LRO/LROC and LOLA data. [CGI Moon Kit, описание и полные credits](https://svs.gsfc.nasa.gov/4720/). Карта 2048 × 1024 даёт около 1024 texel на видимую полусферу; при физическом размере Луны в текущей 5K-композиции её диск занимает примерно 550 пикселей, поэтому текстура имеет почти двукратный запас.

Материалы NASA в общем случае не защищены авторским правом в США и могут использоваться с соблюдением опубликованных условий и отдельных сторонних credits. Это не лицензия MIT на изображения. Сохраняйте атрибуцию и не создавайте впечатления одобрения продукта NASA. Логотипы NASA в проект не включены. [Правила NASA Images and Media](https://www.nasa.gov/nasa-brand-center/images-and-media/).

Млечный Путь: панорама всего неба 6000 × 3000, ESO/S. Brunier, [страница изображения](https://www.hq.eso.org/public/images/eso0932a/), [CC BY 4.0](https://www.eso.org/public/outreach/copyright/). Панорама слегка повёрнута, приглушена и смешана с процедурными звёздами; обязательная подпись источника выводится в правом нижнем углу сцены.

Дополнительные звёзды и атмосферное свечение вычисляются шейдером проекта. День/ночь — математическое приближение по [NOAA General Solar Position Calculations](https://www.gml.noaa.gov/grad/solcalc/solareqns.PDF). Текстуры не являются актуальными наблюдениями.

При замене карт используйте equirectangular изображение с севером сверху и Гринвичем в центре. День/ночь/облака должны совпадать по долготе. После изменения ресурсов пересоберите bundle, чтобы обновить подпись.
