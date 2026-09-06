# Источники локальных ресурсов

Карты Земли: Solar System Scope / INOVE, на основе данных NASA, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). [Источник и условия](https://edu.solarsystemscope.com/textures/). Загружены 5 сентября 2026. Исходники 8192 × 4096; при загрузке преобразуются в RGBA и уменьшаются до 4096 × 2048 для GPU. Цвет и освещение изменяются шейдером.

| Файл | Источник |
|---|---|
| earth-day.jpg | https://edu.solarsystemscope.com/textures/download/8k_earth_daymap.jpg |
| earth-night.jpg | https://edu.solarsystemscope.com/textures/download/8k_earth_nightmap.jpg |
| earth-clouds.jpg | https://edu.solarsystemscope.com/textures/download/8k_earth_clouds.jpg |
| moon.jpg | https://svs.gsfc.nasa.gov/vis/a000000/a004700/a004720/lroc_color_2k.jpg |

Текстуры локальные, не обновляются в реальном времени. IP-геолокация отдельно обращается к ipwho.is.

Луна: NASA Scientific Visualization Studio / Ernie Wright; NASA/GSFC/Arizona State University, LRO/LROC and LOLA data. [CGI Moon Kit, описание и полные credits](https://svs.gsfc.nasa.gov/4720/).

Материалы NASA в общем случае не защищены авторским правом в США и могут использоваться с соблюдением опубликованных условий и отдельных сторонних credits. Это не лицензия MIT на изображения. Сохраняйте атрибуцию и не создавайте впечатления одобрения продукта NASA. Логотипы NASA в проект не включены. [Правила NASA Images and Media](https://www.nasa.gov/nasa-brand-center/images-and-media/).

Звёзды, Млечный Путь и атмосферное свечение вычисляются шейдером проекта, сторонних изображений не используют. День/ночь — математическое приближение по [NOAA General Solar Position Calculations](https://www.gml.noaa.gov/grad/solcalc/solareqns.PDF). Текстуры не являются актуальными наблюдениями.

При замене карт используйте equirectangular изображение с севером сверху и Гринвичем в центре. День/ночь/облака должны совпадать по долготе. После изменения ресурсов пересоберите bundle, чтобы обновить подпись.
